import 'package:flutter/material.dart';

import '../../../core/ui/app_toast.dart';
import '../../../l10n/app_localizations.dart';
import '../data/group_khatma_api.dart';

String groupFailureText(AppLocalizations l, Object error) {
  final failure = error is GroupKhatmaException
      ? error.failure
      : GroupKhatmaFailure.offline;
  return switch (failure) {
    GroupKhatmaFailure.offline => l.gkErrOffline,
    GroupKhatmaFailure.notFound => l.gkErrNotFound,
    GroupKhatmaFailure.taken => l.gkErrTaken,
    GroupKhatmaFailure.forbidden => l.gkErrForbidden,
    GroupKhatmaFailure.busy => l.gkErrBusy,
    GroupKhatmaFailure.invalid => l.gkErrInvalid,
  };
}

void showGroupError(BuildContext context, Object error) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    appToast(
      content: Text(groupFailureText(AppLocalizations.of(context), error)),
    ),
  );
}

String partLabel(AppLocalizations l, GroupKhatma k, int n) =>
    k.isHizb ? l.gkHizbN(n) : l.gkJuzN(n);

/// A one-field dialog (a name, a link); null when cancelled.
Future<String?> askText(
  BuildContext context, {
  required String title,
  required String label,
  String initial = '',
  int maxLength = 40,
  String? Function(String)? validate,
}) {
  final l = AppLocalizations.of(context);
  final controller = TextEditingController(text: initial);
  String? error;
  return showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        void submit() {
          final text = controller.text.trim();
          final e = validate?.call(text);
          if (e != null) {
            setState(() => error = e);
            return;
          }
          Navigator.of(context).pop(text);
        }

        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: maxLength,
            decoration: InputDecoration(labelText: label, errorText: error),
            onSubmitted: (_) => submit(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l.gkCancel),
            ),
            FilledButton(onPressed: submit, child: Text(l.gkSave)),
          ],
        );
      },
    ),
  );
}
