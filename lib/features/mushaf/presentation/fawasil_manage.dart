import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/user_database.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/settings/settings_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/app_toast.dart';
import '../../../core/ui/look_kit.dart';
import '../../../core/ui/meta_separator.dart';
import '../../../l10n/app_localizations.dart';
import '../mushaf_providers.dart';
import 'mushaf_screen.dart' show surahName;
import 'widgets/fasil_bookmarks.dart';
import 'widgets/fasil_sheet.dart';
import 'widgets/illuminated_frame.dart' show NumberFormatter;
import 'widgets/mushaf_page.dart' show VerseKey;

/// «الفواصل» management: moving a fasil anywhere, its own look, the
/// limit of [maxFawasil] and the index's list of them.

/// The first verse (in Hafs numbers) of [page] in the edition being read.
Future<VerseKey?> firstVerseOfPage(ProviderContainer ref, int page) async {
  final ayahs = await ref.read(pageAyahsProvider(page).future);
  final first = ayahs.firstOrNull;
  if (first == null) return null;
  final riwaya = await ref.read(riwayaDataProvider.future);
  return hafsKeyOf(riwaya, (surah: first.surah, ayah: first.number));
}

/// Moves [fasil] to the verse [to] (Hafs numbers); its page is that
/// verse's page in the edition being read, and every other edition finds
/// its own page from the verse.
Future<void> moveFasilTo(
  ProviderContainer ref,
  BookmarkSetRow fasil,
  VerseKey to,
) async {
  final page = await ref.read(versePageProvider((to.surah, to.ayah)).future);
  await ref
      .read(userDatabaseProvider)
      .moveBookmarkSet(fasil.id, surah: to.surah, ayah: to.ayah, page: page);
}

/// Deletes [fasil] and offers «تراجع», which puts it back as it was.
Future<void> deleteFasilWithUndo(
  ScaffoldMessengerState messenger,
  AppLocalizations l,
  UserDatabase db,
  BookmarkSetRow fasil,
) async {
  await db.deleteBookmarkSet(fasil.id);
  messenger.showSnackBar(
    appToast(
      content: Text(l.fasilDeleted),
      action: SnackBarAction(
        label: l.fasilUndo,
        onPressed: () => db.restoreBookmarkSet(fasil),
      ),
    ),
  );
}

enum _MoveBy { current, verse, page }

/// «انقل إلى…»: a surah and verse, a page number, or where the reader is
/// now. True when it moved.
Future<bool> showFasilMove(
  BuildContext context,
  WidgetRef ref,
  BookmarkSetRow fasil,
) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final to = await showDialog<VerseKey>(
    context: context,
    builder: (_) => LookTheme(child: _MoveDialog(fasil: fasil)),
  );
  if (to == null) return false;
  await moveFasilTo(container, fasil, to);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      appToast(content: Text(AppLocalizations.of(context).fasilMoved)),
    );
  }
  return true;
}

class _MoveDialog extends ConsumerStatefulWidget {
  const _MoveDialog({required this.fasil});

  final BookmarkSetRow fasil;

  @override
  ConsumerState<_MoveDialog> createState() => _MoveDialogState();
}

class _MoveDialogState extends ConsumerState<_MoveDialog> {
  /// The reader's choice; until one, where they are reading when known.
  _MoveBy? _chosen;
  _MoveBy get _by =>
      _chosen ??
      (ref.read(readingPositionProvider).value == null
          ? _MoveBy.verse
          : _MoveBy.current);
  late int _surah = widget.fasil.surah;
  late final _ayah = TextEditingController(text: '${widget.fasil.ayah}');
  late final _page = TextEditingController(text: '${widget.fasil.page}');
  String? _error;

  @override
  void dispose() {
    _ayah.dispose();
    _page.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    VerseKey? to;
    switch (_by) {
      case _MoveBy.current:
        final p = ref.read(readingPositionProvider).value;
        if (p != null) to = (surah: p.surah, ayah: p.ayah);
      case _MoveBy.verse:
        final surahs = ref.read(surahsProvider).value;
        final n = int.tryParse(_ayah.text.trim());
        if (surahs != null &&
            n != null &&
            n >= 1 &&
            n <= surahs[_surah - 1].ayahCount) {
          to = (surah: _surah, ayah: n);
        }
      case _MoveBy.page:
        final n = int.tryParse(_page.text.trim());
        final count = ref.read(editionProvider).pageCount;
        if (n != null && n >= 1 && n <= count) {
          to = await firstVerseOfPage(container, n);
        }
    }
    if (!mounted) return;
    if (to == null) {
      setState(() => _error = l.fasilInvalidPlace);
      return;
    }
    Navigator.of(context).pop(to);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final surahs = ref.watch(surahsProvider).value ?? const [];
    final last = ref.watch(readingPositionProvider).value;
    final digits = NumberFormatter(Localizations.localeOf(context));
    final pages = ref.watch(editionProvider).pageCount;
    return AlertDialog(
      title: Text(l.fasilMoveTitle(widget.fasil.name)),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (by, label) in [
            if (last != null) (_MoveBy.current, l.fasilMoveCurrent),
            (_MoveBy.verse, l.fasilMoveBySurah),
            (_MoveBy.page, l.fasilMoveByPage),
          ])
            RadioListTile<_MoveBy>(
              key: ValueKey('fasil-move-${by.name}'),
              contentPadding: EdgeInsets.zero,
              value: by,
              // ignore: deprecated_member_use
              groupValue: _by,
              // ignore: deprecated_member_use
              onChanged: (v) => setState(() {
                _chosen = v!;
                _error = null;
              }),
              title: Text(label),
              subtitle: by == _MoveBy.current && last != null
                  ? MetaText(
                      digits.decimal(
                        l.fasilLastAt(
                          surahs.isEmpty
                              ? ''
                              : surahName(context, surahs[last.surah - 1]),
                          '${last.ayah}',
                          '${ref.watch(versePageProvider((last.surah, last.ayah))).value ?? last.page}',
                        ),
                      ),
                    )
                  : null,
            ),
          if (_by == _MoveBy.verse && surahs.isNotEmpty) ...[
            DropdownButtonFormField<int>(
              key: const ValueKey('fasil-move-surah'),
              initialValue: _surah,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.fasilSurah),
              items: [
                for (final s in surahs)
                  DropdownMenuItem(
                    value: s.id,
                    child: Text(
                      '${digits.decimal('${s.id}')}. ${surahName(context, s)}',
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _surah = v ?? _surah),
            ),
            TextField(
              key: const ValueKey('fasil-move-ayah'),
              controller: _ayah,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l.fasilAyah,
                helperText: l.fasilCount(1, surahs[_surah - 1].ayahCount),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
          if (_by == _MoveBy.page)
            TextField(
              key: const ValueKey('fasil-move-page'),
              controller: _page,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l.fasilPage,
                helperText: l.fasilCount(1, pages),
              ),
              onSubmitted: (_) => _submit(),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        FilledButton(
          key: const ValueKey('fasil-move-submit'),
          onPressed: _submit,
          child: Text(l.fasilMove),
        ),
      ],
    );
  }
}

/// «غيّر الشكل والخامة واللون»: this fasil's own look, cloth and colour,
/// with a live preview. «اتبع الإعداد الافتراضي» clears its own look and
/// cloth, so it follows the settings again.
Future<void> showFasilStyleEditor(
  BuildContext context,
  WidgetRef ref,
  BookmarkSetRow fasil,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => LookTheme(child: _StyleEditor(id: fasil.id)),
);

class _StyleEditor extends ConsumerWidget {
  const _StyleEditor({required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = context.tokens.colors;
    final db = ref.read(userDatabaseProvider);
    final s = ref.watch(settingsProvider);
    final fasil = ref
        .watch(bookmarkSetsProvider)
        .value
        ?.where((r) => r.id == id)
        .firstOrNull;
    if (fasil == null) return const SizedBox(height: 120);
    final own = fasilStyleOf(fasil);
    final cloth = fasilMaterialOf(fasil);
    final base = FasilLook.of(context, s);
    final look = base.forMark(
      FasilMark(
        id: id,
        name: '',
        color: Color(fasil.color),
        page: 0,
        style: own,
        material: cloth,
      ),
    );
    String styleName(FasilStyle v) => switch (v) {
      FasilStyle.tint => l.fasilStyleTint,
      FasilStyle.ribbon => l.fasilStyleRibbon,
      FasilStyle.tab => l.fasilStyleTab,
    };
    String clothName(FasilMaterial v) => switch (v) {
      FasilMaterial.silk => l.fasilSilk,
      FasilMaterial.linen => l.fasilLinen,
      FasilMaterial.velvet => l.fasilVelvet,
    };
    Future<void> set({FasilStyle? style, FasilMaterial? material}) =>
        db.setBookmarkSetStyle(id, look: style?.name, material: material?.name);

    Widget choices<T extends Enum>({
      required String label,
      required List<T> values,
      required T? selected,
      required String Function(T) name,
      required T effectiveDefault,
      required void Function(T?) onPick,
      required String keyPrefix,
    }) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(label, style: TextStyle(color: t.goldText)),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ChoiceChip(
              key: ValueKey('$keyPrefix-default'),
              label: Text(
                '${l.fasilDefaultOption} · ${name(effectiveDefault)}',
              ),
              selected: selected == null,
              onSelected: (_) => onPick(null),
            ),
            for (final v in values)
              ChoiceChip(
                key: ValueKey('$keyPrefix-${v.name}'),
                label: Text(name(v)),
                selected: selected == v,
                onSelected: (_) => onPick(v),
              ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );

    final target = context.tokens.elderly ? elderlyTarget : 44.0;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              header: true,
              child: Text(
                l.fasilStyleTitle(fasil.name),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: t.goldText),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: SizedBox(
                width: 120,
                child: FasilPreview(
                  look: look,
                  color: Color(fasil.color),
                  height: 130,
                ),
              ),
            ),
            const SizedBox(height: 12),
            choices<FasilStyle>(
              label: l.fasilStyleLabel,
              values: FasilStyle.values,
              selected: own,
              name: styleName,
              effectiveDefault: base.style,
              onPick: (v) => set(style: v, material: cloth),
              keyPrefix: 'fasil-own-look',
            ),
            if (look.style == FasilStyle.ribbon)
              choices<FasilMaterial>(
                label: l.fasilMaterialLabel,
                values: FasilMaterial.values,
                selected: cloth,
                name: clothName,
                effectiveDefault: base.material,
                onPick: (v) => set(style: own, material: v),
                keyPrefix: 'fasil-own-cloth',
              ),
            Semantics(
              header: true,
              child: Text(l.fasilColor, style: TextStyle(color: t.goldText)),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in {...fasilCardColors, ...fasilColors})
                  Semantics(
                    button: true,
                    selected: c == fasil.color,
                    label: '${l.fasilColor} #${c.toRadixString(16)}',
                    child: InkResponse(
                      key: ValueKey('fasil-own-color-$c'),
                      onTap: () => db.updateBookmarkSet(id, color: c),
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
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey('fasil-follow-default'),
              icon: const Icon(Icons.settings_backup_restore),
              label: Text(l.fasilFollowDefault),
              onPressed: own == null && cloth == null
                  ? null
                  : () => set(style: null, material: null),
            ),
          ],
        ),
      ),
    );
  }
}

/// The sheet shown when a new fasil would pass [maxFawasil]: the named
/// fawasil, each to move to [here] or delete. A reader with more than the
/// limit (from before it) is told all are kept and how many to delete.
Future<void> showFawasilLimit(
  BuildContext context, {
  required VerseKey here,
  required int page,
}) {
  final messenger = ScaffoldMessenger.of(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => LookTheme(
      child: Consumer(
        builder: (sheet, ref, _) {
          final l = AppLocalizations.of(sheet);
          final t = sheet.tokens.colors;
          final db = ref.read(userDatabaseProvider);
          final named = [
            for (final r in ref.watch(bookmarkSetsProvider).value ?? const [])
              if (r.kind == null) r,
          ];
          final surahs = ref.watch(surahsProvider).value;
          final digits = NumberFormatter(Localizations.localeOf(sheet));
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 12),
              children: [
                Semantics(
                  header: true,
                  child: ListTile(
                    title: Text(
                      digits.decimal(l.fasilLimitTitle(maxFawasil)),
                      style: TextStyle(
                        color: t.goldText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      named.length > maxFawasil
                          ? digits.decimal(
                              l.fasilLimitOver(named.length, maxFawasil - 1),
                            )
                          : l.fasilLimitHint,
                      style: const TextStyle(height: 1.6),
                    ),
                  ),
                ),
                for (final f in named)
                  ListTile(
                    key: ValueKey('fasil-limit-${f.id}'),
                    leading: FasilSwatch(fasil: f),
                    title: Text(f.name),
                    subtitle: surahs == null
                        ? null
                        : MetaText(
                            digits.decimal(
                              l.fasilLastAt(
                                surahName(sheet, surahs[f.surah - 1]),
                                '${f.ayah}',
                                '${ref.watch(versePageProvider((f.surah, f.ayah))).value ?? f.page}',
                              ),
                            ),
                          ),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          key: ValueKey('fasil-limit-move-${f.id}'),
                          tooltip: l.fasilMoveHereShort,
                          icon: const Icon(Icons.swap_horiz),
                          onPressed: () async {
                            armFasilEntrance();
                            await db.moveBookmarkSet(
                              f.id,
                              surah: here.surah,
                              ayah: here.ayah,
                              page: page,
                            );
                            if (sheet.mounted) Navigator.of(sheet).pop();
                            messenger.showSnackBar(
                              appToast(content: Text(l.fasilMoved)),
                            );
                          },
                        ),
                        IconButton(
                          key: ValueKey('fasil-limit-delete-${f.id}'),
                          tooltip: l.delete,
                          icon: Icon(
                            Icons.delete_outline,
                            color: Theme.of(sheet).colorScheme.error,
                          ),
                          onPressed: () =>
                              deleteFasilWithUndo(messenger, l, db, f),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

/// A small mark of a fasil's own look and colour, for lists.
class FasilSwatch extends ConsumerWidget {
  const FasilSwatch({super.key, required this.fasil});

  final BookmarkSetRow fasil;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FasilStyle style =
        fasilStyleOf(fasil) ??
        ref.watch(settingsProvider.select((s) => s.effectiveFasilStyle));
    final color = Color(fasil.color);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: 36,
        child: Center(
          child: switch (style) {
            FasilStyle.tint => Container(
              width: 30,
              height: 14,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            FasilStyle.ribbon => Icon(Icons.bookmark, color: color, size: 30),
            FasilStyle.tab => Container(
              width: 22,
              height: 30,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(11),
                  bottom: Radius.circular(3),
                ),
              ),
            ),
          },
        ),
      ),
    );
  }
}

/// The index's «الفواصل»: every fasil with its look, place and page in the
/// edition being read; open, move, rename, restyle, delete, and drag to
/// set their order on the page edge.
class FawasilIndexTab extends ConsumerWidget {
  const FawasilIndexTab({super.key, required this.onOpen});

  /// Opens the mushaf at a fasil.
  final void Function(BookmarkSetRow) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = context.tokens.colors;
    final rows = ref.watch(bookmarkSetsProvider).value;
    final surahs = ref.watch(surahsProvider).value;
    if (rows == null || surahs == null) {
      return Center(child: Text(l.loadingLabel));
    }
    if (rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            '${l.noFawasil}\n${l.fasilHint}',
            textAlign: TextAlign.center,
            style: TextStyle(color: t.muted, height: 1.7),
          ),
        ),
      );
    }
    final digits = NumberFormatter(Localizations.localeOf(context));
    final named = rows.where((r) => r.kind == null).length;
    final ids = [for (final r in rows) r.id];
    Future<void> reorder(int from, int to) async {
      final next = [...ids];
      final id = next.removeAt(from);
      next.insert(to, id);
      await ref.read(userDatabaseProvider).reorderBookmarkSets(next);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l.fasilReorderHint,
                  style: TextStyle(color: t.muted, fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                digits.decimal(l.fasilCount(named, maxFawasil)),
                key: const ValueKey('fawasil-count'),
                style: TextStyle(
                  color: named >= maxFawasil ? t.goldText : t.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: rows.length,
            onReorderItem: reorder,
            itemBuilder: (context, i) {
              final f = rows[i];
              final page =
                  ref.watch(versePageProvider((f.surah, f.ayah))).value ??
                  f.page;
              final surah = surahName(context, surahs[f.surah - 1]);
              return _FasilTile(
                key: ValueKey('fawasil-row-${f.id}'),
                index: i,
                count: rows.length,
                fasil: f,
                place: digits.decimal(
                  l.fasilLastAt(surah, '${f.ayah}', '$page'),
                ),
                label: digits.decimal(
                  l.fasilItemLabel(f.name, surah, '${f.ayah}', '$page'),
                ),
                onOpen: () => onOpen(f),
                onReorder: reorder,
              );
            },
          ),
        ),
      ],
    );
  }
}

enum _Action { move, rename, style, delete }

class _FasilTile extends ConsumerWidget {
  const _FasilTile({
    super.key,
    required this.index,
    required this.count,
    required this.fasil,
    required this.place,
    required this.label,
    required this.onOpen,
    required this.onReorder,
  });

  final int index;
  final int count;
  final BookmarkSetRow fasil;
  final String place;
  final String label;
  final VoidCallback onOpen;
  final Future<void> Function(int from, int to) onReorder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = context.tokens.colors;
    final db = ref.read(userDatabaseProvider);
    Future<void> act(_Action a) async {
      switch (a) {
        case _Action.move:
          await showFasilMove(context, ref, fasil);
        case _Action.rename:
          final name = await askFasilName(context, initial: fasil.name);
          if (name == null || name.isEmpty) return;
          await db.updateBookmarkSet(fasil.id, name: name);
        case _Action.style:
          await showFasilStyleEditor(context, ref, fasil);
        case _Action.delete:
          await deleteFasilWithUndo(
            ScaffoldMessenger.of(context),
            l,
            db,
            fasil,
          );
      }
    }

    return Semantics(
      label: label,
      customSemanticsActions: {
        if (index > 0)
          CustomSemanticsAction(label: l.fasilMoveUp): () =>
              onReorder(index, index - 1),
        if (index < count - 1)
          CustomSemanticsAction(label: l.fasilMoveDown): () =>
              onReorder(index, index + 1),
      },
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          onTap: onOpen,
          leading: FasilSwatch(fasil: fasil),
          title: ExcludeSemantics(
            child: Text(
              fasil.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          subtitle: ExcludeSemantics(
            child: MetaText(place, style: TextStyle(color: t.muted)),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PopupMenuButton<_Action>(
                key: ValueKey('fawasil-menu-${fasil.id}'),
                tooltip: '${l.fasilMoveTo} · ${fasil.name}',
                onSelected: act,
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: _Action.move,
                    child: ListTile(
                      leading: const Icon(Icons.swap_horiz),
                      title: Text(l.fasilMoveTo),
                    ),
                  ),
                  // The four fixed fawasil keep their names.
                  if (fasil.kind == null)
                    PopupMenuItem(
                      value: _Action.rename,
                      child: ListTile(
                        leading: const Icon(Icons.edit_outlined),
                        title: Text(l.fasilRenameAction),
                      ),
                    ),
                  PopupMenuItem(
                    value: _Action.style,
                    child: ListTile(
                      leading: const Icon(Icons.palette_outlined),
                      title: Text(l.fasilChangeStyle),
                    ),
                  ),
                  PopupMenuItem(
                    value: _Action.delete,
                    child: ListTile(
                      leading: Icon(
                        Icons.delete_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      title: Text(l.delete),
                    ),
                  ),
                ],
              ),
              ReorderableDragStartListener(
                index: index,
                child: Tooltip(
                  message: l.fasilReorderHint,
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.drag_handle),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
