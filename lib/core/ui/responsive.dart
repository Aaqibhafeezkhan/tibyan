// One set of window sizes for the whole app, so every screen changes its
// layout at the same widths: phones, tablets and desktop windows.
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';

/// The window's width class.
/// * [compact]: a phone (under 600).
/// * [medium]: a tablet held upright, a narrow window (600 to 900).
/// * [expanded]: a tablet sideways, a desktop window (900 to 1280).
/// * [large]: a big desktop window (1280 and wider).
enum WindowClass { compact, medium, expanded, large }

abstract final class Breakpoints {
  static const medium = 600.0;
  static const expanded = 900.0;
  static const large = 1280.0;
}

/// How wide content may grow before it is centred with margins: a long
/// line of text is hard to read, a list of cards across a whole desktop
/// screen hard to scan.
abstract final class ContentWidth {
  /// Forms, dialogs, a single card (onboarding, reports).
  static const narrow = 560.0;

  /// Reading text and single-column lists.
  static const text = 760.0;

  /// Grouped sections, lists with two columns.
  static const wide = 1080.0;

  /// The home screen's dashboard.
  static const full = 1240.0;
}

WindowClass windowClassOf(double width) {
  if (width >= Breakpoints.large) return WindowClass.large;
  if (width >= Breakpoints.expanded) return WindowClass.expanded;
  if (width >= Breakpoints.medium) return WindowClass.medium;
  return WindowClass.compact;
}

/// macOS, Windows or Linux.
bool get isDesktopPlatform =>
    !kIsWeb &&
    switch (defaultTargetPlatform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      _ => false,
    };

extension Responsive on BuildContext {
  WindowClass get windowClass => windowClassOf(MediaQuery.sizeOf(this).width);

  /// A tablet or a desktop: the device, not the window, is large. A phone
  /// held sideways is wide but stays a phone.
  bool get isLargeDevice =>
      isDesktopPlatform || MediaQuery.sizeOf(this).shortestSide >= 600;

  /// Two or more columns fit.
  bool get isExpanded => windowClass.index >= WindowClass.expanded.index;
}

/// Scrolling for the whole app. Material already draws scrollbars on the
/// desktop; tablets get them too, since a long list there is as long as on
/// a desktop window. Phones keep the platform's own feel.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    if (isDesktopPlatform || !context.isLargeDevice) {
      return super.buildScrollbar(context, child, details);
    }
    if (axisDirectionToAxis(details.direction) != Axis.vertical) return child;
    return Scrollbar(controller: details.controller, child: child);
  }
}
