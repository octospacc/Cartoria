import 'package:Cartoria/util/json_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('prettyJson', () {
    test('empty map', () {
      expect(prettyJson({}), '{}\n');
    });

    test('empty list', () {
      expect(prettyJson([]), '[]\n');
    });

    test('null value', () {
      expect(prettyJson(null), 'null\n');
    });

    test('simple map with 2-space indent', () {
      expect(
        prettyJson({'a': 1}),
        '{\n  "a": 1\n}\n',
      );
    });

    test('nested map', () {
      expect(
        prettyJson({
          'a': {'b': 2},
        }),
        '{\n  "a": {\n    "b": 2\n  }\n}\n',
      );
    });

    test('list inside map', () {
      expect(
        prettyJson({
          'items': [1, 2],
        }),
        '{\n  "items": [\n    1,\n    2\n  ]\n}\n',
      );
    });

    test('always ends with exactly one newline', () {
      final out = prettyJson({'a': 1});
      expect(out.endsWith('\n'), isTrue);
      expect(out.endsWith('\n\n'), isFalse);
    });

    test('Unicode preserved as-is', () {
      expect(prettyJson({'name': 'caffè'}), contains('caffè'));
    });
  });
}