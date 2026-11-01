import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/core/ui/on_screen.dart';

void main() {
  test('recitation follow animates only on screen', () {
    expect(animatesOnScreen(null), isTrue);
    expect(animatesOnScreen(AppLifecycleState.resumed), isTrue);
    for (final s in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.detached,
    ]) {
      expect(animatesOnScreen(s), isFalse, reason: '$s');
    }
  });

  testWidgets('appOnScreen follows the binding lifecycle', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(appOnScreen, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(appOnScreen, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(appOnScreen, isTrue);
  });
}
