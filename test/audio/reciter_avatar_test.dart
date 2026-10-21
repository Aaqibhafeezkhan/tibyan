import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/core/theme/app_theme.dart';
import 'package:tibyan/core/theme/theme_tokens.dart';
import 'package:tibyan/features/audio/reciter_avatar.dart';

const _colors = ModeTokens(
  bg: Colors.white,
  paper: Colors.white,
  ink: Colors.black,
  muted: Colors.black,
  border: Colors.black,
  frame: Colors.black,
  marker: Colors.black,
  goldText: Colors.black,
  headBg: Colors.black,
  headFg: Colors.white,
  accent: Colors.teal,
  accentFg: Colors.white,
  player: Colors.black,
  playerFg: Colors.white,
  highlight: Colors.transparent,
  control: Colors.teal,
  onControl: Colors.white,
);

const _style = TibyanStyle(
  id: 'test',
  version: 1,
  name: {'en': 'Test'},
  description: {'en': 'Test theme'},
  surahHeaderFont: 'Test',
  frame: FrameSpec(
    outerWidth: 0,
    outerStyle: 'solid',
    innerWidth: 0,
    gap: 0,
    radius: 0,
    innerRadius: 0,
    corner: 'none',
  ),
  ornaments: OrnamentSpec(
    surahHeader: 'minimal',
    ayahMarker: 'minimal',
    density: 'minimal',
  ),
  radii: RadiiSpec(card: 0, sheet: 0, chip: 0, surahHeader: 0),
  modes: {ThemeModeId.light: _colors},
);

final _theme = ThemeData(
  extensions: [
    TibyanTokens(style: _style, mode: ThemeModeId.light, colors: _colors),
  ],
);

Future<void> _pumpAvatar(
  WidgetTester tester, {
  required String name,
  double size = 40,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: _theme,
      home: Scaffold(
        body: Center(
          child: ReciterAvatar(id: 999999, name: name, size: size),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows initials for a two-word name when the photo is missing', (
    tester,
  ) async {
    await _pumpAvatar(tester, name: 'Abdul Basit');

    expect(find.text('AB'), findsOneWidget);
  });

  testWidgets('trims extra whitespace before extracting initials', (
    tester,
  ) async {
    await _pumpAvatar(tester, name: '  Abdul   Basit  ');

    expect(find.text('AB'), findsOneWidget);
  });

  testWidgets('shows the initial for a one-word name', (tester) async {
    await _pumpAvatar(tester, name: 'Husary');

    expect(find.text('H'), findsOneWidget);
  });

  testWidgets('uses the supplied size for both dimensions', (tester) async {
    await _pumpAvatar(tester, name: 'Abdul Basit', size: 64);

    final avatar = find.byType(ReciterAvatar);
    final sizedBox = find.descendant(
      of: avatar,
      matching: find.byType(SizedBox),
    );

    expect(tester.getSize(sizedBox), const Size(64, 64));
  });
}
