import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/user_database.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/settings/settings_controller.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/look_kit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../mushaf_providers.dart';
import 'fasil_bookmarks.dart';
import 'mushaf_page.dart';

/// Colours offered for new fawasil, in order.
const fasilColors = <int>[
  0xFFB23A3A,
  0xFF2E7D5B,
  0xFF2F5E9E,
  0xFFB7860B,
  0xFF7A4A9E,
  0xFF3A7F8C,
];

/// The colour a new fasil takes after [count] others: cards take the card
/// palette.
int nextFasilColor(FasilStyle style, int count) {
  final palette = style == FasilStyle.tab ? fasilCardColors : fasilColors;
  return palette[count % palette.length];
}

/// Moves an existing fasil to [verse], or creates a new one there.
Future<void> showSaveToFasil(
  BuildContext context,
  WidgetRef ref, {
  required VerseKey verse,
  required int page,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => LookTheme(
      child: Builder(
        builder: (sheet) => Consumer(
          builder: (context, ref, _) {
            final l = AppLocalizations.of(context);
            final t = context.tokens.colors;
            final db = ref.read(userDatabaseProvider);
            final sets = ref.watch(bookmarkSetsProvider).value ?? const [];
            void done() {
              Navigator.of(sheet).pop();
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(l.saved)));
            }

            return SafeArea(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 12),
                children: [
                  Semantics(
                    header: true,
                    child: ListTile(
                      title: Text(
                        l.fasilSaveHere,
                        style: TextStyle(
                          color: t.goldText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  for (final s in sets)
                    ListTile(
                      leading: Icon(Icons.bookmark, color: Color(s.color)),
                      title: Text(s.name),
                      onTap: () async {
                        armFasilEntrance();
                        await db.moveBookmarkSet(
                          s.id,
                          surah: verse.surah,
                          ayah: verse.ayah,
                          page: page,
                        );
                        done();
                      },
                    ),
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: Text(l.fasilNew),
                    onTap: () async {
                      final named = sets.where((s) => s.kind == null).length;
                      final style = await ensureFasilStyle(
                        context,
                        ref,
                        hasFawasil: named > 0,
                      );
                      if (style == null || !context.mounted) return;
                      final name = await _askName(context);
                      if (name == null || name.isEmpty) return;
                      armFasilEntrance();
                      await HapticFeedback.lightImpact();
                      await db.addBookmarkSet(
                        name: name,
                        color: nextFasilColor(style, named),
                        surah: verse.surah,
                        ayah: verse.ayah,
                        page: page,
                      );
                      done();
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}

/// The look to make a fasil in. A reader who never chose and has no
/// fawasil yet is asked once (see [FasilStyleChooser]); one who already
/// had fawasil keeps the tinted verse until they change it. Null when the
/// chooser was closed without a choice.
Future<FasilStyle?> ensureFasilStyle(
  BuildContext context,
  WidgetRef ref, {
  required bool hasFawasil,
}) => ensureFasilStyleFor(
  context,
  ProviderScope.containerOf(context, listen: false),
  hasFawasil: hasFawasil,
);

/// [ensureFasilStyle] over a [ProviderContainer].
Future<FasilStyle?> ensureFasilStyleFor(
  BuildContext context,
  ProviderContainer ref, {
  required bool hasFawasil,
}) async {
  final chosen = ref.read(settingsProvider).fasilStyle;
  if (chosen != null) return chosen;
  if (hasFawasil) return FasilStyle.tint;
  final style = await showModalBottomSheet<FasilStyle>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const LookTheme(child: FasilStyleChooser()),
  );
  if (style != null) {
    await ref.read(settingsProvider.notifier).setFasilStyle(style);
  }
  return style;
}

/// «اختر شكل فواصلك»: the three looks side by side, each a live preview
/// on a small page; a tap chooses it.
class FasilStyleChooser extends ConsumerWidget {
  const FasilStyleChooser({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = context.tokens.colors;
    final s = ref.watch(settingsProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                l.fasilChooserTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(color: t.goldText),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l.fasilChooserHint,
              textAlign: TextAlign.center,
              style: TextStyle(color: t.muted),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (style, name) in [
                  (FasilStyle.tint, l.fasilStyleTint),
                  (FasilStyle.ribbon, l.fasilStyleRibbon),
                  (FasilStyle.tab, l.fasilStyleTab),
                ])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Semantics(
                        button: true,
                        label: name,
                        excludeSemantics: true,
                        child: InkWell(
                          key: ValueKey('fasil-choose-${style.name}'),
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.of(context).pop(style),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Column(
                              children: [
                                FasilPreview(
                                  look: FasilLook.of(
                                    context,
                                    s.copyWith(fasilStyle: style),
                                  ).copyNoMotion(),
                                  height: 150,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  name,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

extension on FasilLook {
  FasilLook copyNoMotion() => FasilLook(
    style: style,
    place: place,
    material: material,
    tassel: tassel,
    night: night,
    elderly: elderly,
    motion: false,
  );
}

/// A small page with lines of «text» and one fasil in [look], for the
/// chooser and the settings.
class FasilPreview extends StatelessWidget {
  const FasilPreview({super.key, required this.look, this.height = 140});

  final FasilLook look;
  final double height;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens.colors;
    final color = Color(
      look.style == FasilStyle.tab ? fasilCardColors.first : fasilColors[2],
    );
    final mark = FasilMark(
      id: -1,
      name: l.fasilSuggestReview,
      color: color,
      page: 0,
    );
    final tint = look.style == FasilStyle.tint;
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        child: FasilPageLayer(
          marks: [mark],
          look: look,
          outerRight: true,
          child: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: t.paper,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: t.goldText.withValues(alpha: .5)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (var i = 0; i < 7; i++)
                      Container(
                        height: 3,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: tint && (i == 3 || i == 4)
                              ? color.withValues(alpha: .55)
                              : t.ink.withValues(alpha: .25),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<String?> _askName(BuildContext context, {String? initial}) =>
    showDialog<String>(
      context: context,
      builder: (_) => LookTheme(child: FasilNameDialog(initial: initial)),
    );

/// Asks a new fasil's name; pops it trimmed, or nothing when cancelled.
/// Suggests «حفظ», «تلاوة» and «مراجعة»; any other name can be typed.
/// Owns its text field's controller, released with the dialog.
@visibleForTesting
class FasilNameDialog extends StatefulWidget {
  const FasilNameDialog({super.key, this.initial});

  /// The name now, when renaming.
  final String? initial;

  @override
  State<FasilNameDialog> createState() => _FasilNameDialogState();
}

class _FasilNameDialogState extends State<FasilNameDialog> {
  late final _field = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.initial == null ? l.fasilNew : l.fasilRename),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final s in [
                l.fasilSuggestHifz,
                l.fasilSuggestTilawa,
                l.fasilSuggestReview,
              ])
                ActionChip(
                  key: ValueKey('fasil-suggest-$s'),
                  label: Text(s),
                  onPressed: () => setState(
                    () => _field.value = TextEditingValue(
                      text: s,
                      selection: TextSelection.collapsed(offset: s.length),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _field,
            autofocus: true,
            maxLength: 40,
            decoration: InputDecoration(
              labelText: l.fasilName,
              helperText: l.fasilHint,
            ),
            onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_field.text.trim()),
          child: Text(l.save),
        ),
      ],
    );
  }
}

/// A fasil's actions, from a long press on its bookmark: rename, recolour,
/// move to [here] (the page on screen), delete (asked, and undoable).
Future<void> showFasilActions(
  BuildContext context,
  WidgetRef ref, {
  required BookmarkSetRow fasil,
  required String pageLabel,
  ({int surah, int ayah, int page})? here,
}) {
  final messenger = ScaffoldMessenger.of(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => LookTheme(
      child: Builder(
        builder: (sheet) {
          final l = AppLocalizations.of(sheet);
          final t = sheet.tokens.colors;
          final db = ref.read(userDatabaseProvider);
          final target = sheet.tokens.elderly ? elderlyTarget : 44.0;
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 12),
              children: [
                ListTile(
                  leading: Icon(Icons.bookmark, color: Color(fasil.color)),
                  title: Text(
                    '${fasil.name} · $pageLabel',
                    style: TextStyle(
                      color: t.goldText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(l.fasilRename),
                  onTap: () async {
                    final name = await _askName(sheet, initial: fasil.name);
                    if (name == null || name.isEmpty) return;
                    await db.updateBookmarkSet(fasil.id, name: name);
                    if (sheet.mounted) Navigator.of(sheet).pop();
                  },
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 4),
                  child: Semantics(
                    label: l.fasilColor,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in {...fasilCardColors, ...fasilColors})
                          Semantics(
                            button: true,
                            selected: c == fasil.color,
                            label: '${l.fasilColor} #${c.toRadixString(16)}',
                            child: InkResponse(
                              key: ValueKey('fasil-color-$c'),
                              onTap: () async {
                                await db.updateBookmarkSet(fasil.id, color: c);
                                if (sheet.mounted) Navigator.of(sheet).pop();
                              },
                              child: SizedBox.square(
                                dimension: target,
                                child: Center(
                                  child: Container(
                                    width: target * .62,
                                    height: target * .62,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(c),
                                      border: Border.all(
                                        color: c == fasil.color
                                            ? t.ink
                                            : const Color(0x33000000),
                                        width: c == fasil.color ? 2.5 : 1,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (here != null)
                  ListTile(
                    leading: const Icon(Icons.swap_horiz),
                    title: Text(l.fasilMoveHere),
                    onTap: () async {
                      armFasilEntrance();
                      await db.moveBookmarkSet(
                        fasil.id,
                        surah: here.surah,
                        ayah: here.ayah,
                        page: here.page,
                      );
                      if (sheet.mounted) Navigator.of(sheet).pop();
                    },
                  ),
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: Theme.of(sheet).colorScheme.error,
                  ),
                  title: Text(
                    l.delete,
                    style: TextStyle(color: Theme.of(sheet).colorScheme.error),
                  ),
                  onTap: () async {
                    final sure = await showDialog<bool>(
                      context: sheet,
                      builder: (d) => LookTheme(
                        child: AlertDialog(
                          content: Text(l.fasilDeleteConfirm(fasil.name)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(d).pop(false),
                              child: Text(l.cancel),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.of(d).pop(true),
                              child: Text(l.delete),
                            ),
                          ],
                        ),
                      ),
                    );
                    if (sure != true) return;
                    await db.deleteBookmarkSet(fasil.id);
                    if (sheet.mounted) Navigator.of(sheet).pop();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(l.fasilDeleted),
                        action: SnackBarAction(
                          label: l.fasilUndo,
                          onPressed: () => db.addBookmarkSet(
                            name: fasil.name,
                            color: fasil.color,
                            surah: fasil.surah,
                            ayah: fasil.ayah,
                            page: fasil.page,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
