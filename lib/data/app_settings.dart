import 'dart:convert';

import 'package:fs_shim/fs_shim.dart';
import 'package:path/path.dart' as p;

import '../util/json_format.dart';

/// Per-vault user preferences that aren't tied to any single space.
///
/// Stored in `<vault>/settings.json`. Not synced (it's a top-level file,
/// which `SyncScope.includes()` excludes) — settings are per-device.
class AppSettings {
  final bool onboarded;

  final int? backupRetentionCount;

  /// BCP-47 language code (e.g. `"en"`, `"it"`). Null means "follow the
  /// system locale". Stored separately from [onboarded] so a user who
  /// switches languages does not lose their onboarding flag.
  final String? localeCode;

  const AppSettings({
    this.onboarded = false,
    this.backupRetentionCount,
    this.localeCode,
  });

  AppSettings copyWith({
    bool? onboarded,
    Object? backupRetentionCount = _sentinel,
    Object? localeCode = _sentinel,
  }) =>
      AppSettings(
        onboarded: onboarded ?? this.onboarded,
        backupRetentionCount: identical(backupRetentionCount, _sentinel)
            ? this.backupRetentionCount
            : backupRetentionCount as int?,
        localeCode: identical(localeCode, _sentinel)
            ? this.localeCode
            : localeCode as String?,
      );

  Map<String, dynamic> toJson() => {
        'version': 1,
        'onboarded': onboarded,
        if (backupRetentionCount != null)
          'backupRetentionCount': backupRetentionCount,
        if (localeCode != null) 'localeCode': localeCode,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        onboarded: (j['onboarded'] as bool?) ?? false,
        backupRetentionCount: j['backupRetentionCount'] as int?,
        localeCode: j['localeCode'] as String?,
      );
}

const Object _sentinel = Object();

class AppSettingsStore {
  final FileSystem fs;
  final String vaultPath;
  const AppSettingsStore({required this.fs, required this.vaultPath});

  String get _path => p.join(vaultPath, 'settings.json');

  Future<AppSettings> load() async {
    final f = fs.file(_path);
    if (!await f.exists()) return const AppSettings();
    try {
      final raw = jsonDecode(await f.readAsString()) as Map;
      return AppSettings.fromJson(raw.cast<String, dynamic>());
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) async {
    await fs.directory(vaultPath).create(recursive: true);
    await fs.file(_path).writeAsString(prettyJson(settings.toJson()));
  }
}