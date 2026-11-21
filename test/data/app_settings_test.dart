import 'package:Cartoria/data/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('defaults', () {
    test('const AppSettings has all defaults', () {
      const s = AppSettings();
      expect(s.onboarded, isFalse);
      expect(s.backupRetentionCount, isNull);
      expect(s.localeCode, isNull);
    });
  });

  group('round-trip', () {
    test('minimal', () {
      const s = AppSettings();
      final r = AppSettings.fromJson(s.toJson());
      expect(r.onboarded, isFalse);
      expect(r.backupRetentionCount, isNull);
      expect(r.localeCode, isNull);
    });

    test('full', () {
      const s = AppSettings(
        onboarded: true,
        backupRetentionCount: 5,
        localeCode: 'it',
      );
      final r = AppSettings.fromJson(s.toJson());
      expect(r.onboarded, isTrue);
      expect(r.backupRetentionCount, 5);
      expect(r.localeCode, 'it');
    });

    test('onboarded-only leaves optionals null', () {
      const s = AppSettings(onboarded: true);
      final r = AppSettings.fromJson(s.toJson());
      expect(r.backupRetentionCount, isNull);
      expect(r.localeCode, isNull);
    });
  });

  group('fromJson defaults', () {
    test('empty map', () {
      final s = AppSettings.fromJson({});
      expect(s.onboarded, isFalse);
      expect(s.backupRetentionCount, isNull);
      expect(s.localeCode, isNull);
    });

    test('versioned map with no other fields', () {
      final s = AppSettings.fromJson({'version': 1});
      expect(s.onboarded, isFalse);
    });
  });

  group('copyWith', () {
    test('onboarded only', () {
      final s = const AppSettings(
        backupRetentionCount: 5,
        localeCode: 'it',
      );
      final s2 = s.copyWith(onboarded: true);
      expect(s2.onboarded, isTrue);
      expect(s2.backupRetentionCount, 5);
      expect(s2.localeCode, 'it');
    });

    test('preserves backupRetentionCount when unspecified', () {
      final s = const AppSettings(backupRetentionCount: 3);
      final s2 = s.copyWith(onboarded: true);
      expect(s2.backupRetentionCount, 3);
    });

    test('explicitly nulls backupRetentionCount', () {
      final s = const AppSettings(backupRetentionCount: 3);
      final s2 = s.copyWith(backupRetentionCount: null);
      expect(s2.backupRetentionCount, isNull);
    });

    test('preserves localeCode when unspecified', () {
      final s = const AppSettings(localeCode: 'it');
      final s2 = s.copyWith(onboarded: true);
      expect(s2.localeCode, 'it');
    });

    test('explicitly nulls localeCode', () {
      final s = const AppSettings(localeCode: 'it');
      final s2 = s.copyWith(localeCode: null);
      expect(s2.localeCode, isNull);
    });
  });
}