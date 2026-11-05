import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'sync_config.dart';
import 'sync_provider.dart';

class GitHubProvider extends SyncProvider {
  GitHubProvider({required super.client});

  @override
  SyncProviderKind get kind => SyncProviderKind.github;

  Uri _api(SyncConfig c, String path, [Map<String, String>? query]) =>
      Uri.https('api.github.com', path, query);

  Map<String, String> _headers(String token) => {
        'Authorization': 'token $token',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      };

  void _checkAuth(http.Response resp) {
    if (resp.statusCode == 401) {
      throw const SyncException('Invalid or expired token.', statusCode: 401);
    }
    if (resp.statusCode == 403 || resp.statusCode == 429) {
      throw SyncException(
        'Token lacks permission, or API rate limit exceeded. '
        'Check headers or try again later.',
        statusCode: resp.statusCode,
      );
    }
  }

  @override
  Future<void> verifyAccess({
    required SyncConfig config,
    required String token,
  }) async {
    final uri = _api(config, '/repos/${config.owner}/${config.repo}');
    final resp = await client.get(uri, headers: _headers(token));
    _checkAuth(resp);
    if (resp.statusCode == 404) {
      throw const SyncException(
        'Repository not found, or your token cannot see it.',
        statusCode: 404,
      );
    }
    if (resp.statusCode != 200) {
      throw SyncException(
        'Failed to reach repository: HTTP ${resp.statusCode}',
        statusCode: resp.statusCode,
        remoteBody: resp.body,
      );
    }
  }

  @override
  Future<Map<String, String>> listRemoteFiles({
    required SyncConfig config,
    required String token,
    required bool isPush,
    SyncProgressCallback? onProgress,
  }) async {
    final out = <String, String>{};
    await _fetchTreeRecursive(
      config: config,
      token: token,
      ref: config.branch,
      prefix: '',
      out: out,
      isPush: isPush,
      onProgress: onProgress,
    );
    onProgress?.call(SyncProgress(
      totalFiles: out.length,
      completedFiles: out.length,
      isPush: isPush,
      message: 'Remote tree listed: ${out.length} files',
    ));
    return out;
  }

  Future<void> _fetchTreeRecursive({
    required SyncConfig config,
    required String token,
    required String ref,
    required String prefix,
    required Map<String, String> out,
    required bool isPush,
    SyncProgressCallback? onProgress,
  }) async {
    onProgress?.call(SyncProgress(
      totalFiles: 0,
      completedFiles: out.length,
      isPush: isPush,
      message: 'Listing remote files… ${out.length} found',
    ));

    final uri = _api(
      config,
      '/repos/${config.owner}/${config.repo}/git/trees/$ref',
      {'recursive': '1'},
    );
    final resp = await client.get(uri, headers: _headers(token));
    _checkAuth(resp);
    if (resp.statusCode == 404) return;
    if (resp.statusCode != 200) {
      throw SyncException(
        'Failed to list tree: HTTP ${resp.statusCode}',
        statusCode: resp.statusCode,
        remoteBody: resp.body,
      );
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final tree = (data['tree'] as List?) ?? const [];
    final truncated = data['truncated'] == true;

    if (!truncated) {
      for (final entry in tree) {
        final e = entry as Map<String, dynamic>;
        if (e['type'] == 'blob') {
          out['$prefix${e['path']}'] = e['sha'] as String;
        }
      }
      return;
    }

    // Truncated: walk subtrees. Re-fetch without `recursive` to get the
    // full top-level layout, then recurse into each directory.
    final topUri = _api(
      config,
      '/repos/${config.owner}/${config.repo}/git/trees/$ref',
    );
    final topResp = await client.get(topUri, headers: _headers(token));
    _checkAuth(topResp);
    if (topResp.statusCode != 200) {
      throw SyncException(
        'Failed to walk truncated tree: HTTP ${topResp.statusCode}',
        statusCode: topResp.statusCode,
        remoteBody: topResp.body,
      );
    }
    final topData = jsonDecode(topResp.body) as Map<String, dynamic>;
    final topTree = (topData['tree'] as List?) ?? const [];
    for (final entry in topTree) {
      final e = entry as Map<String, dynamic>;
      if (e['type'] == 'blob') {
        out['$prefix${e['path']}'] = e['sha'] as String;
      } else if (e['type'] == 'tree') {
        await _fetchTreeRecursive(
          config: config,
          token: token,
          ref: e['sha'] as String,
          prefix: '$prefix${e['path']}/',
          out: out,
          isPush: isPush,
          onProgress: onProgress,
        );
      }
    }
  }

  @override
  Future<String?> currentHeadSha({
    required SyncConfig config,
    required String token,
  }) async {
    final uri = _api(
      config,
      '/repos/${config.owner}/${config.repo}/git/ref/heads/${config.branch}',
    );
    final resp = await client.get(uri, headers: _headers(token));
    if (resp.statusCode == 404) return null;
    _checkAuth(resp);
    if (resp.statusCode != 200) return null;
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return (data['object'] as Map<String, dynamic>?)?['sha'] as String?;
  }

  @override
  Future<Uint8List> downloadFile({
    required SyncConfig config,
    required String token,
    required String path,
  }) async {
    final uri = _api(
      config,
      '/repos/${config.owner}/${config.repo}/contents/${Uri.encodeFull(path)}',
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
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final content = data['content'] as String?;
    if (content != null) {
      return base64Decode(content.replaceAll('\n', ''));
    }
    // GitHub omits `content` for files >1MB and sets `download_url`.
    final downloadUrl = data['download_url'] as String?;
    if (downloadUrl == null) {
      throw SyncException(
          'Unexpected response for $path (no content or download_url)');
    }
    final raw = await client.get(Uri.parse(downloadUrl));
    if (raw.statusCode != 200) {
      throw SyncException(
        'Failed to download $path via raw URL: HTTP ${raw.statusCode}',
        statusCode: raw.statusCode,
      );
    }
    return raw.bodyBytes;
  }

  @override
  Future<String> commit({
    required SyncConfig config,
    required String token,
    required String message,
    required List<FileChange> changes,
    SyncProgressCallback? onProgress,
  }) async {
    if (changes.isEmpty) return config.lastCommitSha ?? '';

    // Read current ref (may not exist on empty repo).
    String? parentSha;
    String? baseTreeSha;
    final refUri = _api(config,
        '/repos/${config.owner}/${config.repo}/git/ref/heads/${config.branch}');
    final refResp = await client.get(refUri, headers: _headers(token));
    if (refResp.statusCode == 200) {
      final refData = jsonDecode(refResp.body) as Map<String, dynamic>;
      parentSha = refData['object']['sha'] as String;
      final commitUri = _api(config,
          '/repos/${config.owner}/${config.repo}/git/commits/$parentSha');
      final commitResp = await client.get(commitUri, headers: _headers(token));
      if (commitResp.statusCode == 200) {
        baseTreeSha = (jsonDecode(commitResp.body)
            as Map<String, dynamic>)['tree']['sha'] as String;
      }
    } else if (refResp.statusCode != 404) {
      _checkAuth(refResp);
      throw SyncException(
        'Failed to read branch head: HTTP ${refResp.statusCode}',
        statusCode: refResp.statusCode,
        remoteBody: refResp.body,
      );
    }

// Upload blobs.
    final treeEntries = <Map<String, dynamic>>[];
    var completedBlobs = 0;
    final uploadTotal =
        changes.where((c) => c.kind != FileChangeKind.delete).length;

    for (final change in changes) {
      if (change.kind == FileChangeKind.delete) {
        treeEntries.add({
          'path': change.path,
          'mode': '100644',
          'type': 'blob',
          'sha': null,
        });
        continue;
      }
      final blobUri =
          _api(config, '/repos/${config.owner}/${config.repo}/git/blobs');
      final blobResp = await client.post(
        blobUri,
        headers: _headers(token),
        body: jsonEncode({
          'content': base64Encode(change.content!),
          'encoding': 'base64',
        }),
      );
      _checkAuth(blobResp);
      if (blobResp.statusCode != 201) {
        throw SyncException(
          'Failed to upload blob for ${change.path}: '
          'HTTP ${blobResp.statusCode}',
          statusCode: blobResp.statusCode,
          remoteBody: blobResp.body,
        );
      }
      treeEntries.add({
        'path': change.path,
        'mode': '100644',
        'type': 'blob',
        'sha': (jsonDecode(blobResp.body) as Map<String, dynamic>)['sha']
            as String,
      });
      completedBlobs++;
      onProgress?.call(SyncProgress(
        totalFiles: changes.length,
        completedFiles: completedBlobs,
        isPush: true,
        message: 'Uploaded $completedBlobs/$uploadTotal blobs',
      ));
    }

    onProgress?.call(SyncProgress(
      totalFiles: changes.length,
      completedFiles: changes.length,
      isPush: true,
      message: 'Creating tree and commit…',
    ));

    // Create tree.
    final treeUri =
        _api(config, '/repos/${config.owner}/${config.repo}/git/trees');
    final treeResp = await client.post(
      treeUri,
      headers: _headers(token),
      body: jsonEncode({
        'tree': treeEntries,
        if (baseTreeSha != null) 'base_tree': baseTreeSha,
      }),
    );
    _checkAuth(treeResp);
    if (treeResp.statusCode != 201) {
      throw SyncException(
        'Failed to create tree: HTTP ${treeResp.statusCode}',
        statusCode: treeResp.statusCode,
        remoteBody: treeResp.body,
      );
    }
    final newTreeSha =
        (jsonDecode(treeResp.body) as Map<String, dynamic>)['sha'] as String;

    // Create commit.
    final commitUri =
        _api(config, '/repos/${config.owner}/${config.repo}/git/commits');
    final newCommitResp = await client.post(
      commitUri,
      headers: _headers(token),
      body: jsonEncode({
        'message': message,
        'tree': newTreeSha,
        'parents': parentSha != null ? [parentSha] : <String>[],
      }),
    );
    _checkAuth(newCommitResp);
    if (newCommitResp.statusCode != 201) {
      throw SyncException(
        'Failed to create commit: HTTP ${newCommitResp.statusCode}',
        statusCode: newCommitResp.statusCode,
        remoteBody: newCommitResp.body,
      );
    }
    final newCommitSha = (jsonDecode(newCommitResp.body)
        as Map<String, dynamic>)['sha'] as String;

    // Update or create ref.
    if (parentSha != null) {
      final updateUri = _api(config,
          '/repos/${config.owner}/${config.repo}/git/refs/heads/${config.branch}');
      final updateResp = await client.patch(
        updateUri,
        headers: _headers(token),
        body: jsonEncode({'sha': newCommitSha, 'force': false}),
      );
      _checkAuth(updateResp);
      if (updateResp.statusCode == 422) {
        throw const SyncException(
          'Remote branch has diverged since last sync. Pull first, '
          'then push.',
          statusCode: 422,
        );
      }
      if (updateResp.statusCode != 200) {
        throw SyncException(
          'Failed to update branch ref: HTTP ${updateResp.statusCode}',
          statusCode: updateResp.statusCode,
          remoteBody: updateResp.body,
        );
      }
    } else {
      final createUri =
          _api(config, '/repos/${config.owner}/${config.repo}/git/refs');
      final createResp = await client.post(
        createUri,
        headers: _headers(token),
        body: jsonEncode({
          'ref': 'refs/heads/${config.branch}',
          'sha': newCommitSha,
        }),
      );
      _checkAuth(createResp);
      if (createResp.statusCode != 201) {
        throw SyncException(
          'Failed to create branch: HTTP ${createResp.statusCode}',
          statusCode: createResp.statusCode,
          remoteBody: createResp.body,
        );
      }
    }

    return newCommitSha;
  }
}
