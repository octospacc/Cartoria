import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../hooks.dart';
import '../models.dart';
import 'template.dart';

/// File bytes + name + MIME, resolved lazily by the caller from the vault.
/// The executor does not touch the filesystem — the facade hands it this.
class ResolvedFile {
  final Uint8List bytes;
  final String name;
  final String mimeType;

  const ResolvedFile({
    required this.bytes,
    required this.name,
    required this.mimeType,
  });
}

typedef FileResolver = Future<ResolvedFile?> Function(String fileId);

class HookExecutor {
  final http.Client client;

  const HookExecutor({required this.client});

  Future<PostHookState> execute({
    required Hook hook,
    required Post post,
    required Post? original,
    required Space space,
    required HookTrigger trigger,
    required Map<String, PostHookState> priorStates,
    required FileResolver resolveFile,
  }) async {
    final ctx = TemplateContext(
      post: post,
      space: space,
      hook: hook,
      trigger: trigger,
      original: original,
      priorStates: priorStates,
    );

    final started = DateTime.now();

    try {
      final urlStr = TemplateRenderer.render(
        hook.urlTemplate,
        ctx,
        escape: TemplateEscape.url,
      );
      final uri = Uri.parse(urlStr);

      final headers = <String, String>{};
      for (final e in hook.headers.entries) {
        headers[TemplateRenderer.render(e.key, ctx)] =
            TemplateRenderer.render(e.value, ctx);
      }

      final http.Response resp;
      if (hook.multipartParts.isEmpty) {
        resp = await _sendSimple(
          method: hook.method,
          uri: uri,
          headers: headers,
          bodyTemplate: hook.bodyTemplate,
          ctx: ctx,
          timeout: Duration(seconds: hook.timeoutSeconds),
        );
      } else {
        resp = await _sendMultipart(
          method: hook.method,
          uri: uri,
          headers: headers,
          parts: hook.multipartParts,
          post: post,
          ctx: ctx,
          resolveFile: resolveFile,
          timeout: Duration(seconds: hook.timeoutSeconds),
        );
      }

      return PostHookState(
        lastFiredAt: started,
        lastStatus: resp.statusCode,
        lastBody: resp.body,
        lastHeaders: resp.headers,
        lastError: null,
      );
    } catch (e) {
      return PostHookState(
        lastFiredAt: started,
        lastStatus: null,
        lastBody: null,
        lastHeaders: const {},
        lastError: e.toString(),
      );
    }
  }

  Future<http.Response> _sendSimple({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    required String? bodyTemplate,
    required TemplateContext ctx,
    required Duration timeout,
  }) async {
    final req = http.Request(method.toUpperCase(), uri);
    req.headers.addAll(headers);
    if (bodyTemplate != null && bodyTemplate.isNotEmpty) {
      req.body = TemplateRenderer.render(
        bodyTemplate,
        ctx,
        escape: TemplateEscape.json,
      );
    }
    final streamed = await client.send(req).timeout(timeout);
    return http.Response.fromStream(streamed);
  }

  Future<http.Response> _sendMultipart({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    required List<HookMultipartPart> parts,
    required Post post,
    required TemplateContext ctx,
    required FileResolver resolveFile,
    required Duration timeout,
  }) async {
    final req = http.MultipartRequest(method.toUpperCase(), uri);

    // `package:http` sets `Content-Type: multipart/form-data; boundary=…`
    // itself. A user-configured JSON Content-Type would break the request.
    headers.removeWhere((k, _) => k.toLowerCase() == 'content-type');
    req.headers.addAll(headers);

    for (final part in parts) {
      if (part.template != null) {
        req.fields[part.name] =
            TemplateRenderer.render(part.template!, ctx);
        continue;
      }

      final idx = part.fileIndex!;
      if (idx < 0 || idx >= post.fileIds.length) {
        throw StateError(
          'Multipart part "${part.name}" references file index $idx, '
          'but the post has ${post.fileIds.length} file(s).',
        );
      }
      final fileId = post.fileIds[idx];
      final resolved = await resolveFile(fileId);
      if (resolved == null) {
        throw StateError(
          'Multipart part "${part.name}": file $fileId not found in drive.',
        );
      }

      req.files.add(http.MultipartFile.fromBytes(
        part.name,
        resolved.bytes,
        filename: part.filename ?? resolved.name,
        contentType: MediaType.parse(resolved.mimeType),
      ));
    }

    final streamed = await client.send(req).timeout(timeout);
    return http.Response.fromStream(streamed);
  }
}