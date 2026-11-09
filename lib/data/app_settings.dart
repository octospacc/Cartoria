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

  /// Maximum number of pre-pull backup zips to keep. Null means "use the
  /// platform default" (10 on desktop, 3 on web). Zero means "don't
  /// create pre-pull backups at all".
  final int? backupRetentionCount;

  const AppSettings({
    this.onboarded = false,
    this.backupRetentionCount,
  });

  AppSettings copyWith({
    bool? onboarded,
    Object? backupRetentionCount = _sentinel,
  }) =>
      AppSettings(
        onboarded: onboarded ?? this.onboarded,
        backupRetentionCount: identical(backupRetentionCount, _sentinel)
            ? this.backupRetentionCount
            : backupRetentionCount as int?,
      );

  Map<String, dynamic> toJson() => {
        'version': 1,
        'onboarded': onboarded,
        if (backupRetentionCount != null)
          'backupRetentionCount': backupRetentionCount,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        onboarded: (j['onboarded'] as bool?) ?? false,
        backupRetentionCount: j['backupRetentionCount'] as int?,
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