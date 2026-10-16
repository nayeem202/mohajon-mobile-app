import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../localization/app_localizations.dart';
import '../models/app_update_policy.dart';
import '../services/app_update_installer.dart';
import '../services/app_update_service.dart';
import '../theme/app_typography.dart';
import '../theme/mohajon_warm_theme.dart';

/// Mounted exclusively by AuthenticatedEntry, never by splash or login.
class AppUpdateGate extends ConsumerStatefulWidget {
  const AppUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends ConsumerState<AppUpdateGate>
    with WidgetsBindingObserver {
  AppUpdateDecision? _decision;
  bool _checking = false;
  bool _updating = false;
  String? _messageKey;
  DateTime? _lastCheck;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _updating || _checking) return;
    if ((_decision?.updateRequired ?? false) ||
        _lastCheck == null ||
        DateTime.now().difference(_lastCheck!) > const Duration(minutes: 1)) {
      unawaited(_check());
    }
  }

  Future<void> _check() async {
    if (_checking || _updating) return;
    setState(() {
      _checking = true;
      _messageKey = null;
    });
    AppUpdateDecision decision;
    try {
      decision = await ref.read(appUpdateServiceProvider).check();
    } catch (_) {
      decision = _decision ?? const AppUpdateDecision();
    }
    if (!mounted) return;
    setState(() {
      _decision = decision;
      _checking = false;
      _updating = decision.updateRequired;
      _lastCheck = DateTime.now();
    });
    if (decision.updateRequired) {
      UpdateLaunchResult? result;
      try {
        result = await ref
            .read(appUpdateInstallerProvider)
            .resumeIfInProgress(decision);
      } catch (_) {
        // An unavailable Play service must leave the manual update action usable.
      }
      if (mounted) {
        setState(() {
          _updating = false;
          if (result != null) _messageKey = _messageFor(result);
        });
      }
    }
  }

  Future<void> _update() async {
    final decision = _decision;
    if (decision == null || _updating || _checking) return;
    setState(() {
      _updating = true;
      _messageKey = null;
    });
    UpdateLaunchResult result;
    try {
      result = await ref.read(appUpdateInstallerProvider).launch(decision);
    } catch (_) {
      result = UpdateLaunchResult.failed;
    }
    if (mounted) {
      setState(() {
        _updating = false;
        _messageKey = _messageFor(result);
      });
    }
  }

  String? _messageFor(UpdateLaunchResult result) => switch (result) {
    UpdateLaunchResult.started => 'appUpdateStarting',
    UpdateLaunchResult.cancelled => 'appUpdateCancelled',
    UpdateLaunchResult.storeOpened => 'appUpdateStoreOpened',
    UpdateLaunchResult.failed => 'appUpdateOpenFailed',
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final decision = _decision;
    if (decision == null) {
      return Scaffold(
        backgroundColor: MohajonWarm.surface,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: MohajonWarm.goldText),
                const SizedBox(height: 20),
                Text(l10n.t('appUpdateChecking'), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    }
    if (!decision.updateRequired) return widget.child;
    return PopScope(
      canPop: false,
      child: RequiredUpdateScreen(
        decision: decision,
        busy: _updating || _checking,
        message: _messageKey == null ? null : l10n.t(_messageKey!),
        onUpdate: _update,
        onRetry: _check,
      ),
    );
  }
}

class RequiredUpdateScreen extends StatelessWidget {
  const RequiredUpdateScreen({
    super.key,
    required this.decision,
    required this.onUpdate,
    required this.onRetry,
    this.busy = false,
    this.message,
  });

  final AppUpdateDecision decision;
  final VoidCallback onUpdate;
  final VoidCallback onRetry;
  final bool busy;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = l10n.locale;
    final policy = decision.policy!;
    final customMessage = locale.languageCode == 'bn'
        ? policy.messageBn
        : policy.messageEn;
    return Scaffold(
      backgroundColor: MohajonWarm.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFFFECAE), Color(0xFFFFCE3D)],
                              ),
                              border: Border.all(color: MohajonWarm.goldBorder),
                            ),
                            child: const Icon(
                              Icons.system_update_rounded,
                              size: 48,
                              color: MohajonWarm.ink,
                            ),
                          ),
                          const SizedBox(height: 26),
                          Text(
                            l10n.t('appUpdateTitle'),
                            textAlign: TextAlign.center,
                            style: AppType.heading(
                              const TextStyle(
                                fontSize: 27,
                                color: MohajonWarm.ink,
                              ),
                              locale: locale,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            customMessage.isEmpty
                                ? l10n.t('appUpdateBody')
                                : customMessage,
                            textAlign: TextAlign.center,
                            style: AppType.body(
                              const TextStyle(
                                fontSize: 15,
                                height: 1.6,
                                color: MohajonWarm.muted,
                              ),
                              locale: locale,
                            ),
                          ),
                          const SizedBox(height: 26),
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: MohajonWarm.card,
                              border: Border.all(color: MohajonWarm.goldBorder),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              children: [
                                _version(
                                  context,
                                  l10n.t('appUpdateCurrent'),
                                  decision.installed!.label,
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Divider(
                                    height: 1,
                                    color: MohajonWarm.goldBorder,
                                  ),
                                ),
                                _version(
                                  context,
                                  l10n.t('appUpdateLatest'),
                                  '${policy.latestVersion} (${policy.latestBuildNumber})',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 26),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: busy ? null : onUpdate,
                              style: FilledButton.styleFrom(
                                backgroundColor: MohajonWarm.primary,
                                foregroundColor: MohajonWarm.ink,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 17,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: const Icon(Icons.download_rounded),
                              label: Text(
                                l10n.t(
                                  busy ? 'appUpdateStarting' : 'appUpdateNow',
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: busy ? null : onRetry,
                            child: Text(
                              l10n.t('appUpdateAgain'),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          if (message != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(
                                message!,
                                textAlign: TextAlign.center,
                                style: AppType.body(
                                  const TextStyle(
                                    fontSize: 13,
                                    color: MohajonWarm.goldText,
                                  ),
                                  locale: locale,
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.t('appUpdateStoreHint'),
                            textAlign: TextAlign.center,
                            style: AppType.body(
                              const TextStyle(
                                fontSize: 12,
                                height: 1.5,
                                color: MohajonWarm.muted,
                              ),
                              locale: locale,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _version(BuildContext context, String label, String value) {
    final locale = AppLocalizations.of(context).locale;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: AppType.body(
              const TextStyle(color: MohajonWarm.muted, fontSize: 13),
              locale: locale,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: AppType.body(
              const TextStyle(
                color: MohajonWarm.ink,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              locale: locale,
            ),
          ),
        ),
      ],
    );
  }
}
