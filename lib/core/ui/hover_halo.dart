// A round hover and press highlight for small buttons in thin bars (the
// mushaf's reading tools, the focus bar). Material's ink is painted on the
// bar and cut off at its edges, and the pages drawn after the bar cover
// it; this halo is drawn in the overlay, above everything in the window.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HoverHalo extends StatefulWidget {
  const HoverHalo({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.radius = 20,
    this.color,
  });

  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double radius;

  /// The halo's colour; the theme's ink (onSurface) by default.
  final Color? color;

  @override
  State<HoverHalo> createState() => _HoverHaloState();
}

class _HoverHaloState extends State<HoverHalo>
    with SingleTickerProviderStateMixin {
  final _link = LayerLink();
  final _portal = OverlayPortalController();
  late final _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 140),
  )..addStatusListener(_onStatus);

  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  void _onStatus(AnimationStatus s) {
    if (s == AnimationStatus.dismissed && _portal.isShowing) _portal.hide();
  }

  void _update() {
    final on = _hovered || _pressed || _focused;
    if (on) {
      if (!_portal.isShowing) _portal.show();
      _fade.forward();
    } else {
      _fade.reverse();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.color ?? Theme.of(context).colorScheme.onSurface;
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (context) => CompositedTransformFollower(
        link: _link,
        targetAnchor: Alignment.center,
        followerAnchor: Alignment.center,
        showWhenUnlinked: false,
        child: Align(
          alignment: Alignment.topLeft,
          child: IgnorePointer(
            child: FadeTransition(
              opacity: _fade,
              child: AnimatedScale(
                scale: _pressed ? 0.92 : 1,
                duration: const Duration(milliseconds: 100),
                child: Container(
                  width: widget.radius * 2,
                  height: widget.radius * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: base.withValues(alpha: _pressed ? .16 : .09),
                    border: _focused
                        ? Border.all(color: base.withValues(alpha: .35))
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      child: CompositedTransformTarget(
        link: _link,
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          onShowHoverHighlight: (v) {
            _hovered = v;
            _update();
          },
          onShowFocusHighlight: (v) {
            _focused = v;
            _update();
          },
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onTap();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) {
              _pressed = true;
              _update();
            },
            onTapUp: (_) {
              _pressed = false;
              _update();
            },
            onTapCancel: () {
              _pressed = false;
              _update();
            },
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
