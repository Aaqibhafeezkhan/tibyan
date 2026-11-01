import 'package:flutter/widgets.dart';

/// Whether a motion that follows the recitation (a page turn, a scroll to
/// the recited line) is animated: only with the app on screen. In the
/// background (listening with the screen off) no frames are drawn, so the
/// move is made at once instead of leaving animations to queue up and play
/// out on the return. A null state (none reported yet) counts as on screen.
bool animatesOnScreen(AppLifecycleState? state) =>
    state == null || state == AppLifecycleState.resumed;

/// [animatesOnScreen] for the app's current state.
bool get appOnScreen =>
    animatesOnScreen(WidgetsBinding.instance.lifecycleState);
