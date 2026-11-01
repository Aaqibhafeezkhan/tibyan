import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/core/db/ayahinfo_database.dart';
import 'package:tibyan/core/db/content_database.dart';
import 'package:tibyan/core/settings/app_settings.dart';
import 'package:tibyan/features/mushaf/data/mushaf_repository.dart';
import 'package:tibyan/features/mushaf/mushaf_providers.dart';
import 'package:tibyan/features/mushaf/presentation/widgets/fasil_bookmarks.dart';
import 'package:tibyan/features/mushaf/presentation/widgets/image_page.dart';
import 'package:tibyan/features/mushaf/presentation/widgets/mushaf_page.dart';
import 'package:tibyan/features/mushaf/presentation/widgets/old_mushaf_page.dart';
import 'package:tibyan/features/mushaf/presentation/widgets/shamarly_page.dart';
import 'package:tibyan/l10n/app_localizations.dart';

import '../testing/bundled_pages.dart';

/// A sample page of one edition: its line geometry and verse pieces
/// (image units), laid out as the page lays them out.
typedef _Sample = ({
  String name,
  PageGeometry g,
  List<Rect> pieces,
  bool stretch,
});

/// Ribbons hang in the margin only: on sample pages of each edition, at
/// phone and tablet sizes, with and without a frame's gutter, on either
/// side and in every look that reaches into the page, no ribbon (or the
/// short tab it falls back to) crosses a line of text.
void main() {
  final samples = <_Sample>[];
  Rect rect(num x0, num y0, num x1, num y1) =>
      Rect.fromLTRB(x0.toDouble(), y0.toDouble(), x1.toDouble(), y1.toDouble());

  setUpAll(() async {
    final db = ContentDatabase(
      NativeDatabase(
        File('assets/db/content.db'),
        setup: (raw) => raw.execute('PRAGMA query_only = ON'),
      ),
    );
    final repo = MushafRepository(db);
    for (final page in [3, 50, 300, 521]) {
      final row = (await repo.shamarlyPage(page))!;
      final overflow = <int, List<Rect>>{};
      for (final o in await repo.shamarlyOverflow(page)) {
        overflow
            .putIfAbsent(o.line, () => [])
            .add(rect(o.x0, o.y0, o.x1, o.y1));
      }
      samples.add((
        name: 'Shamarly $page',
        g: shamarlyGeometry(
          row,
          await repo.shamarlyLines(page),
          headers: await repo.shamarlyHeaders(page),
          overflow: overflow,
        ),
        pieces: [
          for (final b in await repo.shamarlyVerseBoxes(page))
            rect(b.x0, b.y0, b.x1, b.y1),
        ],
        stretch: true,
      ));
    }
    final pack = bundledPagesArchive();
    for (final page in [3, 50, 300, 604]) {
      final svg = utf8.decode(
        XZDecoder().decodeBytes(
          pack.findFile('${page.toString().padLeft(3, '0')}.svg.xz')!.content,
        ),
      );
      final v = [
        for (final n in RegExp(
          r'viewBox="([^"]+)"',
        ).firstMatch(svg)!.group(1)!.trim().split(RegExp(r'[\s,]+')))
          double.parse(n),
      ];
      final polys = await repo.polygons(page);
      final g = svgLineGeometry(
        Rect.fromLTWH(v[0], v[1], v[2], v[3]),
        SvgPageGeometry(
          polygons: polys,
          cuts: await repo.lineCuts('madina1441', page),
          overflow: const [],
        ),
        opening: false,
      );
      samples.add((
        name: 'Madina 1441 $page',
        g: g,
        pieces: [for (final p in polys) ...lineRects(outlineRects(p.path), g)],
        stretch: false,
      ));
    }
    // The 1405 glyph boxes arrive with its page pack; used where on disk.
    final glyphs = File(
      Platform.environment['AYAHINFO_DB'] ?? 'tools/.cache/ayahinfo_1024.db',
    );
    if (glyphs.existsSync()) {
      final info = AyahInfoDatabase(NativeDatabase(glyphs));
      final ink = jsonDecode(
        File('assets/config/old_page_ink.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      for (final page in [3, 50, 300]) {
        final own = switch (ink['$page']) {
          [num l, num t, num r, num b] => rect(l, t, r, b),
          _ => null,
        };
        samples.add((
          name: 'Madina 1405 $page',
          g: oldEditionGeometry(
            opening: false,
            cuts: await repo.lineCuts('madina1405', page),
            overflow: const {},
            ownInk: own,
          ),
          pieces: [
            for (final r in await info.page(page))
              rect(r.minX, r.minY, r.maxX, r.maxY),
          ],
          stretch: true,
        ));
      }
      await info.close();
    }
    await db.close();
  });

  const marks = [
    FasilMark(id: 1, name: 'قراءة', color: Color(0xFF2F6FD0), page: 1),
    FasilMark(id: 2, name: 'مراجعة', color: Color(0xFFD0453B), page: 1),
    FasilMark(id: 3, name: 'الكهف', color: Color(0xFF2E9A53), page: 1),
  ];
  const looks = {
    'ribbon': FasilLook(style: FasilStyle.ribbon, motion: false),
    'ribbon side': FasilLook(
      style: FasilStyle.ribbon,
      place: FasilPlace.side,
      motion: false,
    ),
    'ribbon elderly': FasilLook(
      style: FasilStyle.ribbon,
      elderly: true,
      motion: false,
    ),
    'tab, focus': FasilLook(style: FasilStyle.tab, motion: false),
  };
  const sizes = [Size(393, 700), Size(820, 1100)];

  testWidgets('no ribbon crosses a line of text', (tester) async {
    expect(samples.length, greaterThanOrEqualTo(8));
    final failures = <String>[];
    var checked = 0;
    for (final s in samples) {
      for (final size in sizes) {
        for (final gutter in [0.0, 6.0, 18.0]) {
          for (final MapEntry(key: name, value: look) in looks.entries) {
            for (final outerRight in [true, false]) {
              late List<Rect> lines;
              await tester.pumpWidget(
                MaterialApp(
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox.fromSize(
                      size: size,
                      child: FasilPageLayer(
                        key: UniqueKey(),
                        marks: marks,
                        look: look,
                        focus: name.contains('focus'),
                        outerRight: outerRight,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            gutter,
                            gutter + 40,
                            gutter,
                            0,
                          ),
                          child: LayoutBuilder(
                            builder: (context, box) {
                              final layout = StripLayout(
                                box.biggest,
                                s.g,
                                stretch: s.stretch,
                              );
                              final screen = [
                                for (final r in s.pieces)
                                  layout.toScreenRect(r),
                              ];
                              lines = [
                                for (final r in screen)
                                  r.shift(Offset(gutter, gutter + 40)),
                              ];
                              return FasilTextBlock(
                                rect: textBlockOf(
                                  screen,
                                  firstLineTop: layout
                                      .toScreen(
                                        Offset(0, s.g.bandTops.first),
                                        line: 0,
                                      )
                                      .dy,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
              await tester.pump();
              for (final m in marks) {
                final f = find.byKey(ValueKey('fasil-entrance-${m.id}'));
                final r = tester.getRect(f).deflate(.5);
                for (final l in lines) {
                  if (r.overlaps(l)) {
                    failures.add(
                      '${s.name} $size gutter $gutter $name '
                      '${outerRight ? 'right' : 'left'}: ${m.name} $r over $l',
                    );
                    break;
                  }
                }
              }
              checked++;
            }
          }
        }
      }
    }
    expect(checked, greaterThan(0));
    expect(failures.take(10), isEmpty, reason: '${failures.length} failures');
  });
}
