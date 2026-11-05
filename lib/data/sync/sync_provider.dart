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
  double get fraction =>
      totalFiles > 0 ? completedFiles / totalFiles : 0.0;
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

  /// Map of repo-relative path → git blob SHA.
  Future<Map<String, String>> listRemoteFiles({
    required SyncConfig config,
    required String token,
    required bool isPush,             // for progress display
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