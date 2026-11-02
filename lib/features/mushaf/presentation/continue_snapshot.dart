import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/settings/settings_controller.dart';
import '../data/compiled_svg.dart';
import '../mushaf_providers.dart';
import 'widgets/image_page.dart';
import 'widgets/mushaf_page.dart' show markersOnly;
import 'widgets/old_mushaf_page.dart';
import 'widgets/shamarly_page.dart';

/// What a picture of the mushaf's last page was taken of: the same page of
/// the same edition, drawn the same way, in a window of the same size. A
/// picture is shown for «متابعة القراءة» only when every part matches, so it
/// never stands in for another page, look or size.
@immutable
class SnapshotKey {
  const SnapshotKey({
    required this.edition,
    required this.page,
    required this.look,
    required this.landscape,
    required this.width,
    required this.height,
  });

  /// The key for [page] of [edition] as [context]'s window and [settings]
  /// show it now.
  factory SnapshotKey.of(
    BuildContext context,
    AppSettings settings,
    MushafEdition edition,
    int page,
  ) {
    final size = MediaQuery.sizeOf(context);
    return SnapshotKey(
      edition: edition.name,
      page: page,
      look: snapshotLook(settings, MediaQuery.platformBrightnessOf(context)),
      landscape: size.width > size.height,
      width: size.width.round(),
      height: size.height.round(),
    );
  }

  final String edition;
  final int page;

  /// Theme, colour mode, frame and everything else drawn on the page.
  final String look;
  final bool landscape;
  final int width;
  final int height;

  Map<String, Object> toJson() => {
    'edition': edition,
    'page': page,
    'look': look,
    'landscape': landscape,
    'width': width,
    'height': height,
  };

  static SnapshotKey? fromJson(Object? json) {
    if (json is! Map) return null;
    final edition = json['edition'];
    final page = json['page'];
    final look = json['look'];
    final landscape = json['landscape'];
    final width = json['width'];
    final height = json['height'];
    if (edition is! String ||
        page is! int ||
        look is! String ||
        landscape is! bool ||
        width is! int ||
        height is! int) {
      return null;
    }
    return SnapshotKey(
      edition: edition,
      page: page,
      look: look,
      landscape: landscape,
      width: width,
      height: height,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SnapshotKey &&
      other.edition == edition &&
      other.page == page &&
      other.look == look &&
      other.landscape == landscape &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode =>
      Object.hash(edition, page, look, landscape, width, height);

  @override
  String toString() =>
      'SnapshotKey($edition p$page ${width}x$height '
      '${landscape ? 'landscape' : 'portrait'} $look)';
}

/// The settings that change how a page looks, in one string: a picture
/// taken under other ones is not used.
String snapshotLook(AppSettings s, Brightness platform) => [
  s.styleId,
  s.interfaceStyle.name,
  s.mode.name,
  platform.name,
  s.pageFill.name,
  s.markerStyle.name,
  s.markerTint ?? '',
  s.tajweedColors,
  s.highlightDivineNames,
  s.twoPageSpread,
  s.landscapeFit.name,
  s.focusMode,
  s.elderlyMode,
  s.fasilStyle?.name ?? '',
  s.fasilPlace.name,
  s.fasilMaterial.name,
].join('|');

/// The picture of the page the mushaf was left on, kept in the app's cache
/// folder (private, never synced or uploaded) and in memory, decoded, so
/// «متابعة القراءة» can show it in the very first frame.
///
/// One picture only: a new one replaces the old.
class ContinueSnapshots {
  ContinueSnapshots(this._folder);

  final Future<Directory> Function() _folder;

  static const _imageName = 'continue_page.png';
  static const _keyName = 'continue_page.json';

  /// Pictures are taken at this pixel ratio at most: enough to stand in
  /// for the page for a moment, and a few MB in memory.
  static const maxPixelRatio = 1.5;

  SnapshotKey? _key;
  ui.Image? _image;
  SnapshotKey? _armed;
  Future<void>? _loading;

  /// Where the «متابعة القراءة» tap came from, in global coordinates: the
  /// page grows from there.
  Rect? origin;

  /// The picture's key, if one is held.
  SnapshotKey? get key => _key;

  /// Reads the saved picture once (at launch).
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final dir = await _folder();
      final keyFile = File(p.join(dir.path, _keyName));
      final imageFile = File(p.join(dir.path, _imageName));
      if (!keyFile.existsSync() || !imageFile.existsSync()) return;
      final key = SnapshotKey.fromJson(
        jsonDecode(await keyFile.readAsString()),
      );
      if (key == null || _key != null) return;
      final codec = await ui.instantiateImageCodec(
        await imageFile.readAsBytes(),
      );
      final image = (await codec.getNextFrame()).image;
      codec.dispose();
      if (_key != null) {
        image.dispose(); // a newer one was taken meanwhile
        return;
      }
      _key = key;
      _image = image;
    } on Object catch (e) {
      debugPrint('ContinueSnapshots: no saved page ($e)');
    }
  }

  /// The picture for [key], or null when the one held is of anything else.
  ui.Image? match(SnapshotKey key) => key == _key ? _image : null;

  /// The home screen is opening the mushaf at [key]'s page: the mushaf may
  /// show the picture while it opens. Nothing is armed when it does not
  /// match.
  void arm(SnapshotKey? key, {Rect? from}) {
    origin = from;
    _armed = key != null && match(key) != null ? key : null;
  }

  /// The armed picture, for the mushaf opening (it clones it); null when
  /// none.
  (SnapshotKey, ui.Image)? get armed {
    final k = _armed;
    final image = k == null ? null : match(k);
    return k == null || image == null ? null : (k, image);
  }

  void disarm() => _armed = null;

  /// Keeps [image] (owned from here) as the picture of [key], in memory at
  /// once and on disk soon after.
  Future<void> save(SnapshotKey key, ui.Image image) async {
    final old = _image;
    _key = key;
    _image = image;
    old?.dispose();
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null || _key != key) return;
      final dir = await _folder();
      await dir.create(recursive: true);
      await File(p.join(dir.path, _imageName))
          .writeAsBytes(data.buffer.asUint8List(), flush: true);
      await File(p.join(dir.path, _keyName))
          .writeAsString(jsonEncode(key.toJson()), flush: true);
    } on Object catch (e) {
      debugPrint('ContinueSnapshots: not saved ($e)');
    }
  }
}

final continueSnapshotsProvider = Provider<ContinueSnapshots>((ref) {
  final store = ContinueSnapshots(
    () async => Directory(
      p.join((await getApplicationCacheDirectory()).path, 'continue'),
    ),
  );
  unawaited(store.load());
  return store;
});

/// Takes a picture of [boundary] for [key] and keeps it in [store]. Quiet
/// when the boundary cannot be pictured now (not laid out, not painted).
void captureContinueSnapshot(
  ContinueSnapshots store,
  SnapshotKey key,
  RenderRepaintBoundary? boundary,
  double devicePixelRatio,
) {
  if (boundary == null || !boundary.attached || !boundary.hasSize) return;
  try {
    final ratio = devicePixelRatio.clamp(1.0, ContinueSnapshots.maxPixelRatio);
    final image = boundary.toImageSync(pixelRatio: ratio);
    unawaited(store.save(key, image));
  } on Object catch (e) {
    debugPrint('ContinueSnapshots: no picture ($e)');
  }
}

/// Opens the mushaf from the home screen's «متابعة القراءة» ([from] is the
/// card or button tapped): arms the saved picture when it is of the page
/// the reading continues at, and notes where the page grows from.
void openContinueReading(BuildContext from, WidgetRef ref, VoidCallback go) {
  final store = ref.read(continueSnapshotsProvider);
  final position = ref.read(readingPositionProvider).value;
  final edition = ref.read(editionProvider);
  final box = from.findRenderObject();
  final origin = box is RenderBox && box.hasSize && box.attached
      ? box.localToGlobal(Offset.zero) & box.size
      : null;
  final page = position == null
      ? 1
      : position.edition == edition.name
      ? position.page
      : null;
  store.arm(
    page == null
        ? null
        : SnapshotKey.of(from, ref.read(settingsProvider), edition, page),
    from: origin,
  );
  go();
}

/// The mushaf's entrance from «متابعة القراءة»: the page grows from the
/// card tapped into the whole screen; with reduced motion, it fades in.
class ContinueTransition extends StatelessWidget {
  const ContinueTransition({
    super.key,
    required this.animation,
    required this.origin,
    required this.child,
  });

  final Animation<double> animation;

  /// Where the page grows from, in global coordinates; null fades.
  final Rect? origin;
  final Widget child;

  static const duration = Duration(milliseconds: 360);

  @override
  Widget build(BuildContext context) {
    final from = origin;
    if (MediaQuery.disableAnimationsOf(context) || from == null) {
      return FadeTransition(opacity: animation, child: child);
    }
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final t = animation.value;
        if (t >= 1) return child!;
        final c = Curves.easeOutCubic.transform(t);
        final size = MediaQuery.sizeOf(context);
        final rect = Rect.lerp(from, Offset.zero & size, c)!;
        return Stack(
          children: [
            // Absolute rectangles: the same in either reading direction.
            Positioned.fromRect(
              rect: rect,
              child: Opacity(
                opacity: (t * 3).clamp(0.0, 1.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16 * (1 - c)),
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox.fromSize(size: size, child: child),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Prepares the page «متابعة القراءة» opens, and its two neighbours, while
/// the home screen is idle: the page's text and geometry, its artwork
/// compiled (the new editions) or its picture decoded (1405, Shamarly).
/// The page first, the neighbours after, one per idle slot (so a slow
/// device has its page before anything else); a new target (another page,
/// edition or look) drops what is left of the old one.
class ContinuePrewarm extends ConsumerStatefulWidget {
  const ContinuePrewarm({super.key, required this.child, this.warm});

  final Widget child;

  /// Prepares one page; [warmMushafPage] unless a test passes its own.
  final Future<void> Function(WidgetRef ref, MushafEdition edition, int page)?
  warm;

  @override
  ConsumerState<ContinuePrewarm> createState() => ContinuePrewarmState();
}

@visibleForTesting
class ContinuePrewarmState extends ConsumerState<ContinuePrewarm> {
  Object? _target;
  int _generation = 0;
  bool _framed = false;

  /// The target being prepared (tests).
  @visibleForTesting
  Object? get target => _target;

  @override
  void initState() {
    super.initState();
    // After the home screen's first frame: nothing competes with it.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _framed = true;
      _retarget();
    });
  }

  @override
  void dispose() {
    _generation++; // drops whatever is still queued
    super.dispose();
  }

  void _retarget() {
    if (!mounted || !_framed) return;
    final position = ref.read(readingPositionProvider);
    if (position.isLoading) return;
    final edition = ref.read(editionProvider);
    final saved = position.value;
    final page = saved == null
        ? 1
        : saved.edition == edition.name
        ? saved.page
        : null;
    if (page == null) return;
    final look = snapshotLook(
      ref.read(settingsProvider),
      MediaQuery.platformBrightnessOf(context),
    );
    final target = (edition, page, look);
    if (target == _target) return;
    _target = target;
    final generation = ++_generation;
    unawaited(_run(generation, edition, page));
  }

  Future<void> _run(int generation, MushafEdition edition, int page) async {
    final warm = widget.warm ?? warmMushafPage;
    for (final pg in [page, page + 1, page - 1]) {
      if (pg < 1 || pg > edition.pageCount) continue;
      // One page per idle slot, so a frame never waits on the work.
      await SchedulerBinding.instance.scheduleTask<void>(() {}, Priority.idle);
      if (!mounted || generation != _generation) return;
      try {
        await warm(ref, edition, pg);
      } on Object catch (e) {
        debugPrint('ContinuePrewarm: page $pg not prepared ($e)');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(readingPositionProvider, (_, _) => _retarget());
    ref.listen(editionProvider, (_, _) => _retarget());
    ref.listen(
      settingsProvider.select(
        (s) => snapshotLook(s, MediaQuery.platformBrightnessOf(context)),
      ),
      (_, _) => _retarget(),
    );
    // The saved picture is read early, for the first tap.
    ref.read(continueSnapshotsProvider);
    return widget.child;
  }
}

/// Prepares [page] of [edition] for the mushaf to open at.
Future<void> warmMushafPage(
  WidgetRef ref,
  MushafEdition edition,
  int page,
) async {
  final common = (
    ref.read(pageAyahsProvider(page).future),
    ref.read(frameInfoProvider(page).future),
  ).wait;
  switch (edition) {
    case MushafEdition.madina1405:
      await ImageMushafPage.warm(
        loadOldPage,
        page,
        () => loadOldPage(ref, page),
      );
    case MushafEdition.shamarly:
      await ImageMushafPage.warm(
        loadShamarlyPage,
        page,
        () => loadShamarlyPage(ref, page),
      );
    default:
      final svg = await ref.read(pageStoreProvider).svg(page);
      await (
        SvgCompiler.prewarm(svg, 'page $page'),
        SvgCompiler.prewarm(markersOnly(svg), 'page $page markers'),
        ref.read(svgPageGeometryProvider(page).future),
      ).wait;
  }
  await common;
}
