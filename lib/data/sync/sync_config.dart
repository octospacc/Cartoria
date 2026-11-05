import 'dart:convert';

import 'package:fs_shim/fs_shim.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../util/json_format.dart';

enum SyncProviderKind { github, gitlab }

extension SyncProviderKindLabel on SyncProviderKind {
  String get label => switch (this) {
        SyncProviderKind.github => 'GitHub',
        SyncProviderKind.gitlab => 'GitLab',
      };
}

/// Remote configuration for a vault's sync target.
///
/// Stored in `<vault>/sync.json`. The token is *not* stored here — it
/// lives in [SyncTokenStore] outside the vault, so the vault itself
/// remains safe to export or share.
class SyncConfig {
  final SyncProviderKind provider;
  final String owner;
  final String repo;
  final String branch;
  final String pathPrefix;
  final DateTime? lastSyncedAt;
  final String? lastCommitSha;

  const SyncConfig({
    required this.provider,
    required this.owner,
    required this.repo,
    this.branch = 'main',
    this.pathPrefix = '',
    this.lastSyncedAt,
    this.lastCommitSha,
  });

  SyncConfig copyWith({
    SyncProviderKind? provider,
    String? owner,
    String? repo,
    String? branch,
    String? pathPrefix,
    DateTime? lastSyncedAt,
    String? lastCommitSha,
  }) =>
      SyncConfig(
        provider: provider ?? this.provider,
        owner: owner ?? this.owner,
        repo: repo ?? this.repo,
        branch: branch ?? this.branch,
        pathPrefix: pathPrefix ?? this.pathPrefix,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        lastCommitSha: lastCommitSha ?? this.lastCommitSha,
      );

  /// Key used in the token store. Not cryptographic — just a stable
  /// identifier that survives moving the vault directory.
  String get tokenKey => '${provider.name}:$owner/$repo';

  Map<String, dynamic> toJson() => {
        'version': 1,
        'provider': provider.name,
        'owner': owner,
        'repo': repo,
        'branch': branch,
        'pathPrefix': pathPrefix,
        if (lastSyncedAt != null)
          'lastSyncedAt': lastSyncedAt!.toIso8601String(),
        if (lastCommitSha != null) 'lastCommitSha': lastCommitSha,
      };

  factory SyncConfig.fromJson(Map<String, dynamic> j) => SyncConfig(
        provider: SyncProviderKind.values
            .byName((j['provider'] as String?) ?? 'github'),
        owner: j['owner'] as String? ?? '',
        repo: j['repo'] as String? ?? '',
        branch: (j['branch'] as String?) ?? 'main',
        pathPrefix: (j['pathPrefix'] as String?) ?? '',
        lastSyncedAt: j['lastSyncedAt'] != null
            ? DateTime.tryParse(j['lastSyncedAt'] as String)
            : null,
        lastCommitSha: j['lastCommitSha'] as String?,
      );
}

class SyncConfigStore {
  final FileSystem fs;
  final String vaultPath;
  const SyncConfigStore({required this.fs, required this.vaultPath});

  String get _path => p.join(vaultPath, 'sync.json');

  Future<SyncConfig?> load() async {
    final f = fs.file(_path);
    if (!await f.exists()) return null;
    try {
      final raw = jsonDecode(await f.readAsString()) as Map;
      return SyncConfig.fromJson(raw.cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  Future<void> save(SyncConfig config) async {
    await fs.directory(vaultPath).create(recursive: true);
    // `sync.json` is user-editable (see SyncScreen), so pretty-print it.
    await fs.file(_path).writeAsString(prettyJson(config.toJson()));
  }
}

/// Provider tokens, stored outside the vault in the app support dir.
///
/// A single JSON map keyed by `provider:owner/repo`. Multiple entries
/// coexist; deleting the vault leaves the token behind until the user
/// explicitly removes it. Plaintext on disk (like most CLI credentials);
/// harden with `flutter_secure_storage` later if needed.
class SyncTokenStore {
  final FileSystem fs;
  const SyncTokenStore({required this.fs});

  Future<String> _path() async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, 'sync_tokens.json');
  }

  Future<Map<String, dynamic>> _readAll() async {
    final f = fs.file(await _path());
    if (!await f.exists()) return {};
    try {
      return (jsonDecode(await f.readAsString()) as Map).cast<String, dynamic>();
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeAll(Map<String, dynamic> data) async {
    final dir = await getApplicationSupportDirectory();
    await fs.directory(dir.path).create(recursive: true);
    // Pretty-printed so the user can open and edit it by hand (adding or
    // removing a token without going through the UI).
    await fs.file(await _path()).writeAsString(prettyJson(data));
  }

  Future<String?> load(String key) async => (await _readAll())[key] as String?;

  Future<void> save(String key, String token) async {
    final data = await _readAll();
    data[key] = token;
    await _writeAll(data);
  }

  Future<void> delete(String key) async {
    final data = await _readAll();
    data.remove(key);
    await _writeAll(data);
  }
}

/// Caches the last-seen remote file listing, keyed by token key.
///
/// Stored outside the vault in the app support directory — it can be
/// 1-2MB for a large repo and doesn't belong in `sync.json`, which the
/// user may read or edit. Deleted when the config changes or the user
/// clears the token.
class SyncCacheStore {
  final FileSystem fs;
  const SyncCacheStore({required this.fs});

  Future<String> _path(String tokenKey) async {
    final dir = await getApplicationSupportDirectory();
    final safe = tokenKey.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    return p.join(dir.path, 'sync_cache_$safe.json');
  }

  Future<({Map<String, String> files, String? commitSha})?> load(
    String tokenKey,
  ) async {
    final f = fs.file(await _path(tokenKey));
    if (!await f.exists()) return null;
    try {
      final data =
          (jsonDecode(await f.readAsString()) as Map).cast<String, dynamic>();
      final files =
          ((data['files'] as Map?) ?? const {}).cast<String, String>();
      return (files: files, commitSha: data['commitSha'] as String?);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(
    String tokenKey,
    Map<String, String> files,
    String? commitSha,
  ) async {
    final dir = await getApplicationSupportDirectory();
    await fs.directory(dir.path).create(recursive: true);
    // Deliberately compact: this is a transient runtime cache of possibly
    // 26K entries in the app support dir, never in git, and pretty-
    // printing would roughly triple its size on disk and its load time.
    await fs.file(await _path(tokenKey)).writeAsString(jsonEncode({
      'files': files,
      'commitSha': commitSha,
      'savedAt': DateTime.now().toUtc().toIso8601String(),
    }));
  }

  Future<void> clear(String tokenKey) async {
    final f = fs.file(await _path(tokenKey));
    if (await f.exists()) await f.delete();
  }
}