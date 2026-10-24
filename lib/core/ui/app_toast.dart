import 'package:flutter/material.dart';

/// How long a plain toast stays up.
const kToastDuration = Duration(seconds: 4);

/// How long a toast with an action (e.g. «تراجع») stays up: a bit longer,
/// so the reader has time to reach it.
const kToastActionDuration = Duration(seconds: 6);

/// The one SnackBar every toast in the app uses, so they all behave alike:
/// it always dismisses itself (Flutter keeps a SnackBar with an action up
/// forever unless `persist` is false), carries a close (×) button beside any
/// action, and a horizontal swipe dismisses it at once.
///
/// [duration] may shorten a quick notice; it never makes a toast persist.
SnackBar appToast({
  required Widget content,
  SnackBarAction? action,
  Duration? duration,
  SnackBarBehavior? behavior,
}) => SnackBar(
  content: content,
  action: action,
  behavior: behavior,
  duration:
      duration ?? (action == null ? kToastDuration : kToastActionDuration),
  persist: false,
  showCloseIcon: true,
  dismissDirection: DismissDirection.horizontal,
);
