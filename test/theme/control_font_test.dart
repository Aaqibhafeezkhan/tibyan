import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/core/theme/app_theme.dart';
import 'package:tibyan/core/theme/interface_style.dart';
import 'package:tibyan/core/theme/theme_registry.dart';
import 'package:tibyan/core/theme/theme_tokens.dart';

/// Every control's label is drawn in the interface face (its family and
/// fallbacks, the digits face first under Changa), never the system font:
/// buttons, segments, chips, the navigation bar, dialogs and snackbars, in
/// normal and elderly mode, for each interface font, in the base theme and
/// the screens' look.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ThemeRegistry registry;
  setUpAll(() async => registry = await ThemeRegistry.load(rootBundle));

  TextStyle styleOf(WidgetTester tester, String text) {
    final p = tester.renderObject<RenderParagraph>(find.text(text).last);
    return p.text.style!;
  }

  for (final font in UiFont.values) {
    for (final elderly in [false, true]) {
      for (final screens in [false, true]) {
        final tag =
            '${font.name}${elderly ? ' elderly' : ''}'
            '${screens ? ' screens' : ''}';
        testWidgets('controls use the interface face: $tag', (tester) async {
          var theme = buildTheme(
            style: registry.byId(registry.defaultStyleId),
            mode: ThemeModeId.light,
            uiFont: font,
            elderly: elderly,
          );
          if (screens) theme = theme.extension<UiLook>()!.screens(theme);
          await tester.binding.setSurfaceSize(const Size(800, 1200));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: Scaffold(
                body: ListView(
                  children: [
                    FilledButton(onPressed: () {}, child: const Text('f1')),
                    ElevatedButton(onPressed: () {}, child: const Text('e1')),
                    OutlinedButton(onPressed: () {}, child: const Text('o1')),
                    TextButton(onPressed: () {}, child: const Text('t1')),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 1, label: Text('s1')),
                        ButtonSegment(value: 2, label: Text('s2')),
                      ],
                      selected: const {1},
                      onSelectionChanged: (_) {},
                    ),
                    const Chip(label: Text('c1')),
                    FilterChip(
                      label: const Text('c2'),
                      selected: true,
                      onSelected: (_) {},
                    ),
                    const AlertDialog(title: Text('d1'), content: Text('d2')),
                  ],
                ),
                bottomNavigationBar: NavigationBar(
                  destinations: const [
                    NavigationDestination(icon: Icon(Icons.home), label: 'n1'),
                    NavigationDestination(icon: Icon(Icons.book), label: 'n2'),
                  ],
                ),
              ),
            ),
          );
          final context = tester.element(find.byType(ListView));
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('b1')));
          await tester.pumpAndSettle();

          for (final text in [
            'f1',
            'e1',
            'o1',
            't1',
            's1',
            'c1',
            'c2',
            'd1',
            'd2',
            'n1',
            'b1',
          ]) {
            final style = styleOf(tester, text);
            expect(style.fontFamily, font.textFamily, reason: '$text $tag');
            final fallback = style.fontFamilyFallback ?? const <String>[];
            if (font.textFamily != font.family) {
              expect(fallback.first, font.family, reason: '$text $tag');
            }
            expect(fallback, contains('IBMPlexSansArabic'), reason: text);
          }
          if (elderly) {
            expect(styleOf(tester, 'f1').fontSize, 18, reason: tag);
          }
        });
      }
    }
  }
}
