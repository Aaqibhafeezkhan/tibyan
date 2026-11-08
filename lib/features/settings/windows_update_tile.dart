import 'package:flutter/material.dart';

import '../../core/theme/interface_style.dart';
import '../../core/update/windows_updater.dart';
import '../../l10n/app_localizations.dart';

/// «البحث عن تحديثات» (Windows only): the updater's state and its one action.
class WindowsUpdateTile extends StatelessWidget {
  const WindowsUpdateTile({super.key, this.updater});

  /// Tests pass their own; the app uses [windowsUpdater].
  final WindowsUpdater? updater;

  @override
  Widget build(BuildContext context) {
    final updater = this.updater ?? windowsUpdater;
    final l = AppLocalizations.of(context);
    return ValueListenableBuilder<UpdateState>(
      valueListenable: updater,
      builder: (context, s, _) {
        final (String? subtitle, double? progress) = switch (s) {
          UpdateIdle() => (null, null),
          UpdateChecking() => (l.updateChecking, null),
          UpdateUpToDate() => (l.updateUpToDate, null),
          UpdateDownloading(:final feed, :final progress) => (
            l.updateDownloading(
              feed.version,
              progress == null ? '' : '${(progress * 100).round()}%',
            ),
            progress,
          ),
          UpdateReady(:final feed) => (l.updateReady(feed.version), null),
          UpdateFailed() => (l.updateFailed, null),
        };
        final busy = s is UpdateChecking || s is UpdateDownloading;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.system_update_alt),
              title: Text(l.updateCheckTitle),
              subtitle: subtitle == null
                  ? null
                  : Text(subtitle, style: TextStyle(color: context.look.sub)),
              trailing: s is UpdateReady
                  ? FilledButton(
                      onPressed: updater.install,
                      child: Text(l.updateRestart),
                    )
                  : busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: busy || s is UpdateReady ? null : updater.check,
            ),
            if (s is UpdateDownloading)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: LinearProgressIndicator(value: progress),
              ),
          ],
        );
      },
    );
  }
}
