import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show OpenMode, sqlite3;

import 'redesign_prototype.dart';

/// Not a test: renders the redesign directions (Home, Index, Settings) with
/// the real fonts and the real index data into `build/redesign/`.
/// Runs only with RENDER_REDESIGN=1.
void main() {
  final run = Platform.environment['RENDER_REDESIGN'] == '1';

  ProtoData load() {
    final db = sqlite3.open('assets/db/content.db', mode: OpenMode.readOnly);
    final juzOf = <int, int>{
      for (final r in db.select(
        'SELECT surah, MIN(juz) j FROM ayah GROUP BY surah',
      ))
        r['surah'] as int: r['j'] as int,
    };
    final surahs = [
      for (final r in db.select('SELECT * FROM surah ORDER BY id'))
        SurahRow(
          r['id'] as int,
          r['name_ar'] as String,
          r['name_en'] as String,
          r['revelation'] == 'meccan',
          r['ayah_count'] as int,
          r['start_page'] as int,
          juzOf[r['id']]!,
        ),
    ];
    final juz = [
      for (final r in db.select(
        'SELECT a.juz, s.name_ar, a.number, a.page FROM ayah a '
        'JOIN surah s ON s.id = a.surah '
        'WHERE a.id IN (SELECT MIN(id) FROM ayah GROUP BY juz) ORDER BY a.juz',
      ))
        JuzRow(
          r['juz'] as int,
          r['name_ar'] as String,
          r['number'] as int,
          r['page'] as int,
        ),
    ];
    db.close();
    return ProtoData(surahs, juz);
  }

  testWidgets('render redesign', (tester) async {
    await tester.runAsync(() async {
      final manifest = json.decode(
        await rootBundle.loadString('FontManifest.json'),
      ) as List<dynamic>;
      for (final f in manifest.cast<Map<String, dynamic>>()) {
        final loader = FontLoader(f['family'] as String);
        for (final a in (f['fonts'] as List).cast<Map<String, dynamic>>()) {
          loader.addFont(rootBundle.load(Uri.decodeFull(a['asset'] as String)));
        }
        await loader.load();
      }
      // KFGQPC display faces already in the repo but not registered in the
      // app; loaded here only for the prototype.
      for (final e in {
        'KSAHeading': 'KSAHeading.ttf',
        'Zakhrfa': 'Zakhrfa.ttf',
        'UthmanTSB': 'UthmanTSBVer1.ttf',
      }.entries) {
        final bytes = File('assets/fonts/kfgqpc/${e.value}').readAsBytesSync();
        await (FontLoader(
          e.key,
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      }
    });
    logoImage = await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(
        File('assets/ornaments/share_logo.png').readAsBytesSync(),
      );
      return (await codec.getNextFrame()).image;
    });
    addTearDown(tester.view.reset);
    final data = load();
    final out = Directory('build/redesign')..createSync(recursive: true);

    Future<void> shot(String name, Size size, Widget child) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(key: key, child: child),
        ),
      );
      await tester.pump();
      final object =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final bytes = await tester.runAsync(() async {
        final image = await object.toImage(pixelRatio: 2);
        final d = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        return d!.buffer.asUint8List();
      });
      File('${out.path}/$name.png').writeAsBytesSync(bytes!);
    }

    // Surah-name typeface specimen.
    await shot(
      'specimen_names',
      const Size(393, 560),
      Material(
        color: const Color(0xFFF7EDDE),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final f in [
                'UthmanTahaNaskh',
                'UthmanTSB',
                'KSAHeading',
                'KFGQPCAN',
                'ArefRuqaa',
                'KFGQPCKufiExtended',
                'Zakhrfa',
              ])
                Row(
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(f, style: const TextStyle(fontSize: 11)),
                    ),
                    Text(
                      'البقرة  آل عمران',
                      style: TextStyle(
                        fontFamily: f,
                        fontSize: 28,
                        height: 1.6,
                        color: const Color(0xFF1E1915),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );

    const phone = Size(393, 852);
    const small = Size(375, 667);
    const laptop = Size(1280, 800);
    for (final d in Dir.values) {
      for (final night in [false, true]) {
        final c = Ctx(look: Look.of(d, night), data: data);
        final m = night ? 'night' : 'light';
        await shot('${d.name}_home_$m', phone, HomeProto(c));
        await shot('${d.name}_index_$m', phone, IndexProto(c));
        await shot('${d.name}_settings_$m', phone, SettingsProto(c));
      }
      final c = Ctx(look: Look.of(d, false), data: data);
      final n = Ctx(look: Look.of(d, true), data: data);
      await shot('${d.name}_juz_light', phone, IndexProto(c, tab: 1));
      await shot('${d.name}_home_small', small, HomeProto(c));
      await shot('${d.name}_index_laptop', laptop, IndexProto(n));
      await shot('${d.name}_home_laptop', laptop, HomeProto(c));
      final en = Ctx(look: Look.of(d, false), data: data, english: true);
      await shot('${d.name}_index_en', phone, IndexProto(en));
      final old = Ctx(look: Look.of(d, false), data: data, elderly: true);
      await shot('${d.name}_home_elderly', phone, HomeProto(old));
      await shot('${d.name}_index_elderly', phone, IndexProto(old));
    }
  }, skip: !run);
}
