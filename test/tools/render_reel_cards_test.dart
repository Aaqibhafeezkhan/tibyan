import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/features/audio/reciter_avatar.dart';
import 'package:tibyan/features/share_video/reel_painter.dart';
import 'package:tibyan/features/share_video/reel_timeline.dart';

/// Not a test: draws the «share as video» start and end cards into
/// `$REEL_CARDS_OUT/` (default build/reel_cards). Runs only with
/// RENDER_REEL_CARDS=1.
void main() {
  final run = Platform.environment['RENDER_REEL_CARDS'] == '1';
  final outPath = Platform.environment['REEL_CARDS_OUT'] ?? 'build/reel_cards';

  testWidgets('render reel cards', (tester) async {
    await tester.runAsync(() async {
      final manifest = jsonDecode(
        await rootBundle.loadString('FontManifest.json'),
      ) as List<dynamic>;
      for (final f in manifest.cast<Map<String, dynamic>>()) {
        final loader = FontLoader(f['family'] as String);
        for (final a in (f['fonts'] as List).cast<Map<String, dynamic>>()) {
          loader.addFont(rootBundle.load(Uri.decodeFull(a['asset'] as String)));
        }
        await loader.load();
      }
      final logo = await vg.loadPicture(
        const SvgAssetLoader('assets/brand/tibyan_logo.svg'),
        null,
      );
      final marks = [
        for (final p in reelPlatforms)
          await vg.loadPicture(
            SvgAssetLoader('assets/brand/platform_$p.svg'),
            null,
          ),
      ];
      final blank = ui.PictureRecorder();
      ui.Canvas(blank).drawRect(
        const ui.Rect.fromLTWH(0, 0, 1, 1),
        ui.Paint()..color = const ui.Color(0x00000000),
      );
      final frame = await blank.endRecording().toImage(1, 1);
      final tl = ReelTimeline.build(
        first: 1,
        last: 1,
        verses: const [(ayah: 1, startMs: 0, endMs: 4000)],
      )!;
      final out = Directory(outPath)..createSync(recursive: true);
      for (final (id, name) in [
        (1, 'محمد صديق المنشاوي'),
        (7, 'قارئ بلا صورة'),
      ]) {
        final painter = ReelPainter(
          ReelContent(
            surah: 18,
            verses: const [ReelVerse(number: 90, displayText: 'نص تجريبي ٩٠')],
            heading: 'من القرآن الكريم',
            range: 'الآية ٩٠',
            voice: 'بصوت الشيخ $name',
            credit: '',
            join: 'حمّل التطبيق الآن',
            url: 'altibyan.app',
            platforms: [for (final m in marks) m.picture],
            photo: await reciterPhotoImage(id),
            frame: frame,
            logo: logo.picture,
            logoSize: logo.size,
            paper: const ui.Color(0xFFF6F1E8),
          ),
          tl,
        );
        for (final (card, state) in [
          (
            'start',
            const FrameState(
              intro: 255,
              body: 0,
              outro: 0,
              pages: [],
              cue: null,
            ),
          ),
          (
            'end',
            const FrameState(
              intro: 0,
              body: 0,
              outro: 255,
              pages: [],
              cue: null,
            ),
          ),
        ]) {
          if (card == 'end' && id != 1) continue;
          final r = ui.PictureRecorder();
          painter.paint(ui.Canvas(r), reelDesign, state);
          final img = await r.endRecording().toImage(1080, 1920);
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File('${out.path}/after_${card}_reciter$id.png')
              .writeAsBytesSync(png!.buffer.asUint8List());
        }
      }
    });
  }, skip: !run);
}
