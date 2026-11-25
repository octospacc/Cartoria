import 'package:Cartoria/data/models.dart';
import 'package:Cartoria/util/search_filter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Post _post(DateTime createdAt) => Post(
      id: 'p',
      kind: PostKind.note,
      body: '',
      createdAt: createdAt,
    );

void main() {
  group('postMatchesDateRange', () {
    test('null range → always true', () {
      expect(postMatchesDateRange(_post(DateTime(2025)), null), isTrue);
    });

    test('post exactly at start of range → true', () {
      final post = _post(DateTime(2025, 1, 15, 0, 0, 0));
      final range = DateTimeRange(
        start: DateTime(2025, 1, 15),
        end: DateTime(2025, 1, 20),
      );
      expect(postMatchesDateRange(post, range), isTrue);
    });

    test('post exactly at end day 23:59 → true', () {
      final post = _post(DateTime(2025, 1, 20, 23, 59, 59));
      final range = DateTimeRange(
        start: DateTime(2025, 1, 15),
        end: DateTime(2025, 1, 20),
      );
      expect(postMatchesDateRange(post, range), isTrue);
    });

    test('post before range → false', () {
      final post = _post(DateTime(2025, 1, 14, 23, 59));
      final range = DateTimeRange(
        start: DateTime(2025, 1, 15),
        end: DateTime(2025, 1, 20),
      );
      expect(postMatchesDateRange(post, range), isFalse);
    });

    test('post after range → false', () {
      final post = _post(DateTime(2025, 1, 21, 0, 0));
      final range = DateTimeRange(
        start: DateTime(2025, 1, 15),
        end: DateTime(2025, 1, 20),
      );
      expect(postMatchesDateRange(post, range), isFalse);
    });

    test('post on single-day range → true at any hour', () {
      final range = DateTimeRange(
        start: DateTime(2025, 1, 15),
        end: DateTime(2025, 1, 15),
      );
      expect(
        postMatchesDateRange(_post(DateTime(2025, 1, 15, 6)), range),
        isTrue,
      );
      expect(
        postMatchesDateRange(_post(DateTime(2025, 1, 15, 22)), range),
        isTrue,
      );
    });

    test('post uses local time, not UTC', () {
      // A post created at 2025-01-15 in local time should match a
      // 2025-01-15 range regardless of the machine's TZ.
      final post = _post(DateTime(2025, 1, 15, 12));
      final range = DateTimeRange(
        start: DateTime(2025, 1, 15),
        end: DateTime(2025, 1, 15),
      );
      expect(postMatchesDateRange(post, range), isTrue);
    });
  });
}