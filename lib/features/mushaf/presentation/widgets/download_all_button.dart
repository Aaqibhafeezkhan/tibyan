import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/page_pack.dart';
import '../../mushaf_providers.dart';
import 'illuminated_frame.dart';

/// Opens the Downloads Center, where the editions not on the device yet
/// can be downloaded. Hidden when all of them are there.
class DownloadAllButton extends ConsumerWidget {
  const DownloadAllButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final digits = NumberFormatter(Localizations.localeOf(context));
    final here = ref.watch(installedEditionsProvider);
    final missing = [
      for (final e in MushafEdition.values)
        if (!here.contains(e)) e,
    ];
    if (missing.isEmpty) return const SizedBox.shrink();
    final mb = missing.fold<int>(0, (sum, e) => sum + PagePackSpec.of(e).bytes);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: OutlinedButton.icon(
        icon: const Icon(Icons.download_for_offline_outlined),
        label: Text(l.downloadAllEditions(digits((mb / 1e6).round()))),
        // Opens the Downloads Center; downloading is its own button there.
        onPressed: () => context.push('/downloads'),
      ),
    );
  }
}
