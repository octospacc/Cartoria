import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'sync_config.dart';

enum FileChangeKind { create, update, delete }

class FileChange {
  final String path;
  final FileChangeKind kind;
  final Uint8List? content;
  const FileChange.create(this.path, this.content)
      : kind = FileChangeKind.create;
  const FileChange.update(this.path, this.content)
      : kind = FileChangeKind.update;
  const FileChange.delete(this.path)
      : kind = FileChangeKind.delete,
        content = null;
}

class SyncException implements Exception {
  final String message;
  final int? statusCode;
  final String? remoteBody;
  const SyncException(this.message, {this.statusCode, this.remoteBody});

  @override
  String toString() => statusCode != null
      ? 'SyncException($statusCode): $message'
      : 'SyncException: $message';
}

class SyncProgress {
  final int totalFiles;
  final int completedFiles;
  final bool isPush;
  final String? message;
  const SyncProgress({
    required this.totalFiles,
    required this.completedFiles,
    required this.isPush,
    this.message,
  });
  double get fraction => totalFiles > 0 ? completedFiles / totalFiles : 0.0;
}

typedef SyncProgressCallback = void Function(SyncProgress);

/// Provider-agnostic interface. Implementations translate to the
/// specific git-forge REST API but keep the same three operations:
/// verify, list, commit. Downloads are individual-file pulls.
abstract class SyncProvider {
  final http.Client client;
  const SyncProvider({required this.client});

  SyncProviderKind get kind;

  Future<void> verifyAccess({
    required SyncConfig config,
    required String token,
  });

  /// Top-level directory names at the repo root (one per space), minus
  /// `hooks` which is vault-level and not user-selectable. Cheap:
  /// single API call, non-recursive.
  ///
  /// Used by the config editor to show remote spaces that don't yet exist
  /// locally — otherwise a user setting up a scoped sync config has no way
  /// to add a space they haven't pulled yet.
  Future<Set<String>> listRemoteTopLevelDirs({
    required SyncConfig config,
    required String token,
  });

  /// Lists the spaces present at the repo root with their display names.
  ///
  /// Returns a map of `spaceId → displayName`. `displayName` is null when
  /// the metadata file can't be read (rare — permissions, corrupt JSON,
  /// or a space directory that has no `space.json`/`space.html` yet).
  ///
  /// Names are best-effort: callers should fall back to the ID for
  /// display. Used by the sync config editor to show remote-only spaces
  /// that don't exist locally — without a name, the picker is just a list
  /// of UUIDs, which is unhelpful.
  Future<Map<String, String?>> listRemoteSpaces({
    required SyncConfig config,
    required String token,
  });

  /// Map of repo-relative path → git blob SHA.
  Future<Map<String, String>> listRemoteFiles({
    required SyncConfig config,
    required String token,
    required bool isPush, // for progress display
    SyncProgressCallback? onProgress,
  });

  /// SHA of the branch head, or null for an empty repo. One cheap API call —
  /// used to check whether a cached listing is still valid.
  Future<String?> currentHeadSha({
    required SyncConfig config,
    required String token,
  });

  Future<Uint8List> downloadFile({
    required SyncConfig config,
    required String token,
    required String path,
  });

  /// Applies all [changes] as one commit. Returns the new commit SHA.
  Future<String> commit({
    required SyncConfig config,
    required String token,
    required String message,
    required List<FileChange> changes,
    SyncProgressCallback? onProgress,
  });
}
