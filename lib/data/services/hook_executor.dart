import 'package:http/http.dart' as http;

import '../hooks.dart';
import '../models.dart';
import 'template.dart';

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
  }) async {
    final ctx = TemplateContext(
      post: post, space: space, hook: hook,
      trigger: trigger, original: original, priorStates: priorStates,
    );

    final started = DateTime.now();

    try {
      final urlStr = TemplateRenderer.render(
        hook.urlTemplate, ctx, escape: TemplateEscape.url,
      );
      final uri = Uri.parse(urlStr);

      final headers = <String, String>{};
      for (final e in hook.headers.entries) {
        headers[TemplateRenderer.render(e.key, ctx)] =
            TemplateRenderer.render(e.value, ctx);
      }

      final req = http.Request(hook.method.toUpperCase(), uri);
      req.headers.addAll(headers);
      if (hook.bodyTemplate != null && hook.bodyTemplate!.isNotEmpty) {
        req.body = TemplateRenderer.render(
          hook.bodyTemplate!, ctx, escape: TemplateEscape.json,
        );
      }

      final streamed = await client
          .send(req)
          .timeout(Duration(seconds: hook.timeoutSeconds));
      final resp = await http.Response.fromStream(streamed);

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
}