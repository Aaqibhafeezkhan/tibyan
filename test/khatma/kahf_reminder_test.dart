import 'package:flutter_test/flutter_test.dart';

import 'package:tibyan/core/settings/app_settings.dart';
import 'package:tibyan/features/khatma/services/kahf_reminder.dart';
import 'package:tibyan/features/khatma/services/reminder_scheduler.dart';

class _Recording extends NoReminders {
  var asked = 0;

  @override
  Future<bool> requestPermission() async {
    asked++;
    return true;
  }

  final texts = <int, (String, String, String)>{};

  @override
  Future<void> scheduleOnce({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String payload,
    required String channel,
  }) async {
    texts[id] = (title, body, payload);
    await super.scheduleOnce(
      id: id,
      at: at,
      title: title,
      body: body,
      payload: payload,
      channel: channel,
    );
  }
}

void main() {
  // A Wednesday.
  final now = DateTime(2026, 11, 4, 12);

  test('on by default', () {
    expect(const AppSettings(styleId: 'simple').kahfReminder, isTrue);
  });

  test('turned off: nothing is scheduled', () async {
    final s = _Recording();
    await syncKahfReminder(
      s,
      const AppSettings(styleId: 'simple', kahfReminder: false),
      now: now,
    );
    expect(s.once, isEmpty);
  });

  test('without the permission it waits, and never asks', () async {
    final s = _Recording()..permitted = false;
    await syncKahfReminder(s, const AppSettings(styleId: 'simple'), now: now);
    expect(s.once, isEmpty);
    expect(s.asked, 0);
    s.permitted = true;
    await syncKahfReminder(s, const AppSettings(styleId: 'simple'), now: now);
    expect(s.once.length, kahfRemindersAhead);
  });

  test('on: the next Fridays at 09:00, opening 18:1', () async {
    final s = _Recording();
    await syncKahfReminder(
      s,
      const AppSettings(styleId: 'simple', kahfReminder: true),
      now: now,
    );
    expect(s.once.length, kahfRemindersAhead);
    for (final at in s.once.values) {
      expect(at.weekday, DateTime.friday);
      expect((at.hour, at.minute), (9, 0));
    }
    expect(s.once[kahfReminderIdBase], DateTime(2026, 11, 6, 9));
    final (title, body, payload) = s.texts[kahfReminderIdBase]!;
    expect(title, 'تذكير: سورة الكهف');
    expect(body, 'اضغط لفتح السورة.');
    expect(payload, 'tibyan://verse?s=18&a=1');
  });

  test('turned off again: the scheduled Fridays are cancelled', () async {
    final s = _Recording();
    await syncKahfReminder(
      s,
      const AppSettings(styleId: 'simple', kahfReminder: true),
      now: now,
    );
    await syncKahfReminder(
      s,
      const AppSettings(styleId: 'simple', kahfReminder: false),
      now: now,
    );
    expect(s.once, isEmpty);
  });

  test('English text', () async {
    final s = _Recording();
    await syncKahfReminder(
      s,
      const AppSettings(
        styleId: 'simple',
        kahfReminder: true,
        language: LanguageSetting.en,
      ),
      now: now,
    );
    expect(s.texts[kahfReminderIdBase]!.$1, 'Reminder: Surah Al-Kahf');
  });
}
