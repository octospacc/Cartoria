import 'package:Cartoria/data/models.dart';
import 'package:Cartoria/util/hook_outcome.dart';
import 'package:flutter_test/flutter_test.dart';

PostHookState _state({int? status, String? error}) => PostHookState(
      lastFiredAt: DateTime.utc(2024),
      lastStatus: status,
      lastError: error,
    );

void main() {
  group('hookStateFailed', () {
    test('null status, no error → not failed', () {
      expect(hookStateFailed(_state()), isFalse);
    });
    test('2xx → not failed', () {
      expect(hookStateFailed(_state(status: 200)), isFalse);
      expect(hookStateFailed(_state(status: 201)), isFalse);
      expect(hookStateFailed(_state(status: 299)), isFalse);
    });
    test('4xx / 5xx → failed', () {
      expect(hookStateFailed(_state(status: 400)), isTrue);
      expect(hookStateFailed(_state(status: 500)), isTrue);
    });
    test('non-null error → failed', () {
      expect(hookStateFailed(_state(error: 'boom')), isTrue);
      expect(hookStateFailed(_state(status: 200, error: 'boom')), isTrue);
    });
  });

  group('hookOutcomeFor', () {
    test('no active, no states → none', () {
      expect(
        hookOutcomeFor(hasActive: false, states: const {}),
        HookOutcome.none,
      );
    });
    test('any active → running (wins over past failure)', () {
      final states = {'a': _state(status: 500)};
      expect(
        hookOutcomeFor(hasActive: true, states: states),
        HookOutcome.running,
      );
    });
    test('any failure → failure', () {
      final states = {
        'a': _state(status: 200),
        'b': _state(status: 500),
      };
      expect(
        hookOutcomeFor(hasActive: false, states: states),
        HookOutcome.failure,
      );
    });
    test('all success → success', () {
      final states = {
        'a': _state(status: 200),
        'b': _state(status: 201),
      };
      expect(
        hookOutcomeFor(hasActive: false, states: states),
        HookOutcome.success,
      );
    });
  });
}