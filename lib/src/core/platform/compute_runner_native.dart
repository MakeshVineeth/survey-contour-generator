import 'dart:isolate';

import 'compute_runner.dart';

ComputeRunner createComputeRunner() => const _IsolateComputeRunner();

final class _IsolateComputeRunner implements ComputeRunner {
  const _IsolateComputeRunner();

  @override
  Future<R> run<Q, R>(R Function(Q) fn, Q message) =>
      Isolate.run(() => fn(message));
}
