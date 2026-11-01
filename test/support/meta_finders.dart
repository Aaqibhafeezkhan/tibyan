import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tibyan/core/ui/meta_separator.dart';

String? _data(Widget w) => switch (w) {
  MetaText(:final data) => data,
  Text(:final data?) => data,
  _ => null,
};

/// A [Text] or [MetaText] showing exactly [text] (separators as « · »).
Finder findMeta(String text) =>
    find.byWidgetPredicate((w) => _data(w) == text, description: 'meta $text');

/// A [Text] or [MetaText] whose text contains [part].
Finder findMetaContaining(String part) => find.byWidgetPredicate(
  (w) => _data(w)?.contains(part) ?? false,
  description: 'meta containing $part',
);
