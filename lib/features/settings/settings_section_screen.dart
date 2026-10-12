import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/interface_style.dart';
import '../../core/ui/look_kit.dart';
import '../../l10n/app_localizations.dart';
import 'settings_catalog.dart';

/// One tile of the settings grid: its groups of settings. With [focus]
/// (a setting's id, from the search) it scrolls to that setting and
/// lights it for a moment.
class SettingsSectionScreen extends ConsumerStatefulWidget {
  const SettingsSectionScreen({super.key, required this.section, this.focus});

  final SettingsSection section;
  final String? focus;

  @override
  ConsumerState<SettingsSectionScreen> createState() =>
      _SettingsSectionScreenState();
}

class _SettingsSectionScreenState extends ConsumerState<SettingsSectionScreen> {
  final _keys = <String, GlobalKey>{};
  String? _lit;
  Timer? _unlight;

  @override
  void dispose() {
    _unlight?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final focus = widget.focus;
    if (focus == null) return;
    _lit = focus;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final target = _keys[focus]?.currentContext;
      if (target == null || !mounted) return;
      final reduce = MediaQuery.disableAnimationsOf(context);
      await Scrollable.ensureVisible(
        target,
        alignment: .2,
        duration: reduce ? Duration.zero : const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
      if (!mounted) return;
      _unlight = Timer(const Duration(milliseconds: 1600), () {
        if (mounted) setState(() => _lit = null);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final look = context.look;
    return LookScaffold(
      selected: RailItem.settings,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            LookTopBar(title: widget.section.title(l)),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  // Built whole, not lazily: the search scrolls to any
                  // setting, so each must exist.
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final g in widget.section.groups)
                          LookGroup(
                            icon: g.icon,
                            title: g.title(l),
                            children: [
                              for (final e in g.entries)
                                AnimatedContainer(
                                  key: _keys.putIfAbsent(
                                    e.id,
                                    () => GlobalKey(debugLabel: e.id),
                                  ),
                                  duration: const Duration(milliseconds: 400),
                                  color: _lit == e.id
                                      ? look.control.withValues(alpha: .14)
                                      : look.control.withValues(alpha: 0),
                                  child: Material(
                                    type: MaterialType.transparency,
                                    child: Semantics(
                                      container: true,
                                      identifier: 'setting.${e.id}',
                                      child: e.build(context, ref),
                                    ),
                                  ),
                                ),
                            ],
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
