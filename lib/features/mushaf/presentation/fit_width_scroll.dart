import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../../core/theme/reveal.dart';

/// A page read by scrolling down (a phone held sideways, the page as wide
/// as the screen). It keeps the place reading has reached in view: a
/// [FollowMark] on the page asks it to scroll there, unless the reader
/// scrolled by hand a moment ago.
class FitWidthScroll extends StatefulWidget {
  const FitWidthScroll({super.key, required this.child});

  final Widget child;

  /// How long a scroll by hand holds the following back.
  static const userHold = Duration(seconds: 4);

  @override
  State<FitWidthScroll> createState() => FitWidthScrollState();
}

class FitWidthScrollState extends State<FitWidthScroll> {
  final _controller = ScrollController();
  DateTime? _userScrolled;

  /// The clock; tests replace it.
  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Scrolls so [box] (on the page) is in view, if it is not already.
  void reveal(RenderObject box) {
    if (!_controller.hasClients || !box.attached) return;
    final held = _userScrolled;
    if (held != null && now().difference(held) < FitWidthScroll.userHold) {
      return;
    }
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return;
    final position = _controller.position;
    final top = viewport.getOffsetToReveal(box, 0).offset;
    final bottom = viewport.getOffsetToReveal(box, 1).offset;
    final view = position.viewportDimension;
    final margin = view * 0.1;
    // In view with a margin above and below: nothing to do. ([top] is the
    // offset that puts the box at the viewport's head, [bottom] the one
    // that puts it at its foot.)
    if (position.pixels <= top - margin && position.pixels >= bottom + margin) {
      return;
    }
    // The line a quarter of the way down, so what follows shows too.
    final target = (top - view * 0.25).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() < 1) return;
    if (reduceMotion(context)) {
      _controller.jumpTo(target);
    } else {
      _controller.animateTo(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<UserScrollNotification>(
        onNotification: (n) {
          if (n.direction != ScrollDirection.idle) _userScrolled = now();
          return false;
        },
        child: _FitWidthScope(
          state: this,
          child: SingleChildScrollView(
            controller: _controller,
            child: widget.child,
          ),
        ),
      );
}

class _FitWidthScope extends InheritedWidget {
  const _FitWidthScope({required this.state, required super.child});

  final FitWidthScrollState state;

  @override
  bool updateShouldNotify(_FitWidthScope old) => old.state != state;
}

/// An invisible box over the place reading has reached ([rect], on the
/// page). Under a [FitWidthScroll] it keeps itself in view whenever it
/// moves; anywhere else it does nothing.
class FollowMark extends StatefulWidget {
  const FollowMark({super.key, required this.rect});

  final Rect rect;

  @override
  State<FollowMark> createState() => _FollowMarkState();
}

class _FollowMarkState extends State<FollowMark> {
  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(FollowMark old) {
    super.didUpdateWidget(old);
    if (old.rect != widget.rect) _schedule();
  }

  void _schedule() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    final scope = context.getInheritedWidgetOfExactType<_FitWidthScope>();
    final box = context.findRenderObject();
    if (scope == null || box == null) return;
    scope.state.reveal(box);
  });

  @override
  Widget build(BuildContext context) =>
      const IgnorePointer(child: SizedBox.expand());
}
