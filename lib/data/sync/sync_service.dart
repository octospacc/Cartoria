import 'dart:typed_data';

import 'package:fs_shim/fs_shim.dart';
import 'package:path/path.dart' as p;

import '../../util/fs_walk.dart';
import 'git_blob.dart';
import 'sync_config.dart';
import 'sync_provider.dart';
import 'sync_scope.dart';

class SyncPushResult {
  final int pushed;
  final int deleted;
  final int skippedLarge;
  final String commitSha;
  const SyncPushResult({
    required this.pushed,
    required this.deleted,
    required this.skippedLarge,
    required this.commitSha,
  });
}

class SyncPullResult {
  final int pulled;
  final int deleted;
  const SyncPullResult({required this.pulled, required this.deleted});
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

  Future<SyncPushResult> push({
    required String token,
    SyncProgressCallback? onProgress,
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

    final changes = <FileChange>[];
    final localShas = <String, String>{};
    var skippedLarge = 0;
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
      if (!localShas.containsKey(path)) {
        changes.add(FileChange.delete(path));
      }
    }

    if (changes.isEmpty) {
      onProgress?.call(SyncProgress(
        totalFiles: 1,
        completedFiles: 1,
        isPush: true,
        message: 'Nothing to push'
            '${skippedLarge > 0 ? " ($skippedLarge large files skipped)" : ""}',
      ));
      return SyncPushResult(
        pushed: 0,
        deleted: 0,
        skippedLarge: skippedLarge,
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

    // Cache is the FULL remote state, so scoping changes on this config
    // don't accidentally treat still-existing out-of-scope files as new.
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
      commitSha: newSha,
    );
  }

  Future<SyncPullResult> pull({
    required String token,
    SyncProgressCallback? onProgress,
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
    final inScopeCount = remoteMap.keys.where(scope.includes).length;
    if (inScopeCount == 0) {
      onProgress?.call(const SyncProgress(
        totalFiles: 0,
        completedFiles: 0,
        isPush: false,
        message: 'Nothing in scope on the remote; nothing to pull.',
      ));
      return const SyncPullResult(pulled: 0, deleted: 0);
    }

    final localFiles = await _collectLocalFiles();
    final total = inScopeCount;
    var done = 0;
    var pulled = 0;

    for (final entry in remoteMap.entries) {
      final path = entry.key;
      if (!scope.includes(path)) continue;
      final remoteSha = entry.value;
      final localBytes = localFiles[path];
      if (localBytes != null && gitBlobSha(localBytes) == remoteSha) {
        done++;
        onProgress?.call(SyncProgress(
          totalFiles: total,
          completedFiles: done,
          isPush: false,
          message: 'Unchanged: $path',
        ));
        continue;
      }
      onProgress?.call(SyncProgress(
        totalFiles: total,
        completedFiles: done,
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
      done++;
    }

    var deleted = 0;
    for (final path in localFiles.keys) {
      if (!scope.includes(path)) continue;
      if (remoteMap.containsKey(path)) continue;
      if (_isExcluded(path)) continue;
      final file = fs.file(p.join(vaultPath, path));
      if (await file.exists()) {
        await file.delete();
        deleted++;
      }
    }

    final head = await provider.currentHeadSha(
      config: config,
      token: token,
    );
    await cacheStore?.save(config.cacheKey, remoteMap, head);

    onProgress?.call(SyncProgress(
      totalFiles: total,
      completedFiles: done,
      isPush: false,
      message: 'Pulled: $pulled updated, $deleted deleted',
    ));
    return SyncPullResult(pulled: pulled, deleted: deleted);
  }

  // ── Internals ─────────────────────────────────────────────────────────

  Future<Map<String, String>> _remoteListing({
    required String token,
    required bool isPush,
    SyncProgressCallback? onProgress,
  }) async {
    final head = await provider.currentHeadSha(
      config: config,
      token: token,
    );
    final cache = await cacheStore?.load(config.cacheKey);
    if (head != null && cache != null && cache.commitSha == head) {
      onProgress?.call(SyncProgress(
        totalFiles: cache.files.length,
        completedFiles: cache.files.length,
        isPush: isPush,
        message:
            'Using cached remote listing (${cache.files.length} files)',
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

  bool _isExcluded(String relPath) {
    if (_excludedFiles.contains(relPath)) return true;
    final first = relPath.split('/').first;
    return first == '.git';
  }
}