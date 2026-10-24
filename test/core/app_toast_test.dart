import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/core/ui/app_toast.dart';

Future<ScaffoldMessengerState> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: SizedBox.expand())),
  );
  return tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger));
}

void main() {
  test('every toast auto-dismisses, has a close icon and swipes away', () {
    final plain = appToast(content: const Text('x'));
    expect(plain.persist, isFalse);
    expect(plain.showCloseIcon, isTrue);
    expect(plain.dismissDirection, DismissDirection.horizontal);
    expect(plain.duration, kToastDuration);

    final undo = appToast(
      content: const Text('x'),
      action: SnackBarAction(label: 'undo', onPressed: () {}),
    );
    expect(undo.persist, isFalse, reason: 'an action must not pin it');
    expect(undo.showCloseIcon, isTrue);
    expect(undo.duration, kToastActionDuration);
    expect(kToastActionDuration > kToastDuration, isTrue);
  });

  testWidgets('a toast with Undo goes away on its own', (tester) async {
    final messenger = await _pump(tester);
    messenger.showSnackBar(
      appToast(
        content: const Text('deleted'),
        action: SnackBarAction(label: 'undo', onPressed: () {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('deleted'), findsOneWidget);
    expect(find.text('undo'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    await tester.pump(kToastActionDuration);
    await tester.pumpAndSettle();
    expect(find.text('deleted'), findsNothing);
  });

  testWidgets('the close button dismisses at once', (tester) async {
    final messenger = await _pump(tester);
    messenger.showSnackBar(appToast(content: const Text('hi')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('hi'), findsNothing);
  });

  testWidgets('a horizontal swipe dismisses at once', (tester) async {
    final messenger = await _pump(tester);
    messenger.showSnackBar(appToast(content: const Text('hi')));
    await tester.pumpAndSettle();
    await tester.drag(find.text('hi'), const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(find.text('hi'), findsNothing);
  });
}
