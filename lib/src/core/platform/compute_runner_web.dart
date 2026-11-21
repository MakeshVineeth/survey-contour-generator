import 'compute_runner.dart';

ComputeRunner createComputeRunner() => const _InlineComputeRunner();

/// Web has no isolates: yield to the event loop once, then run inline.
final class _InlineComputeRunner implements ComputeRunner {
  const _InlineComputeRunner();

  @override
  Future<R> run<Q, R>(R Function(Q) fn, Q message) async {
    await Future<void>.delayed(Duration.zero);
    return fn(message);
  }
}
