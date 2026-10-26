import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/db/content_database.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../audio/recitation.dart';
import '../../core/settings/app_settings.dart';
import '../mushaf/mushaf_providers.dart';
import '../mushaf/presentation/widgets/illuminated_frame.dart';
import 'reel_maker.dart';
import 'reel_painter.dart';
import 'reel_timeline.dart';

/// The encoder the screen uses; tests put their own.
final reelEncoderProvider = Provider<ReelEncoder>(
  (ref) => const ChannelReelEncoder(),
);

/// Opens «مشاركة كمقطع فيديو» for the verses [range] (the first one's
/// surah; whole verses only).
Future<void> showShareVideo(
  BuildContext context,
  List<({int surah, int ayah})> range,
) {
  // The page's own look, for the frame drawn in the reel.
  final theme = Theme.of(context);
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => ShareVideoScreen(
        surah: range.first.surah,
        from: range.first.ayah,
        to: range.last.surah == range.first.surah
            ? range.last.ayah
            : range.first.ayah,
        pageTheme: theme,
      ),
    ),
  );
}

/// The verse texts of the reel (Arabic, whatever the interface language).
final AppLocalizations _ar = lookupAppLocalizations(const Locale('ar'));
final _digits = NumberFormatter(const Locale('ar'));

/// «الآية ٥» or «الآيات ١ إلى ٤».
String reelRangeLabel(int from, int to) => from == to
    ? _ar.reelVerse(_digits(from))
    : _ar.reelVerses(_digits(from), _digits(to));

/// The recitation's source as its host names it: «mp3quran.net».
String reelSource(String folderUrl) {
  final host = Uri.tryParse(folderUrl)?.host ?? '';
  final parts = host.split('.');
  return parts.length <= 2 ? host : parts.sublist(parts.length - 2).join('.');
}

enum _Phase { choose, audio, rendering, saving, done, failed }

class ShareVideoScreen extends ConsumerStatefulWidget {
  const ShareVideoScreen({
    super.key,
    required this.surah,
    required this.from,
    required this.to,
    this.pageTheme,
    this.onFinished,
    this.reciterId,
  });

  /// A reciter other than the reader's (tests).
  final int? reciterId;

  final int surah, from, to;
  final ThemeData? pageTheme;

  /// Called with the finished file instead of the share sheet, for tests.
  final void Function(String path)? onFinished;

  @override
  ConsumerState<ShareVideoScreen> createState() => _ShareVideoState();
}

class _ShareVideoState extends ConsumerState<ShareVideoScreen> {
  late int _from = widget.from, _to = widget.to;
  ReciterRow? _reciter;
  List<AyahRow> _ayahs = const [];
  List<VerseTime> _verses = const [];
  List<WordTime> _words = const [];
  bool _loading = true;
  _Phase _phase = _Phase.choose;
  double _progress = 0;
  bool _cancel = false;
  String? _error;
  String? _out;

  final _frameKey = GlobalKey();
  final _bannerKey = GlobalKey();

  static const _frameLogical = Size(404, 675);
  static const _bannerLogical = Size(340, 40);

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init() async {
    final repo = ref.read(mushafRepositoryProvider);
    var reciter = await ref.read(currentReciterProvider.future);
    if (widget.reciterId case final id?) {
      final all = await ref.read(recitersProvider.future);
      reciter = all.where((r) => r.id == id).firstOrNull ?? reciter;
    }
    final ayahs = await repo.ayahsOfSurah(widget.surah);
    if (!mounted) return;
    setState(() => _ayahs = ayahs);
    await _useReciter(reciter);
  }

  Future<void> _useReciter(ReciterRow? r) async {
    setState(() {
      _reciter = r;
      _loading = true;
    });
    if (r == null) return setState(() => _loading = false);
    final repo = ref.read(mushafRepositoryProvider);
    final times = await repo.timings(r.id, widget.surah);
    var words = await repo.wordTimings(r.id, widget.surah);
    if (words.isEmpty) {
      words =
          await (repo.fetchWordTimings(r.id, widget.surah) ??
              Future.value(words));
    }
    if (!mounted || _reciter != r) return;
    setState(() {
      _verses = [
        for (final t in times)
          (ayah: t.ayah, startMs: t.startMs, endMs: t.endMs),
      ];
      _words = [
        for (final w in words)
          (ayah: w.ayah, word: w.word, startMs: w.startMs, endMs: w.endMs),
      ];
      _loading = false;
    });
  }

  List<AyahRow> get _chosen => [
    for (final a in _ayahs)
      if (a.number >= _from && a.number <= _to) a,
  ];

  ReelTimeline? get _timeline => _verses.isEmpty
      ? null
      : ReelTimeline.build(
          first: _from,
          last: _to,
          verses: _verses,
          words: _words,
          wordCounts: {
            for (final a in _chosen)
              a.number: ReelVerse(
                number: a.number,
                displayText: a.displayText,
              ).words.length,
          },
        );

  Future<ui.Image> _capture(GlobalKey key, double ratio) async {
    final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    return b.toImage(pixelRatio: ratio);
  }

  Future<void> _make() async {
    final l = AppLocalizations.of(context);
    final tokens = (widget.pageTheme ?? Theme.of(context))
        .extension<TibyanTokens>()!;
    final tl = _timeline;
    final r = _reciter;
    if (tl == null || r == null) return;
    setState(() {
      _phase = _Phase.audio;
      _cancel = false;
      _progress = 0;
      _error = null;
    });
    try {
      final encoder = ref.read(reelEncoderProvider);
      if (!await encoder.available()) {
        throw _Failure(l.shareVideoUnsupported);
      }
      final files = ref.read(audioFilesProvider);
      if (!files.has(r.id, widget.surah)) {
        try {
          await files.download(r, widget.surah);
        } on Object {
          throw _Failure(l.shareVideoOffline);
        }
      }
      if (_cancel) throw ReelCancelled();
      final audio = files.file(r.id, widget.surah);
      // Android encodes on the processor: a smaller picture keeps it quick.
      final size = !kIsWeb && Platform.isAndroid
          ? const Size(720, 1280)
          : reelDesign;
      // The frame and banner as the reader's theme draws them, sharp at
      // the reel's page size (808 design pixels wide).
      final scale = size.width / reelDesign.width;
      final ratio = 808 * scale / _frameLogical.width;
      await ref.read(frameImagesProvider(tokens.colors.artTint).future);
      // The art drawn into the hidden frame (RasterFrame draws it after a
      // frame), then captured.
      for (var i = 0; i < 3; i++) {
        await WidgetsBinding.instance.endOfFrame;
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      final frame = await _capture(_frameKey, ratio);
      final banner = _from == 1 ? await _capture(_bannerKey, ratio) : null;
      final logo = await vg.loadPicture(
        const SvgAssetLoader('assets/brand/tibyan_logo.svg'),
        null,
      );
      final verses = [
        for (final a in _chosen)
          ReelVerse(number: a.number, displayText: a.displayText),
      ];
      final painter = ReelPainter(
        ReelContent(
          surah: widget.surah,
          verses: verses,
          heading: _ar.reelHeading,
          range: reelRangeLabel(_from, _to),
          voice: _ar.reelVoice(r.nameAr),
          credit: _ar.reelCredit(r.nameAr, reelSource(r.folderUrl)),
          join: _ar.reelJoin,
          url: 'altibyan.app',
          stores: 'Google Play  ·  App Store  ·  Mac',
          frame: frame,
          banner: banner,
          logo: logo.picture,
          logoSize: logo.size,
          paper: tokens.colors.paper,
        ),
        tl,
      );
      if (!mounted) return;
      setState(() => _phase = _Phase.rendering);
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/tibyan-${widget.surah}-$_from-$_to-${r.id}.mp4';
      final out = await makeReel(
        painter: painter,
        timeline: tl,
        encoder: encoder,
        path: path,
        size: size,
        audio: audio,
        onProgress: (p) {
          if (!mounted) return;
          setState(() {
            _progress = p;
            if (p >= 1) _phase = _Phase.saving;
          });
        },
        cancelled: () => _cancel || !mounted,
      );
      painter.dispose();
      frame.dispose();
      banner?.dispose();
      if (!mounted) return;
      setState(() {
        _phase = _Phase.done;
        _out = out;
      });
      await _share();
    } on ReelCancelled {
      if (mounted) setState(() => _phase = _Phase.choose);
    } on _Failure catch (e) {
      if (mounted) {
        setState(() {
          _phase = _Phase.failed;
          _error = e.message;
        });
      }
    } on Object catch (e) {
      debugPrint('share video: $e');
      if (mounted) {
        setState(() {
          _phase = _Phase.failed;
          _error = l.shareVideoFailed;
        });
      }
    }
  }

  Future<void> _share() async {
    final out = _out;
    if (out == null) return;
    if (widget.onFinished case final f?) return f(out);
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(out, mimeType: 'video/mp4')],
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final digits = NumberFormatter(Localizations.localeOf(context));
    final riwaya = ref.watch(editionProvider).isRiwaya;
    final reciters = ref.watch(recitersProvider).value ?? const [];
    final surahs = ref.watch(surahsProvider).value;
    final count = _ayahs.length;
    final tl = _timeline;
    final busy =
        _phase == _Phase.audio ||
        _phase == _Phase.rendering ||
        _phase == _Phase.saving;
    final pageTheme = widget.pageTheme ?? Theme.of(context);
    final sur = surahs?[widget.surah - 1];

    Widget body;
    if (riwaya) {
      body = _Note(l.shareVideoRiwaya);
    } else if (_loading || count == 0) {
      body = const Center(child: CircularProgressIndicator());
    } else if (busy) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(switch (_phase) {
                _Phase.audio => l.shareVideoAudio,
                _Phase.saving => l.shareVideoSaving,
                _ => l.shareVideoRendering(digits((_progress * 100).floor())),
              }, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: _phase == _Phase.rendering ? _progress : null,
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => setState(() => _cancel = true),
                child: Text(
                  MaterialLocalizations.of(context).cancelButtonLabel,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      final ayahItems = [
        for (var a = 1; a <= count; a++)
          DropdownMenuItem(value: a, child: Text(digits(a))),
      ];
      body = ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (sur != null)
            Text(
              l.surahWord(sur.nameAr),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _from,
                  decoration: InputDecoration(labelText: l.shareVideoFrom),
                  items: ayahItems,
                  onChanged: (v) => setState(() {
                    _from = v!;
                    if (_to < _from) _to = _from;
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  key: ValueKey(_to),
                  initialValue: _to,
                  decoration: InputDecoration(labelText: l.shareVideoTo),
                  items: [
                    for (final i in ayahItems)
                      if (i.value! >= _from) i,
                  ],
                  onChanged: (v) => setState(() => _to = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _reciter?.id,
            decoration: InputDecoration(labelText: l.shareVideoReciter),
            isExpanded: true,
            items: [
              for (final r in reciters)
                DropdownMenuItem(
                  value: r.id,
                  child: Text(
                    Localizations.localeOf(context).languageCode == 'ar'
                        ? r.nameAr
                        : r.nameEn,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (id) =>
                _useReciter(reciters.firstWhere((r) => r.id == id)),
          ),
          const SizedBox(height: 16),
          if (tl == null)
            _Note(l.shareVideoNoTimings)
          else ...[
            Text(l.shareVideoLength(digits(tl.total.ceil()))),
            const SizedBox(height: 4),
            Text(tl.wordLevel ? l.shareVideoWordsNote : l.shareVideoAyahNote),
            if (tl.tooLong) ...[
              const SizedBox(height: 8),
              Text(
                l.shareVideoTooLong(digits(ReelTiming.maxLength.round())),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
          if (_phase == _Phase.failed && _error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: tl == null || tl.tooLong ? null : _make,
            icon: const Icon(Icons.movie_creation_outlined),
            label: Text(l.shareVideoMake),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          if (_phase == _Phase.done && _out != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _share,
              icon: const Icon(Icons.ios_share),
              label: Text(l.shareVideoShare),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ],
      );
    }

    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(title: Text(l.shareVideoTitle)),
        body: Stack(
          children: [
            // The page's frame and the surah's banner as the reader's
            // theme draws them, captured for the reel; hidden under the
            // screen.
            if (!riwaya && sur != null)
              Positioned(
                left: 0,
                top: 0,
                child: ExcludeSemantics(
                  child: IgnorePointer(
                    child: Theme(
                      data: pageTheme,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RepaintBoundary(
                            key: _frameKey,
                            child: SizedBox.fromSize(
                              size: _frameLogical,
                              child: const IlluminatedFrame(
                                info: null,
                                child: SizedBox.expand(),
                              ),
                            ),
                          ),
                          RepaintBoundary(
                            key: _bannerKey,
                            child: SizedBox.fromSize(
                              size: _bannerLogical,
                              child: _Banner(surahs: surahs!, surah: sur.id),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              child: ColoredBox(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends ConsumerWidget {
  const _Banner({required this.surahs, required this.surah});
  final List<SurahRow> surahs;
  final int surah;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = surahs[surah - 1];
    final before = surahs
        .where((x) => x.revelationOrder == s.revelationOrder - 1)
        .firstOrNull;
    final images = ref
        .watch(frameImagesProvider(context.tokens.colors.artTint))
        .value;
    return SurahBannerView(
      banner: SurahBanner(
        line: 0,
        number: s.id,
        name: s.nameAr,
        meccan: s.revelation == 'meccan',
        ayahCount: s.ayahCount,
        order: s.revelationOrder,
        after: before?.nameAr,
      ),
      images: images,
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Text(text, textAlign: TextAlign.center),
  );
}

class _Failure implements Exception {
  _Failure(this.message);
  final String message;
}
