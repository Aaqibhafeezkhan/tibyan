import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/core/settings/app_settings.dart';
import 'package:tibyan/core/theme/app_theme.dart';
import 'package:tibyan/core/theme/theme_registry.dart';
import 'package:tibyan/core/theme/theme_tokens.dart';
import 'package:tibyan/features/mushaf/presentation/widgets/fasil_bookmarks.dart';
import 'package:tibyan/features/mushaf/presentation/widgets/illuminated_frame.dart';
import 'package:tibyan/l10n/app_localizations.dart';

/// A fasil in any frame hangs from the page's top, painted over the frame
/// and the info bar: whole where the text leaves room, else down to the
/// text (at least [FasilPageLayer.minTabShowing], in the plain frame whose
/// box sits right on the text), and never over the text. It once hung from
/// under the info bar: a sliver in the plain frame, cut off in the others.
///
/// With RENDER_FASIL_PLAIN=1 it also draws each case into
/// `$FASIL_PLAIN_OUT/<name>.png`.
void main() {
  const marks = [
    FasilMark(id: 1, name: 'قراءة', color: Color(0xFFE07A1F), page: 2),
    FasilMark(id: 2, name: 'الكهف', color: Color(0xFF2E9A53), page: 2),
  ];
  const textKey = Key('text');
  const sizes = {
    // The low-end Android emulator: 720×1600 at 2x.
    'android720': Size(360, 800),
    'iphone61': Size(393, 852),
    'landscape': Size(800, 360),
    'tablet': Size(600, 960),
  };
  const looks = {
    'tab': FasilLook(style: FasilStyle.tab, motion: false),
    'tab-elderly': FasilLook(
      style: FasilStyle.tab,
      elderly: true,
      motion: false,
    ),
    'ribbon': FasilLook(style: FasilStyle.ribbon, motion: false),
  };
  final render = Platform.environment['RENDER_FASIL_PLAIN'] == '1';
  final out = Platform.environment['FASIL_PLAIN_OUT'] ?? 'build/fasil_plain';
  late ThemeData theme;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // The real fonts: the info box's words at their own width.
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
    final registry = await ThemeRegistry.load(rootBundle);
    theme = buildTheme(
      style: registry.byId(registry.defaultStyleId),
      mode: ThemeModeId.light,
      uiFont: UiFont.changa,
    );
  });

  Future<GlobalKey> pump(
    WidgetTester tester,
    Size size,
    FasilLook look,
    bool outerRight,
    bool plain,
  ) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final boundary = GlobalKey();
    final colors = theme.extension<TibyanTokens>()!.colors;
    const info = FrameInfo(page: 2, juz: 1, hizb: 1, surahName: 'البقرة');
    // The text fills the page to its edges, as on a phone.
    final text = Stack(
      key: textKey,
      children: [
        LayoutBuilder(
          builder: (context, box) =>
              FasilTextBlock(rect: Offset.zero & box.biggest),
        ),
        Positioned.fill(
          child: Column(
            children: [
              for (var i = 0; i < 15; i++)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: colors.ink.withValues(alpha: .25),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: theme,
        home: RepaintBoundary(
          key: boundary,
          child: Material(
            color: colors.bg,
            child: FasilPageLayer(
              key: UniqueKey(),
              marks: marks,
              look: look,
              outerRight: outerRight,
              child: plain
                  ? PlainFrame(info: info, child: text)
                  : IlluminatedFrame(info: info, child: text),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return boundary;
  }

  for (final MapEntry(key: sizeName, value: size) in sizes.entries) {
    for (final MapEntry(key: lookName, value: look) in looks.entries) {
      for (final (outerRight, plain) in [
        (true, true),
        (false, true),
        (true, false),
        (false, false),
      ]) {
        final name =
            '${plain ? 'plain' : 'illuminated'}-$sizeName-$lookName-'
            '${outerRight ? 'right' : 'left'}';
        testWidgets('$name: the fasil shows, over the bar, off the text', (
          tester,
        ) async {
          final boundary = await pump(tester, size, look, outerRight, plain);
          if (render) {
            final object =
                boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final bytes = (await tester.runAsync(() async {
              final image = await object.toImage(pixelRatio: 2);
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              return data!.buffer.asUint8List();
            }))!;
            File('$out/$name.png')
              ..createSync(recursive: true)
              ..writeAsBytesSync(bytes);
          }
          final page = Offset.zero & size;
          final text = tester.getRect(find.byKey(textKey));
          for (final m in marks) {
            final entrance = find.byKey(ValueKey('fasil-entrance-${m.id}'));
            final shown = tester.getRect(entrance).intersect(page);
            final whole = tester.getSize(
              find.descendant(of: entrance, matching: find.byType(FasilTab)),
            );
            expect(shown.top, 0, reason: '${m.name} hangs from the top');
            // Whole where the text leaves room, else down to the text.
            expect(
              shown.height,
              moreOrLessEquals(
                math.min(whole.height, text.top - 2),
                epsilon: .5,
              ),
              reason: '${m.name}: $shown, text at ${text.top}',
            );
            expect(
              shown.height,
              greaterThanOrEqualTo(FasilPageLayer.minTabShowing(look) - .5),
            );
            expect(shown.width, greaterThanOrEqualTo(look.tabWidth * .6 - .5));
            expect(shown.bottom, lessThanOrEqualTo(text.top + .5));
            // Painted above the frame and the bar: a tap on it lands on it.
            final hit = HitTestResult();
            WidgetsBinding.instance.hitTestInView(
              hit,
              shown.center,
              tester.view.viewId,
            );
            final inside = <RenderObject>{};
            void walk(RenderObject o) {
              inside.add(o);
              o.visitChildren(walk);
            }

            walk(tester.renderObject(entrance));
            expect(
              inside.contains(hit.path.first.target),
              isTrue,
              reason: '${m.name} is under something at ${shown.center}',
            );
          }
        });
      }
    }
  }
}
