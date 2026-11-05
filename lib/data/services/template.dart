import 'dart:convert';

import '../../util/file_category.dart';
import '../../util/mime.dart';
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
  final List<DriveFile> files;

  /// The post this one replies to, if any. Enables `parent.post.*` (fields)
  /// and `parent.previous.<key>.*` (parent's hook results).
  final Post? parent;

  /// Parent's `hookState` map, if [parent] is not null.
  final Map<String, PostHookState> parentPriorStates;

  const TemplateContext({
    required this.post,
    required this.space,
    required this.hook,
    required this.trigger,
    this.original,
    this.priorStates = const {},
    this.files = const [],
    this.parent,
    this.parentPriorStates = const {},
  });

  String? lookup(String expr) {
    final parts = expr.split('.');
    final head = parts.first;

    switch (head) {
      case 'post':
        if (parts.length >= 2 && parts[1] == 'files') {
          if (parts.length == 3 && parts[2] == 'length') {
            return files.length.toString();
          }
          if (parts.length >= 4) {
            final idx = int.tryParse(parts[2]);
            if (idx == null || idx < 0 || idx >= files.length) return null;
            final f = files[idx];
            switch (parts[3]) {
              case 'id':
                return f.id;
              case 'name':
                return f.name;
              case 'category':
                return categoryFor(f.name).name;
              case 'mime':
                return mimeTypeForName(f.name);
              case 'size':
                return f.sizeBytes.toString();
            }
          }
          return null;
        }
        if (parts.length != 2) return null;
        switch (parts[1]) {
          case 'id': return post.id;
          case 'parentId': return post.parentId; // null for root posts
          case 'url': return post.url ?? '';
          case 'title': return post.title ?? '';
          case 'description': return post.description ?? '';
          case 'body': return post.plaintext;
          case 'tags': return post.tags.join(',');
          case 'kind': return post.kind.name;
          case 'createdAt': return post.createdAt.toIso8601String();
        }
        return null;
      case 'space':
        if (parts.length != 2) return null;
        switch (parts[1]) {
          case 'id': return space.id;
          case 'name': return space.name;
          case 'icon': return space.icon;
        }
        return null;
      case 'hook':
        if (parts.length != 2) return null;
        switch (parts[1]) {
          case 'id': return hook.id;
          case 'key': return hook.key;
          case 'name': return hook.name;
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
          case 'url': return o.url ?? '';
          case 'title': return o.title ?? '';
          case 'description': return o.description ?? '';
          case 'body': return o.plaintext;
        }
        return null;
      case 'parent':
        final p = parent;
        if (p == null || parts.length < 3) return null;
        if (parts[1] == 'post') {
          switch (parts[2]) {
            case 'id': return p.id;
            case 'parentId': return p.parentId;
            case 'url': return p.url ?? '';
            case 'title': return p.title ?? '';
            case 'description': return p.description ?? '';
            case 'body': return p.plaintext;
            case 'tags': return p.tags.join(',');
            case 'kind': return p.kind.name;
            case 'createdAt': return p.createdAt.toIso8601String();
          }
          return null;
        }
        if (parts[1] == 'previous' && parts.length >= 4) {
          return _resolvePrevious(
            parentPriorStates,
            parts.sublist(2),
          );
        }
        return null;
      case 'previous':
        if (parts.length < 3) return null;
        return _resolvePrevious(priorStates, parts.sublist(1));
    }
    return null;
  }

  /// Shared logic for `previous.<key>.<path>` and `parent.previous.<key>.<path>`.
  static String? _resolvePrevious(
    Map<String, PostHookState> states,
    List<String> parts,
  ) {
    final key = parts[0];
    final state = states[key];
    if (state == null) return null;
    if (parts.length < 2) return null;
    switch (parts[1]) {
      case 'status':
        return state.lastStatus?.toString() ?? '';
      case 'body':
        return state.lastBody ?? '';
      case 'error':
        return state.lastError ?? '';
      case 'headers':
        if (parts.length < 3) return null;
        return state.lastHeaders[parts[2]] ?? '';
      case 'json':
        if (parts.length < 3) return null;
        final raw = state.lastBody;
        if (raw == null || raw.isEmpty) return null;
        try {
          dynamic v = jsonDecode(raw);
          for (var i = 2; i < parts.length; i++) {
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
}

class TemplateRenderer {
  static final _triple = RegExp(r'\{\{\{(.+?)\}\}\}', dotAll: true);
  static final _double = RegExp(r'\{\{(.+?)\}\}', dotAll: true);

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
    final segments = _splitPipeline(raw);
    var value = _resolveBase(segments.first, ctx);
    for (var i = 1; i < segments.length; i++) {
      value = _applyFunction(value, segments[i]);
    }
    return _escape(value, escape);
  }

  static List<String> _splitPipeline(String raw) {
    final parts = <String>[];
    final cur = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      final c = raw[i];
      if (c == '|' && i + 1 < raw.length && raw[i + 1] == '|') {
        cur.write('||');
        i++;
      } else if (c == '|') {
        parts.add(cur.toString().trim());
        cur.clear();
      } else {
        cur.write(c);
      }
    }
    parts.add(cur.toString().trim());
    return parts;
  }

  static String _resolveBase(String raw, TemplateContext ctx) {
    final alternatives = raw.split('||').map((s) => s.trim());
    for (final alt in alternatives) {
      String? value;
      if (alt.contains('.')) {
        value = ctx.lookup(alt);
      } else {
        final asExpr = ctx.lookup(alt);
        value = asExpr ?? alt;
      }
      if (value != null && value.isNotEmpty) return value;
    }
    return '';
  }

  static String _applyFunction(String value, String spec) {
    final m = RegExp(r'^(\w+)(?:\((.*)\))?$').firstMatch(spec.trim());
    if (m == null) return value;
    final name = m.group(1)!;
    final argsRaw = m.group(2);
    final args = <String, String>{};
    if (argsRaw != null) {
      for (final pair in _splitArgs(argsRaw)) {
        final eq = pair.indexOf('=');
        if (eq < 0) {
          // Positional arg — stored under numeric keys "0", "1", …
          args[args.length.toString()] = _unquote(pair.trim());
        } else {
          args[pair.substring(0, eq).trim()] =
              _unquote(pair.substring(eq + 1).trim());
        }
      }
    }
    switch (name) {
      case 'upper':
        return value.toUpperCase();
      case 'lower':
        return value.toLowerCase();
      case 'default':
        final d = args['value'] ?? args['0'] ?? '';
        return value.isEmpty ? d : value;
      case 'map':
        if (args.containsKey(value)) return args[value]!;
        return args['default'] ?? value;
      case 'wrap':
        if (value.isEmpty) return '';
        final prefix = args['prefix'] ?? '';
        final suffix = args['suffix'] ?? '';
        return '$prefix$value$suffix';
    }
    return value;
  }

  /// Splits `a=1, b='x,y', c=z` on top-level commas, ignoring commas
  /// inside single- or double-quoted substrings.
  static List<String> _splitArgs(String raw) {
    final result = <String>[];
    final buf = StringBuffer();
    var quote = '';
    for (var i = 0; i < raw.length; i++) {
      final c = raw[i];
      if (quote.isNotEmpty) {
        buf.write(c);
        if (c == quote) quote = '';
      } else if (c == '"' || c == "'") {
        quote = c;
        buf.write(c);
      } else if (c == ',') {
        final s = buf.toString().trim();
        if (s.isNotEmpty) result.add(s);
        buf.clear();
      } else {
        buf.write(c);
      }
    }
    final s = buf.toString().trim();
    if (s.isNotEmpty) result.add(s);
    return result;
  }

  static String _unquote(String s) {
    if (s.length >= 2) {
      final first = s[0];
      final last = s[s.length - 1];
      if ((first == '"' && last == '"') ||
          (first == "'" && last == "'")) {
        return s.substring(1, s.length - 1);
      }
    }
    return s;
  }

  static String _escape(String v, TemplateEscape escape) {
    switch (escape) {
      case TemplateEscape.url:
        return Uri.encodeComponent(v);
      case TemplateEscape.json:
        return jsonEncode(v).substring(1, jsonEncode(v).length - 1);
      case TemplateEscape.raw:
        return v;
    }
  }
}