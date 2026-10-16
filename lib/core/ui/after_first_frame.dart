import 'package:flutter/widgets.dart';

/// Completes once the app's first frame is on the screen, at once when it
/// already is or when no Flutter binding runs (a plain Dart test).
Future<void> afterFirstFrame() async {
  final WidgetsBinding binding;
  try {
    binding = WidgetsBinding.instance;
  } on Object {
    return;
  }
  if (binding.firstFrameRasterized) return;
  await binding.waitUntilFirstFrameRasterized;
}
