import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/action_button.dart';
import '../../../core/widgets/async_action_state.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/app/app_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../../../core/theme/mohajon_warm_theme.dart';

class AccountSecurityScreen extends ConsumerStatefulWidget {
  const AccountSecurityScreen({super.key});

  @override
  ConsumerState<AccountSecurityScreen> createState() =>
      _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends ConsumerState<AccountSecurityScreen>
    with AsyncActionState<AccountSecurityScreen> {
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  String? _message;
  bool _success = false;
  bool _obscure = true;

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authStateProvider).value;
    final hasPassword = session == null || session.provider != 'google';
    final l10n = AppLocalizations.of(context);

    return Theme(
      data: MohajonWarm.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: MohajonWarm.pageGradient),
          child: SafeArea(
            child: Column(
              children: [
                _Header(
                  onBack: () => Navigator.of(context).pop(),
                  title: hasPassword
                      ? l10n.t('changePassword')
                      : l10n.t('setPassword'),
                  subtitle: l10n.t('keepAccountSecure'),
                  icon: Icons.shield_outlined,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: MohajonWarm.card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: MohajonWarm.goldBorder),
                          boxShadow: [
                            BoxShadow(
                              color: MohajonWarm.ink.withValues(alpha: 0.06),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              hasPassword
                                  ? l10n.t('updateYourPassword')
                                  : l10n.t('createPassword'),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: MohajonWarm.ink,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              hasPassword
                                  ? l10n.t('existingPwDesc')
                                  : l10n.t('gmailPasswordInfo'),
                              style: const TextStyle(
                                fontSize: 12,
                                color: MohajonWarm.muted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 18),
                            if (hasPassword) ...[
                              _Field(
                                controller: _currentPassword,
                                label: l10n.t('currentPasswordField'),
                                icon: Icons.lock_outline_rounded,
                                obscure: _obscure,
                                onToggle: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                              const SizedBox(height: 14),
                            ],
                            _Field(
                              controller: _newPassword,
                              label: l10n.t('newPasswordField'),
                              icon: Icons.lock_rounded,
                              obscure: _obscure,
                              onToggle: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                            const SizedBox(height: 14),
                            _Field(
                              controller: _confirmPassword,
                              label: l10n.t('confirmPasswordField'),
                              icon: Icons.lock_reset_rounded,
                              obscure: _obscure,
                              onToggle: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                            if (_message != null) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: (_success
                                          ? MohajonWarm.green
                                          : Theme.of(context).colorScheme.error)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _success
                                          ? Icons.check_circle_rounded
                                          : Icons.error_outline_rounded,
                                      size: 18,
                                      color: _success
                                          ? MohajonWarm.green
                                          : Theme.of(context).colorScheme.error,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _message!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: _success
                                              ? MohajonWarm.green
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .error,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            ActionButton(
                              onPressed: () {
                                if (hasPassword) {
                                  _changePassword();
                                } else {
                                  _setPasswordForGoogle();
                                }
                              },
                              isBusy: isBusy,
                              icon: Icons.save_alt_rounded,
                              label: hasPassword
                                  ? l10n.t('updatePassword')
                                  : l10n.t('setPasswordBtn'),
                              busyLabel: l10n.t('saving'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _validateNewPassword() {
    final l10n = AppLocalizations.of(context);
    if (_newPassword.text.length < 6) return l10n.t('atLeast6Chars');
    if (_newPassword.text != _confirmPassword.text) {
      return l10n.t('passwordsDoNotMatch');
    }
    return null;
  }

  Future<void> _changePassword() async {
    final validation = _validateNewPassword();
    if (validation != null) {
      setState(() {
        _success = false;
        _message = validation;
      });
      return;
    }
    await runBusyAction(() async {
      try {
        await ref
            .read(authServiceProvider)
            .changePassword(
              currentPassword: _currentPassword.text,
              newPassword: _newPassword.text,
            );
        if (mounted) _showSuccess(AppLocalizations.of(context).t('passwordUpdated'));
      } catch (error) {
        if (mounted) _showError(authErrorMessage(error));
      }
    });
  }

  Future<void> _setPasswordForGoogle() async {
    final validation = _validateNewPassword();
    if (validation != null) {
      setState(() {
        _success = false;
        _message = validation;
      });
      return;
    }
    await runBusyAction(() async {
      try {
        await ref
            .read(authServiceProvider)
            .setPasswordForGoogleAccount(_newPassword.text);
        if (mounted) {
          _showSuccess(
              AppLocalizations.of(context).t('passwordLoginEnabled'));
        }
      } catch (error) {
        if (mounted) _showError(authErrorMessage(error));
      }
    });
  }

  void _showSuccess(String message) {
    _currentPassword.clear();
    _newPassword.clear();
    _confirmPassword.clear();
    setState(() {
      _success = true;
      _message = message;
    });
  }

  void _showError(String message) {
    setState(() {
      _success = false;
      _message = message;
    });
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onBack,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final VoidCallback onBack;
  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
      child: Row(
        children: [
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(11),
            child: InkWell(
              borderRadius: BorderRadius.circular(11),
              onTap: onBack,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: MohajonWarm.goldBorder),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: MohajonWarm.ink,
                  size: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [MohajonWarm.primary, MohajonWarm.primaryPale],
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: MohajonWarm.primary.withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: MohajonWarm.ink, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: MohajonWarm.ink,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF77735F),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    required this.obscure,
    required this.onToggle,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: MohajonWarm.ink,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: MohajonWarm.primary, size: 20),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: MohajonWarm.muted,
          ),
        ),
      ),
    );
  }
}
