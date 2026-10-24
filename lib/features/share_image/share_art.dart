import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/app_settings.dart';
import '../mushaf/data/compiled_svg.dart';
import '../mushaf/data/mushaf_repository.dart';
import '../mushaf/mushaf_providers.dart';
import '../mushaf/presentation/widgets/image_page.dart';
import '../mushaf/presentation/widgets/old_mushaf_page.dart';
import '../mushaf/presentation/widgets/shamarly_page.dart';
import 'share_layout.dart' show MushafPlace;
import 'share_source.dart';

/// One picture of a passage shared as its mushaf's own pages: page [page]
/// of the edition being read, cut to [crop] (page units: the SVG's viewBox,
/// or the page image's pixels), under the header of [surah].
class ShareArtPage {
  const ShareArtPage({
    required this.page,
    required this.surah,
    required this.crop,
    required this.render,
  });

  final int page;
  final int surah;
  final Rect crop;

  /// Draws the page's [crop] on [paper], [width] pixels wide.
  final Future<ui.Image> Function(double width, Color paper) render;
}

/// The part of a page that holds [lines] (indexes into [tops] and
/// [bottoms], the bands the page view splits the page into): from the top
/// of the first line's band to the bottom of the last one's, across
/// [page]. The bands meet at the cuts between lines (the rows with least
/// ink), so no line is ever cut through. All the lines, or none known:
/// the whole of [page].
Rect linesCrop({
  required Rect page,
  required List<double> tops,
  required List<double> bottoms,
  required Iterable<int> lines,
}) {
  final n = tops.length;
  final kept = {
    for (final l in lines)
      if (l >= 0 && l < n) l,
  };
  if (kept.isEmpty || kept.length == n) return page;
  final first = kept.reduce((a, b) => a < b ? a : b);
  final last = kept.reduce((a, b) => a > b ? a : b);
  return Rect.fromLTRB(
    page.left,
    first == 0 ? page.top : tops[first],
    page.right,
    last == n - 1 ? page.bottom : bottoms[last],
  );
}

/// The bands of a page split at [cuts] (top to bottom), inside [page].
({List<double> tops, List<double> bottoms}) bandsOfCuts(
  Rect page,
  List<double> cuts,
) => (tops: [page.top, ...cuts], bottoms: [...cuts, page.bottom]);

/// The line of [y] among bands [tops]..[bottoms]: the band holding it, or
/// the nearest one.
int lineOfY(double y, List<double> tops, List<double> bottoms) {
  var best = 0;
  var bestD = double.infinity;
  for (var j = 0; j < tops.length; j++) {
    if (y >= tops[j] && y < bottoms[j]) return j;
    final d = y < tops[j] ? tops[j] - y : y - bottoms[j];
    if (d < bestD) {
      bestD = d;
      best = j;
    }
  }
  return best;
}

/// The pages of [places] (word → page and line), in order, each with the
/// lines that hold the passage's words and the surah of its first word.
List<({int page, Set<int> lines, int surah})> pagesOfPlaces(
  Map<(int, int, int), MushafPlace> places,
) {
  final keys = places.keys.toList()
    ..sort((a, b) {
      final s = a.$1.compareTo(b.$1);
      if (s != 0) return s;
      final v = a.$2.compareTo(b.$2);
      return v != 0 ? v : a.$3.compareTo(b.$3);
    });
  final out = <int, ({int page, Set<int> lines, int surah})>{};
  for (final k in keys) {
    final p = places[k]!;
    (out[p.page] ??= (
      page: p.page,
      lines: <int>{},
      surah: k.$1,
    )).lines.add(p.line);
  }
  return [for (final k in out.keys.toList()..sort()) out[k]!];
}

Rect _viewBoxOf(String svg) {
  final m = RegExp(r'viewBox="([\d.\s-]+)"').firstMatch(svg);
  if (m == null) return const Rect.fromLTWH(0, 0, 345, 550);
  final v = m.group(1)!.trim().split(RegExp(r'\s+')).map(double.parse).toList();
  return Rect.fromLTWH(v[0], v[1], v[2], v[3]);
}

Future<ui.Image> _draw(
  Rect crop,
  double width,
  Color paper,
  void Function(Canvas canvas) paint,
) async {
  final scale = width / crop.width;
  final w = width.round(), h = (crop.height * scale).round();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawRect(
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..color = paper,
    )
    ..scale(scale)
    ..translate(-crop.left, -crop.top);
  paint(canvas);
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(w, h);
  } finally {
    picture.dispose();
  }
}

/// The pages of [range] (numbered as in the edition being read) in the
/// edition's own artwork, each cut to the lines the passage holds; null
/// when the edition's pages are not on the device or the places of the
/// passage are not known, so the caller shares the text instead.
Future<List<ShareArtPage>?> shareArtPages(
  WidgetRef ref,
  ShareRange range,
) async {
  if (range.isEmpty || !ref.read(pagesInstalledProvider)) return null;
  final edition = ref.read(editionProvider);
  switch (edition) {
    case MushafEdition.madina1405:
      return _imagePages(ref, range, edition, loadOldPage);
    case MushafEdition.shamarly:
      return _imagePages(ref, range, edition, loadShamarlyPage);
    default:
      return _svgPages(ref, range, edition);
  }
}

Future<List<ShareArtPage>?> _svgPages(
  WidgetRef ref,
  ShareRange range,
  MushafEdition edition,
) async {
  final Map<(int, int, int), MushafPlace>? places;
  if (edition.isRiwaya) {
    final data = await ref.read(riwayaDataProvider.future);
    places = data == null ? null : riwayaMushafPlaces(data, range);
  } else {
    places = await hafsMushafPlaces(ref.read(mushafRepositoryProvider), range);
  }
  if (places == null || places.isEmpty) return null;
  // The words of the verses on each side were read too, for the words at
  // the passage's edges: they are not shared.
  final keys = {for (final k in range) (k.surah, k.ayah)};
  final ours = {
    for (final e in places.entries)
      if (keys.contains((e.key.$1, e.key.$2))) e.key: e.value,
  };
  if (ours.isEmpty) return null;
  final firstOfSurah = {
    for (final e in ours.keys)
      if (e.$2 == 1 && e.$3 == 1) ours[e]!.page: e.$1,
  };
  final store = ref.read(pageStoreProvider);
  final out = <ShareArtPage>[];
  for (final p in pagesOfPlaces(ours)) {
    final svg = await store.svg(p.page);
    final geometry = await ref.read(svgPageGeometryProvider(p.page).future);
    final box = _viewBoxOf(svg);
    final bands = bandsOfCuts(box, geometry.cuts);
    // A surah opening on this page: its printed title (and basmala, but
    // at-Tawba has none) stand on the lines above its first verse.
    final lines = {...p.lines};
    if (firstOfSurah[p.page] case final s?) {
      final top = lines.reduce((a, b) => a < b ? a : b);
      for (var l = top - (s == 9 ? 1 : 2); l < top; l++) {
        if (l >= 0) lines.add(l);
      }
    }
    final crop = geometry.cuts.isEmpty
        ? box
        : linesCrop(
            page: box,
            tops: bands.tops,
            bottoms: bands.bottoms,
            lines: lines,
          );
    out.add(
      ShareArtPage(
        page: p.page,
        surah: p.surah,
        crop: crop,
        render: (width, paper) async {
          final info = await compiledSvgPicture(
            await store.svg(p.page),
            name: 'share ${p.page}',
          );
          try {
            return await _draw(crop, width, paper, (c) {
              // The picture starts at the viewBox corner.
              c
                ..translate(box.left, box.top)
                ..drawPicture(info.picture);
            });
          } finally {
            info.picture.dispose();
          }
        },
      ),
    );
  }
  return out;
}

Future<List<ShareArtPage>?> _imagePages(
  WidgetRef ref,
  ShareRange range,
  MushafEdition edition,
  Future<ImagePageData> Function(WidgetRef ref, int page) load,
) async {
  final repo = ref.read(mushafRepositoryProvider);
  final keys = {for (final k in range) (k.surah, k.ayah)};
  final surahs = {for (final k in range) k.surah};
  var first = edition.pageCount, last = 1;
  for (final s in surahs) {
    for (final a in await repo.ayahsOfSurah(s)) {
      if (!keys.contains((s, a.number))) continue;
      final page = a.pageIn(edition);
      if (page < first) first = page;
      if (page > last) last = page;
    }
  }
  if (first > last) return null;
  // The last verse may run on to the next page.
  last = last < edition.pageCount ? last + 1 : last;
  final out = <ShareArtPage>[];
  for (var page = first; page <= last; page++) {
    final ImagePageData data;
    try {
      data = await load(ref, page);
    } on Object {
      return null;
    }
    final g = data.geometry;
    data.image.dispose();
    final lines = <int>{};
    final inked = <int>{};
    int? surah;
    for (final (k, r) in data.pieces) {
      final line = lineOfY(r.center.dy, g.bandTops, g.bandBottoms);
      inked.add(line);
      if (!keys.contains((k.surah, k.ayah))) continue;
      surah ??= k.surah;
      lines.add(line);
    }
    if (surah == null) continue;
    // The lines just above the passage that hold no verse (a surah's
    // printed title and its basmala) go with it.
    for (
      var l = lines.reduce((a, b) => a < b ? a : b) - 1;
      l >= 0 && !inked.contains(l);
      l--
    ) {
      lines.add(l);
    }
    final crop = g.whole
        ? g.ink
        : linesCrop(
            page: g.ink,
            tops: g.bandTops,
            bottoms: g.bandBottoms,
            lines: lines,
          );
    out.add(
      ShareArtPage(
        page: page,
        surah: surah,
        crop: crop,
        render: (width, paper) async {
          final image = (await load(ref, page)).image;
          try {
            return await _draw(crop, width, paper, (c) {
              // Black ink on white or clear paper: multiplied, the paper
              // takes the picture's colour and the ink stays.
              c.drawImage(
                image,
                Offset.zero,
                Paint()
                  ..filterQuality = FilterQuality.high
                  ..blendMode = BlendMode.multiply,
              );
            });
          } finally {
            image.dispose();
          }
        },
      ),
    );
  }
  return out.isEmpty ? null : out;
}
