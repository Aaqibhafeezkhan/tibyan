import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/sync/cloud/cloud_store.dart';
import '../../core/theme/interface_style.dart';
import '../../core/ui/app_toast.dart';
import '../../core/ui/look_kit.dart';
import '../../core/ui/responsive.dart';
import '../../l10n/app_localizations.dart';
import 'sync_controller.dart';

/// «المزامنة»: the switch, where the data goes, the status and last sync,
/// «زامن الآن», and stopping with the cloud data deleted.
class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(ref.read(cloudSyncProvider.notifier).refresh());
  }

  Future<void> _toggle(bool on) async {
    final c = ref.read(cloudSyncProvider.notifier);
    setState(() => _busy = true);
    try {
      on ? await c.enable() : await c.disable();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteCloud() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => LookTheme(
        child: Builder(
          builder: (context) => AlertDialog(
            title: Text(l.syncDeleteConfirmTitle),
            content: Text(l.syncDeleteConfirmBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l.delete),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(cloudSyncProvider.notifier).disableAndDeleteCloud();
      messenger.showSnackBar(appToast(content: Text(l.syncDeleted)));
    } on Object {
      messenger.showSnackBar(appToast(content: Text(l.syncDeleteFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(cloudSyncProvider);
    final muted = TextStyle(color: context.look.sub);
    final notInBuild =
        s.kind == null ||
        s.unavailable == CloudUnavailable.notInThisBuild ||
        s.unavailable == CloudUnavailable.unsupported;
    final unavailableText = switch (s.unavailable) {
      null => null,
      CloudUnavailable.notInThisBuild => l.syncNotInBuild,
      CloudUnavailable.unsupported => l.syncUnsupported,
      CloudUnavailable.noAccount =>
        s.kind == 'icloud' ? l.syncNoAccountICloud : l.syncNoAccountDrive,
    };
    final locale = Localizations.localeOf(context).toLanguageTag();
    final last = s.lastSync;
    final status = switch (s.phase) {
      SyncPhase.syncing => l.syncRunning,
      SyncPhase.failed when s.unavailable == null => l.syncFailed,
      _ =>
        last == null
            ? l.syncNever
            : l.syncLast(DateFormat.yMMMd(locale).add_jm().format(last)),
    };

    return LookScaffold(
      maxWidth: ContentWidth.text,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            LookTopBar(title: l.syncTitle),
            Expanded(
              child: ListView(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.sync),
                    title: Text(l.syncSwitch),
                    subtitle: Text(
                      s.kind == null
                          ? l.syncUnsupported
                          : notInBuild
                          ? l.syncNotInBuild
                          : s.kind == 'icloud'
                          ? l.syncViaICloud
                          : l.syncViaDrive,
                      style: muted,
                    ),
                    value: s.enabled,
                    onChanged: _busy || (notInBuild && !s.enabled)
                        ? null
                        : _toggle,
                  ),
                  if (unavailableText != null && !notInBuild)
                    ListTile(
                      leading: const Icon(Icons.cloud_off_outlined),
                      title: Text(unavailableText),
                    ),
                  if (s.enabled) ...[
                    Semantics(
                      liveRegion: true,
                      child: ListTile(
                        leading: s.phase == SyncPhase.syncing
                            ? const SizedBox.square(
                                dimension: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                s.phase == SyncPhase.failed
                                    ? Icons.sync_problem
                                    : Icons.cloud_done_outlined,
                              ),
                        title: Text(status),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.sync),
                      title: Text(l.syncNow),
                      enabled: !_busy && s.phase != SyncPhase.syncing,
                      onTap: () => unawaited(
                        ref.read(cloudSyncProvider.notifier).syncNow(),
                      ),
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(l.syncWhat, style: muted),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Text(l.syncPrivacy, style: muted),
                  ),
                  if (!notInBuild)
                    ListTile(
                      leading: Icon(
                        Icons.delete_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      title: Text(
                        l.syncDeleteCloud,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      enabled: !_busy,
                      onTap: _deleteCloud,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
