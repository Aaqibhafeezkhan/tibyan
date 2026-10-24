import 'package:flutter/material.dart';

import '../../../core/ui/app_toast.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import 'tasmee_style.dart';

/// The public platform where volunteers donate recitations to train the
/// tasmee model.
final trainingPlatformUrl = Uri.parse('https://train.altibyan.app');

/// Opens [url] in the external browser; false when that failed.
typedef ExternalLinkOpener = Future<bool> Function(Uri url);

Future<bool> _openExternal(Uri url) async {
  try {
    return await launchUrl(url, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// Settings › Tasmee, last: invites the reader to the training platform,
/// with what it is, how to take part and what happens to the recordings.
/// Every fact mirrors train.altibyan.app.
class TasmeeTrainCard extends StatelessWidget {
  const TasmeeTrainCard({super.key, this.open = _openExternal});

  final ExternalLinkOpener open;

  Future<void> _go(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final failed = AppLocalizations.of(context).tasmeeTrainOpenFailed;
    if (!await open(trainingPlatformUrl)) {
      messenger?.showSnackBar(appToast(content: Text(failed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens.colors;
    final steps = [
      l.tasmeeTrainStep1,
      l.tasmeeTrainStep2,
      l.tasmeeTrainStep3,
      l.tasmeeTrainStep4,
    ];
    return Card(
      key: const ValueKey('tasmee-train-card'),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.volunteer_activism, color: t.goldText, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l.tasmeeTrainTitle,
                      style: TextStyle(
                        color: t.goldText,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(l.tasmeeTrainBody, style: const TextStyle(height: 1.6)),
            Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: const ValueKey('tasmee-train-how'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 4),
                title: Text(
                  l.tasmeeTrainHowTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                children: [
                  for (final (i, step) in steps.indexed)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: t.goldText.withValues(alpha: .15),
                            child: Text(
                              context.digits(i + 1),
                              style: TextStyle(
                                color: t.goldText,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              step,
                              style: const TextStyle(height: 1.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline, size: 18, color: t.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.tasmeeTrainPrivacy,
                    style: TextStyle(color: t.muted, fontSize: 13, height: 1.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              key: const ValueKey('tasmee-train-open'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () => _go(context),
              // Mirrors in RTL: points the reading way.
              icon: const Icon(Icons.arrow_forward),
              label: Text(l.tasmeeTrainOpen),
            ),
            const SizedBox(height: 4),
            Text(
              'train.altibyan.app',
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
              style: TextStyle(color: t.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
