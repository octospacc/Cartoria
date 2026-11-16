import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fs_shim/fs_shim.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../util/fs_walk.dart';
import 'git_blob.dart';
import 'offloaded_store.dart';
import 'sync_config.dart';
import 'sync_provider.dart';
import 'sync_scope.dart';

/// Short-hash for status lines: `"sha a1b2c3d"`, or null when the SHA is
/// absent (first-ever sync, or empty repo).
String? _shortSha(String? sha) {
  if (sha == null || sha.isEmpty) return null;
  final s = sha.length > 7 ? sha.substring(0, 7) : sha;
  return 'sha $s';
}

class SyncPushResult {
  /// Files the push created on the remote (didn't exist there before).
  final int created;

  /// Files the push overwrote on the remote (existed, content differed).
  final int updated;

  /// Files the push removed from the remote.
  final int deleted;

  final int skippedLarge;
  final int skippedOffloaded;
  final String commitSha;

  const SyncPushResult({
    required this.created,
    required this.updated,
    required this.deleted,
    required this.skippedLarge,
    this.skippedOffloaded = 0,
    required this.commitSha,
  });

  /// Human-readable one-line summary for UI status lines.
  String get summary {
    final parts = <String>[
      '$created created',
      '$updated updated',
      '$deleted deleted',
    ];
    if (skippedLarge > 0) parts.add('$skippedLarge skipped (large)');
    if (skippedOffloaded > 0) parts.add('$skippedOffloaded offloaded');
    final sha = _shortSha(commitSha);
    return 'Pushed: ${parts.join(', ')}${sha != null ? ' · $sha' : ''}';
  }
}

class SyncPullResult {
  /// Files downloaded that did not exist locally before.
  final int added;

  /// Local files overwritten by the remote version.
  final int updated;

  /// Non-drive files removed from local disk (posts, space.json,
  /// drive_meta.json, hooks). This is the "did it eat my posts?" counter.
  final int deletedNonDrive;

  /// Drive blobs removed from local disk.
  final int deletedDrive;

  /// Files moved from local disk to remote-only (offload policy).
  final int offloaded;

  /// Head commit SHA at pull time, or null when it couldn't be read.
  final String? commitSha;

  const SyncPullResult({
    required this.added,
    required this.updated,
    this.deletedNonDrive = 0,
    this.deletedDrive = 0,
    this.offloaded = 0,
    this.commitSha,
  });

  int get deleted => deletedNonDrive + deletedDrive;

  /// Human-readable one-line summary for UI status lines.
  String get summary {
    final parts = <String>[
      '$added added',
      '$updated updated',
      '$deleted deleted ($deletedNonDrive posts, $deletedDrive blobs)',
    ];
    if (offloaded > 0) parts.add('$offloaded offloaded');
    final sha = _shortSha(commitSha);
    return 'Pulled: ${parts.join(', ')}${sha != null ? ' · $sha' : ''}';
  }
}

/// A pending change tracked between pass 1 (SHA computation) and pass 2
/// (byte loading + commit). Holds only metadata — no file bytes.
class _PendingChange {
  final String path;
  final FileChangeKind kind;
  final int size;
  const _PendingChange({
    required this.path,
    required this.kind,
    required this.size,
  });
}

class SyncService {
  final FileSystem fs;
  final String vaultPath;
  final SyncConfig config;
  final SyncProvider provider;
  final SyncCacheStore? cacheStore;
  final SyncScope scope;

  const SyncService({
    required this.fs,
    required this.vaultPath,
    required this.config,
    required this.provider,
    this.cacheStore,
    required this.scope,
  });

  static const _excludedFiles = {'sync.json', '.DS_Store', 'Thumbs.db'};
  static const _maxFileBytes = 20 * 1024 * 1024;

  /// Web downloads run at lower concurrency because each in-flight
  /// request holds its full response in memory (BrowserClient buffers
  /// rather than streams) and iOS Safari's heap is much tighter.
  static int get _phase1Concurrency => kIsWeb ? 2 : 8;

  /// Timer-based yield for WebKit GC. `Duration.zero` schedules a
  /// microtask that the timer-driven collector never sees — only a
  /// real timer allows collection to run. 20 ms is small enough to be
  /// unnoticeable per call and long enough to trigger collection.
  static Future<void> _gcYield() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  // ── Push ───────────────────────────────────────────────────────────────

  Future<SyncPushResult> push({
    required String token,
    SyncProgressCallback? onProgress,
    required OffloadedStore offloadedStore,
  }) async {
    onProgress?.call(const SyncProgress(
      totalFiles: 0,
      completedFiles: 0,
      isPush: true,
      message: 'Checking remote…',
    ));
    final remoteMap = await _remoteListing(
      token: token,
      isPush: true,
      onProgress: onProgress,
    );

    onProgress?.call(const SyncProgress(
      totalFiles: 0,
      completedFiles: 0,
      isPush: true,
      message: 'Scanning local files…',
    ));
    final localInfos = await _collectLocalFileInfo();

    final offloadedByPath = await _buildOffloadedByPath(
      remoteMap: remoteMap,
      offloadedStore: offloadedStore,
    );

    // Diff: local vs remote.
    final pendingChanges = <_PendingChange>[];
    var skippedLarge = 0;
    var skippedOffloaded = 0;

    for (final entry in localInfos.entries) {
      final path = entry.key;
      if (!scope.includes(path)) continue;
      final info = entry.value;
      if (info.size > _maxFileBytes) {
        skippedLarge++;
        continue;
      }
      final remoteSha = remoteMap[path];
      if (remoteSha == info.sha) continue;
      pendingChanges.add(_PendingChange(
        path: path,
        kind: remoteSha == null ? FileChangeKind.create : FileChangeKind.update,
        size: info.size,
      ));
    }

    for (final path in remoteMap.keys) {
      if (!scope.includes(path)) continue;
      if (localInfos.containsKey(path)) continue;
      if (offloadedByPath.containsKey(path)) {
        skippedOffloaded++;
        continue;
      }
      pendingChanges.add(_PendingChange(
        path: path,
        kind: FileChangeKind.delete,
        size: 0,
      ));
    }

    if (pendingChanges.isEmpty) {
      onProgress?.call(SyncProgress(
        totalFiles: 1,
        completedFiles: 1,
        isPush: true,
        message: 'Nothing to push'
            '${skippedLarge > 0 ? " ($skippedLarge large files skipped)" : ""}'
            '${skippedOffloaded > 0 ? " ($skippedOffloaded offloaded)" : ""}',
      ));
      return SyncPushResult(
        created: 0, updated: 0, deleted: 0,
        skippedLarge: skippedLarge,
        skippedOffloaded: skippedOffloaded,
        commitSha: config.lastCommitSha ?? '',
      );
    }

    // Pass 2: load bytes and commit. The provider owns internal
    // batching — GitLab splits large batches into sub-batches and
    // reports their progress; GitHub uploads blobs individually then
    // creates one tree. Doing our own batching AND letting the provider
    // batch produced doubly-suffixed commit messages like "(5/6) (1/2)".
    onProgress?.call(SyncProgress(
      totalFiles: pendingChanges.length,
      completedFiles: 0,
      isPush: true,
      message: 'Uploading ${pendingChanges.length} '
          'change${pendingChanges.length == 1 ? "" : "s"}…',
    ));

    final fileChanges = <FileChange>[];
    for (final c in pendingChanges) {
      if (c.kind == FileChangeKind.delete) {
        fileChanges.add(FileChange.delete(c.path));
        continue;
      }
      try {
        final bytes = await fs.file(p.join(vaultPath, c.path)).readAsBytes();
        fileChanges.add(c.kind == FileChangeKind.create
            ? FileChange.create(c.path, bytes)
            : FileChange.update(c.path, bytes));
      } catch (e) {
        debugPrint('Could not read ${c.path} for push: $e');
      }
      if (kIsWeb) await _gcYield();
    }

    if (fileChanges.isEmpty) {
      return SyncPushResult(
        created: 0, updated: 0, deleted: 0,
        skippedLarge: skippedLarge,
        skippedOffloaded: skippedOffloaded,
        commitSha: config.lastCommitSha ?? '',
      );
    }

    final newSha = await provider.commit(
      config: config,
      token: token,
      message: 'Vault sync ${DateTime.now().toUtc().toIso8601String()}',
      changes: fileChanges,
      onProgress: onProgress,
    );

    final created = fileChanges
        .where((c) => c.kind == FileChangeKind.create).length;
    final updated = fileChanges
        .where((c) => c.kind == FileChangeKind.update).length;
    final deleted = fileChanges
        .where((c) => c.kind == FileChangeKind.delete).length;

    // Cache update with the new full remote state.
    final newCacheFiles = <String, String>{...remoteMap};
    for (final c in pendingChanges) {
      if (c.kind == FileChangeKind.delete) {
        newCacheFiles.remove(c.path);
      } else {
        final sha = localInfos[c.path]?.sha;
        if (sha != null && sha.isNotEmpty) {
          newCacheFiles[c.path] = sha;
        }
      }
    }
    if (newSha.isNotEmpty) {
      await cacheStore?.save(config.cacheKey, newCacheFiles, newSha);
    }

    // Apply the offload policy after the commit — every file the policy
    // might remove is now confirmed on the remote. Uses the SHAs already
    // computed by `_collectLocalFileInfo`, so no re-hashing.
    if (config.keepLocalFileCount != null) {
      await _applyOffloadPolicy(
        remoteMap: newCacheFiles,
        offloadedStore: offloadedStore,
        localInfos: localInfos,
      );
    }

    onProgress?.call(SyncProgress(
      totalFiles: pendingChanges.length,
      completedFiles: pendingChanges.length,
      isPush: true,
      message: 'Pushed: $created created, $updated updated, '
          '$deleted deleted',
    ));

    return SyncPushResult(
      created: created,
      updated: updated,
      deleted: deleted,
      skippedLarge: skippedLarge,
      skippedOffloaded: skippedOffloaded,
      commitSha: newSha,
    );
  }

  // ── Pull ───────────────────────────────────────────────────────────────

  Future<SyncPullResult> pull({
    required String token,
    SyncProgressCallback? onProgress,
    required OffloadedStore offloadedStore,
  }) async {
    onProgress?.call(const SyncProgress(
      totalFiles: 0,
      completedFiles: 0,
      isPush: false,
      message: 'Checking remote…',
    ));
    final remoteMap = await _remoteListing(
      token: token,
      isPush: false,
      onProgress: onProgress,
    );

    final inScope = <String, String>{};
    for (final e in remoteMap.entries) {
      if (scope.includes(e.key)) inScope[e.key] = e.value;
    }
    if (inScope.isEmpty) {
      onProgress?.call(const SyncProgress(
        totalFiles: 0,
        completedFiles: 0,
        isPush: false,
        message: 'Nothing in scope on the remote.',
      ));
      return const SyncPullResult(
        added: 0, updated: 0, deletedNonDrive: 0, deletedDrive: 0,
      );
    }

    onProgress?.call(const SyncProgress(
      totalFiles: 0,
      completedFiles: 0,
      isPush: false,
      message: 'Scanning local files…',
    ));

    // SHA-only map of non-drive files. Drive files are resolved from
    // directory listing in phase 2 — reading their bytes during the
    // scan was the primary source of iOS Safari OOM.
    final localShas = await _collectLocalFileShas();

    // Was: var pulled = 0; var deleted = 0; var offloadedCount = 0;
    var added = 0;
    var updated = 0;
    var deletedNonDrive = 0;
    var deletedDrive = 0;
    var offloadedCount = 0;

    // ── Phase 1: non-drive files (posts, metadata, hooks) ────────────────
    final toDownload = <MapEntry<String, String>>[];
    for (final entry in inScope.entries) {
      if (_isDrivePath(entry.key)) continue;
      if (localShas[entry.key] == entry.value) continue;
      toDownload.add(entry);
    }

    // Pre-create parent directories so parallel workers never race on
    // create(recursive: true) for the same parent.
    final dirs = <String>{};
    for (final entry in toDownload) {
      dirs.add(p.dirname(p.join(vaultPath, entry.key)));
    }
    for (final dir in dirs) {
      await fs.directory(dir).create(recursive: true);
    }

    final failures = <String, Object>{};
    var phase1Completed = 0;

    await _parallelForEach<MapEntry<String, String>>(
      items: toDownload,
      concurrency: _phase1Concurrency,
      body: (entry) async {
        try {
          final bytes = await _downloadWithRetry(
            token: token, path: entry.key,
          );
          final dest = p.join(vaultPath, entry.key);
          await fs.file(dest).writeAsBytes(bytes);
          // `localShas` was captured before any writes, so "was it
          // there before?" is a faithful new-vs-overwrite signal.
          if (localShas.containsKey(entry.key)) {
            updated++;
          } else {
            added++;
          }
          phase1Completed++;
          onProgress?.call(SyncProgress(
            totalFiles: inScope.length,
            completedFiles: added + updated,
            isPush: false,
            message: 'Downloading ${entry.key} '
                '($phase1Completed/${toDownload.length})',
          ));
        } finally {
          if (kIsWeb) await _gcYield();
        }
      },
      onError: (entry, err) {
        failures[entry.key] = err;
        debugPrint('Failed to download ${entry.key}: $err');
      },
    );

    if (toDownload.isNotEmpty && failures.length == toDownload.length) {
      throw StateError('All ${toDownload.length} file downloads failed. '
          'First error: ${failures.values.first}');
    }
    if (failures.isNotEmpty) {
      debugPrint('Pull completed with ${failures.length}/${toDownload.length} '
          'file download(s) failed; they will be retried on next pull.');
    }

    // ── Phase 2: drive files, policy-aware ───────────────────────────────
    final scopeSpaces = <String>{};
    for (final path in inScope.keys) {
      if (!_isDrivePath(path)) continue;
      final slash = path.indexOf('/');
      if (slash > 0) scopeSpaces.add(path.substring(0, slash));
    }

    for (final spaceId in scopeSpaces) {
      final meta = await _readDriveMeta(spaceId);
      final sortedIds = meta.keys.toList()
        ..sort((a, b) {
          final ca = (meta[a] as Map)['created'] as String? ?? '';
          final cb = (meta[b] as Map)['created'] as String? ?? '';
          return cb.compareTo(ca);
        });

      final keepCount = config.keepLocalFileCount;
      final keepIds = keepCount == null
          ? sortedIds.toSet()
          : sortedIds.take(keepCount).toSet();

      final offloaded = await offloadedStore.load(spaceId);
      var offloadedChanged = false;
      final driveDir = fs.directory(p.join(vaultPath, spaceId, 'drive'));
      final pathMap = await _resolveDrivePaths(driveDir);

      var filesSinceYield = 0;
      for (final id in sortedIds) {
        try {
          final localPath = pathMap[id];
          final remotePath = localPath != null
              ? '$spaceId/drive/${p.basename(localPath)}'
              : _findRemotePathForId(inScope, spaceId, id);
          if (remotePath == null) continue;
          final remoteSha = inScope[remotePath];
          if (remoteSha == null) continue;

          if (keepIds.contains(id)) {
            // Fast path: file on disk and matching remote.
            if (localPath != null) {
              try {
                final bytes = await fs.file(localPath).readAsBytes();
                if (gitBlobSha(bytes) == remoteSha) {
                  if (offloaded.remove(id) != null) {
                    offloadedChanged = true;
                  }
                  continue; // finally block runs the yield
                }
              } catch (_) {}
            }
            // Download.
            final existed = localPath != null;
            onProgress?.call(SyncProgress(
              totalFiles: inScope.length,
              completedFiles: added + updated,
              isPush: false,
              message: 'Downloading drive/$id',
            ));
            final bytes = await provider.downloadFile(
              config: config, token: token, path: remotePath,
            );
            final metaEntry = meta[id] as Map? ?? const {};
            final name = (metaEntry['name'] as String?) ?? id;
            final ext = _sanitizedExt(name);
            final diskName = ext.isEmpty ? id : '$id.$ext';
            final dest = p.join(vaultPath, spaceId, 'drive', diskName);
            await fs.directory(p.dirname(dest)).create(recursive: true);
            await fs.file(dest).writeAsBytes(bytes);
            pathMap[id] = dest;
            if (offloaded.remove(id) != null) offloadedChanged = true;
            if (existed) {
              updated++;
            } else {
              added++;
            }
          } else {
            // Offload.
            var size = offloaded[id]?.size ?? 0;
            if (localPath != null) {
              try {
                size = (await fs.file(localPath).stat()).size;
                await fs.file(localPath).delete();
                pathMap.remove(id);
              } catch (_) {}
            }
            offloaded[id] = OffloadedFileInfo(remoteSha: remoteSha, size: size);
            offloadedChanged = true;
            offloadedCount++;
          }
        } finally {
          filesSinceYield++;
          if (kIsWeb && filesSinceYield >= 3) {
            filesSinceYield = 0;
            await _gcYield();
          }
        }
      }

      // Prune offloaded entries no longer in meta.
      final toRemove = <String>[];
      for (final id in offloaded.keys) {
        if (!meta.containsKey(id)) toRemove.add(id);
      }
      for (final id in toRemove) {
        offloaded.remove(id);
        offloadedChanged = true;
      }

      if (offloadedChanged) {
        await offloadedStore.save(spaceId, offloaded);
      }
    }

    // ── Phase 3a: non-drive files absent from the remote ─────────────────
    for (final path in localShas.keys) {
      if (!scope.includes(path)) continue;
      if (inScope.containsKey(path)) continue;
      if (_isExcluded(path)) continue;
      final file = fs.file(p.join(vaultPath, path));
      if (await file.exists()) {
        await file.delete();
        deletedNonDrive++;
      }
    }

    // ── Phase 3b: drive files absent from the remote ─────────────────────
    // Not covered by `localShas` (drive files are skipped in the scan),
    // so walk each space's drive directory directly.
    for (final spaceId in scopeSpaces) {
      final driveDir = fs.directory(p.join(vaultPath, spaceId, 'drive'));
      if (!await driveDir.exists()) continue;
      final pathMap = await _resolveDrivePaths(driveDir);
      for (final id in pathMap.keys.toList()) {
        final localPath = pathMap[id]!;
        final remotePath = '$spaceId/drive/${p.basename(localPath)}';
        if (inScope.containsKey(remotePath)) continue;
        try {
          await fs.file(localPath).delete();
          deletedDrive++;
        } catch (_) {}
        final offloaded = await offloadedStore.load(spaceId);
        if (offloaded.remove(id) != null) {
          await offloadedStore.save(spaceId, offloaded);
        }
      }
    }

    final head = await provider.currentHeadSha(config: config, token: token);
    await cacheStore?.save(config.cacheKey, remoteMap, head);

    onProgress?.call(SyncProgress(
      totalFiles: inScope.length,
      completedFiles: added + updated,
      isPush: false,
      message: 'Pulled: $added added, $updated updated, '
          '$deletedNonDrive posts deleted, $deletedDrive blobs deleted, '
          '$offloadedCount offloaded',
    ));
    return SyncPullResult(
      added: added,
      updated: updated,
      deletedNonDrive: deletedNonDrive,
      deletedDrive: deletedDrive,
      offloaded: offloadedCount,
      commitSha: head,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  /// Scans all local files (including drive) and returns size + SHA.
  /// Uses the mtime-keyed SHA cache to skip re-hashing unchanged files,
  /// and skips reading files above `_maxFileBytes` entirely.
  Future<Map<String, ({String sha, int size})>> _collectLocalFileInfo() async {
    final cached = await cacheStore?.loadLocalShas(config.cacheKey) ?? const {};

    final out = <String, ({String sha, int size})>{};
    final updated = <String, ({int size, DateTime mtime, String sha})>{};
    final root = fs.directory(vaultPath);
    if (!await root.exists()) return out;

    final files = await walkFiles(root);
    var sinceYield = 0;
    var reused = 0;
    var rescanned = 0;

    for (final f in files) {
      final rel = p.relative(f.path, from: vaultPath);
      if (_isExcluded(rel)) continue;
      try {
        final stat = await f.stat();

        // Too large to ever sync. Report size with an empty SHA so the
        // diff loop's `_maxFileBytes` check trips and skips it, and the
        // deletion loop sees it as present (never deleted).
        if (stat.size > _maxFileBytes) {
          out[rel] = (sha: '', size: stat.size);
          continue;
        }

        final entry = cached[rel];
        if (entry != null &&
            entry.size == stat.size &&
            entry.mtime == stat.modified) {
          out[rel] = (sha: entry.sha, size: stat.size);
          updated[rel] = entry;
          reused++;
        } else {
          final bytes = await f.readAsBytes();
          final sha = gitBlobSha(bytes);
          out[rel] = (sha: sha, size: stat.size);
          updated[rel] = (size: stat.size, mtime: stat.modified, sha: sha);
          rescanned++;
        }
      } catch (_) {}
      sinceYield++;
      if (kIsWeb && sinceYield >= 30) {
        sinceYield = 0;
        await _gcYield();
      }
    }

    await cacheStore?.saveLocalShas(config.cacheKey, updated);
    debugPrint('Push scan: $reused reused, $rescanned rescanned');
    return out;
  }

  /// SHA-only scan for pull. Skips drive files (handled in phase 2),
  /// uses the mtime-keyed SHA cache to avoid re-reading unchanged
  /// non-drive files, and preserves drive entries from the previous
  /// cache (populated by the last push).
  Future<Map<String, String>> _collectLocalFileShas() async {
    final cached = await cacheStore?.loadLocalShas(config.cacheKey) ?? const {};

    final out = <String, String>{};
    final updated = <String, ({int size, DateTime mtime, String sha})>{};
    final root = fs.directory(vaultPath);
    if (!await root.exists()) return out;

    final files = await walkFiles(root);
    var sinceYield = 0;
    var reused = 0;
    var rescanned = 0;

    for (final f in files) {
      final rel = p.relative(f.path, from: vaultPath);
      if (_isExcluded(rel)) continue;
      if (_isDrivePath(rel)) continue;
      try {
        final stat = await f.stat();
        final entry = cached[rel];
        if (entry != null &&
            entry.size == stat.size &&
            entry.mtime == stat.modified) {
          out[rel] = entry.sha;
          updated[rel] = entry;
          reused++;
        } else {
          final bytes = await f.readAsBytes();
          final sha = gitBlobSha(bytes);
          out[rel] = sha;
          updated[rel] = (size: stat.size, mtime: stat.modified, sha: sha);
          rescanned++;
        }
      } catch (_) {}
      sinceYield++;
      if (kIsWeb && sinceYield >= 30) {
        sinceYield = 0;
        await _gcYield();
      }
    }

    // Preserve drive entries from the previous cache (populated by
    // push). Pull doesn't touch them, so re-saving them avoids forcing
    // a re-hash of all drive files on the next push.
    final merged = <String, ({int size, DateTime mtime, String sha})>{};
    for (final e in cached.entries) {
      if (_isDrivePath(e.key)) merged[e.key] = e.value;
    }
    merged.addAll(updated);
    await cacheStore?.saveLocalShas(config.cacheKey, merged);

    debugPrint('Pull scan: $reused reused, $rescanned rescanned, '
        '${merged.length - updated.length} drive entries preserved');
    return out;
  }

  /// Builds `path → remoteSha` for offloaded files, so push can
  /// distinguish "offloaded (skip)" from "genuinely deleted (remove)".
  Future<Map<String, String>> _buildOffloadedByPath({
    required Map<String, String> remoteMap,
    required OffloadedStore offloadedStore,
  }) async {
    final out = <String, String>{};
    final spaces = <String>{};
    for (final path in remoteMap.keys) {
      if (!scope.includes(path)) continue;
      final slash = path.indexOf('/');
      if (slash > 0) spaces.add(path.substring(0, slash));
    }
    for (final spaceId in spaces) {
      final info = await offloadedStore.load(spaceId);
      for (final e in info.entries) {
        final prefix = '$spaceId/drive/${e.key}';
        for (final remotePath in remoteMap.keys) {
          if (remotePath == prefix || remotePath.startsWith('$prefix.')) {
            out[remotePath] = e.value.remoteSha;
            break;
          }
        }
      }
    }
    return out;
  }

  /// Deletes local drive files beyond `keepLocalFileCount`, using
  /// `localInfos` (already-computed SHAs from `_collectLocalFileInfo`)
  /// to skip re-hashing. Saves offload records before deleting blobs,
  /// so a save failure preserves the files on disk rather than losing
  /// them without a record.
  Future<void> _applyOffloadPolicy({
    required Map<String, String> remoteMap,
    required OffloadedStore offloadedStore,
    required Map<String, ({String sha, int size})> localInfos,
  }) async {
    final keepCount = config.keepLocalFileCount;
    if (keepCount == null) return;

    final spaces = <String>{};
    for (final path in remoteMap.keys) {
      if (!scope.includes(path)) continue;
      final slash = path.indexOf('/');
      if (slash > 0) spaces.add(path.substring(0, slash));
    }

    for (final spaceId in spaces) {
      final meta = await _readDriveMeta(spaceId);
      if (meta.isEmpty) continue;

      final sortedIds = meta.keys.toList()
        ..sort((a, b) {
          final ca = (meta[a] as Map)['created'] as String? ?? '';
          final cb = (meta[b] as Map)['created'] as String? ?? '';
          return cb.compareTo(ca);
        });
      final keepIds = sortedIds.take(keepCount).toSet();

      final driveDir = fs.directory(p.join(vaultPath, spaceId, 'drive'));
      if (!await driveDir.exists()) continue;
      final pathMap = await _resolveDrivePaths(driveDir);

      final offloaded = await offloadedStore.load(spaceId);
      final pendingDeletes = <String, ({String remoteSha, int size})>{};

      for (final id in sortedIds) {
        if (keepIds.contains(id)) continue;
        if (offloaded.containsKey(id)) continue;
        final localPath = pathMap[id];
        if (localPath == null) continue;

        final remotePath = '$spaceId/drive/${p.basename(localPath)}';
        final remoteSha = remoteMap[remotePath];
        if (remoteSha == null) continue;

        // Use cached SHA from the scan — skips re-reading. If the local
        // content differs (unpushed local edit), preserve the file.
        final info = localInfos[remotePath];
        if (info == null) continue;
        if (info.sha != remoteSha) {
          debugPrint('Offload: skipping $remotePath — local SHA differs from '
              'remote (unpushed local edit)');
          continue;
        }

        pendingDeletes[id] = (remoteSha: remoteSha, size: info.size);
      }

      if (pendingDeletes.isEmpty) continue;

      // Save offload records FIRST. If the save fails, the local files
      // stay on disk (recovered on the next pull/push), which is
      // strictly better than deleting them without a record and having
      // the next push treat them as deletions from the remote.
      for (final e in pendingDeletes.entries) {
        offloaded[e.key] = OffloadedFileInfo(
          remoteSha: e.value.remoteSha,
          size: e.value.size,
        );
      }
      try {
        await offloadedStore.save(spaceId, offloaded);
      } catch (e) {
        debugPrint('Offload save failed for $spaceId; keeping local files: $e');
        // Roll back the in-memory additions so they match what's on disk.
        for (final id in pendingDeletes.keys) {
          offloaded.remove(id);
        }
        continue;
      }

      // Save succeeded — now safe to delete.
      for (final id in pendingDeletes.keys) {
        final localPath = pathMap[id];
        if (localPath == null) continue;
        try {
          await fs.file(localPath).delete();
        } catch (e) {
          debugPrint('Offload delete failed for $localPath: $e');
        }
        if (kIsWeb) await _gcYield();
      }
    }
  }

  /// Wraps a download in a per-attempt timeout and retries transient
  /// failures. A hung connection would otherwise block a phase-1 worker
  /// indefinitely.
  Future<Uint8List> _downloadWithRetry({
    required String token,
    required String path,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final bytes = await provider
            .downloadFile(config: config, token: token, path: path)
            .timeout(const Duration(seconds: 120));
        return bytes;
      } on SyncException catch (e) {
        lastError = e;
        final sc = e.statusCode;
        if (sc == 429 || sc == 403) {
          await Future<void>.delayed(Duration(seconds: 15 * (attempt + 1)));
          continue;
        }
        if (sc != null && sc >= 400 && sc < 500) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      } catch (e) {
        lastError = e;
        await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }
    throw lastError ?? StateError('Download failed for $path');
  }

  /// Runs [body] on each item with at most [concurrency] tasks in
  /// flight. Errors are passed to [onError] and do not stop the queue.
  Future<void> _parallelForEach<T>({
    required List<T> items,
    required int concurrency,
    required Future<void> Function(T) body,
    required void Function(T item, Object error) onError,
  }) async {
    if (items.isEmpty) return;
    var index = 0;
    final workers = List.generate(concurrency, (_) async {
      while (true) {
        final i = index++;
        if (i >= items.length) return;
        try {
          await body(items[i]);
        } catch (e) {
          onError(items[i], e);
        }
      }
    });
    await Future.wait(workers);
  }

  Future<Map<String, String>> _remoteListing({
    required String token,
    required bool isPush,
    SyncProgressCallback? onProgress,
  }) async {
    final head = await provider.currentHeadSha(config: config, token: token);
    final cache = await cacheStore?.load(config.cacheKey);
    if (head != null && cache != null && cache.commitSha == head) {
      onProgress?.call(SyncProgress(
        totalFiles: cache.files.length,
        completedFiles: cache.files.length,
        isPush: isPush,
        message: 'Using cached remote listing (${cache.files.length} files)',
      ));
      return cache.files;
    }
    return provider.listRemoteFiles(
      config: config,
      token: token,
      isPush: isPush,
      onProgress: onProgress,
    );
  }

  Future<Map<String, Map<String, dynamic>>> _readDriveMeta(
      String spaceId) async {
    final f = fs.file(p.join(vaultPath, spaceId, 'drive_meta.json'));
    if (!await f.exists()) return {};
    try {
      final raw = jsonDecode(await f.readAsString()) as Map;
      return raw.map(
          (k, v) => MapEntry(k as String, (v as Map).cast<String, dynamic>()));
    } catch (_) {
      return {};
    }
  }

  bool _isDrivePath(String path) => path.contains('/drive/');

  String? _findRemotePathForId(
    Map<String, String> inScope,
    String spaceId,
    String id,
  ) {
    final prefix = '$spaceId/drive/$id';
    for (final path in inScope.keys) {
      if (path == prefix || path.startsWith('$prefix.')) return path;
    }
    return null;
  }

  /// Single-scan resolution of a drive directory into an `id → path`
  /// map. Called once per space per phase; avoids the O(N²) directory
  /// enumeration that a per-file scan would produce.
  Future<Map<String, String>> _resolveDrivePaths(Directory driveDir) async {
    final out = <String, String>{};
    if (!await driveDir.exists()) return out;
    await for (final e in driveDir.list(followLinks: false)) {
      if (e is! File) continue;
      final base = p.basename(e.path);
      final dot = base.indexOf('.');
      final id = dot < 0 ? base : base.substring(0, dot);
      out[id] = e.path;
    }
    return out;
  }

  String _sanitizedExt(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == 0) return '';
    return name
        .substring(dot + 1)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  bool _isExcluded(String relPath) {
    if (_excludedFiles.contains(relPath)) return true;
    final first = relPath.split('/').first;
    return first == '.git';
  }
}
