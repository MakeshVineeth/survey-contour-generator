import 'compute_runner_native.dart'
    if (dart.library.js_interop) 'compute_runner_web.dart'
    as impl;

/// Runs heavy synchronous work off the UI path.
abstract interface class ComputeRunner {
  Future<R> run<Q, R>(R Function(Q) fn, Q message);
}

/// The runner for the current platform (isolate on native, inline on web).
ComputeRunner createComputeRunner() => impl.createComputeRunner();
