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
      message: 'Walking local files…',
    ));
    final localFiles = await _collectLocalFiles();

    // Build offloaded-by-path map (path → known remote sha).
    final offloadedByPath = <String, String>{};
    final scopedSpaces = <String>{};
    for (final path in remoteMap.keys) {
      if (!scope.includes(path)) continue;
      final slash = path.indexOf('/');
      if (slash > 0) scopedSpaces.add(path.substring(0, slash));
    }
    for (final spaceId in scopedSpaces) {
      final info = await offloadedStore.load(spaceId);
      for (final e in info.entries) {
        final prefix = '$spaceId/drive/${e.key}';
        for (final remotePath in remoteMap.keys) {
          if (remotePath == prefix || remotePath.startsWith('$prefix.')) {
            offloadedByPath[remotePath] = e.value.remoteSha;
            break;
          }
        }
      }
    }

    final changes = <FileChange>[];
    final localShas = <String, String>{};
    var skippedLarge = 0;
    var skippedOffloaded = 0;

    for (final entry in localFiles.entries) {
      final path = entry.key;
      if (!scope.includes(path)) continue;
      final bytes = entry.value;
      if (bytes.length > _maxFileBytes) {
        skippedLarge++;
        continue;
      }
      final localSha = gitBlobSha(bytes);
      localShas[path] = localSha;
      final remoteSha = remoteMap[path];
      if (remoteSha == localSha) continue;
      if (remoteSha == null) {
        changes.add(FileChange.create(path, bytes));
      } else {
        changes.add(FileChange.update(path, bytes));
      }
    }

    for (final path in remoteMap.keys) {
      if (!scope.includes(path)) continue;
      if (localShas.containsKey(path)) continue;
      final knownRemoteSha = offloadedByPath[path];
      if (knownRemoteSha != null) {
        if (knownRemoteSha == remoteMap[path]) {
          skippedOffloaded++;
          continue;
        }
        debugPrint('Offloaded file $path changed remotely; '
            'will reconcile on next pull');
        skippedOffloaded++;
        continue;
      }
      // Not offloaded and not local → genuine delete.
      changes.add(FileChange.delete(path));
    }

    if (changes.isEmpty) {
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

    final total = changes.length;
    onProgress?.call(SyncProgress(
      totalFiles: total,
      completedFiles: 0,
      isPush: true,
      message: 'Committing $total change${total == 1 ? "" : "s"}…',
    ));

    final newSha = await provider.commit(
      config: config,
      token: token,
      message: 'Vault sync ${DateTime.now().toUtc().toIso8601String()}',
      changes: changes,
      onProgress: onProgress,
    );

    // Cache the full remote state (in-scope + out-of-scope), so policy
    // changes on this config don't trigger spurious re-listings.
    final newCacheFiles = <String, String>{...remoteMap};
    for (final c in changes) {
      if (c.kind == FileChangeKind.delete) {
        newCacheFiles.remove(c.path);
      } else {
        newCacheFiles[c.path] = gitBlobSha(c.content!);
      }
    }
    await cacheStore?.save(config.cacheKey, newCacheFiles, newSha);

    final created =
        changes.where((c) => c.kind == FileChangeKind.create).length;
    final updated =
        changes.where((c) => c.kind == FileChangeKind.update).length;
    final deleted =
        changes.where((c) => c.kind == FileChangeKind.delete).length;

    onProgress?.call(SyncProgress(
      totalFiles: total,
      completedFiles: total,
      isPush: true,
      message: 'Pushed: $created new, $updated updated, $deleted deleted',
    ));

    return SyncPushResult(
      pushed: created + updated,
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

    final localFiles = await _collectLocalFiles();
    var pulled = 0;
    var deleted = 0;
    var offloadedCount = 0;

    // Phase 1: non-drive files. All metadata (space.json, drive_meta.json,
    // entries/, hooks/) is brought current before policy touches drive files.
    for (final entry in inScope.entries) {
      final path = entry.key;
      if (_isDrivePath(path)) continue;
      final remoteSha = entry.value;
      final localBytes = localFiles[path];
      if (localBytes != null && gitBlobSha(localBytes) == remoteSha) continue;
      onProgress?.call(SyncProgress(
        totalFiles: inScope.length,
        completedFiles: pulled,
        isPush: false,
        message: 'Downloading $path',
      ));
      final bytes = await provider.downloadFile(
        config: config,
        token: token,
        path: path,
      );
      final dest = p.join(vaultPath, path);
      await fs.directory(p.dirname(dest)).create(recursive: true);
      await fs.file(dest).writeAsBytes(bytes);
      pulled++;
    }

    // Phase 2: drive files, policy-aware.
    final scopeSpaces = <String>{};
    for (final path in inScope.keys) {
      if (!_isDrivePath(path)) continue;
      final firstSlash = path.indexOf('/');
      if (firstSlash > 0) scopeSpaces.add(path.substring(0, firstSlash));
    }

    for (final spaceId in scopeSpaces) {
      final meta = await _readDriveMeta(spaceId);
      final sortedIds = meta.keys.toList()
        ..sort((a, b) {
          final ca = (meta[a] as Map)['created'] as String? ?? '';
          final cb = (meta[b] as Map)['created'] as String? ?? '';
          return cb.compareTo(ca); // newest first
        });

      final keepCount = config.keepLocalFileCount;
      final keepIds = keepCount == null
          ? sortedIds.toSet()
          : sortedIds.take(keepCount).toSet();

      final offloaded = await offloadedStore.load(spaceId);
      var offloadedChanged = false;
      final driveDir = fs.directory(p.join(vaultPath, spaceId, 'drive'));

      for (final id in sortedIds) {
        final localPath = await _resolveDrivePath(driveDir, id);
        final remotePath = localPath != null
            ? '$spaceId/drive/${p.basename(localPath)}'
            : _findRemotePathForId(inScope, spaceId, id);
        if (remotePath == null) continue;
        final remoteSha = inScope[remotePath];
        if (remoteSha == null) continue;

        if (keepIds.contains(id)) {
          // Keep local — download if missing or stale.
          if (localPath != null) {
            try {
              final bytes = await fs.file(localPath).readAsBytes();
              if (gitBlobSha(bytes) == remoteSha) {
                if (offloaded.remove(id) != null) offloadedChanged = true;
                continue;
              }
            } catch (_) {}
          }
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
          if (offloaded.remove(id) != null) offloadedChanged = true;
          pulled++;
        } else {
          // Offload — delete from disk if present, record in store.
          var size = offloaded[id]?.size ?? 0;
          if (localPath != null) {
            try {
              size = (await fs.file(localPath).stat()).size;
              await fs.file(localPath).delete();
            } catch (_) {}
          }
          offloaded[id] = OffloadedFileInfo(remoteSha: remoteSha, size: size);
          offloadedChanged = true;
          offloadedCount++;
        }
      }

      // Prune offloaded entries whose file is no longer in meta.
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

    // Phase 3: delete local files not on remote.
    for (final path in localFiles.keys) {
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
      message:
          'Pulled: $pulled updated, $deleted deleted, $offloadedCount offloaded',
    ));
    return SyncPullResult(
        pulled: pulled, deleted: deleted, offloaded: offloadedCount);
  }

  // ── Internals ─────────────────────────────────────────────────────────

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

  Future<Map<String, Uint8List>> _collectLocalFiles() async {
    final out = <String, Uint8List>{};
    final root = fs.directory(vaultPath);
    if (!await root.exists()) return out;
    final files = await walkFiles(root);
    for (final f in files) {
      final rel = p.relative(f.path, from: vaultPath);
      if (_isExcluded(rel)) continue;
      try {
        out[rel] = await f.readAsBytes();
      } catch (_) {}
    }
    return out;
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

  Future<String?> _resolveDrivePath(Directory driveDir, String id) async {
    if (!await driveDir.exists()) return null;
    await for (final e in driveDir.list(followLinks: false)) {
      if (e is! File) continue;
      final base = p.basename(e.path);
      if (base == id || base.startsWith('$id.')) return e.path;
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
}
