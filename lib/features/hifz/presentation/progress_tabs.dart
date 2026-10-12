import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/db/content_database.dart';
import '../../../core/db/user_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/look_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../../mushaf/mushaf_providers.dart';
import '../../mushaf/presentation/widgets/illuminated_frame.dart'
    show NumberFormatter;
import '../../word_study/data/word_study_repository.dart' show verseWords;
import '../../khatma/khatma_providers.dart' show quranIndexProvider;
import '../data/hifz_repository.dart';
import '../data/recitation_store.dart';
import '../domain/hifz_progress.dart';
import '../domain/recitation_record.dart';
import '../hifz_providers.dart';
import 'hifz_sheets.dart' show showStartTestSheet;
import 'hifz_screen.dart' show openHifzTest;
import 'strength_style.dart';

/// A whole number in the interface's digits.
String _n(BuildContext context, int v) =>
    NumberFormatter(Localizations.localeOf(context))(v);

/// A share (0..1) as a percentage in the interface's digits.
String hifzPercent(BuildContext context, double v) {
  final p = (v * 100).round();
  return Localizations.localeOf(context).languageCode == 'ar'
      ? '${_n(context, p)}٪'
      : '$p%';
}

String _surah(BuildContext context, List<SurahRow>? surahs, int s) {
  if (surahs == null) return _n(context, s);
  final ar = Localizations.localeOf(context).languageCode == 'ar';
  return ar ? surahs[s - 1].nameAr : surahs[s - 1].nameEn;
}

/// «الملك ١–١٠» or «الملك ١ – القلم ٥» for verses [from]..[to] (ids).
String verseSpan(
  BuildContext context,
  List<SurahRow>? surahs,
  ({int surah, int ayah}) from,
  ({int surah, int ayah}) to,
) {
  final l = AppLocalizations.of(context);
  if (from.surah == to.surah) {
    return l.verseRange(
      _surah(context, surahs, from.surah),
      _n(context, from.ayah),
      _n(context, to.ayah),
    );
  }
  return '${_surah(context, surahs, from.surah)} ${_n(context, from.ayah)} – '
      '${_surah(context, surahs, to.surah)} ${_n(context, to.ayah)}';
}

String _day(BuildContext context, DateTime d) =>
    DateFormat.yMMMd(Localizations.localeOf(context).languageCode).format(d);

/// A heading in the screen's gold.
class HifzHeading extends StatelessWidget {
  const HifzHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: context.tokens.colors.goldText,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

/// A calm empty state: one line, and an action when there is one.
class _Empty extends StatelessWidget {
  const _Empty(this.text, {this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: TextStyle(color: context.tokens.colors.ink)),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    ),
  );
}

/// Two thin bars: memorized under mastered.
class ShareBars extends StatelessWidget {
  const ShareBars({super.key, required this.memorized, required this.mastered});

  final double memorized, mastered;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    Widget bar(double v, Color c) => ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: v,
        minHeight: 6,
        color: c,
        backgroundColor: tokens.colors.border.withValues(alpha: .5),
      ),
    );
    return ExcludeSemantics(
      child: Column(
        children: [
          bar(memorized, stateFill(VerseState.memorized, tokens.mode)),
          const SizedBox(height: 3),
          bar(mastered, stateFill(VerseState.mastered, tokens.mode)),
        ],
      ),
    );
  }
}

// -- التقدّم ------------------------------------------------------------------

/// Progress on three levels: in all, by surah or juz, and the map.
class ProgressTab extends ConsumerStatefulWidget {
  const ProgressTab({super.key});

  @override
  ConsumerState<ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends ConsumerState<ProgressTab> {
  bool _byJuz = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens.colors;
    final p = ref.watch(hifzProgressProvider).value;
    final surahs = ref.watch(surahsProvider).value;
    if (p == null) return const Center(child: CircularProgressIndicator());
    final o = p.overall;
    final parts = [
      for (final x in _byJuz ? p.juzs : p.surahs)
        if (x.memorized > 0) x,
    ];
    Widget stat(String value, String label) => Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: t.ink,
            ),
          ),
          Text(label, style: TextStyle(color: t.muted, fontSize: 13)),
        ],
      ),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        LookGroup(
          icon: Icons.insights_outlined,
          title: l.progressOverall,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  stat(_n(context, p.juzMemorized), l.progressJuzCount),
                  stat(_n(context, p.pagesMemorized), l.progressPagesCount),
                  stat(_n(context, o.memorized), l.progressVersesCount),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShareBars(
                    memorized: o.memorizedShare,
                    mastered: o.masteredShare,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 14,
                    runSpacing: 8,
                    children: [
                      for (final s in [
                        VerseState.memorized,
                        VerseState.mastered,
                        VerseState.needsReview,
                      ])
                        StateChip(
                          state: s,
                          label:
                              '${stateLabel(l, s)} ${_n(context, switch (s) {
                                VerseState.mastered => o.mastered,
                                VerseState.needsReview => o.needsReview,
                                _ => o.memorized - o.mastered - o.needsReview,
                              })}',
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${l.progressAccuracy30}: '
                    '${p.accuracy30 == null ? '–' : hifzPercent(context, p.accuracy30!)}',
                    style: TextStyle(color: t.ink),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (p.unrecited > 0)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.progressSuggestRecite(_n(context, p.unrecited)),
                      style: TextStyle(color: t.ink),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () async {
                      final unit = await showStartTestSheet(context);
                      if (unit == null || !context.mounted) return;
                      await openHifzTest(
                        context,
                        ref,
                        kind: unit.kind,
                        fromRef: unit.fromRef,
                        toRef: unit.toRef,
                      );
                    },
                    child: Text(l.goalRecite),
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            l.progressMasteryRule,
            style: TextStyle(color: t.muted, fontSize: 13),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, label: Text(l.progressBySurah)),
                  ButtonSegment(value: true, label: Text(l.progressByJuz)),
                ],
                selected: {_byJuz},
                showSelectedIcon: false,
                onSelectionChanged: (v) => setState(() => _byJuz = v.first),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: l.progressOpenMap,
              onPressed: () => context.push('/hifz/map'),
              icon: const Icon(Icons.grid_view),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (parts.isEmpty)
          _Empty(
            l.progressEmpty,
            action: OutlinedButton(
              onPressed: () => context.push('/hifz/map'),
              child: Text(l.progressOpenMap),
            ),
          )
        else
          for (final x in parts)
            _PartRow(
              part: x,
              title: _byJuz
                  ? l.juzLabel(_n(context, x.number))
                  : l.surahWord(_surah(context, surahs, x.number)),
            ),
      ],
    );
  }
}

/// A coloured swatch with its mark and label.
class StateChip extends StatelessWidget {
  const StateChip({super.key, required this.state, required this.label});

  final VerseState state;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 20,
          decoration: BoxDecoration(
            color: stateFill(state, tokens.mode),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: tokens.colors.border),
          ),
          child: Icon(
            stateIcon(state),
            size: 13,
            color: stateInk(state, tokens.mode, tokens.colors.ink),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}

class _PartRow extends StatelessWidget {
  const _PartRow({required this.part, required this.title});

  final ProgressPart part;
  final String title;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens.colors;
    final acc = part.accuracy;
    final last = part.lastRecited;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  l.progressShares(
                    hifzPercent(context, part.memorizedShare),
                    hifzPercent(context, part.masteredShare),
                  ),
                  style: TextStyle(color: t.ink, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ShareBars(
              memorized: part.memorizedShare,
              mastered: part.masteredShare,
            ),
            const SizedBox(height: 6),
            Text(
              [
                last == null
                    ? l.progressNotRecited
                    : l.progressLastRecited(_day(context, last)),
                if (acc != null) l.progressAccuracy(hifzPercent(context, acc)),
              ].join(' · '),
              style: TextStyle(color: t.muted, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

// -- السجل --------------------------------------------------------------------

String recitationKindLabel(AppLocalizations l, String kind) =>
    switch (RecitationKind.values.asNameMap()[kind]) {
      RecitationKind.voice => l.recitationVoice,
      RecitationKind.touch => l.recitationTouch,
      _ => l.recitationTest,
    };

IconData recitationKindIcon(String kind) =>
    switch (RecitationKind.values.asNameMap()[kind]) {
      RecitationKind.voice => Icons.mic_none,
      RecitationKind.touch => Icons.touch_app_outlined,
      _ => Icons.visibility_off_outlined,
    };

/// The past sessions, newest first; each opens its summary.
class HistoryTab extends ConsumerWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = context.tokens.colors;
    final sessions = ref.watch(recitationsProvider).value;
    final index = ref.watch(quranIndexProvider).value;
    final surahs = ref.watch(surahsProvider).value;
    if (sessions == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        if (sessions.isEmpty) _Empty(l.historyEmpty),
        for (final s in sessions)
          Card(
            child: ListTile(
              onTap: () => context.push('/hifz/session/${s.uuid}'),
              leading: CircleAvatar(
                backgroundColor: t.border.withValues(alpha: .4),
                foregroundColor: t.ink,
                child: Icon(recitationKindIcon(s.kind), size: 20),
              ),
              title: Text(
                index == null
                    ? ''
                    : verseSpan(
                        context,
                        surahs,
                        index.keyOf(s.fromVerse),
                        index.keyOf(s.toVerse),
                      ),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${recitationKindLabel(l, s.kind)} · ${_day(context, s.endedAt)}',
              ),
              trailing: Text(
                s.accuracy == null ? '–' : hifzPercent(context, s.accuracy!),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isMastered(s.accuracy) ? t.goldText : t.ink,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// One session's summary: per verse, and the slips by place, their words
/// read from content.db.
class RecitationSessionScreen extends ConsumerWidget {
  const RecitationSessionScreen({super.key, required this.uuid});

  final String uuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = context.tokens.colors;
    final data = ref.watch(_sessionProvider(uuid)).value;
    final surahs = ref.watch(surahsProvider).value;
    return LookScaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            LookTopBar(
              title: l.sessionSummary,
              actions: [
                if (data != null)
                  IconButton(
                    tooltip: l.sessionDelete,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await ref
                          .read(userDatabaseProvider)
                          .deleteRecitation(uuid);
                      if (context.mounted) context.pop();
                    },
                  ),
              ],
            ),
            Expanded(
              child: data == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Text(
                                  data.session.accuracy == null
                                      ? '–'
                                      : hifzPercent(
                                          context,
                                          data.session.accuracy!,
                                        ),
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w800,
                                    color: t.goldText,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        recitationKindLabel(
                                          l,
                                          data.session.kind,
                                        ),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        _day(context, data.session.endedAt),
                                        style: TextStyle(color: t.muted),
                                      ),
                                      if (data.session.sensitivity
                                          case final s?)
                                        Text(
                                          l.sessionSensitivity(
                                            _strictness(l, s),
                                          ),
                                          style: TextStyle(color: t.muted),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            l.progressMasteryRule,
                            style: TextStyle(color: t.muted, fontSize: 13),
                          ),
                        ),
                        for (final v in data.verses)
                          Card(
                            child: ListTile(
                              leading: Icon(
                                stateIcon(
                                  isMastered(v.row.accuracy)
                                      ? VerseState.mastered
                                      : VerseState.needsReview,
                                ),
                                color: isMastered(v.row.accuracy)
                                    ? t.goldText
                                    : t.muted,
                              ),
                              title: Text(
                                verseSpan(context, surahs, v.key, v.key),
                              ),
                              subtitle: v.row.words == 0
                                  ? null
                                  : Text(
                                      '${l.tasmeeWordWrong} ${_n(context, v.row.wrong)} · '
                                      '${l.tasmeeWordSkipped} ${_n(context, v.row.skipped)} · '
                                      '${l.tasmeeWordCorrectedShort} ${_n(context, v.row.corrected)}',
                                    ),
                              trailing: Text(
                                v.row.accuracy == null
                                    ? '–'
                                    : hifzPercent(context, v.row.accuracy!),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        if (data.slips.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          HifzHeading(l.sessionSlips),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final s in data.slips)
                                QuranWordChip(
                                  word: s.$2,
                                  place: verseSpan(context, surahs, s.$1, s.$1),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static String _strictness(AppLocalizations l, String s) => switch (s) {
    'strict' => l.tasmeeStrict,
    'lenient' => l.tasmeeLenient,
    _ => l.tasmeeMedium,
  };
}

/// A word of the Quran exactly as content.db has it, with its place.
class QuranWordChip extends StatelessWidget {
  const QuranWordChip({super.key, required this.word, required this.place});

  final String word;
  final String place;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: t.paper,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            word,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'UthmanicHafs',
              fontSize: 24,
              height: 1.6,
              color: t.ink,
            ),
          ),
          Text(place, style: TextStyle(color: t.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

typedef _VerseLine = ({RecitationVerseRow row, ({int surah, int ayah}) key});

final _sessionProvider = FutureProvider.autoDispose
    .family<
      ({
        RecitationSessionRow session,
        List<_VerseLine> verses,
        List<(({int surah, int ayah}), String)> slips,
      })?,
      String
    >((ref, uuid) async {
      final db = ref.watch(userDatabaseProvider);
      final s = await db.recitation(uuid);
      if (s == null) return null;
      final repo = ref.watch(hifzRepositoryProvider);
      final verses = <_VerseLine>[];
      for (final v in await db.versesOfRecitation(uuid)) {
        final a = await repo.ayahById(v.verse);
        verses.add((row: v, key: (surah: a.surah, ayah: a.number)));
      }
      final slips = <(({int surah, int ayah}), String)>[];
      for (final w in await db.slipsOfRecitation(uuid)) {
        final a = await repo.ayahById(w.verse);
        final words = verseWords(a);
        if (w.word < 1 || w.word > words.length) continue;
        slips.add(((surah: a.surah, ayah: a.number), words[w.word - 1]));
      }
      return (session: s, verses: verses, slips: slips);
    });

// -- الكلمات الصعبة -----------------------------------------------------------

/// Words slipped on more than once, most often first, their text read
/// from content.db by their place.
class HardWordsTab extends ConsumerWidget {
  const HardWordsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = context.tokens.colors;
    final hard = ref.watch(hardWordsProvider).value;
    final surahs = ref.watch(surahsProvider).value;
    if (hard == null) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        if (hard.isEmpty)
          _Empty(l.hardWordsEmpty)
        else ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l.hardWordsHint,
              style: TextStyle(color: t.muted, fontSize: 13),
            ),
          ),
          for (final h in hard)
            Card(
              child: ListTile(
                title: Consumer(
                  builder: (context, ref, _) {
                    final a = ref.watch(_ayahProvider(h.verse)).value;
                    final words = a == null ? const <String>[] : verseWords(a);
                    final text = h.word >= 1 && h.word <= words.length
                        ? words[h.word - 1]
                        : '';
                    return Text(
                      text,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: 'UthmanicHafs',
                        fontSize: 26,
                        height: 1.6,
                        color: t.ink,
                      ),
                    );
                  },
                ),
                subtitle: Consumer(
                  builder: (context, ref, _) {
                    final a = ref.watch(_ayahProvider(h.verse)).value;
                    final place = a == null
                        ? ''
                        : verseSpan(
                            context,
                            surahs,
                            (surah: a.surah, ayah: a.number),
                            (surah: a.surah, ayah: a.number),
                          );
                    return Text(
                      '$place\n${l.hardWordsCount(h.count, _n(context, h.count), _day(context, h.last))}',
                    );
                  },
                ),
                isThreeLine: true,
                trailing: IconButton(
                  tooltip: l.goalRecite,
                  icon: const Icon(Icons.visibility_off_outlined),
                  onPressed: () async {
                    final a = await ref
                        .read(hifzRepositoryProvider)
                        .ayahById(h.verse);
                    if (!context.mounted) return;
                    final r = '${a.surah}:${a.number}';
                    await openHifzTest(
                      context,
                      ref,
                      kind: HifzUnitKind.page,
                      fromRef: r,
                      toRef: r,
                    );
                  },
                ),
              ),
            ),
        ],
      ],
    );
  }
}

final _ayahProvider = FutureProvider.autoDispose.family<AyahRow, int>(
  (ref, id) => ref.watch(hifzRepositoryProvider).ayahById(id),
);
