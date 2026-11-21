part of '../store.dart';

extension BackupOps on VaultStore {
  int get effectiveBackupRetentionCount =>
      _settings.backupRetentionCount ?? (kIsWeb ? 3 : 10);

  int? get backupRetentionCountOverride => _settings.backupRetentionCount;

  Future<void> setBackupRetentionCount(int? count) async {
    if (count != null && count < 0) {
      throw ArgumentError('Retention count cannot be negative');
    }
    if (count != null && count > 100) {
      throw ArgumentError('Retention count cannot exceed 100');
    }
    _settings = _settings.copyWith(backupRetentionCount: count);
    try {
      await _settingsStore.save(_settings);
    } catch (e) {
      debugPrint('Could not persist backup retention: $e');
    }
    await _pruneOldBackups(await _backupDir(),
        keep: effectiveBackupRetentionCount);
    notifyInternal();
  }

  Future<List<BackupInfo>> listBackups() async {
    final dir = await _backupDir();
    if (!await dir.exists()) return const [];
    final result = <BackupInfo>[];
    try {
      await for (final e in dir.list(followLinks: false)) {
        if (e is! File || !e.path.endsWith('.zip')) continue;
        try {
          final stat = await e.stat();
          result.add(BackupInfo(
            name: p.basename(e.path),
            sizeBytes: stat.size,
            modified: stat.modified,
          ));
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error listing backups: $e');
    }
    result.sort((a, b) => b.modified.compareTo(a.modified));
    return result;
  }

  Future<void> clearAllBackups() async {
    final dir = await _backupDir();
    if (!await dir.exists()) return;
    try {
      await for (final e in dir.list(followLinks: false)) {
        if (e is! File || !e.path.endsWith('.zip')) continue;
        try {
          await e.delete();
        } catch (err) {
          debugPrint('Could not delete backup ${e.path}: $err');
        }
      }
    } catch (e) {
      debugPrint('Error clearing backups: $e');
    }
    notifyInternal();
  }

  Future<Directory> _backupDir() async {
    if (kIsWeb) return fs.directory('/pre-pull-backups');
    final supportDir = await getApplicationSupportDirectory();
    return fs.directory(p.join(supportDir.path, 'vault_backups'));
  }

  Future<Uint8List> readBackupBytes(String name) async {
    final safeName = p.basename(name);
    if (safeName != name || name.contains('..')) {
      throw ArgumentError('Invalid backup name');
    }
    final dir = await _backupDir();
    final file = fs.file(p.join(dir.path, safeName));
    if (!await file.exists()) {
      throw StateError('Backup $safeName not found');
    }
    return file.readAsBytes();
  }

  Future<void> deleteBackup(String name) async {
    final safeName = p.basename(name);
    if (safeName != name || name.contains('..')) {
      throw ArgumentError('Invalid backup name');
    }
    final dir = await _backupDir();
    final file = fs.file(p.join(dir.path, safeName));
    if (await file.exists()) {
      await file.delete();
    }
    notifyInternal();
  }

  Future<void> _backupVault() async {
    final retention = effectiveBackupRetentionCount;
    if (retention <= 0) return;

    final archive = Archive();
    final root = fs.directory(vaultPath);
    if (!await root.exists()) return;
    final files = await walkFiles(root);
    for (final f in files) {
      try {
        final rel = p.relative(f.path, from: vaultPath);
        if (kIsWeb && _isDriveBlob(rel)) continue;
        final bytes = await f.readAsBytes();
        archive.addFile(ArchiveFile(rel, bytes.length, bytes));
        if (kIsWeb) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      } catch (_) {}
    }
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(RegExp(r'[^0-9T]'), '')
        .substring(0, 15);
    final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive)!);

    final backupDir = await _backupDir();
    await backupDir.create(recursive: true);
    await fs
        .file(p.join(backupDir.path, 'pre-pull-$stamp.zip'))
        .writeAsBytes(zipBytes);
    debugPrint('Pre-pull backup: '
        '${(zipBytes.length / 1024).toStringAsFixed(0)} KB, '
        '${archive.files.length} file(s)');

    await _pruneOldBackups(backupDir, keep: retention);
  }

  bool _isDriveBlob(String relPath) {
    final parts = relPath.split('/');
    if (parts.length != 3) return false;
    return parts[1] == 'drive';
  }

  Future<void> _pruneOldBackups(Directory dir, {required int keep}) async {
    try {
      final entries = <File>[];
      await for (final e in dir.list(followLinks: false)) {
        if (e is File && e.path.endsWith('.zip')) entries.add(e);
      }
      if (entries.length <= keep) return;

      final stats = <({File f, DateTime modified})>[];
      for (final f in entries) {
        try {
          stats.add((f: f, modified: (await f.stat()).modified));
        } catch (_) {}
      }
      stats.sort((a, b) => a.modified.compareTo(b.modified));
      final toDelete = stats.take(stats.length - keep);
      for (final s in toDelete) {
        try {
          await s.f.delete();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Backup pruning failed: $e');
    }
  }
}