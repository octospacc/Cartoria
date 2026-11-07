import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../store.dart';
import 'github_provider.dart';
import 'gitlab_provider.dart';
import 'sync_config.dart';
import 'sync_provider.dart';

/// Fetches file bytes on demand from the sync remote when the file is
/// not on local disk. Looks up the sync config that includes the space,
/// preferring the primary, then any other config in scope.
///
/// Uses a persistent [http.Client] for the lifetime of the store. The
/// previous implementation created and closed a fresh client per fetch,
/// which raced with response-body streaming and produced
/// `ClientException: Request aborted by abortTrigger` on some requests.
/// Closing the client only at [dispose] eliminates the race and lets
/// keep-alive connections be reused, which also speeds up thumbnail
/// batches.
class ContentFetcher {
  final VaultStore store;
  final http.Client _client = http.Client();
  ContentFetcher(this.store);

  void dispose() {
    _client.close();
  }

  Future<Uint8List> fetch(String spaceId, String fileId) async {
    final config = _configForSpace(spaceId);
    if (config == null) {
      throw StateError(
          'No sync config includes space $spaceId. Cannot fetch $fileId.');
    }
    final token = await store.loadSyncToken(config.id);
    if (token == null || token.isEmpty) {
      throw StateError(
          'No token for sync config "${config.name}". Cannot fetch $fileId.');
    }
    final file = store.fileById(spaceId, fileId);
    if (file == null) {
      throw StateError('File $fileId not found in space $spaceId.');
    }

    final provider = _providerFor(config.provider, _client);
    final remotePath = _remotePath(spaceId, fileId, file.name);

    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        // 60s hard timeout. Without it, a stuck TCP connection or a slow
        // GitLab raw-file endpoint hangs the Future forever, which the UI
        // presents as an infinite spinner.
        final bytes = await provider
            .downloadFile(config: config, token: token, path: remotePath)
            .timeout(const Duration(seconds: 60));
        return bytes;
      } on TimeoutException catch (e) {
        lastError = e;
        debugPrint('Fetch timeout (attempt ${attempt + 1}) for $remotePath');
        if (attempt < 2) {
          await Future<void>.delayed(
              Duration(milliseconds: 500 * (attempt + 1)));
        }
      } on SyncException catch (e) {
        lastError = e;
        final sc = e.statusCode;
        if (sc != null && sc >= 400 && sc < 500) {
          rethrow; // Definitive client error — no retry.
        }
        if (attempt < 2) {
          await Future<void>.delayed(
              Duration(milliseconds: 500 * (attempt + 1)));
        }
      } catch (e) {
        lastError = e;
        debugPrint('Fetch attempt ${attempt + 1} failed for $remotePath: $e');
        if (attempt < 2) {
          await Future<void>.delayed(
              Duration(milliseconds: 500 * (attempt + 1)));
        }
      }
    }
    throw lastError ?? StateError('Fetch failed for $remotePath');
  }

  SyncProvider _providerFor(SyncProviderKind kind, http.Client client) {
    switch (kind) {
      case SyncProviderKind.github:
        return GitHubProvider(client: client);
      case SyncProviderKind.gitlab:
        return GitLabProvider(client: client);
    }
  }

  SyncConfig? _configForSpace(String spaceId) {
    final primary = store.primarySyncConfig;
    if (primary != null && _includes(primary, spaceId)) return primary;
    for (final c in store.syncConfigs) {
      if (_includes(c, spaceId)) return c;
    }
    return null;
  }

  bool _includes(SyncConfig c, String spaceId) {
    final ids = c.spaceIds;
    return ids == null || ids.contains(spaceId);
  }

  /// Matches the vault's on-disk layout: `<spaceId>/drive/<fileId>.<ext>`.
  String _remotePath(String spaceId, String fileId, String name) {
    final dot = name.lastIndexOf('.');
    final ext = (dot < 0 || dot == 0)
        ? ''
        : name
            .substring(dot + 1)
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]'), '');
    final fileName = ext.isEmpty ? fileId : '$fileId.$ext';
    return '$spaceId/drive/$fileName';
  }
}
