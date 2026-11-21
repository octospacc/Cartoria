import 'package:Cartoria/data/sync/sync_config.dart';
import 'package:Cartoria/data/sync/sync_scope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SyncScope.includes', () {
    test('primary with no space filter includes everything', () {
      const s = SyncScope(spaceIds: null, includeVaultLevel: true);
      expect(s.includes('hooks.json'), isTrue);
      expect(s.includes('hooks/x.json'), isTrue);
      expect(s.includes('space1/entries/a.html'), isTrue);
      expect(s.includes('space2/drive/x.png'), isTrue);
    });

    test('primary without space filter still excludes top-level non-hooks files', () {
      const s = SyncScope(spaceIds: null, includeVaultLevel: true);
      // sync.json, settings.json, etc. — no slash → not synced.
      expect(s.includes('sync.json'), isFalse);
      expect(s.includes('settings.json'), isFalse);
    });

    test('non-primary excludes hooks', () {
      const s = SyncScope(spaceIds: null, includeVaultLevel: false);
      expect(s.includes('hooks.json'), isFalse);
      expect(s.includes('hooks/x.json'), isFalse);
      expect(s.includes('space1/entries/a.html'), isTrue);
    });

    test('space filter includes only listed spaces', () {
      const s = SyncScope(
        spaceIds: {'a', 'b'},
        includeVaultLevel: false,
      );
      expect(s.includes('a/x'), isTrue);
      expect(s.includes('b/x'), isTrue);
      expect(s.includes('c/x'), isFalse);
    });

    test('empty Set excludes all spaces', () {
      const s = SyncScope(spaceIds: <String>{}, includeVaultLevel: false);
      expect(s.includes('a/x'), isFalse);
      expect(s.includes('b/y'), isFalse);
    });

    test('empty Set still excludes hooks when non-primary', () {
      const s = SyncScope(spaceIds: <String>{}, includeVaultLevel: false);
      expect(s.includes('hooks.json'), isFalse);
    });

    test('empty Set includes hooks when primary', () {
      const s = SyncScope(spaceIds: <String>{}, includeVaultLevel: true);
      expect(s.includes('hooks.json'), isTrue);
      expect(s.includes('hooks/x.json'), isTrue);
      // But no spaces are in scope.
      expect(s.includes('a/x'), isFalse);
    });
  });

  group('SyncScope.forConfig', () {
    test('primary → includeVaultLevel true', () {
      final config = SyncConfig(
        id: 'c',
        name: 'n',
        provider: SyncProviderKind.github,
        owner: 'o',
        repo: 'r',
        isPrimary: true,
      );
      final s = SyncScope.forConfig(config);
      expect(s.includeVaultLevel, isTrue);
      expect(s.spaceIds, isNull);
    });

    test('non-primary → includeVaultLevel false', () {
      final config = SyncConfig(
        id: 'c',
        name: 'n',
        provider: SyncProviderKind.github,
        owner: 'o',
        repo: 'r',
        spaceIds: {'a'},
      );
      final s = SyncScope.forConfig(config);
      expect(s.includeVaultLevel, isFalse);
      expect(s.spaceIds, {'a'});
    });
  });
}