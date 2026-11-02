import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/reveal.dart';

/// How long the index takes to fade in over the mushaf.
const indexFadeIn = Duration(milliseconds: 180);

/// How long it takes to fade out when a row opens a page: short, so the
/// page under it is drawn with as little else on screen as can be.
const indexFadeOut = Duration(milliseconds: 120);

/// The index's route: a plain fade (the same in either reading direction),
/// with no slide or zoom over the mushaf; with less motion asked for it
/// comes and goes at once.
CustomTransitionPage<void> indexTransitionPage({
  required LocalKey key,
  required Widget child,
}) => CustomTransitionPage<void>(
  key: key,
  child: child,
  transitionDuration: indexFadeIn,
  reverseTransitionDuration: indexFadeOut,
  transitionsBuilder: (context, animation, _, child) {
    if (reduceMotion(context)) return child;
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ),
      child: child,
    );
  },
);
