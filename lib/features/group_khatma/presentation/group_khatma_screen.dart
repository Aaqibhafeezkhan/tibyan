import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/interface_style.dart';
import '../../../core/ui/look_kit.dart';
import '../../../core/ui/responsive.dart';
import '../../../l10n/app_localizations.dart';
import '../../khatma/khatma_providers.dart';
import '../data/group_khatma_api.dart';
import '../data/group_khatma_store.dart';
import '../group_khatma_providers.dart';
import 'group_khatma_common.dart';

/// One group khatma: progress and the parts. Shows the saved copy at once
/// and the server's state when it arrives; offline it says so and keeps
/// the saved copy. Nothing is queued: an action needs a connection.
class GroupKhatmaScreen extends ConsumerStatefulWidget {
  const GroupKhatmaScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<GroupKhatmaScreen> createState() => _GroupKhatmaScreenState();
}

class _GroupKhatmaScreenState extends ConsumerState<GroupKhatmaScreen> {
  SavedGroupKhatma? _saved;
  Object? _error;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _saved = ref.read(groupKhatmasProvider.notifier).saved(widget.id);
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final s = await ref
          .read(groupKhatmasProvider.notifier)
          .refresh(widget.id);
      if (mounted) setState(() => (_saved = s, _error = null));
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(
    Future<SavedGroupKhatma?> Function(GroupKhatmas c) action,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final s = await action(ref.read(groupKhatmasProvider.notifier));
      if (mounted && s != null) setState(() => (_saved = s, _error = null));
    } catch (e) {
      if (mounted) showGroupError(context, e);
      if (e is GroupKhatmaException && e.failure == GroupKhatmaFailure.taken) {
        await _refresh();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _claim(GroupKhatma k, int n) async {
    final l = AppLocalizations.of(context);
    final name = await askText(
      context,
      title: partLabel(l, k, n),
      label: l.gkYourName,
      validate: (t) => t.isEmpty ? l.gkErrInvalid : null,
    );
    if (name == null) return;
    await _run((c) => c.claim(k.id, n, name));
  }

  Future<void> _remind(GroupKhatma k, int n) async {
    final l = AppLocalizations.of(context);
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 20, minute: 0),
    );
    if (time == null || !mounted) return;
    final now = DateTime.now();
    var at = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    final scheduler = ref.read(reminderSchedulerProvider);
    await scheduler.requestPermission();
    await scheduler.scheduleOnce(
      id: groupReminderId(k.id, n),
      at: at,
      title: k.title ?? l.gkTitle,
      body: l.gkReminderBody(partLabel(l, k, n)),
      payload: 'tibyan://group?id=${k.id}',
      channel: l.gkTitle,
    );
    await _run((c) async {
      await c.setReminder(k.id, n, at);
      return c.saved(k.id);
    });
  }

  Future<void> _cancelReminder(GroupKhatma k, int n) async {
    await ref
        .read(reminderSchedulerProvider)
        .cancelOnce(groupReminderId(k.id, n));
    await _run((c) async {
      await c.setReminder(k.id, n, null);
      return c.saved(k.id);
    });
  }

  Future<void> _release(GroupKhatma k, int n) async {
    await ref
        .read(reminderSchedulerProvider)
        .cancelOnce(groupReminderId(k.id, n));
    await _run((c) => c.release(k.id, n));
  }

  Future<void> _menu(String action, GroupKhatma k) async {
    final l = AppLocalizations.of(context);
    switch (action) {
      case 'rename':
        final title = await askText(
          context,
          title: l.gkRename,
          label: l.gkKhatmaName,
          initial: k.title ?? '',
          maxLength: 80,
        );
        if (title != null) await _run((c) => c.rename(k.id, title));
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l.gkDelete),
            content: Text(l.gkDeleteConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l.gkCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l.gkDelete),
              ),
            ],
          ),
        );
        if (ok != true) return;
        await _run((c) async {
          await c.delete(k.id);
          if (mounted) context.pop();
          return null;
        });
      case 'forget':
        await ref.read(groupKhatmasProvider.notifier).forget(k.id);
        if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final k = _saved?.cached;
    final offline = _error != null && k != null;
    return LookScaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            LookTopBar(
              title: k?.title ?? l.gkTitle,
              actions: [
                if (k != null)
                  IconButton(
                    tooltip: l.gkShare,
                    icon: const Icon(Icons.share_outlined),
                    onPressed: () => SharePlus.instance.share(
                      ShareParams(
                        text: l.gkShareText(k.title ?? l.gkTitle, '${k.link}'),
                      ),
                    ),
                  ),
                if (k != null)
                  PopupMenuButton<String>(
                    onSelected: (a) => _menu(a, k),
                    itemBuilder: (_) => [
                      if (_saved!.isOrganizer) ...[
                        PopupMenuItem(value: 'rename', child: Text(l.gkRename)),
                        PopupMenuItem(value: 'delete', child: Text(l.gkDelete)),
                      ],
                      PopupMenuItem(value: 'forget', child: Text(l.gkForget)),
                    ],
                  ),
              ],
            ),
            if (_loading || _busy) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: ContentWidth.text,
                  ),
                  child: k == null
                      ? _Message(
                          text: _error == null
                              ? ''
                              : groupFailureText(l, _error!),
                          onRetry: _error == null ? null : _refresh,
                        )
                      : RefreshIndicator(
                          onRefresh: _refresh,
                          child: _Body(
                            khatma: k,
                            saved: _saved!,
                            offline: offline,
                            onClaim: (n) => _claim(k, n),
                            onDone: (n) => _run((c) => c.markDone(k.id, n)),
                            onUndo: (n) => _run((c) => c.undoDone(k.id, n)),
                            onRelease: (n) => _release(k, n),
                            onRemind: (n) => _remind(k, n),
                            onCancelReminder: (n) => _cancelReminder(k, n),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.onRetry});
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: const Icon(Icons.refresh),
            ),
          ],
        ],
      ),
    ),
  );
}

class _Body extends StatelessWidget {
  const _Body({
    required this.khatma,
    required this.saved,
    required this.offline,
    required this.onClaim,
    required this.onDone,
    required this.onUndo,
    required this.onRelease,
    required this.onRemind,
    required this.onCancelReminder,
  });

  final GroupKhatma khatma;
  final SavedGroupKhatma saved;
  final bool offline;
  final void Function(int) onClaim;
  final void Function(int) onDone;
  final void Function(int) onUndo;
  final void Function(int) onRelease;
  final void Function(int) onRemind;
  final void Function(int) onCancelReminder;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ml = MaterialLocalizations.of(context);
    final look = context.look;
    final k = khatma;
    final total = k.parts.length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (offline)
          Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_off_outlined),
              title: Text(l.gkOfflineCached),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.gkProgress(k.taken, k.done, total),
                  key: const Key('gk-progress'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : k.done / total,
                    minHeight: 8,
                    color: look.accent,
                    backgroundColor: look.line,
                  ),
                ),
                if (k.organizer != null || k.targetDate != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    [
                      if (k.organizer != null) l.gkOrganizer(k.organizer!),
                      if (k.targetDate != null)
                        l.gkTarget(ml.formatMediumDate(k.targetDate!)),
                    ].join(' · '),
                    style: TextStyle(color: look.sub),
                  ),
                ],
                if (k.completedAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    l.gkCompleted,
                    style: TextStyle(
                      color: look.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final p in k.parts) _partTile(context, l, ml, p),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _partTile(
    BuildContext context,
    AppLocalizations l,
    MaterialLocalizations ml,
    GroupPart p,
  ) {
    final look = context.look;
    final mine = saved.partSecrets.containsKey(p.number);
    final reminder = saved.reminders[p.number];
    final state = switch (p.state) {
      PartState.open => l.gkOpenPart,
      PartState.taken => l.gkTakenPart,
      PartState.done => l.gkDonePart,
    };
    final who = p.name == null
        ? state
        : '${p.name}${mine ? ' (${l.gkYou})' : ''} · $state';
    final Widget? trailing;
    if (offline) {
      trailing = null;
    } else if (p.state == PartState.open) {
      trailing = TextButton(
        key: Key('gk-claim-${p.number}'),
        onPressed: () => onClaim(p.number),
        child: Text(l.gkClaim),
      );
    } else if (mine) {
      trailing = PopupMenuButton<String>(
        key: Key('gk-mine-${p.number}'),
        onSelected: (a) => switch (a) {
          'done' => onDone(p.number),
          'undo' => onUndo(p.number),
          'remind' => onRemind(p.number),
          'unremind' => onCancelReminder(p.number),
          _ => onRelease(p.number),
        },
        itemBuilder: (_) => [
          if (p.state == PartState.taken)
            PopupMenuItem(value: 'done', child: Text(l.gkMarkDone))
          else
            PopupMenuItem(value: 'undo', child: Text(l.gkUndoDone)),
          if (p.state == PartState.taken)
            reminder == null
                ? PopupMenuItem(value: 'remind', child: Text(l.gkRemind))
                : PopupMenuItem(
                    value: 'unremind',
                    child: Text(l.gkReminderCancel),
                  ),
          PopupMenuItem(value: 'release', child: Text(l.gkRelease)),
        ],
      );
    } else if (saved.isOrganizer) {
      trailing = PopupMenuButton<String>(
        onSelected: (_) => onRelease(p.number),
        itemBuilder: (_) => [
          PopupMenuItem(value: 'release', child: Text(l.gkReleaseOther)),
        ],
      );
    } else {
      trailing = null;
    }
    return Card(
      color: p.state == PartState.done
          ? Color.alphaBlend(look.gold.withValues(alpha: 0.14), look.surface)
          : null,
      shape: mine
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: look.accent, width: 1.5),
            )
          : null,
      child: ListTile(
        leading: Icon(switch (p.state) {
          PartState.open => Icons.radio_button_unchecked,
          PartState.taken => Icons.schedule,
          PartState.done => Icons.check_circle,
        }, color: p.state == PartState.done ? look.accent : look.sub),
        title: Text(partLabel(l, khatma, p.number)),
        subtitle: Text(
          reminder == null
              ? who
              : '$who\n${l.gkReminderSet('${ml.formatMediumDate(reminder)} ${ml.formatTimeOfDay(TimeOfDay.fromDateTime(reminder))}')}',
        ),
        trailing: trailing,
      ),
    );
  }
}
