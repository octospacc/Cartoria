part of '../store.dart';

extension SyncOps on VaultStore {
  Future<void> saveSyncConfig(SyncConfig config) async {
    final old = syncConfigById(config.id);
    if (old != null && old.cacheKey != config.cacheKey) {
      try {
        await _syncCacheStore.clear(old.cacheKey);
      } catch (_) {}
    }
    if (_syncConfigs.isEmpty) {
      config = config.copyWith(isPrimary: true);
    }
    final idx = _syncConfigs.indexWhere((c) => c.id == config.id);
    if (idx >= 0) {
      _syncConfigs[idx] = config;
    } else {
      _syncConfigs.add(config);
    }
    if (config.isPrimary) {
      for (var i = 0; i < _syncConfigs.length; i++) {
        if (_syncConfigs[i].id != config.id && _syncConfigs[i].isPrimary) {
          _syncConfigs[i] = _syncConfigs[i].copyWith(isPrimary: false);
        }
      }
    } else if (!_syncConfigs.any((c) => c.isPrimary)) {
      _syncConfigs[0] = _syncConfigs[0].copyWith(isPrimary: true);
    }
    await _syncConfigsStore.save(_syncConfigs);
    notifyInternal();
  }

  Future<void> removeSyncConfig(String id) async {
    final config = syncConfigById(id);
    if (config == null) return;
    final wasPrimary = config.isPrimary;
    _syncConfigs.removeWhere((c) => c.id == id);
    if (wasPrimary && _syncConfigs.isNotEmpty) {
      _syncConfigs[0] = _syncConfigs[0].copyWith(isPrimary: true);
    }
    await _syncConfigsStore.save(_syncConfigs);
    try {
      await _syncCacheStore.clear(config.cacheKey);
    } catch (_) {}
    notifyInternal();
  }

  Future<String?> loadSyncToken(String configId) async {
    final c = syncConfigById(configId);
    if (c == null) return null;
    return _syncTokenStore.load(c.tokenKey);
  }

  Future<void> saveSyncToken(String configId, String token) async {
    final c = syncConfigById(configId);
    if (c == null) throw StateError('Sync config not found');
    await _syncTokenStore.save(c.tokenKey, token);
  }

  Future<void> clearSyncToken(String configId) async {
    final c = syncConfigById(configId);
    if (c == null) return;
    await _syncTokenStore.delete(c.tokenKey);
  }

  SyncProvider _makeProvider(http.Client client, SyncConfig config) {
    switch (config.provider) {
      case SyncProviderKind.github:
        return GitHubProvider(client: client);
      case SyncProviderKind.gitlab:
        return GitLabProvider(client: client);
    }
  }

  Future<Map<String, String?>> listRemoteSpaces(String configId) async {
    final config = syncConfigById(configId);
    if (config == null) throw StateError('Sync config not found');
    final token = await _syncTokenStore.load(config.tokenKey);
    if (token == null) throw StateError('Sync token not set');
    final client = http.Client();
    try {
      return await _makeProvider(client, config)
          .listRemoteSpaces(config: config, token: token);
    } finally {
      client.close();
    }
  }

  Future<void> verifySyncAccess(String configId) async {
    final config = syncConfigById(configId);
    if (config == null) throw StateError('Sync config not found');
    final token = await _syncTokenStore.load(config.tokenKey);
    if (token == null) throw StateError('Sync token not set');
    final client = http.Client();
    try {
      await _makeProvider(client, config)
          .verifyAccess(config: config, token: token);
    } finally {
      client.close();
    }
  }

  Future<SyncPushResult> syncPush(
    String configId, {
    SyncProgressCallback? onProgress,
  }) async {
    final config = syncConfigById(configId);
    if (config == null) throw StateError('Sync config not found');
    final token = await _syncTokenStore.load(config.tokenKey);
    if (token == null) throw StateError('Sync token not set');
    final client = http.Client();
    try {
      final provider = _makeProvider(client, config);
      final scope = SyncScope.forConfig(config);
      final service = SyncService(
          fs: fs,
          vaultPath: vaultPath,
          config: config,
          provider: provider,
          cacheStore: _syncCacheStore,
          scope: scope);
      final result = await service.push(
          token: token,
          onProgress: onProgress,
          offloadedStore: _offloadedStore);
      await saveSyncConfig(config.copyWith(
          lastSyncedAt: DateTime.now().toUtc(),
          lastCommitSha: result.commitSha));
      return result;
    } finally {
      client.close();
    }
  }

  Future<SyncPullResult> syncPull(
    String configId, {
    SyncProgressCallback? onProgress,
  }) async {
    final config = syncConfigById(configId);
    if (config == null) throw StateError('Sync config not found');
    final token = await _syncTokenStore.load(config.tokenKey);
    if (token == null) throw StateError('Sync token not set');

    await _backupVault();

    final client = http.Client();
    try {
      final provider = _makeProvider(client, config);
      final scope = SyncScope.forConfig(config);
      final service = SyncService(
          fs: fs,
          vaultPath: vaultPath,
          config: config,
          provider: provider,
          cacheStore: _syncCacheStore,
          scope: scope);
      clearImageCacheForSync();
      final result = await service.pull(
          token: token,
          onProgress: onProgress,
          offloadedStore: _offloadedStore);
      await saveSyncConfig(config.copyWith(
        lastSyncedAt: DateTime.now().toUtc(),
      ));

      final changed = result.added > 0 ||
          result.updated > 0 ||
          result.deleted > 0 ||
          result.offloaded > 0;
      if (changed) {
        await reload();
        clearImageCacheForSync();
      } else {
        notifyInternal();
      }
      return result;
    } finally {
      client.close();
    }
  }

  void clearImageCacheForSync() {
    _imageCache.clear();
    notifyInternal();
  }
}