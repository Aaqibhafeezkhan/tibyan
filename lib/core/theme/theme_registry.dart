import 'dart:convert';

import 'package:flutter/services.dart';

import 'theme_tokens.dart';

/// All styles found in `assets/themes/index.json`.
class ThemeRegistry {
  const ThemeRegistry({required this.defaultStyleId, required this.styles});

  final String defaultStyleId;
  final List<TibyanStyle> styles;

  TibyanStyle byId(String id) => styles.firstWhere(
    (s) => s.id == id,
    orElse: () => styles.firstWhere((s) => s.id == defaultStyleId),
  );

  static Future<ThemeRegistry> load(AssetBundle bundle) async {
    final index = jsonDecode(
      await bundle.loadString('assets/themes/index.json'),
    ) as Map<String, dynamic>;
    final ids = List<String>.from(index['styles'] as List);
    // All at once: one by one, each read waits its own turn on a cold
    // start (a slow phone's storage), most of a second in all.
    final styles = [
      for (final json in await Future.wait([
        for (final id in ids) bundle.loadString('assets/themes/$id.json'),
      ]))
        TibyanStyle.fromJson(jsonDecode(json) as Map<String, dynamic>),
    ];
    return ThemeRegistry(
      defaultStyleId: index['default'] as String,
      styles: styles,
    );
  }
}
