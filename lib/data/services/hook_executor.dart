import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../hooks.dart';
import '../models.dart';
import 'condition.dart';
import 'template.dart';

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
    required Post? parent,
    required Space space,
    required HookTrigger trigger,
    required Map<String, PostHookState> priorStates,
    required Map<String, PostHookState> parentPriorStates,
    required List<DriveFile> files,
    required FileResolver resolveFile,
  }) async {
    final started = DateTime.now();
    final baseCtx = TemplateContext(
      post: post,
      space: space,
      hook: hook,
      trigger: trigger,
      original: original,
      priorStates: priorStates,
      files: files,
      parent: parent,
      parentPriorStates: parentPriorStates,
    );

    HookRule? chosen;
    for (final rule in hook.rules) {
      if (ConditionEvaluator.evaluate(rule.when, baseCtx)) {
        chosen = rule;
        break;
      }
    }
    if (chosen == null) {
      return PostHookState(
        lastFiredAt: started,
        lastError: 'No rule matched for this post',
      );
    }

    try {
      final urlStr = TemplateRenderer.render(
        chosen.urlTemplate,
        baseCtx,
        escape: TemplateEscape.url,
      );
      final uri = Uri.parse(urlStr);

      final headers = <String, String>{};
      for (final e in chosen.headers.entries) {
        headers[TemplateRenderer.render(e.key, baseCtx)] =
            TemplateRenderer.render(e.value, baseCtx);
      }

      final http.Response resp;
      if (chosen.multipartParts.isEmpty) {
        resp = await _sendSimple(
          method: chosen.method,
          uri: uri,
          headers: headers,
          bodyTemplate: chosen.bodyTemplate,
          ctx: baseCtx,
          timeout: Duration(seconds: hook.timeoutSeconds),
        );
      } else {
        resp = await _sendMultipart(
          method: chosen.method,
          uri: uri,
          headers: headers,
          parts: chosen.multipartParts,
          ctx: baseCtx,
          resolveFile: resolveFile,
          timeout: Duration(seconds: hook.timeoutSeconds),
        );
      }

      return PostHookState(
        lastFiredAt: started,
        lastStatus: resp.statusCode,
        lastBody: resp.body,
        lastHeaders: resp.headers,
      );
    } catch (e) {
      return PostHookState(lastFiredAt: started, lastError: e.toString());
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
      req.body = TemplateRenderer.render(bodyTemplate, ctx,
          escape: TemplateEscape.json);
    }
    final streamed = await client.send(req).timeout(timeout);
    return http.Response.fromStream(streamed);
  }

  Future<http.Response> _sendMultipart({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    required List<HookMultipartPart> parts,
    required TemplateContext ctx,
    required FileResolver resolveFile,
    required Duration timeout,
  }) async {
    final req = http.MultipartRequest(method.toUpperCase(), uri);
    headers.removeWhere((k, _) => k.toLowerCase() == 'content-type');
    req.headers.addAll(headers);

    for (final part in parts) {
      if (part.repeat == null) {
        await _emitSinglePart(part, ctx, resolveFile, req);
      } else {
        await _emitRepeatedPart(part, ctx, resolveFile, req);
      }
    }

    final streamed = await client.send(req).timeout(timeout);
    return http.Response.fromStream(streamed);
  }

  Future<void> _emitSinglePart(
    HookMultipartPart part,
    TemplateContext ctx,
    FileResolver resolveFile,
    http.MultipartRequest req,
  ) async {
    if (part.template != null) {
      final value = TemplateRenderer.render(part.template!, ctx);
      if (part.skipIfEmpty && value.isEmpty) return;
      req.fields[part.name] = value;
      return;
    }
    final fileId = ctx.lookup(part.filePath!);
    if (fileId == null || fileId.isEmpty) {
      if (part.skipIfEmpty) return;
      throw StateError('Part "${part.name}": filePath '
          '"${part.filePath}" resolved to nothing.');
    }
    final resolved = await resolveFile(fileId);
    if (resolved == null) {
      if (part.skipIfEmpty) return;
      throw StateError('Part "${part.name}": file $fileId not found.');
    }
    req.files.add(http.MultipartFile.fromBytes(
      part.name,
      resolved.bytes,
      filename: part.filename ?? resolved.name,
      contentType: MediaType.parse(resolved.mimeType),
    ));
  }

  Future<void> _emitRepeatedPart(
    HookMultipartPart part,
    TemplateContext ctx,
    FileResolver resolveFile,
    http.MultipartRequest req,
  ) async {
    final files = part.repeat == 'post.files' ? ctx.files : const <DriveFile>[];
    if (files.isEmpty) return;

    if (part.join != null) {
      final joinSep = part.join!;
      final rendered = <String>[];
      for (var i = 0; i < files.length; i++) {
        final iterCtx = _iterContext(ctx, files, i);
        if (part.template != null) {
          rendered.add(TemplateRenderer.render(part.template!, iterCtx));
        } else {
          final id = iterCtx.lookup(part.filePath!);
          if (id == null || id.isEmpty) continue;
          final resolved = await resolveFile(id);
          if (resolved != null) {
            rendered.add(resolved.name);
          }
        }
      }
      final value =
          '${part.prefix ?? ''}${rendered.join(joinSep)}${part.suffix ?? ''}';
      if (part.skipIfEmpty && value.isEmpty) return;
      req.fields[part.name] = value;
      return;
    }

    for (var i = 0; i < files.length; i++) {
      final iterCtx = _iterContext(ctx, files, i);
      final name = TemplateRenderer.render(part.name, iterCtx);
      if (part.template != null) {
        final value = TemplateRenderer.render(part.template!, iterCtx);
        if (part.skipIfEmpty && value.isEmpty) continue;
        req.fields[name] = value;
      } else {
        final id = iterCtx.lookup(part.filePath!);
        if (id == null || id.isEmpty) continue;
        final resolved = await resolveFile(id);
        if (resolved == null) continue;
        final filename = part.filename != null
            ? TemplateRenderer.render(part.filename!, iterCtx)
            : resolved.name;
        req.files.add(http.MultipartFile.fromBytes(
          name,
          resolved.bytes,
          filename: filename,
          contentType: MediaType.parse(resolved.mimeType),
        ));
      }
    }
  }

  TemplateContext _iterContext(
    TemplateContext ctx,
    List<DriveFile> files,
    int index,
  ) {
    final f = files[index];
    return _RepeatTemplateContext(host: ctx, file: f, index: index);
  }
}

class _RepeatTemplateContext extends TemplateContext {
  final TemplateContext _host;
  final DriveFile file;
  final int index;

  _RepeatTemplateContext({
    required TemplateContext host,
    required this.file,
    required this.index,
  })  : _host = host,
        super(
          post: host.post,
          space: host.space,
          hook: host.hook,
          trigger: host.trigger,
          original: host.original,
          priorStates: host.priorStates,
          files: host.files,
          parent: host.parent,
          parentPriorStates: host.parentPriorStates,
        );

  @override
  String? lookup(String expr) {
    if (expr == 'repeat.index') return index.toString();
    if (expr.startsWith('repeat.file.')) {
      switch (expr.substring('repeat.file.'.length)) {
        case 'id':
          return file.id;
        case 'name':
          return file.name;
        case 'category':
          return _host.lookup('post.files.$index.category');
        case 'mime':
          return _host.lookup('post.files.$index.mime');
        case 'size':
          return file.sizeBytes.toString();
      }
      return null;
    }
    return _host.lookup(expr);
  }
}
