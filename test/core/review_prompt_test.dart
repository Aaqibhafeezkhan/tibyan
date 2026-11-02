import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tibyan/core/review/review_prompt.dart';

void main() {
  late SharedPreferences prefs;
  late DateTime now;
  late int asked;
  var version = '0.6.0+42';

  ReviewPrompt make({bool supported = true, bool services = true}) =>
      ReviewPrompt(
        prefs,
        available: () async => true,
        request: () async => asked++,
        version: () async => version,
        clock: () => now,
        supported: supported,
        services: () async => services,
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    now = DateTime(2026, 1, 1, 10);
    asked = 0;
    version = '0.6.0+42';
  });

  test('never on the day of the first launch', () async {
    final p = make();
    await p.noteLaunch();
    expect(await p.maybeAsk(ReviewMoment.khatmaComplete), isFalse);
    now = now.add(const Duration(days: 1));
    expect(await p.maybeAsk(ReviewMoment.khatmaComplete), isTrue);
    expect(asked, 1);
  });

  test('without a recorded first launch it never asks', () async {
    now = now.add(const Duration(days: 30));
    expect(await make().maybeAsk(ReviewMoment.khatmaComplete), isFalse);
  });

  test('the seventh distinct reading day asks, not before', () async {
    final p = make();
    await p.noteLaunch();
    for (var i = 0; i < 6; i++) {
      now = now.add(const Duration(days: 1));
      expect(await p.readingSession(), isFalse);
      // Twice the same day counts once.
      expect(await p.readingSession(), isFalse);
    }
    expect(p.distinctDays, 6);
    now = now.add(const Duration(days: 1));
    expect(await p.readingSession(), isTrue);
    expect(asked, 1);
  });

  test('once per version, and a cooldown across versions', () async {
    final p = make();
    await p.noteLaunch();
    now = now.add(const Duration(days: 2));
    expect(await p.maybeAsk(ReviewMoment.khatmaComplete), isTrue);
    now = now.add(const Duration(days: 200));
    expect(await p.maybeAsk(ReviewMoment.khatmaComplete), isFalse);
    version = '0.6.1+43';
    now = DateTime(2026, 1, 3).add(const Duration(days: 30));
    expect(await p.maybeAsk(ReviewMoment.khatmaComplete), isFalse);
    now = DateTime(2026, 1, 3).add(const Duration(days: 121));
    expect(await p.maybeAsk(ReviewMoment.khatmaComplete), isTrue);
    expect(asked, 2);
  });

  test('desktop and watch: nothing', () async {
    final p = make(supported: false);
    await p.noteLaunch();
    now = now.add(const Duration(days: 10));
    expect(await p.maybeAsk(ReviewMoment.khatmaComplete), isFalse);
    expect(asked, 0);
  });

  test('a recorded day without asking', () async {
    final p = make();
    await p.noteLaunch();
    now = now.add(const Duration(days: 1));
    expect(await p.readingSession(ask: false), isFalse);
    expect(p.distinctDays, 1);
  });

  test('without Google Play services (Huawei) it never asks', () async {
    final p = make(services: false);
    await p.noteLaunch();
    now = now.add(const Duration(days: 1));
    expect(await p.maybeAsk(ReviewMoment.khatmaComplete), isFalse);
    expect(asked, 0);
  });
}
