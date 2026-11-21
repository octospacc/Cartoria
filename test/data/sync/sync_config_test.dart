import 'package:Cartoria/data/sync/sync_config.dart';
import 'package:flutter_test/flutter_test.dart';

SyncConfig _cfg({
  String id = 'c1',
  String name = 'test',
  SyncProviderKind provider = SyncProviderKind.github,
  String? host,
  String owner = 'me',
  String repo = 'vault',
  String branch = 'main',
  Set<String>? spaceIds,
  bool isPrimary = false,
}) =>
    SyncConfig(
      id: id,
      name: name,
      provider: provider,
      host: host,
      owner: owner,
      repo: repo,
      branch: branch,
      spaceIds: spaceIds,
      isPrimary: isPrimary,
    );

void main() {
  group('sanitizeHost', () {
    test('null → null', () {
      expect(SyncConfig.sanitizeHost(null), isNull);
    });
    test('empty / whitespace → null', () {
      expect(SyncConfig.sanitizeHost(''), isNull);
      expect(SyncConfig.sanitizeHost('   '), isNull);
    });
    test('strips https://', () {
      expect(SyncConfig.sanitizeHost('https://example.com'), 'example.com');
    });
    test('strips http://', () {
      expect(SyncConfig.sanitizeHost('http://example.com'), 'example.com');
    });
    test('preserves path component', () {
      expect(SyncConfig.sanitizeHost('example.com/gh'), 'example.com/gh');
    });
    test('strips user:pass@', () {
      expect(SyncConfig.sanitizeHost('user:pass@example.com'), 'example.com');
    });
    test('strips trailing slashes', () {
      expect(SyncConfig.sanitizeHost('example.com///'), 'example.com');
    });
    test('github.com → null (public canonical)', () {
      expect(SyncConfig.sanitizeHost('github.com'), isNull);
    });
    test('gitlab.com → null', () {
      expect(SyncConfig.sanitizeHost('gitlab.com'), isNull);
    });
    test('strips everything except a non-canonical host', () {
      expect(
        SyncConfig.sanitizeHost('https://user:pw@ghe.example.com/path/'),
        'ghe.example.com/path',
      );
    });
  });

  group('tokenKey', () {
    test('public host → provider:owner/repo', () {
      expect(_cfg().tokenKey, 'github:me/vault');
    });
    test('self-hosted host → provider:host:owner/repo', () {
      expect(_cfg(host: 'ghe.example.com').tokenKey,
          'github:ghe.example.com:me/vault');
    });
    test('gitlab provider uses its own prefix', () {
      expect(_cfg(provider: SyncProviderKind.gitlab).tokenKey,
          'gitlab:me/vault');
    });
  });

  group('cacheKey', () {
    test('includes provider, owner, repo, branch', () {
      expect(_cfg().cacheKey, 'github:me/vault:main');
    });
    test('custom branch reflected', () {
      expect(_cfg(branch: 'dev').cacheKey, 'github:me/vault:dev');
    });
    test('self-hosted host included', () {
      expect(
        _cfg(host: 'ghe.example.com', branch: 'trunk').cacheKey,
        'github:ghe.example.com:me/vault:trunk',
      );
    });
  });

  group('copyWith', () {
    test('preserves unspecified fields', () {
      final c = _cfg(host: 'ghe.example.com', isPrimary: true);
      final c2 = c.copyWith(name: 'renamed');
      expect(c2.name, 'renamed');
      expect(c2.host, 'ghe.example.com');
      expect(c2.isPrimary, isTrue);
      expect(c2.owner, 'me');
    });

    test('can explicitly null host', () {
      final c = _cfg(host: 'ghe.example.com');
      final c2 = c.copyWith(host: null);
      expect(c2.host, isNull);
    });

    test('can explicitly null spaceIds (all spaces)', () {
      final c = _cfg(spaceIds: {'a', 'b'});
      final c2 = c.copyWith(spaceIds: null);
      expect(c2.spaceIds, isNull);
    });

    test('can replace spaceIds', () {
      final c = _cfg(spaceIds: {'a'});
      final c2 = c.copyWith(spaceIds: {'c'});
      expect(c2.spaceIds, {'c'});
    });

    test('can explicitly null backupRetention-style int (via keepLocalFileCount)', () {
      final c = _cfg();
      final c2 = c.copyWith(keepLocalFileCount: 5);
      expect(c2.keepLocalFileCount, 5);
      final c3 = c2.copyWith(keepLocalFileCount: null);
      expect(c3.keepLocalFileCount, isNull);
    });
  });

  group('fromJson / toJson round-trip', () {
    test('minimal config', () {
      final c = _cfg();
      final restored = SyncConfig.fromJson(c.toJson());
      expect(restored.id, c.id);
      expect(restored.name, c.name);
      expect(restored.provider, c.provider);
      expect(restored.host, isNull);
      expect(restored.owner, c.owner);
      expect(restored.repo, c.repo);
      expect(restored.branch, c.branch);
      expect(restored.spaceIds, isNull);
      expect(restored.isPrimary, false);
    });

    test('full config', () {
      final c = SyncConfig(
        id: 'c1',
        name: 'backup',
        isPrimary: true,
        provider: SyncProviderKind.gitlab,
        host: 'ghe.example.com',
        owner: 'org',
        repo: 'vault',
        branch: 'prod',
        pathPrefix: 'data/',
        spaceIds: {'s1', 's2'},
        keepLocalFileCount: 7,
        lastSyncedAt: DateTime.utc(2025, 1, 1),
        lastCommitSha: 'abc123',
      );
      final r = SyncConfig.fromJson(c.toJson());
      expect(r.host, 'ghe.example.com');
      expect(r.pathPrefix, 'data/');
      expect(r.spaceIds, {'s1', 's2'});
      expect(r.keepLocalFileCount, 7);
      expect(r.lastCommitSha, 'abc123');
      expect(r.isPrimary, isTrue);
    });

    test('host sanitized on load', () {
      final r = SyncConfig.fromJson({
        'id': 'c1',
        'name': 'n',
        'provider': 'github',
        'host': 'https://ghe.example.com/',
        'owner': 'o',
        'repo': 'r',
      });
      expect(r.host, 'ghe.example.com');
    });

    test('empty spaceIds Set is preserved (means "no spaces")', () {
      final r = SyncConfig.fromJson({
        'id': 'c1',
        'name': 'n',
        'provider': 'github',
        'owner': 'o',
        'repo': 'r',
        'spaceIds': <String>[],
      });
      expect(r.spaceIds, isEmpty);
      expect(r.spaceIds, isNotNull);
    });

    test('missing spaceIds means "all spaces"', () {
      final r = SyncConfig.fromJson({
        'id': 'c1',
        'name': 'n',
        'provider': 'github',
        'owner': 'o',
        'repo': 'r',
      });
      expect(r.spaceIds, isNull);
    });
  });
}