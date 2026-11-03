import 'dart:convert';

import '../hooks.dart';
import '../models.dart';

enum TemplateEscape { url, json, raw }

class TemplateContext {
  final Post post;
  final Space space;
  final Hook hook;
  final HookTrigger trigger;
  final Post? original;
  final Map<String, PostHookState> priorStates;

  const TemplateContext({
    required this.post,
    required this.space,
    required this.hook,
    required this.trigger,
    this.original,
    this.priorStates = const {},
  });

  /// Resolves an expression like `post.title` or
  /// `previous.tg_post.json.result.message_id`. Returns null when the path
  /// doesn't resolve.
  String? lookup(String expr) {
    final parts = expr.split('.');
    final head = parts.first;

    String? simple(String v) => v;

    switch (head) {
      case 'post':
        if (parts.length != 2) return null;
        switch (parts[1]) {
          case 'id':
            return post.id;
          case 'url':
            return post.url ?? '';
          case 'title':
            return post.title ?? '';
          case 'description':
            return post.description ?? '';
          case 'body':
            return post.plaintext;
          case 'tags':
            return post.tags.join(',');
          case 'kind':
            return post.kind.name;
          case 'createdAt':
            return post.createdAt.toIso8601String();
        }
        return null;
      case 'space':
        if (parts.length != 2) return null;
        switch (parts[1]) {
          case 'id':
            return space.id;
          case 'name':
            return space.name;
          case 'icon':
            return space.icon;
        }
        return null;
      case 'hook':
        if (parts.length != 2) return null;
        switch (parts[1]) {
          case 'id':
            return hook.id;
          case 'key':
            return hook.key;
          case 'name':
            return hook.name;
        }
        return null;
      case 'trigger':
        return trigger.name;
      case 'now':
        return DateTime.now().toIso8601String();
      case 'original':
        final o = original;
        if (o == null || parts.length != 2) return null;
        switch (parts[1]) {
          case 'url':
            return o.url ?? '';
          case 'title':
            return o.title ?? '';
          case 'description':
            return o.description ?? '';
          case 'body':
            return o.plaintext;
        }
        return null;
      case 'previous':
        if (parts.length < 3) return null;
        final state = priorStates[parts[1]];
        if (state == null) return null;
        switch (parts[2]) {
          case 'status':
            return state.lastStatus?.toString() ?? '';
          case 'body':
            return state.lastBody ?? '';
          case 'error':
            return state.lastError ?? '';
          case 'headers':
            if (parts.length < 4) return null;
            return state.lastHeaders[parts[3]] ?? '';
          case 'json':
            if (parts.length < 4) return null;
            final raw = state.lastBody;
            if (raw == null || raw.isEmpty) return null;
            try {
              dynamic v = jsonDecode(raw);
              for (var i = 3; i < parts.length; i++) {
                if (v is Map) {
                  v = v[parts[i]];
                } else if (v is List) {
                  final idx = int.tryParse(parts[i]);
                  if (idx == null || idx < 0 || idx >= v.length) return null;
                  v = v[idx];
                } else {
                  return null;
                }
              }
              if (v == null) return null;
              if (v is String) return v;
              if (v is num || v is bool) return v.toString();
              return jsonEncode(v);
            } catch (_) {
              return null;
            }
        }
        return null;
    }
    return null;
  }
}

class TemplateRenderer {
  static final _triple = RegExp(r'\{\{\{([^}]+)\}\}\}');
  static final _double = RegExp(r'\{\{([^}]+)\}\}');

  static String render(
    String template,
    TemplateContext ctx, {
    TemplateEscape escape = TemplateEscape.raw,
  }) {
    var out = template.replaceAllMapped(_triple, (m) {
      return _resolve(m.group(1)!, ctx, TemplateEscape.raw);
    });
    out = out.replaceAllMapped(_double, (m) {
      return _resolve(m.group(1)!, ctx, escape);
    });
    return out;
  }

  static String _resolve(
    String raw,
    TemplateContext ctx,
    TemplateEscape escape,
  ) {
    // `{{a || fallback}}` — first non-empty wins. Fallback with no `.` is
    // treated as a literal; with `.` it's looked up like any expression.
    final alternatives = raw.split('||').map((s) => s.trim());
    for (final alt in alternatives) {
      String? value;
      if (alt.contains('.')) {
        value = ctx.lookup(alt);
      } else {
        // Single-segment: known identifiers, or a literal.
        final asExpr = ctx.lookup(alt);
        value = asExpr ?? alt;
      }
      if (value != null && value.isNotEmpty) {
        return _escape(value, escape);
      }
    }
    return '';
  }

  static String _escape(String v, TemplateEscape escape) {
    switch (escape) {
      case TemplateEscape.url:
        return Uri.encodeComponent(v);
      case TemplateEscape.json:
        // Escape for embedding inside a JSON string value.
        return jsonEncode(v).substring(1, jsonEncode(v).length - 1);
      case TemplateEscape.raw:
        return v;
    }
  }
}