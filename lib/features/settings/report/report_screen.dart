import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/settings_controller.dart';
import '../../../core/theme/interface_style.dart';
import '../../../core/ui/look_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../settings_widgets.dart' show appVersionProvider;
import 'problem_report.dart';

const reportLocation = '/settings/report';

/// «الإبلاغ عن مشكلة»: the kind, what happened, an optional way to reply,
/// the device facts that go with it, and the crash-reports switch.
class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  final _form = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  ReportType _type = ReportType.bug;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // A report queued while offline goes out when the form opens again.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(reportServiceProvider).flush();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _description.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  String _typeName(AppLocalizations l, ReportType t) => switch (t) {
    ReportType.bug => l.reportTypeBug,
    ReportType.problem => l.reportTypeProblem,
    ReportType.suggestion => l.reportTypeSuggestion,
    ReportType.other => l.reportTypeOther,
  };

  Future<void> _submit(ReportDevice device) async {
    if (_sending || !_form.currentState!.validate()) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    final outcome = await ref
        .read(reportServiceProvider)
        .submit(
          ProblemReport(
            type: _type,
            description: _description.text,
            phone: _phone.text,
            email: _email.text,
            device: device,
          ),
        );
    if (!mounted) return;
    setState(() => _sending = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(switch (outcome) {
          ReportOutcome.sent => l.reportSent,
          ReportOutcome.queued => l.reportQueued,
          ReportOutcome.rateLimited => l.reportRateLimited,
          ReportOutcome.failed => l.reportFailed,
        }),
      ),
    );
    if (outcome == ReportOutcome.sent || outcome == ReportOutcome.queued) {
      _description.clear();
      _phone.clear();
      _email.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final look = context.look;
    final device = ReportDevice.current(
      ref.watch(appVersionProvider).value ?? '',
    );
    final pending = ref.watch(reportServiceProvider).queue.length;
    final crashOptIn = ref.watch(
      settingsProvider.select((s) => s.crashReportsOptIn),
    );
    return LookScaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            LookTopBar(title: l.reportProblemTitle),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Form(
                    key: _form,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      children: [
                        DropdownButtonFormField<ReportType>(
                          key: const ValueKey('report-type'),
                          initialValue: _type,
                          decoration: InputDecoration(labelText: l.reportType),
                          items: [
                            for (final t in ReportType.values)
                              DropdownMenuItem(
                                value: t,
                                child: Text(_typeName(l, t)),
                              ),
                          ],
                          onChanged: (t) => setState(() => _type = t ?? _type),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          key: const ValueKey('report-description'),
                          controller: _description,
                          minLines: 4,
                          maxLines: 10,
                          maxLength: reportMaxLength,
                          decoration: InputDecoration(
                            labelText: l.reportDescription,
                            hintText: l.reportDescriptionHint,
                            alignLabelWithHint: true,
                          ),
                          validator: (v) =>
                              (v ?? '').trim().length < reportMinLength
                              ? l.reportDescriptionShort
                              : null,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          key: const ValueKey('report-phone'),
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(labelText: l.reportPhone),
                          validator: (v) => isValidReportPhone(v ?? '')
                              ? null
                              : l.reportPhoneInvalid,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          key: const ValueKey('report-email'),
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(labelText: l.reportEmail),
                          validator: (v) => isValidReportEmail(v ?? '')
                              ? null
                              : l.reportEmailInvalid,
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                          child: Text(
                            l.reportContactNote,
                            style: TextStyle(color: look.sub, fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          key: const ValueKey('report-device'),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l.reportDeviceTitle,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  l.reportDeviceVersion(device.appVersion),
                                  style: TextStyle(color: look.sub),
                                ),
                                Text(
                                  l.reportDeviceSystem(
                                    device.platform,
                                    device.osVersion,
                                  ),
                                  style: TextStyle(color: look.sub),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (pending > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              l.reportPendingCount(pending),
                              style: TextStyle(color: look.sub),
                            ),
                          ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          key: const ValueKey('report-send'),
                          onPressed: _sending ? null : () => _submit(device),
                          icon: _sending
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send_outlined),
                          label: Text(l.reportSend),
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          key: const ValueKey('report-crash-switch'),
                          contentPadding: EdgeInsets.zero,
                          title: Text(l.crashReportsLabel),
                          subtitle: Text(
                            l.crashReportsHint,
                            style: TextStyle(color: look.sub),
                          ),
                          value: crashOptIn,
                          onChanged: (v) => ref
                              .read(settingsProvider.notifier)
                              .setCrashReportsOptIn(v),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
