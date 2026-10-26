import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/recitation.dart';
import '../mushaf_providers.dart';
import 'widgets/mushaf_page.dart';
import 'widgets/page_interaction.dart';

/// A mushaf page with the recitation drawn on it: the verse being recited
/// highlighted (when [followVerse]: no selection of the reader's own) and
/// its word. Only this layer follows the recitation, so the screen around
/// the page is not built again for every word.
class RecitedPage extends ConsumerWidget {
  const RecitedPage({
    super.key,
    required this.page,
    required this.interaction,
    required this.followVerse,
    required this.builder,
  });

  /// How many times a page was built for the recitation; for tests.
  @visibleForTesting
  static int debugBuildCount = 0;

  final int page;
  final PageInteraction interaction;
  final bool followVerse;

  /// The page itself, with [interaction] as the recitation leaves it.
  final Widget Function(PageInteraction interaction) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    debugBuildCount++;
    final r = ref.watch(
      recitationProvider.select(
        (r) => (active: r.active, surah: r.surah, ayah: r.ayah, word: r.word),
      ),
    );
    final ayah = r.ayah;
    if (!r.active || ayah == null) return builder(interaction);
    final word = r.word;
    final boxes = ref.watch(pageWordBoxesProvider(page)).value;
    final pieces = word == null ? null : boxes?[(r.surah, ayah, word)];
    final activeWord = pieces?.reduce((a, b) => a.expandToInclude(b));
    // Without word timings, the verse as a whole is followed.
    final verse = [
      for (final e
          in boxes?.entries ?? const <MapEntry<(int, int, int), List<Rect>>>[])
        if (e.key.$1 == r.surah && e.key.$2 == ayah) ...e.value,
    ];
    return builder(
      interaction.recited(
        selection: followVerse
            ? <VerseKey>{(surah: r.surah, ayah: ayah)}
            : interaction.selection,
        activeWord: activeWord,
        follow:
            activeWord ??
            (verse.isEmpty
                ? null
                : verse.reduce((a, b) => a.expandToInclude(b))),
      ),
    );
  }
}
