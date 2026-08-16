/// Small exponential-backoff policy used by foreground cloud recovery.
///
/// It replaces an always-running network probe timer: a retry timer exists only
/// after a real failure and backs off until the connection is healthy again.
class AdaptiveRetryPolicy {
  final Duration initialDelay;
  final Duration maximumDelay;
  Duration _nextDelay;

  AdaptiveRetryPolicy({
    this.initialDelay = const Duration(seconds: 15),
    this.maximumDelay = const Duration(minutes: 2),
  }) : _nextDelay = initialDelay;

  Duration takeNextDelay() {
    final current = _nextDelay;
    final doubledMilliseconds = current.inMilliseconds * 2;
    _nextDelay = Duration(
      milliseconds: doubledMilliseconds > maximumDelay.inMilliseconds
          ? maximumDelay.inMilliseconds
          : doubledMilliseconds,
    );
    return current;
  }

  void reset() {
    _nextDelay = initialDelay;
  }

  Duration get nextDelay => _nextDelay;
}
