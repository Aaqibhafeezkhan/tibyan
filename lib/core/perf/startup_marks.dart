/// Startup stages, printed in a build run with `--dart-define=PROF=true`
/// as `STARTUP <stage> <ms since main() began>`. Off, and free, in every
/// other build.
library;

final _startup = Stopwatch()..start();

/// Notes that [stage] of the startup is reached (a profiling build only).
void startupMark(String stage) {
  if (!const bool.fromEnvironment('PROF')) return;
  // ignore: avoid_print
  print('STARTUP $stage ${_startup.elapsedMicroseconds / 1000}');
}
