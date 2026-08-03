import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import '../../../core/widgets/action_button.dart';

/// Prompts the user for the 6-digit email verification code sent by the
/// custom auth service. Returns true when the email got verified.
Future<bool> showEmailVerificationDialog(
  BuildContext context,
  WidgetRef ref, {
  required String email,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _EmailVerificationDialog(email: email),
  );
  return result ?? false;
}

class _EmailVerificationDialog extends ConsumerStatefulWidget {
  const _EmailVerificationDialog({required this.email});

  final String email;

  @override
  ConsumerState<_EmailVerificationDialog> createState() =>
      _EmailVerificationDialogState();
}

class _EmailVerificationDialogState
    extends ConsumerState<_EmailVerificationDialog> {
  final _codeController = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _success = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter the verification code from your email.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authServiceProvider)
          .verifyEmail(email: widget.email, code: code);
      if (!mounted) return;
      setState(() => _success = true);
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authServiceProvider)
          .sendEmailVerificationCode(widget.email);
      if (mounted) {
        setState(() => _error = 'A fresh code was sent to your email.');
      }
    } catch (error) {
      if (mounted) setState(() => _error = authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: _success,
      child: AlertDialog(
        title: const Text('Verify your email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'We sent a 6-digit code to ${widget.email}. Enter it below to '
              'finish creating your account.',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _codeController,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Verification code',
                prefixIcon: Icon(Icons.sms_outlined),
                counterText: '',
              ),
              onSubmitted: (_) => _verify(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: colors.error, fontSize: 13),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : _resend,
            child: const Text('Resend code'),
          ),
          TextButton(
            onPressed: _busy || _success
                ? null
                : () => Navigator.of(context).pop(false),
            child: const Text('Skip for now'),
          ),
          ActionButton(
            onPressed: _busy ? null : _verify,
            isBusy: _busy,
            label: 'Verify',
            busyLabel: 'Verifying...',
          ),
        ],
      ),
    );
  }
}
