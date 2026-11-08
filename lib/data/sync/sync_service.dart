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

class SyncPushResult {
  final int pushed;
  final int deleted;
  final int skippedLarge;
  final int skippedOffloaded;
  final String commitSha;
  const SyncPushResult({
    required this.pushed,
    required this.deleted,
    required this.skippedLarge,
    this.skippedOffloaded = 0,
    required this.commitSha,
  });
}

class SyncPullResult {
  final int pulled;
  final int deleted;
  final int offloaded;
  const SyncPullResult({
    required this.pulled,
    required this.deleted,
    this.offloaded = 0,
  });
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

  /// Max bytes of file content held in memory at once during push.
  /// Bounds the transient memory cost of the second pass; on iOS Safari
  /// even 30 MB starts to reach the tab budget when multiplied by
  /// platform overhead.
  static const _commitBatchMaxBytes = 10 * 1024 * 1024;

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

    // Pass 1: walk local files once, compute SHA + size, decide what
    // needs pushing. Only paths and hashes stay in memory — not bytes.
    final localInfos = await _collectLocalFileInfo();
    final offloadedByPath = await _buildOffloadedByPath(
      remoteMap: remoteMap,
      offloadedStore: offloadedStore,
    );

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

    // Deletes: remote paths absent locally. Files present locally (even
    // ones skipped for size) are NOT deleted remotely.
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
        pushed: 0,
        deleted: 0,
        skippedLarge: skippedLarge,
        skippedOffloaded: skippedOffloaded,
        commitSha: config.lastCommitSha ?? '',
      );
    }

    // Pass 2: batch by size, load bytes per batch, commit. Peak memory
    // is bounded by _commitBatchMaxBytes + overhead, not vault size.
    final batches = _batchChanges(pendingChanges);
    var newSha = config.lastCommitSha ?? '';
    var pushed = 0;
    var deleted = 0;
    var completed = 0;

    for (var i = 0; i < batches.length; i++) {
      final batch = batches[i];
      final fileChanges = <FileChange>[];

      for (final c in batch) {
        if (c.kind == FileChangeKind.delete) {
          fileChanges.add(FileChange.delete(c.path));
          continue;
        }
        try {
          final bytes = await fs.file(p.join(vaultPath, c.path)).readAsBytes();
          fileChanges.add(c.kind == FileChangeKind.create
              ? FileChange.create(c.path, bytes)
              : FileChange.update(c.path, bytes));
          // bytes goes out of scope after this iteration
        } catch (e) {
          debugPrint('Could not read ${c.path} for push: $e');
        }
      }
      if (fileChanges.isEmpty) continue;

      final message = batches.length == 1
          ? 'Vault sync ${DateTime.now().toUtc().toIso8601String()}'
          : 'Vault sync ${DateTime.now().toUtc().toIso8601String()} '
              '(${i + 1}/${batches.length})';

      newSha = await provider.commit(
        config: config,
        token: token,
        message: message,
        changes: fileChanges,
        onProgress: onProgress,
      );

      pushed +=
          fileChanges.where((c) => c.kind != FileChangeKind.delete).length;
      deleted +=
          fileChanges.where((c) => c.kind == FileChangeKind.delete).length;
      completed += fileChanges.length;

      onProgress?.call(SyncProgress(
        totalFiles: pendingChanges.length,
        completedFiles: completed,
        isPush: true,
        message: 'Committed ${i + 1}/${batches.length} — '
            '$completed/${pendingChanges.length} files',
      ));

      // Yield so GC can reclaim batch bytes before the next batch starts.
      await Future<void>.delayed(Duration.zero);
    }

    // Update cache with the new full remote state.
    final newCacheFiles = <String, String>{...remoteMap};
    for (final c in pendingChanges) {
      if (c.kind == FileChangeKind.delete) {
        newCacheFiles.remove(c.path);
      } else {
        final sha = localInfos[c.path]?.sha;
        if (sha != null) newCacheFiles[c.path] = sha;
      }
    }
    if (newSha.isNotEmpty) {
      await cacheStore?.save(config.cacheKey, newCacheFiles, newSha);
    }

    onProgress?.call(SyncProgress(
      totalFiles: pendingChanges.length,
      completedFiles: completed,
      isPush: true,
      message: 'Pushed: $pushed new/updated, $deleted deleted',
    ));

    return SyncPushResult(
      pushed: pushed,
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
      return const SyncPullResult(pulled: 0, deleted: 0);
    }

    onProgress?.call(const SyncProgress(
      totalFiles: 0,
      completedFiles: 0,
      isPush: false,
      message: 'Scanning local files…',
    ));

    // SHA-only map — the previous version held the bytes of every local
    // file simultaneously, which on iOS Safari with a media-heavy vault
    // exceeded the tab memory budget and crashed the app mid-pull.
    final localShas = await _collectLocalFileShas();

    var pulled = 0;
    var deleted = 0;
    var offloadedCount = 0;

    // Phase 1: non-drive files (entries, space metadata, hooks). These
    // are small — a few KB each — so bounded-parallel downloads turn a
    // 43-minute sequential pull of a large vault into a ~6-minute
    // download. Concurrency is capped at 8 to stay under GitHub's
    // secondary rate limit (~900 points/minute for authenticated
    // requests); GitLab's limits allow more but 8 is safe for both.
    final toDownload = <MapEntry<String, String>>[];
    for (final entry in inScope.entries) {
      if (_isDrivePath(entry.key)) continue;
      if (localShas[entry.key] == entry.value) continue;
      toDownload.add(entry);
    }

    // Pre-create every destination directory once, sequentially, so the
    // parallel workers never race on `create(recursive: true)` for the
    // same parent.
    final dirs = <String>{};
    for (final entry in toDownload) {
      dirs.add(p.dirname(p.join(vaultPath, entry.key)));
    }
    for (final dir in dirs) {
      await fs.directory(dir).create(recursive: true);
    }

    final failures = <String, Object>{};
    var phase1Completed = 0;
    const concurrency = 8;

    await _parallelForEach<MapEntry<String, String>>(
      items: toDownload,
      concurrency: concurrency,
      body: (entry) async {
        final bytes = await _downloadWithRetry(
          token: token,
          path: entry.key,
        );
        final dest = p.join(vaultPath, entry.key);
        await fs.file(dest).writeAsBytes(bytes);
        pulled++;
        phase1Completed++;
        onProgress?.call(SyncProgress(
          totalFiles: inScope.length,
          completedFiles: pulled,
          isPush: false,
          message: 'Downloading ${entry.key} '
              '($phase1Completed/${toDownload.length})',
        ));
      },
      onError: (entry, err) {
        failures[entry.key] = err;
        debugPrint('Failed to download ${entry.key}: $err');
      },
    );

    // If every file failed, something systemic is wrong (bad token,
    // network down) — surface it instead of continuing into phase 2
    // with a nearly-empty pull.
    if (toDownload.isNotEmpty && failures.length == toDownload.length) {
      throw StateError('All ${toDownload.length} file downloads failed. '
          'First error: ${failures.values.first}');
    }
    if (failures.isNotEmpty) {
      debugPrint('Pull completed with ${failures.length}/${toDownload.length} '
          'file download(s) failed; they will be retried on next pull.');
    }

    // Phase 2: drive files, policy-aware.
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

      // Single directory scan for the whole space. Previously one scan
      // per file — O(N²) directory listings that compounded the memory
      // pressure by generating small objects continuously.
      final pathMap = await _resolveDrivePaths(
        fs.directory(p.join(vaultPath, spaceId, 'drive')),
      );

      for (final id in sortedIds) {
        final localPath = pathMap[id];
        final remotePath = localPath != null
            ? '$spaceId/drive/${p.basename(localPath)}'
            : _findRemotePathForId(inScope, spaceId, id);
        if (remotePath == null) continue;
        final remoteSha = inScope[remotePath];
        if (remoteSha == null) continue;

        if (keepIds.contains(id)) {
          // Fast path: file present locally and content matches.
          if (localPath != null) {
            try {
              final bytes = await fs.file(localPath).readAsBytes();
              final matches = gitBlobSha(bytes) == remoteSha;
              // bytes goes out of scope
              if (matches) {
                if (offloaded.remove(id) != null) offloadedChanged = true;
                continue;
              }
            } catch (_) {}
          }
          // Download.
          onProgress?.call(SyncProgress(
            totalFiles: inScope.length,
            completedFiles: pulled,
            isPush: false,
            message: 'Downloading drive/$id',
          ));
          final bytes = await provider.downloadFile(
            config: config,
            token: token,
            path: remotePath,
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
          pulled++;
          await Future<void>.delayed(Duration.zero);
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

    // Phase 3: delete local files absent from the remote.
    for (final path in localShas.keys) {
      if (!scope.includes(path)) continue;
      if (inScope.containsKey(path)) continue;
      if (_isExcluded(path)) continue;
      final file = fs.file(p.join(vaultPath, path));
      if (await file.exists()) {
        await file.delete();
        deleted++;
      }
    }

    final head = await provider.currentHeadSha(config: config, token: token);
    await cacheStore?.save(config.cacheKey, remoteMap, head);

    onProgress?.call(SyncProgress(
      totalFiles: inScope.length,
      completedFiles: pulled,
      isPush: false,
      message: 'Pulled: $pulled updated, $deleted deleted, '
          '$offloadedCount offloaded',
    ));
    return SyncPullResult(
      pulled: pulled,
      deleted: deleted,
      offloaded: offloadedCount,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  /// Returns SHA + size of every local file, one at a time. Bytes are
  /// dropped immediately after hashing, so the peak memory is a single
  /// file's size — not the sum of every file in the vault.
  Future<Map<String, ({String sha, int size})>> _collectLocalFileInfo() async {
    final out = <String, ({String sha, int size})>{};
    final root = fs.directory(vaultPath);
    if (!await root.exists()) return out;
    final files = await walkFiles(root);
    for (final f in files) {
      final rel = p.relative(f.path, from: vaultPath);
      if (_isExcluded(rel)) continue;
      try {
        final stat = await f.stat();
        final bytes = await f.readAsBytes();
        out[rel] = (sha: gitBlobSha(bytes), size: stat.size);
      } catch (_) {}
    }
    return out;
  }

  /// SHA-only variant used by pull, which never needs the sizes.
  Future<Map<String, String>> _collectLocalFileShas() async {
    final out = <String, String>{};
    final root = fs.directory(vaultPath);
    if (!await root.exists()) return out;
    final files = await walkFiles(root);
    for (final f in files) {
      final rel = p.relative(f.path, from: vaultPath);
      if (_isExcluded(rel)) continue;
      try {
        final bytes = await f.readAsBytes();
        out[rel] = gitBlobSha(bytes);
      } catch (_) {}
    }
    return out;
  }

  /// Builds the path → known remote SHA map for offloaded files so push
  /// doesn't misclassify them as deletes.
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

  /// Single-scan resolution of a drive directory into a path map.
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

  /// Splits pending changes into batches whose combined file content
  /// stays under [_commitBatchMaxBytes]. A single oversized file (up to
  /// [_maxFileBytes]) gets its own batch.
  List<List<_PendingChange>> _batchChanges(List<_PendingChange> changes) {
    final batches = <List<_PendingChange>>[];
    var current = <_PendingChange>[];
    var currentBytes = 0;
    for (final c in changes) {
      if (current.isNotEmpty && currentBytes + c.size > _commitBatchMaxBytes) {
        batches.add(current);
        current = [];
        currentBytes = 0;
      }
      current.add(c);
      currentBytes += c.size;
    }
    if (current.isNotEmpty) batches.add(current);
    return batches;
  }

  // ── Unchanged helpers ─────────────────────────────────────────────────

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

  /// Runs [body] on each item with at most [concurrency] tasks in flight.
  /// Errors from [body] are passed to [onError] and do not stop the
  /// queue — one failed download must not abort the whole pull.
  ///
  /// Dart's single-threaded event loop makes `index++` race-free across
  /// workers without locks: the increment is synchronous between awaits.
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

  /// Wraps a download in a per-attempt timeout and retries on transient
  /// failures (429/403 rate-limit, network errors). A hung connection
  /// would otherwise block one worker forever, progressively reducing
  /// effective concurrency to zero.
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
        if (e.statusCode == 429 || e.statusCode == 403) {
          // Rate limited — back off before retrying.
          await Future<void>.delayed(Duration(seconds: 15 * (attempt + 1)));
          continue;
        }
        if (e.statusCode != null &&
            e.statusCode! >= 400 &&
            e.statusCode! < 500) {
          rethrow;
        }
        await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      } catch (e) {
        lastError = e;
        await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }
    throw lastError ?? StateError('Download failed for $path');
  }
}
