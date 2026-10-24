// Memorization mode (hidden words): its bar and its hiding-style sheet.

part of 'mushaf_screen.dart';

String _maskStyleLabel(AppLocalizations l, MaskStyle s) => switch (s) {
  MaskStyle.all => l.memorizeStyleAll,
  MaskStyle.firstLetter => l.memorizeStyleFirstLetter,
  MaskStyle.firstWord => l.memorizeStyleFirstWord,
  MaskStyle.alternate => l.memorizeStyleAlternate,
  MaskStyle.progressive => l.memorizeStyleProgressive,
};

/// What reveal by reciting can do here.
enum _VoiceState {
  /// The model is on the device and the edition is a Hafs one.
  available,

  /// The tasmee model is not downloaded.
  needsModel,

  /// A riwaya edition: the tasmee knows the Hafs words only.
  edition,
}

/// Memorization mode's bar: the verse being memorized, the self-check,
/// and the reveal tools.
class _MemorizeBar extends StatelessWidget {
  const _MemorizeBar({
    required this.verse,
    required this.result,
    required this.note,
    required this.style,
    required this.listening,
    required this.onRevealVerse,
    required this.onRevealAll,
    required this.onHideAll,
    required this.onRepeat,
    required this.onMastered,
    required this.onMissed,
    required this.onStyles,
    required this.onVoice,
    required this.onClose,
  });

  /// The verse being memorized, named; null before the first reveal.
  final String? verse;
  final VerseResult? result;

  /// A hint, the progressive step, or why words are hidden whole.
  final String note;
  final MaskStyle style;

  /// Reveal by reciting is on; null: not offered (see the styles sheet).
  final bool? listening;
  final VoidCallback onRevealVerse;
  final VoidCallback onRevealAll;
  final VoidCallback onHideAll;
  final VoidCallback onRepeat;
  final VoidCallback? onMastered;
  final VoidCallback? onMissed;
  final VoidCallback onStyles;
  final VoidCallback? onVoice;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens.colors;
    final elderly = context.tokens.elderly;
    final tools = <(IconData, String, VoidCallback?, bool)>[
      (Icons.visibility_outlined, l.memorizeRevealAll, onRevealAll, false),
      (Icons.visibility_off_outlined, l.memorizeHideAll, onHideAll, false),
      (Icons.replay, l.memorizeRepeat, onRepeat, false),
      if (listening != null)
        (
          listening! ? Icons.mic : Icons.mic_none,
          l.memorizeByVoice,
          onVoice,
          listening!,
        ),
      (Icons.tune, l.memorizeStyleTitle, onStyles, false),
      (Icons.close, l.memorizeClose, onClose, false),
    ];
    return Material(
      color: t.paper,
      elevation: 6,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 6, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              liveRegion: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (verse != null)
                    Text(
                      verse!,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  Text(note, style: TextStyle(fontSize: 12, color: t.muted)),
                ],
              ),
            ),
            if (verse != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _JudgeButton(
                      label: l.memorizeMastered,
                      icon: Icons.check,
                      chosen: result == VerseResult.remembered,
                      onPressed: onMastered,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _JudgeButton(
                      label: l.memorizeMissed,
                      icon: Icons.close,
                      chosen: result == VerseResult.missed,
                      onPressed: onMissed,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
            ],
            const SizedBox(height: 6),
            if (elderly)
              // Elderly mode: every tool with its name.
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  FilledButton.icon(
                    onPressed: onRevealVerse,
                    icon: const Icon(Icons.visibility),
                    label: Text(l.memorizeRevealVerse),
                  ),
                  for (final (icon, label, onTap, on) in tools)
                    Semantics(
                      toggled: icon == Icons.mic || icon == Icons.mic_none
                          ? on
                          : null,
                      child: FilledButton.tonalIcon(
                        onPressed: onTap,
                        icon: Icon(icon),
                        label: Text(label),
                      ),
                    ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: onRevealVerse,
                      child: Text(l.memorizeRevealVerse),
                    ),
                  ),
                  for (final (icon, label, onTap, on) in tools)
                    IconButton(
                      tooltip: label,
                      isSelected: on,
                      onPressed: onTap,
                      icon: Icon(icon),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// The hiding styles and reveal by reciting; the choice is kept.
class _MemorizeStylesSheet extends ConsumerWidget {
  const _MemorizeStylesSheet({required this.voice, required this.onStyle});

  final _VoiceState voice;
  final ValueChanged<MaskStyle> onStyle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = context.tokens.colors;
    final prefs = ref.watch(memorizePrefsProvider);
    final notifier = ref.read(memorizePrefsProvider.notifier);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                l.memorizeStyleTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            RadioGroup<MaskStyle>(
              groupValue: prefs.style,
              onChanged: (s) {
                if (s == null) return;
                notifier.setStyle(s);
                onStyle(s);
              },
              child: Column(
                children: [
                  for (final s in MaskStyle.values)
                    RadioListTile<MaskStyle>(
                      value: s,
                      title: Text(_maskStyleLabel(l, s)),
                    ),
                ],
              ),
            ),
            const Divider(),
            switch (voice) {
              _VoiceState.available => SwitchListTile(
                value: prefs.byVoice,
                onChanged: notifier.setByVoice,
                secondary: const Icon(Icons.mic_none),
                title: Text(l.memorizeByVoice),
                subtitle: Text(l.memorizeByVoiceHint),
              ),
              _VoiceState.needsModel => ListTile(
                leading: Icon(Icons.mic_off_outlined, color: t.muted),
                title: Text(l.memorizeByVoice),
                subtitle: Text(l.memorizeVoiceNeedsModel),
                trailing: const Icon(Icons.download_outlined),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/settings/tasmee');
                },
              ),
              _VoiceState.edition => ListTile(
                leading: Icon(Icons.mic_off_outlined, color: t.muted),
                title: Text(l.memorizeByVoice),
                subtitle: Text(l.memorizeVoiceEdition),
                enabled: false,
              ),
            },
          ],
        ),
      ),
    );
  }
}
