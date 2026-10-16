import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/interface_style.dart';
import '../../../core/ui/look_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../../mushaf/presentation/widgets/illuminated_frame.dart'
    show NumberFormatter;
import '../domain/dhikr.dart';
import '../domain/tasbih_counter.dart';
import '../tasbih_providers.dart';
import '../tasbih_settings.dart';
import 'tasbih_screen.dart' show MineBadge;

/// The list of adhkar to count: the app's (with their source) and the
/// reader's own, which can be added, edited and deleted.
Future<void> showDhikrSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => const DhikrSheet(),
);

class DhikrSheet extends ConsumerWidget {
  const DhikrSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final look = context.look;
    final app = ref.watch(appAdhkarProvider).value;
    final mine = ref.watch(myAdhkarProvider).value ?? const [];
    final current = ref.watch(currentDhikrProvider)?.key;
    void choose(Dhikr d) {
      final ctrl = ref.read(tasbihSettingsProvider.notifier);
      ctrl.setDhikr(d.key);
      if (d.target != null) ctrl.setTarget(d.target);
      Navigator.of(context).pop();
    }

    Widget tile(Dhikr d) => RadioListTile<String>(
      value: d.key,
      title: Text(d.text, style: const TextStyle(height: 1.6)),
      subtitle: d.mine
          ? Align(
              alignment: AlignmentDirectional.centerStart,
              child: MineBadge(label: l.tasbihMine),
            )
          : d.reference == null
          ? null
          : Text(d.reference!, style: TextStyle(color: look.sub, fontSize: 12)),
      secondary: d.mine
          ? PopupMenuButton<bool>(
              onSelected: (edit) async {
                if (edit) {
                  await showDhikrEditor(context, existing: d);
                } else {
                  await ref.read(tasbihRepositoryProvider).remove(d.uuid!);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: true, child: Text(l.tasbihEditDhikr)),
                PopupMenuItem(value: false, child: Text(l.tasbihDeleteDhikr)),
              ],
            )
          : null,
    );

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .8,
        ),
        child: RadioGroup<String>(
          groupValue: current,
          onChanged: (key) {
            final all = [...?app?.adhkar, ...mine];
            final d = all.where((d) => d.key == key).firstOrNull;
            if (d != null) choose(d);
          },
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              LookSheetHeader(title: l.tasbihChooseDhikr),
              if (app != null && app.adhkar.isNotEmpty) ...[
                _Head(l.tasbihAppAdhkar),
                for (final d in app.adhkar) tile(d),
              ],
              _Head(l.tasbihMyAdhkar),
              for (final d in mine) tile(d),
              ListTile(
                leading: Icon(Icons.add, color: look.accent),
                title: Text(
                  l.tasbihAddDhikr,
                  style: TextStyle(
                    color: look.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => showDhikrEditor(context),
              ),
              if (app != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    l.tasbihSourceLine(
                      app.source.url.replaceFirst('https://', ''),
                      app.source.license,
                    ),
                    style: TextStyle(color: look.sub, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 4),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: TextStyle(color: context.look.sub, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

/// Adds a dhikr of the reader's, or edits [existing].
Future<void> showDhikrEditor(BuildContext context, {Dhikr? existing}) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: DhikrEditor(existing: existing),
      ),
    );

class DhikrEditor extends ConsumerStatefulWidget {
  const DhikrEditor({super.key, this.existing});

  final Dhikr? existing;

  @override
  ConsumerState<DhikrEditor> createState() => _DhikrEditorState();
}

class _DhikrEditorState extends ConsumerState<DhikrEditor> {
  late final _text = TextEditingController(text: widget.existing?.text);
  late final _ref = TextEditingController(text: widget.existing?.reference);
  late int? _target = widget.existing == null ? 33 : widget.existing!.target;

  @override
  void dispose() {
    _text.dispose();
    _ref.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    final repo = ref.read(tasbihRepositoryProvider);
    final e = widget.existing;
    if (e == null) {
      final d = await repo.add(text, reference: _ref.text, target: _target);
      final ctrl = ref.read(tasbihSettingsProvider.notifier);
      await ctrl.setDhikr(d.key);
      await ctrl.setTarget(_target);
    } else {
      await repo.edit(
        e.uuid!,
        text: text,
        reference: _ref.text,
        target: _target,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final look = context.look;
    final digits = NumberFormatter(Localizations.localeOf(context));
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            LookSheetHeader(
              title: widget.existing == null
                  ? l.tasbihAddDhikr
                  : l.tasbihEditDhikr,
            ),
            TextField(
              controller: _text,
              autofocus: widget.existing == null,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: l.tasbihDhikrText,
                hintText: l.tasbihDhikrTextHint,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Text(
              l.tasbihMineNote,
              style: TextStyle(color: look.sub, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ref,
              decoration: InputDecoration(
                labelText: l.tasbihDhikrReference,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l.tasbihTarget,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton.outlined(
                  icon: const Icon(Icons.remove),
                  tooltip: l.tasbihTargetLess,
                  onPressed: _target == null
                      ? null
                      : () => setState(
                          () => _target = stepTarget(_target, up: false),
                        ),
                ),
                Expanded(
                  child: Text(
                    _target == null ? l.tasbihNoTarget : digits(_target!),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton.outlined(
                  icon: const Icon(Icons.add),
                  tooltip: l.tasbihTargetMore,
                  onPressed: () =>
                      setState(() => _target = stepTarget(_target, up: true)),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final t in tasbihPresetTargets)
                  ChoiceChip(
                    label: Text(t == null ? l.tasbihNoTarget : digits(t)),
                    selected: _target == t,
                    onSelected: (_) => setState(() => _target = t),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _text.text.trim().isEmpty ? null : _save,
              child: Text(l.tasbihSave),
            ),
          ],
        ),
      ),
    );
  }
}
