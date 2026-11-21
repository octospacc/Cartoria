import 'dart:convert';
import 'dart:typed_data';

import 'package:Cartoria/data/sync/git_blob.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('gitBlobSha', () {
    test('empty content matches git hash-object', () {
      // `echo -n '' | git hash-object --stdin`
      expect(gitBlobSha(Uint8List(0)),
          'e69de29bb2d1d6434b8b29ae775ad8c2e48c5391');
    });

    test('"test content\\n" matches git hash-object', () {
      // `echo 'test content' | git hash-object --stdin`
      final bytes = Uint8List.fromList(utf8.encode('test content\n'));
      expect(gitBlobSha(bytes),
          'd670460b4b4aece5915caf5c68d12f560a9fe3e4');
    });

    test('deterministic for identical bytes', () {
      final a = Uint8List.fromList(utf8.encode('abc'));
      final b = Uint8List.fromList(utf8.encode('abc'));
      expect(gitBlobSha(a), gitBlobSha(b));
    });

    test('different content → different SHA', () {
      final a = Uint8List.fromList(utf8.encode('abc'));
      final b = Uint8List.fromList(utf8.encode('abd'));
      expect(gitBlobSha(a), isNot(gitBlobSha(b)));
    });
  });
}