import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'sync_config.dart';
import 'sync_provider.dart';
import '../../util/html_utils.dart';

class GitLabProvider extends SyncProvider {
  GitLabProvider({required super.client});

  @override
  SyncProviderKind get kind => SyncProviderKind.gitlab;

  String _projectId(SyncConfig c) =>
      Uri.encodeComponent('${c.owner}/${c.repo}');

  // AFTER — preserves the already-encoded project ID
  Uri _api(SyncConfig c, String path, [Map<String, String>? query]) {
    // Same shape as GitHub, but GitLab self-hosted and GitLab.com both
    // serve the API at /api/v4 — no separate API host, no subpath quirk
    // beyond the optional mount prefix the customer configured.
    final host = c.host?.trim() ?? '';
    final base = (host.isEmpty)
        ? 'https://gitlab.com/api/v4$path'
        : 'https://$host/api/v4$path';
    final uri = Uri.parse(base);
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  Map<String, String> _headers(String token) => {
        'PRIVATE-TOKEN': token,
        'Accept': 'application/json',
      };

  void _checkAuth(http.Response resp) {
    if (resp.statusCode == 401) {
      throw const SyncException('Invalid or expired token.', statusCode: 401);
    }

    // Specifically handle 403 Forbidden errors
    if (resp.statusCode == 403) {
      final remaining = resp.headers['x-ratelimit-remaining'];
      final retryAfter = resp.headers['retry-after'];
      final message = jsonDecode(resp.body)['message'] as String? ?? '';

      // Case 1: Primary Rate Limit Exceeded
      if (remaining == '0') {
        throw SyncException(
          'GitHub primary rate limit exceeded. Please try again later.',
          statusCode: 403,
          remoteBody: resp.body,
        );
      }

      // Case 2: Secondary Rate Limit Exceeded
      if (retryAfter != null || message.toLowerCase().contains('rate limit')) {
        final waitSeconds = retryAfter ?? 'at least 60';
        throw SyncException(
          'GitHub secondary rate limit hit. Please wait $waitSeconds seconds '
          'before retrying.',
          statusCode: 403,
          remoteBody: resp.body,
        );
      }

      // Case 3: Permission Error (no rate limit headers present)
      throw const SyncException(
        'GitHub API forbidden (403). This is likely a permission issue. '
        'Check that your token has "Contents: Read and write" (fine-grained) '
        'or "repo" scope (classic) and that the repository is accessible.',
        statusCode: 403,
      );
    }

    // Handle other potential errors
    if (resp.statusCode == 429) {
      throw SyncException('GitHub API rate limit exceeded (429).',
          statusCode: 429, remoteBody: resp.body);
    }
  }

  @override
  Future<void> verifyAccess({
    required SyncConfig config,
    required String token,
  }) async {
    final uri = _api(config, '/projects/${_projectId(config)}');
    final resp = await client.get(uri, headers: _headers(token));
    _checkAuth(resp);
    if (resp.statusCode == 404) {
      throw const SyncException(
        'Project not found, or your token cannot see it.',
        statusCode: 404,
      );
    }
    if (resp.statusCode != 200) {
      throw SyncException(
        'Failed to reach project: HTTP ${resp.statusCode}',
        statusCode: resp.statusCode,
        remoteBody: resp.body,
      );
    }
  }

  @override
  Future<Map<String, String?>> listRemoteSpaces({
    required SyncConfig config,
    required String token,
  }) async {
    final dirs = await _listRootDirs(config: config, token: token);
    if (dirs.isEmpty) return {};

    final entries = await Future.wait(dirs.map((id) async {
      try {
        final name = await _fetchSpaceName(
          config: config,
          token: token,
          spaceId: id,
        );
        return MapEntry<String, String?>(id, name);
      } catch (e) {
        debugPrint('Could not fetch name for $id: $e');
        return MapEntry<String, String?>(id, null);
      }
    }));
    return Map.fromEntries(entries);
  }

  Future<Set<String>> _listRootDirs({
    required SyncConfig config,
    required String token,
  }) async {
    final uri = _api(
      config,
      '/projects/${_projectId(config)}/repository/tree',
      {'ref': config.branch, 'per_page': '100', 'page': '1'},
    );
    final resp = await client.get(uri, headers: _headers(token));
    _checkAuth(resp);
    if (resp.statusCode == 404) return {};
    if (resp.statusCode != 200) {
      throw SyncException(
        'Failed to list root: HTTP ${resp.statusCode}',
        statusCode: resp.statusCode,
        remoteBody: resp.body,
      );
    }
    final items = jsonDecode(resp.body);
    if (items is! List) return {};
    final out = <String>{};
    for (final item in items) {
      final m = item as Map<String, dynamic>;
      if (m['type'] != 'tree') continue;
      final name = m['name'] as String?;
      if (name == null || name == 'hooks') continue;
      out.add(name);
    }
    return out;
  }

  Future<String?> _fetchSpaceName({
    required SyncConfig config,
    required String token,
    required String spaceId,
  }) async {
    final json = await _fetchFileBytes(
      config: config,
      token: token,
      path: '$spaceId/space.json',
    );
    if (json != null) {
      try {
        final meta = jsonDecode(utf8.decode(json)) as Map<String, dynamic>;
        final name = meta['name'] as String?;
        if (name != null && name.isNotEmpty) return name;
      } catch (_) {}
    }
    final html = await _fetchFileBytes(
      config: config,
      token: token,
      path: '$spaceId/space.html',
    );
    if (html != null) {
      try {
        final meta = parseFrontmatterMeta(utf8.decode(html));
        final name = meta['name'] as String?;
        if (name != null && name.isNotEmpty) return name;
      } catch (_) {}
    }
    return null;
  }

  Future<Uint8List?> _fetchFileBytes({
    required SyncConfig config,
    required String token,
    required String path,
  }) async {
    final encoded = Uri.encodeComponent(path);
    final uri = _api(
      config,
      '/projects/${_projectId(config)}/repository/files/$encoded/raw',
      {'ref': config.branch},
    );
    final resp = await client
        .get(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode == 404) return null;
    _checkAuth(resp);
    if (resp.statusCode != 200) return null;
    return resp.bodyBytes;
  }

  @override
  Future<Set<String>> listRemoteTopLevelDirs({
    required SyncConfig config,
    required String token,
  }) async {
    // No `recursive=true` — one page suffices unless the repo has >100
    // root-level entries, which would mean >100 spaces, in which case
    // pagination handling is a reasonable follow-up.
    final uri = _api(
      config,
      '/projects/${_projectId(config)}/repository/tree',
      {'ref': config.branch, 'per_page': '100', 'page': '1'},
    );
    final resp = await client.get(uri, headers: _headers(token));
    _checkAuth(resp);
    if (resp.statusCode == 404) return {};
    if (resp.statusCode != 200) {
      throw SyncException(
        'Failed to list root: HTTP ${resp.statusCode}',
        statusCode: resp.statusCode,
        remoteBody: resp.body,
      );
    }
    final items = jsonDecode(resp.body);
    if (items is! List) return {};
    final out = <String>{};
    for (final item in items) {
      final m = item as Map<String, dynamic>;
      if (m['type'] != 'tree') continue;
      final name = m['name'] as String?;
      if (name == null || name == 'hooks') continue;
      out.add(name);
    }
    return out;
  }

  @override
  Future<Map<String, String>> listRemoteFiles({
    required SyncConfig config,
    required String token,
    required bool isPush,
    SyncProgressCallback? onProgress,
  }) async {
    final out = <String, String>{};
    var page = 1;
    while (true) {
      onProgress?.call(SyncProgress(
        totalFiles: 0,
        completedFiles: out.length,
        isPush: isPush,
        message: 'Listing remote files… ${out.length} found (page $page)',
      ));
      final uri = _api(
        config,
        '/projects/${_projectId(config)}/repository/tree',
        {
          'ref': config.branch,
          'recursive': 'true',
          'per_page': '100',
          'page': page.toString(),
        },
      );
      final resp = await client.get(uri, headers: _headers(token));
      _checkAuth(resp);
      if (resp.statusCode == 404) return {};
      if (resp.statusCode != 200) {
        throw SyncException(
          'Failed to list tree: HTTP ${resp.statusCode}',
          statusCode: resp.statusCode,
          remoteBody: resp.body,
        );
      }
      final items = jsonDecode(resp.body) as List;
      for (final item in items) {
        final m = item as Map<String, dynamic>;
        if (m['type'] != 'blob') continue;
        out[m['path'] as String] = m['id'] as String;
      }
      if (items.length < 100) break;
      page++;
    }
    onProgress?.call(SyncProgress(
      totalFiles: out.length,
      completedFiles: out.length,
      isPush: isPush,
      message: 'Remote tree listed: ${out.length} files',
    ));
    return out;
  }

  @override
  Future<String?> currentHeadSha({
    required SyncConfig config,
    required String token,
  }) async {
    final uri = _api(
      config,
      '/projects/${_projectId(config)}/repository/branches/'
      '${Uri.encodeComponent(config.branch)}',
    );
    final resp = await client.get(uri, headers: _headers(token));
    if (resp.statusCode == 404) return null;
    _checkAuth(resp);
    if (resp.statusCode != 200) return null;
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return (data['commit'] as Map<String, dynamic>?)?['id'] as String?;
  }

  @override
  Future<Uint8List> downloadFile({
    required SyncConfig config,
    required String token,
    required String path,
  }) async {
    final encoded = Uri.encodeComponent(path);
    final uri = _api(
      config,
      '/projects/${_projectId(config)}/repository/files/$encoded/raw',
      {'ref': config.branch},
    );
    final resp = await client.get(uri, headers: _headers(token));
    _checkAuth(resp);
    if (resp.statusCode != 200) {
      throw SyncException(
        'Failed to download $path: HTTP ${resp.statusCode}',
        statusCode: resp.statusCode,
        remoteBody: resp.body,
      );
    }
    return resp.bodyBytes;
  }

  static const int _commitBatchSize = 1000;
  static const int _commitBatchMaxBytes = 10 * 1024 * 1024; // 10 MB body

  @override
  Future<String> commit({
    required SyncConfig config,
    required String token,
    required String message,
    required List<FileChange> changes,
    SyncProgressCallback? onProgress,
  }) async {
    if (changes.isEmpty) return config.lastCommitSha ?? '';

    // Bootstrap the branch if it doesn't exist yet (unchanged from before).
    var workingChanges = changes;
    if (!await _branchExists(config, token, config.branch)) {
      final defaultBranch = await _projectDefaultBranch(config, token);
      if (defaultBranch == null || defaultBranch.isEmpty) {
        final first = workingChanges.firstWhere(
          (c) => c.kind != FileChangeKind.delete,
          orElse: () => throw const SyncException(
            'Remote repository is empty and there is nothing to create.',
          ),
        );
        await _createFirstFile(
          config: config,
          token: token,
          change: first,
          branch: config.branch,
          commitMessage: message,
        );
        workingChanges =
            workingChanges.where((c) => !identical(c, first)).toList();
        if (workingChanges.isEmpty) {
          return _currentBranchHeadSha(config, token, config.branch);
        }
      } else if (defaultBranch != config.branch) {
        await _createBranch(
          config: config,
          token: token,
          branch: config.branch,
          ref: defaultBranch,
        );
      }
    }

    // Split by both count and base64 body size so one huge file can't blow
    // up a batch and one tiny file can't make batches too numerous.
    final batches = _splitIntoBatches(workingChanges);
    var lastSha = '';
    var completedFiles = 0;

    for (var i = 0; i < batches.length; i++) {
      final batch = batches[i];
      final msg = batches.length == 1
          ? message
          : '$message (${i + 1}/${batches.length})';
      lastSha = await _commitBatch(
        config: config,
        token: token,
        message: msg,
        changes: batch,
      );
      completedFiles += batch.length;
      onProgress?.call(SyncProgress(
        totalFiles: workingChanges.length,
        completedFiles: completedFiles,
        isPush: true,
        message: 'Committed ${i + 1}/${batches.length} — '
            '$completedFiles/${workingChanges.length} files',
      ));
    }
    return lastSha;
  }

  List<List<FileChange>> _splitIntoBatches(List<FileChange> changes) {
    final batches = <List<FileChange>>[];
    var current = <FileChange>[];
    var currentBytes = 0;
    for (final c in changes) {
      final size = c.content?.length ?? 0;
      // base64 inflates by 4/3. Sum raw bytes, inflate once at the end.
      final b64 = (size * 4 / 3).ceil();
      final wouldOverflowBytes =
          current.isNotEmpty && currentBytes + b64 > _commitBatchMaxBytes;
      final wouldOverflowCount = current.length >= _commitBatchSize;
      if (wouldOverflowBytes || wouldOverflowCount) {
        batches.add(current);
        current = [];
        currentBytes = 0;
      }
      current.add(c);
      currentBytes += b64;
    }
    if (current.isNotEmpty) batches.add(current);
    return batches;
  }

  Future<String> _commitBatch({
    required SyncConfig config,
    required String token,
    required String message,
    required List<FileChange> changes,
  }) async {
    final actions = <Map<String, dynamic>>[];
    for (final c in changes) {
      switch (c.kind) {
        case FileChangeKind.delete:
          actions.add({'action': 'delete', 'file_path': c.path});
        case FileChangeKind.create:
          actions.add({
            'action': 'create',
            'file_path': c.path,
            'content': base64Encode(c.content!),
            'encoding': 'base64',
          });
        case FileChangeKind.update:
          actions.add({
            'action': 'update',
            'file_path': c.path,
            'content': base64Encode(c.content!),
            'encoding': 'base64',
          });
      }
    }

    final uri = _api(
      config,
      '/projects/${_projectId(config)}/repository/commits',
    );
    final resp = await client.post(
      uri,
      headers: {..._headers(token), 'Content-Type': 'application/json'},
      body: jsonEncode({
        'branch': config.branch,
        'commit_message': message,
        'actions': actions,
      }),
    );
    _checkAuth(resp);
    if (resp.statusCode == 404) {
      throw const SyncException(
        'Commit rejected (404). The branch does not exist, the request '
        'was too large even after batching, or your token lacks the "api" '
        'scope. "write_repository" alone is not enough.',
        statusCode: 404,
      );
    }
    if (resp.statusCode != 201) {
      throw SyncException(
        'Failed to create commit: HTTP ${resp.statusCode}',
        statusCode: resp.statusCode,
        remoteBody: resp.body,
      );
    }
    return (jsonDecode(resp.body) as Map<String, dynamic>)['id'] as String;
  }

  Future<String> _currentBranchHeadSha(
    SyncConfig config,
    String token,
    String branch,
  ) async {
    final uri = _api(
      config,
      '/projects/${_projectId(config)}/repository/branches/'
      '${Uri.encodeComponent(branch)}',
    );
    final resp = await client.get(uri, headers: _headers(token));
    if (resp.statusCode != 200) return '';
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return (data['commit'] as Map<String, dynamic>?)?['id'] as String? ?? '';
  }

// ── Branch helpers ─────────────────────────────────────────────────────────

  Future<bool> _branchExists(
    SyncConfig config,
    String token,
    String branch,
  ) async {
    final uri = _api(
      config,
      '/projects/${_projectId(config)}/repository/branches/'
      '${Uri.encodeComponent(branch)}',
    );
    final resp = await client.get(uri, headers: _headers(token));
    if (resp.statusCode == 200) return true;
    if (resp.statusCode == 404) return false;
    _checkAuth(resp);
    throw SyncException(
      'Failed to check branch "$branch": HTTP ${resp.statusCode}',
      statusCode: resp.statusCode,
      remoteBody: resp.body,
    );
  }

  Future<String?> _projectDefaultBranch(
    SyncConfig config,
    String token,
  ) async {
    final uri = _api(config, '/projects/${_projectId(config)}');
    final resp = await client.get(uri, headers: _headers(token));
    _checkAuth(resp);
    if (resp.statusCode != 200) {
      throw SyncException(
        'Failed to read project: HTTP ${resp.statusCode}',
        statusCode: resp.statusCode,
        remoteBody: resp.body,
      );
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (data['empty_repo'] == true) return null;
    return data['default_branch'] as String?;
  }

  Future<void> _createBranch({
    required SyncConfig config,
    required String token,
    required String branch,
    required String ref,
  }) async {
    final uri = _api(
      config,
      '/projects/${_projectId(config)}/repository/branches',
      {'branch': branch, 'ref': ref},
    );
    final resp = await client.post(uri, headers: _headers(token));
    _checkAuth(resp);
    if (resp.statusCode != 201) {
      throw SyncException(
        'Failed to create branch "$branch" from "$ref": '
        'HTTP ${resp.statusCode}',
        statusCode: resp.statusCode,
        remoteBody: resp.body,
      );
    }
  }

  Future<void> _createFirstFile({
    required SyncConfig config,
    required String token,
    required FileChange change,
    required String branch,
    required String commitMessage,
  }) async {
    if (change.kind == FileChangeKind.delete) {
      throw const SyncException(
        'Cannot bootstrap an empty repository with a delete.',
      );
    }
    final path = Uri.encodeComponent(change.path);
    final uri = _api(
      config,
      '/projects/${_projectId(config)}/repository/files/$path',
    );
    final resp = await client.post(
      uri,
      headers: {..._headers(token), 'Content-Type': 'application/json'},
      body: jsonEncode({
        'branch': branch,
        'content': base64Encode(change.content!),
        'encoding': 'base64',
        'commit_message': commitMessage,
        'author_name': 'Vault',
        'author_email': 'vault@localhost',
      }),
    );
    _checkAuth(resp);
    if (resp.statusCode != 201) {
      throw SyncException(
        'Failed to create initial file ${change.path}: '
        'HTTP ${resp.statusCode}. If this is an existing repository, '
        'check that the branch name matches (try "main" or "master").',
        statusCode: resp.statusCode,
        remoteBody: resp.body,
      );
    }
  }
}
