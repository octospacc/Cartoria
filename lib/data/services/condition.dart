import 'template.dart';

/// Evaluates a `when` predicate against a [TemplateContext].
///
/// Grammar (whitespace-tolerant):
///   expr    := or
///   or      := and ('||' and)*
///   and     := cmp ('&&' cmp)*
///   cmp     := primary (('==' | '!=' | '<=' | '>=' | '<' | '>') primary)?
///   primary := '(' expr ')' | string | number | path | 'true' | 'false'
///
/// Paths resolve via [TemplateContext.lookup] — the same namespace as
/// templates, so `post.files.length`, `post.kind`, `post.files.0.category`
/// all work. Missing paths evaluate to the empty string.
class ConditionEvaluator {
  static bool evaluate(String? expression, TemplateContext ctx) {
    if (expression == null || expression.trim().isEmpty) return true;
    try {
      return _Parser(expression, ctx).parseOr().value as bool;
    } catch (_) {
      // Malformed expression: fire the hook rather than silently drop it.
      return true;
    }
  }
}

class _Result {
  final Object? value;
  final int nextPos;
  const _Result(this.value, this.nextPos);
}

class _Parser {
  final String src;
  final TemplateContext ctx;
  int pos = 0;

  _Parser(this.src, this.ctx);

  _Result parseOr() {
    var left = parseAnd();
    while (_try('||')) {
      final right = parseAnd();
      left = _Result(_truthy(left.value) || _truthy(right.value), right.nextPos);
    }
    return left;
  }

  _Result parseAnd() {
    var left = parseCmp();
    while (_try('&&')) {
      final right = parseCmp();
      left = _Result(_truthy(left.value) && _truthy(right.value), right.nextPos);
    }
    return left;
  }

  _Result parseCmp() {
    final left = parsePrimary();
    for (final op in const ['==', '!=', '<=', '>=', '<', '>']) {
      if (_try(op)) {
        final right = parsePrimary();
        return _Result(_compare(left.value, right.value, op), right.nextPos);
      }
    }
    return left;
  }

  _Result parsePrimary() {
    _skipWs();
    if (_try('(')) {
      final r = parseOr();
      _try(')');
      return r;
    }
    if (pos < src.length && (src[pos] == '"' || src[pos] == "'")) {
      final quote = src[pos];
      pos++;
      final start = pos;
      while (pos < src.length && src[pos] != quote) {
        pos++;
      }
      final value = src.substring(start, pos);
      pos++;
      return _Result(value, pos);
    }
    final numMatch = RegExp(r'^\d+(\.\d+)?').firstMatch(src.substring(pos));
    if (numMatch != null) {
      pos += numMatch.group(0)!.length;
      return _Result(numMatch.group(0)!, pos);
    }
    final identMatch = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*(\.[a-zA-Z0-9_]+)*')
        .firstMatch(src.substring(pos));
    if (identMatch != null) {
      final path = identMatch.group(0)!;
      pos += path.length;
      if (path == 'true') return _Result(true, pos);
      if (path == 'false') return _Result(false, pos);
      return _Result(ctx.lookup(path), pos);
    }
    throw FormatException('Unexpected token at $pos in "$src"');
  }

  bool _try(String token) {
    _skipWs();
    if (src.startsWith(token, pos)) {
      pos += token.length;
      return true;
    }
    return false;
  }

  void _skipWs() {
    while (pos < src.length && (src[pos] == ' ' || src[pos] == '\t')) {
      pos++;
    }
  }

  static bool _truthy(Object? v) {
    if (v == null) return false;
    if (v is bool) return v;
    final s = v.toString().toLowerCase();
    return s.isNotEmpty && s != 'false' && s != '0' && s != 'no';
  }

  static bool _compare(Object? a, Object? b, String op) {
    final an = num.tryParse(a?.toString() ?? '');
    final bn = num.tryParse(b?.toString() ?? '');
    final isNumeric = an != null && bn != null;
    switch (op) {
      case '==':
        return isNumeric ? an == bn : a?.toString() == b?.toString();
      case '!=':
        return isNumeric ? an != bn : a?.toString() != b?.toString();
      case '<':
        return isNumeric && an < bn;
      case '<=':
        return isNumeric && an <= bn;
      case '>':
        return isNumeric && an > bn;
      case '>=':
        return isNumeric && an >= bn;
    }
    return false;
  }
}