import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/settings_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../khatma_providers.dart' show reminderSchedulerProvider;
import '../services/kahf_reminder.dart';

/// The Friday Surah Al-Kahf reminder's switch (off by default).
class KahfReminderTile extends ConsumerWidget {
  const KahfReminderTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = context.tokens.colors;
    final on = ref.watch(settingsProvider.select((s) => s.kahfReminder));
    return SwitchListTile(
      secondary: const Icon(Icons.notifications_none),
      title: Text(l.kahfReminderToggle),
      subtitle: Text(l.kahfReminderHint, style: TextStyle(color: t.muted)),
      value: on,
      onChanged: (value) async {
        final scheduler = ref.read(reminderSchedulerProvider);
        if (value) await scheduler.requestPermission();
        await ref.read(settingsProvider.notifier).setKahfReminder(value);
        await syncKahfReminder(scheduler, ref.read(settingsProvider));
      },
    );
  }
}
