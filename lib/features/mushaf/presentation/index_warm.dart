import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/app_settings.dart';
import '../mushaf_providers.dart';
import 'continue_snapshot.dart' show warmMushafPage;

/// Prepares the page an index row opens while the finger is still on the
/// row: the tap lands about a tenth of a second later, and the mushaf then
/// finds the page's text, artwork and picture ready instead of making them
/// during the index's exit.
///
/// One page at a time, between frames (a frame never waits on it). A new
/// row retargets; a scroll or a cancelled touch drops what has not started.
class IndexJumpWarmer {
  IndexJumpWarmer({required this.warm, this.schedule = idleSlot});

  /// Prepares one page of the edition being read.
  final Future<void> Function(int page) warm;

  /// Waits for a moment when the app is idle ([idleSlot]; tests pass
  /// their own).
  final Future<void> Function() schedule;

  int? _target;
  int _generation = 0;

  /// The page being prepared, or null when none is.
  int? get target => _target;

  /// A finger came down on a row opening [page].
  void touchDown(int page) {
    if (page == _target) return;
    _target = page;
    final generation = ++_generation;
    unawaited(_run(generation, page));
  }

  /// The finger moved off into a scroll, or the touch was cancelled.
  void cancel() {
    _target = null;
    _generation++;
  }

  /// Nothing more is to be prepared (the index is closing for good).
  void dispose() => cancel();

  Future<void> _run(int generation, int page) async {
    await schedule();
    if (generation != _generation) return;
    try {
      await warm(page);
    } on Object catch (e) {
      debugPrint('IndexJumpWarmer: page $page not prepared ($e)');
    }
  }
}

/// Prepares [page] of the edition being read for the mushaf to land on.
Future<void> warmIndexTarget(WidgetRef ref, int page) async {
  final edition = ref.read(editionProvider);
  if (page < 1 || page > edition.pageCount) return;
  // The full preparation «متابعة القراءة» uses: text, frame, the new
  // editions' artwork compiled, the picture editions' page decoded.
  await warmMushafPage(ref, edition, page);
}

/// After the frame being drawn, in a task of its own: the touch's frame
/// (the row's highlight) is never kept waiting. Not the scheduler's idle
/// priority: the index's ink and fades keep frames coming, and an idle
/// task would wait them out, past the tap.
Future<void> idleSlot() async {
  await SchedulerBinding.instance.endOfFrame;
  await Future<void>.delayed(Duration.zero);
}

/// Gives the index's rows their [IndexJumpWarmer], and drops its target
/// when a list under it starts to scroll (the finger was not tapping).
class IndexWarmScope extends StatelessWidget {
  const IndexWarmScope({super.key, required this.warmer, required this.child});

  final IndexJumpWarmer warmer;
  final Widget child;

  static IndexJumpWarmer? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_IndexWarmInherited>()?.warmer;

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollStartNotification>(
        onNotification: (n) {
          // A drag: the touch turned into a scroll (the lists, the tabs).
          if (n.dragDetails != null) warmer.cancel();
          return false;
        },
        child: _IndexWarmInherited(warmer: warmer, child: child),
      );
}

class _IndexWarmInherited extends InheritedWidget {
  const _IndexWarmInherited({required this.warmer, required super.child});

  final IndexJumpWarmer warmer;

  @override
  bool updateShouldNotify(_IndexWarmInherited old) => warmer != old.warmer;
}

/// A row of the index that opens [page]: a touch on it starts preparing
/// the page. It changes nothing of the row's own taps or semantics.
class IndexWarmRow extends StatelessWidget {
  const IndexWarmRow({super.key, required this.page, required this.child});

  /// The page the row opens; null when not yet known (nothing is warmed).
  final int? page;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final warmer = IndexWarmScope.maybeOf(context);
    final p = page;
    if (warmer == null || p == null) return child;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => warmer.touchDown(p),
      onPointerCancel: (_) => warmer.cancel(),
      child: child,
    );
  }
}
