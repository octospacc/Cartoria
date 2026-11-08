import 'dart:convert';

import 'package:fs_shim/fs_shim.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../util/json_format.dart';

export 'sync_cache_store.dart';
export 'sync_token_store.dart';

enum SyncProviderKind { github, gitlab }

extension SyncProviderKindLabel on SyncProviderKind {
  String get label => switch (this) {
        SyncProviderKind.github => 'GitHub',
        SyncProviderKind.gitlab => 'GitLab',
      };

  /// Short emoji tag paired with the label wherever the provider name is
  /// shown alone, so GitHub and GitLab are distinguishable at a glance
  /// (their names differ by two characters and read almost identically
  /// in a dropdown at normal UI sizes).
  ///
  /// 🐙 for GitHub (Octocat lineage — the most widely recognised icon for
  /// the service short of its actual logo asset).
  /// 🦊 for GitLab (the tanuki/fox mascot, unambiguous to anyone who has
  /// used the service).
  String get emoji => switch (this) {
        SyncProviderKind.github => '🐙',
        SyncProviderKind.gitlab => '🦊',
      };

  /// Placeholder shown in the form when host is empty.
  String get defaultHost => switch (this) {
        SyncProviderKind.github => 'github.com',
        SyncProviderKind.gitlab => 'gitlab.com',
      };
}

const Object _unspecifiedSpaceIds = Object();

/// Per-remote sync configuration.
///
/// Multiple configs can coexist per vault. Exactly one is marked primary;
/// the primary additionally backs up vault-level data (`hooks/`, legacy
/// `hooks.json`) alongside whichever spaces it manages. Non-primary configs
/// back up only their selected spaces.
///
/// [host] is optional. Empty / null means the public instance
/// (`github.com` / `gitlab.com`). A non-empty value points at a
/// self-hosted instance and must be a bare hostname, optionally with a
/// path prefix — `git.example.com` or `example.com/gh`.
///
/// `spaceIds` semantics:
///   - null   → all spaces, including future ones
///   - empty  → no spaces (only vault-level, meaningful for primary)
///   - set    → exactly those spaces
class SyncConfig {
  final String id;
  final String name;
  final bool isPrimary;
  final SyncProviderKind provider;
  final String? host;
  final String owner;
  final String repo;
  final String branch;
  final String pathPrefix;
  final Set<String>? spaceIds;
  final int? keepLocalFileCount;
  final DateTime? lastSyncedAt;
  final String? lastCommitSha;

  const SyncConfig({
    required this.id,
    required this.name,
    this.isPrimary = false,
    required this.provider,
    this.host,
    required this.owner,
    required this.repo,
    this.branch = 'main',
    this.pathPrefix = '',
    this.spaceIds,
    this.keepLocalFileCount,
    this.lastSyncedAt,
    this.lastCommitSha,
  });

  /// Normalises a user-entered host string.
  ///
  /// Strips `https://` / `http://`, any `user:pass@` prefix, and trailing
  /// slashes. Preserves any path component (`example.com/gh` survives) so
  /// GitHub Enterprise installations behind a subpath work.
  ///
  /// Returns null when the result is empty, so callers can treat "the
  /// public host" as a single canonical state.
  static String? sanitizeHost(String? raw) {
    if (raw == null) return null;
    var h = raw.trim();
    if (h.isEmpty) return null;
    if (h.startsWith('https://')) h = h.substring(8);
    if (h.startsWith('http://')) h = h.substring(7);
    final at = h.indexOf('@');
    if (at >= 0) h = h.substring(at + 1);
    while (h.endsWith('/')) {
      h = h.substring(0, h.length - 1);
    }
    if (h.isEmpty) return null;
    if (h == 'github.com' || h == 'gitlab.com') return null;
    return h;
  }

  /// Segment used in [tokenKey] / [cacheKey]. Empty for the public host,
  /// `<host>:` otherwise. Colon separates it from the owner segment so
  /// parsing (if ever needed) is unambiguous.
  String get _hostSegment {
    final h = host?.trim() ?? '';
    return h.isEmpty ? '' : '$h:';
  }

  /// Key for the token store. Self-hosted configs get their own key
  /// bucket so a token for `git.example.com` can't be sent to a
  /// same-named repo on `gitlab.com`. Public-host configs keep the
  /// pre-host key format, so existing tokens continue to work without
  /// migration.
  String get tokenKey => '${provider.name}:$_hostSegment$owner/$repo';

  /// Key for the remote-listing cache. Includes branch so two configs on
  /// the same repo but different branches have independent caches.
  String get cacheKey => '${provider.name}:$_hostSegment$owner/$repo:$branch';

  SyncConfig copyWith({
    String? name,
    bool? isPrimary,
    SyncProviderKind? provider,
    Object? host = _unspecifiedSpaceIds,
    Object? keepLocalFileCount = _unspecifiedSpaceIds,
    String? owner,
    String? repo,
    String? branch,
    String? pathPrefix,
    Object? spaceIds = _unspecifiedSpaceIds,
    DateTime? lastSyncedAt,
    String? lastCommitSha,
  }) =>
      SyncConfig(
        id: id,
        name: name ?? this.name,
        isPrimary: isPrimary ?? this.isPrimary,
        provider: provider ?? this.provider,
        host:
            identical(host, _unspecifiedSpaceIds) ? this.host : host as String?,
        owner: owner ?? this.owner,
        repo: repo ?? this.repo,
        branch: branch ?? this.branch,
        pathPrefix: pathPrefix ?? this.pathPrefix,
        spaceIds: identical(spaceIds, _unspecifiedSpaceIds)
            ? this.spaceIds
            : spaceIds as Set<String>?,
        keepLocalFileCount: identical(keepLocalFileCount, _unspecifiedSpaceIds)
            ? this.keepLocalFileCount
            : keepLocalFileCount as int?,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        lastCommitSha: lastCommitSha ?? this.lastCommitSha,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (isPrimary) 'isPrimary': true,
        'provider': provider.name,
        if (host != null && host!.isNotEmpty) 'host': host,
        'owner': owner,
        'repo': repo,
        'branch': branch,
        'pathPrefix': pathPrefix,
        if (spaceIds != null) 'spaceIds': spaceIds!.toList(),
        if (keepLocalFileCount != null) 'keepLocalFileCount': keepLocalFileCount,
        if (lastSyncedAt != null)
          'lastSyncedAt': lastSyncedAt!.toIso8601String(),
        if (lastCommitSha != null) 'lastCommitSha': lastCommitSha,
      };

  factory SyncConfig.fromJson(Map<String, dynamic> j) => SyncConfig(
        id: (j['id'] as String?) ?? const Uuid().v7(),
        name: (j['name'] as String?) ?? 'Repository',
        isPrimary: (j['isPrimary'] as bool?) ?? false,
        provider: SyncProviderKind.values
            .byName((j['provider'] as String?) ?? 'github'),
        host: sanitizeHost(j['host'] as String?),
        owner: (j['owner'] as String?) ?? '',
        repo: (j['repo'] as String?) ?? '',
        branch: (j['branch'] as String?) ?? 'main',
        pathPrefix: (j['pathPrefix'] as String?) ?? '',
        spaceIds: j.containsKey('spaceIds')
            ? ((j['spaceIds'] as List?) ?? const []).cast<String>().toSet()
            : null,
        keepLocalFileCount: j['keepLocalFileCount'] as int?,
        lastSyncedAt: j['lastSyncedAt'] != null
            ? DateTime.tryParse(j['lastSyncedAt'] as String)
            : null,
        lastCommitSha: j['lastCommitSha'] as String?,
      );
}

/// Reads and writes `<vault>/sync.json` (v2 format) with migration from
/// the v1 single-config format. Unchanged from the previous version.
class SyncConfigsStore {
  final FileSystem fs;
  final String vaultPath;
  const SyncConfigsStore({required this.fs, required this.vaultPath});

  String get _path => p.join(vaultPath, 'sync.json');

  Future<List<SyncConfig>> load() async {
    final f = fs.file(_path);
    if (!await f.exists()) return [];
    try {
      final raw = jsonDecode(await f.readAsString()) as Map;
      final version = (raw['version'] as int?) ?? 1;
      if (version >= 2) {
        final remotes = (raw['remotes'] as List?) ?? const [];
        final configs = <SyncConfig>[];
        for (final e in remotes) {
          try {
            configs
                .add(SyncConfig.fromJson((e as Map).cast<String, dynamic>()));
          } catch (err) {
            debugPrint('Bad sync config: $err');
          }
        }
        _enforcePrimaryInvariant(configs);
        return configs;
      }
      final migrated = SyncConfig(
        id: const Uuid().v7(),
        name: 'Primary',
        isPrimary: true,
        provider: SyncProviderKind.values
            .byName((raw['provider'] as String?) ?? 'github'),
        host: null,
        owner: (raw['owner'] as String?) ?? '',
        repo: (raw['repo'] as String?) ?? '',
        branch: (raw['branch'] as String?) ?? 'main',
        pathPrefix: (raw['pathPrefix'] as String?) ?? '',
        spaceIds: null,
        keepLocalFileCount: null,
        lastSyncedAt: raw['lastSyncedAt'] != null
            ? DateTime.tryParse(raw['lastSyncedAt'] as String)
            : null,
        lastCommitSha: raw['lastCommitSha'] as String?,
      );
      debugPrint('Migrated legacy single-config sync.json');
      return [migrated];
    } catch (e) {
      debugPrint('Bad sync.json: $e');
      return [];
    }
  }

  void _enforcePrimaryInvariant(List<SyncConfig> configs) {
    if (configs.isEmpty) return;
    final primaries = configs.where((c) => c.isPrimary).toList();
    if (primaries.length == 1) return;
    if (primaries.isEmpty) {
      final first = configs.first;
      configs[configs.indexOf(first)] = first.copyWith(isPrimary: true);
      debugPrint('No primary config found; promoted "${first.name}"');
      return;
    }
    debugPrint('Multiple primary configs found; demoting all but the first');
    var seen = false;
    for (var i = 0; i < configs.length; i++) {
      if (!configs[i].isPrimary) continue;
      if (seen) {
        configs[i] = configs[i].copyWith(isPrimary: false);
      } else {
        seen = true;
      }
    }
  }

  Future<void> save(List<SyncConfig> configs) async {
    if (configs.isNotEmpty) {
      final primaries = configs.where((c) => c.isPrimary).length;
      if (primaries != 1) {
        throw StateError(
            'Exactly one sync config must be primary; found $primaries');
      }
    }
    await fs.directory(vaultPath).create(recursive: true);
    await fs.file(_path).writeAsString(prettyJson({
          'version': 2,
          'remotes': configs.map((c) => c.toJson()).toList(),
        }));
  }
}
