import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/action_button.dart';
import '../../../core/widgets/async_action_state.dart';
import '../../auth/providers/auth_providers.dart';
import '../../../core/app/app_providers.dart';
import '../../../core/widgets/app_icon_asset.dart';
import '../../../core/widgets/flaticon_icons.dart';

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
    final colors = Theme.of(context).colorScheme;

    return withLoadingOverlay(
      Scaffold(
        appBar: AppBar(title: const Text('Account security')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      hasPassword ? 'Change password' : 'Set password',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hasPassword
                          ? 'Enter your current password and choose a new one.'
                          : 'Your account is signed in with Gmail. Set a password to also login with email and password.',
                    ),
                    const SizedBox(height: 16),
                    if (hasPassword) ...[
                      TextField(
                        controller: _currentPassword,
                        obscureText: _obscure,
                        decoration: const InputDecoration(
                          labelText: 'Previous password',
                          prefixIcon: Padding(padding: EdgeInsets.all(12), child: AppIconAsset(assetPath: FlaticonIcons.lock_clock_outlined, size: 20, color: Color(0xFF98A2B3))),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: _newPassword,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'New password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? FlaticonIcons.eye
                                : FlaticonIcons.eye,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmPassword,
                      obscureText: _obscure,
                      decoration: const InputDecoration(
                        labelText: 'Confirm password',
                        prefixIcon: Padding(padding: EdgeInsets.all(12), child: AppIconAsset(assetPath: FlaticonIcons.lock_reset_outlined, size: 20, color: Color(0xFF98A2B3))),
                      ),
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _message!,
                        style: TextStyle(
                          color: _success ? colors.primary : colors.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    ActionButton(
                      onPressed: hasPassword ? _changePassword : _setPasswordForGoogle,
                      isBusy: isBusy,
                      icon: FlaticonIcons.save,
                      label: hasPassword ? 'Update password' : 'Set password',
                      busyLabel: 'Saving...',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      label: 'Updating...',
    );
  }

  String? _validateNewPassword() {
    if (_newPassword.text.length < 6) return 'Use at least 6 characters.';
    if (_newPassword.text != _confirmPassword.text) {
      return 'Passwords do not match.';
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
        if (mounted) _showSuccess('Password updated.');
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
        if (mounted) _showSuccess('Password login enabled for this account.');
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
