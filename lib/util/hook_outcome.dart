import '../data/models.dart';

/// Aggregate state of a post's hooks, for the card indicator and the
/// hook status dialog.
enum HookOutcome { none, running, success, failure }

/// A single hook result is considered failed if the request threw (error
/// non-null) or the response status is not 2xx. A missing status with no
/// error is treated as success — that combination only appears when a
/// state was hand-edited, and treating it as success is less alarming
/// than treating it as failure.
bool hookStateFailed(PostHookState s) {
  if (s.lastError != null && s.lastError!.isNotEmpty) return true;
  final status = s.lastStatus;
  if (status == null) return false;
  return status < 200 || status >= 300;
}

/// Aggregate outcome for the card indicator.
///
/// Priority: running > failure > success > none. "Running" wins so the
/// user sees the spinner even if a previous run had failed — a retry is
/// clearly in progress.
HookOutcome hookOutcomeFor({
  required bool hasActive,
  required Map<String, PostHookState> states,
}) {
  if (hasActive) return HookOutcome.running;
  if (states.isEmpty) return HookOutcome.none;
  for (final s in states.values) {
    if (hookStateFailed(s)) return HookOutcome.failure;
  }
  return HookOutcome.success;
}