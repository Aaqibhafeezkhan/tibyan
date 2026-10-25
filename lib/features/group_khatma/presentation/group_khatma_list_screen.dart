import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/look_kit.dart';
import '../../../core/ui/responsive.dart';
import '../../../core/theme/interface_style.dart';
import '../../../l10n/app_localizations.dart';
import '../data/group_khatma_api.dart';
import '../group_khatma_providers.dart';
import 'group_khatma_common.dart';

/// «ختمة جماعية»: create one, join by a link, and the ones you follow.
class GroupKhatmaListScreen extends ConsumerWidget {
  const GroupKhatmaListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final look = context.look;
    final mine = ref.watch(groupKhatmasProvider);
    return LookScaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            LookTopBar(title: l.gkTitle),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: ContentWidth.text,
                  ),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(l.gkSubtitle, style: TextStyle(color: look.sub)),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        key: const Key('gk-create'),
                        icon: const Icon(Icons.group_add_outlined),
                        label: Text(l.gkCreate),
                        onPressed: () => _create(context, ref),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        key: const Key('gk-join'),
                        icon: const Icon(Icons.link),
                        label: Text(l.gkJoin),
                        onPressed: () => _join(context),
                      ),
                      const SizedBox(height: 20),
                      LookGroup(
                        icon: Icons.groups_outlined,
                        title: l.gkMine,
                        children: [
                          if (mine.isEmpty)
                            ListTile(title: Text(l.gkNone))
                          else
                            for (final s in mine)
                              ListTile(
                                title: Text(s.cached?.title ?? l.gkTitle),
                                subtitle: s.cached == null
                                    ? null
                                    : Text(
                                        l.gkProgress(
                                          s.cached!.taken,
                                          s.cached!.done,
                                          s.cached!.parts.length,
                                        ),
                                      ),
                                leading: Icon(
                                  s.isOrganizer
                                      ? Icons.star_outline
                                      : Icons.menu_book_outlined,
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () =>
                                    context.push('/khatma/group/${s.id}'),
                              ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l.gkPrivacyNote,
                        style: TextStyle(color: look.sub, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _join(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final link = await askText(
      context,
      title: l.gkJoin,
      label: l.gkLinkHint,
      maxLength: 200,
      validate: (t) => groupKhatmaIdOf(t) == null ? l.gkLinkInvalid : null,
    );
    if (link == null || !context.mounted) return;
    await context.push('/khatma/group/${groupKhatmaIdOf(link)}');
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final created = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const CreateGroupKhatmaSheet(),
    );
    if (created != null && context.mounted) {
      await context.push('/khatma/group/$created');
    }
  }
}

/// The create form; pops with the new khatma's id.
class CreateGroupKhatmaSheet extends ConsumerStatefulWidget {
  const CreateGroupKhatmaSheet({super.key});

  @override
  ConsumerState<CreateGroupKhatmaSheet> createState() => _CreateState();
}

class _CreateState extends ConsumerState<CreateGroupKhatmaSheet> {
  final _title = TextEditingController();
  final _organizer = TextEditingController();
  bool _hizb = false;
  DateTime? _target;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _organizer.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      final s = await ref
          .read(groupKhatmasProvider.notifier)
          .create(
            title: _title.text,
            organizer: _organizer.text,
            hizb: _hizb,
            targetDate: _target,
          );
      if (mounted) Navigator.of(context).pop(s.id);
    } catch (e) {
      if (mounted) showGroupError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ml = MaterialLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.gkCreate, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              key: const Key('gk-title'),
              controller: _title,
              maxLength: 80,
              decoration: InputDecoration(labelText: l.gkKhatmaName),
            ),
            TextField(
              key: const Key('gk-organizer'),
              controller: _organizer,
              maxLength: 40,
              decoration: InputDecoration(labelText: l.gkOrganizerName),
            ),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(l.gkUnitJuz)),
                ButtonSegment(value: true, label: Text(l.gkUnitHizb)),
              ],
              selected: {_hizb},
              onSelectionChanged: (v) => setState(() => _hizb = v.first),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(l.gkTargetDate),
              subtitle: Text(
                _target == null ? l.gkNoDate : ml.formatMediumDate(_target!),
              ),
              trailing: _target == null
                  ? null
                  : IconButton(
                      tooltip: l.gkCancel,
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _target = null),
                    ),
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  firstDate: now,
                  lastDate: now.add(const Duration(days: 730)),
                  initialDate: _target ?? now.add(const Duration(days: 30)),
                );
                if (picked != null) setState(() => _target = picked);
              },
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('gk-create-submit'),
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l.gkCreateAction),
            ),
          ],
        ),
      ),
    );
  }
}
