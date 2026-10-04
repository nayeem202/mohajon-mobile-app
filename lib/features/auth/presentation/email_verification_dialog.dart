import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import 'auth_brand.dart';

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
  final _codeFocus = FocusNode();
  String? _error;
  bool _notice = false;
  bool _busy = false;
  bool _success = false;
  Timer? _countdownTimer;
  Duration _codeRemaining = const Duration(minutes: 3);
  int _resendRemaining = 30;

  bool get _codeExpired => _codeRemaining == Duration.zero;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _codeRemaining = const Duration(minutes: 3);
    _resendRemaining = 30;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final nextCode = _codeRemaining - const Duration(seconds: 1);
      setState(() {
        _codeRemaining = nextCode.isNegative ? Duration.zero : nextCode;
        _resendRemaining = _resendRemaining > 0 ? _resendRemaining - 1 : 0;
      });
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _codeController.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (_codeExpired) {
      setState(() {
        _error = 'This code has expired. Please resend a new code.';
        _notice = false;
      });
      return;
    }
    if (code.isEmpty) {
      setState(() {
        _error = 'Enter the 6-digit code';
        _notice = false;
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _notice = false;
    });

    try {
      await ref
          .read(authServiceProvider)
          .verifyEmail(email: widget.email, code: code);
      if (mounted) {
        setState(() {
          _success = true;
          _error = null;
        });
        await Future.delayed(const Duration(milliseconds: 350));
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _notice = false;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_resendRemaining > 0) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = false;
    });
    try {
      await ref.read(authServiceProvider).sendEmailVerificationCode(widget.email);
      if (mounted) {
        setState(() {
          _error = 'Code resent to ${widget.email}';
          _notice = true;
        });
        _startCountdown();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _notice = false;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final media = MediaQuery.of(context);
    final availableHeight = media.size.height - media.viewInsets.bottom - 32;
    final dialogHeight = (availableHeight * .84).clamp(300.0, 520.0).toDouble();

    return PopScope(
      canPop: _success,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SizedBox(
            height: dialogHeight,
            child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AuthBrand.panelBackground,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: AuthBrand.buttonGlow.withValues(alpha: .22),
                  blurRadius: 40,
                  offset: const Offset(0, 18),
                ),
                BoxShadow(
                  color: AuthBrand.panelText.withValues(alpha: .10),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(email: widget.email, locale: locale),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Enter the 6-digit code we emailed you to confirm this address and finish setting up your account.',
                          textAlign: TextAlign.center,
                          style: AppType.body(
                            const TextStyle(
                              color: AuthBrand.panelMuted,
                              fontSize: 14.5,
                              height: 1.45,
                            ),
                            locale: locale,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _CodeField(
                          controller: _codeController,
                          focusNode: _codeFocus,
                          locale: locale,
                          onSubmitted: (_) => _verify(),
                        ),
                        const SizedBox(height: 10),
                        Builder(
                          builder: (context) {
                            final bangla =
                                Localizations.localeOf(context).languageCode ==
                                'bn';
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _codeExpired
                                      ? Icons.error_outline_rounded
                                      : Icons.timer_outlined,
                                  size: 16,
                                  color: _codeExpired
                                      ? AuthBrand.danger
                                      : AuthBrand.primaryDeep,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _codeExpired
                                      ? (bangla
                                            ? 'কোডের মেয়াদ শেষ হয়েছে'
                                            : 'Code expired')
                                      : (bangla
                                            ? 'কোডের মেয়াদ শেষ হবে ${_formatDuration(_codeRemaining)} পরে'
                                            : 'Code expires in ${_formatDuration(_codeRemaining)}'),
                                  style: TextStyle(
                                    color: _codeExpired
                                        ? AuthBrand.danger
                                        : AuthBrand.panelMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.topCenter,
                          child: _error == null
                              ? const SizedBox(width: double.infinity)
                              : Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: _StatusLine(
                                    message: _error!,
                                    isNotice: _notice,
                                    locale: locale,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 20),
                        _VerifyButton(
                          busy: _busy,
                          enabled: !_codeExpired,
                          label: 'Verify & continue',
                          onPressed: _verify,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: _busy || _resendRemaining > 0
                                    ? null
                                    : _resend,
                                style: TextButton.styleFrom(
                                  foregroundColor: AuthBrand.primaryDeep,
                                  disabledForegroundColor: AuthBrand.panelMuted
                                      .withValues(alpha: .45),
                                ),
                                child: Text(
                                  _resendRemaining > 0
                                      ? 'Resend in ${_resendRemaining}s'
                                      : 'Resend code',
                                ),
                              ),
                            ),
                            Container(
                              height: 18,
                              width: 1,
                              color: AuthBrand.fieldBorder,
                            ),
                            Expanded(
                              child: TextButton(
                                onPressed: _busy || _success
                                    ? null
                                    : () => Navigator.of(context).pop(false),
                                style: TextButton.styleFrom(
                                  foregroundColor: AuthBrand.panelMuted,
                                  disabledForegroundColor: AuthBrand.panelMuted
                                      .withValues(alpha: .45),
                                ),
                                child: const Text('Skip for now'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Gold banner across the top of the card: an emblem disc, the title, and the
/// address the code went to. Rounded only at the top so it meets the card
/// corners exactly.
class _Header extends StatelessWidget {
  const _Header({required this.email, required this.locale});

  final String email;
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AuthBrand.gradient),
      child: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: AuthBrand.buttonSheen),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
            child: Column(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .58),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .75),
                      width: 1.2,
                    ),
                  ),
                  child: const Icon(
                    Icons.mark_email_read_rounded,
                    color: AuthBrand.primaryDeep,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Verify your email',
                  style: AppType.heading(
                    const TextStyle(
                      color: AuthBrand.onGradient,
                      fontSize: 21,
                      letterSpacing: .1,
                    ),
                    locale: locale,
                    weight: AppType.buttonWeight,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  email,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body(
                    // Deepened from the button label: pure espresso on gold
                    // drops under 4.5:1 for body-sized text.
                    const TextStyle(
                      color: Color(0xFF6A5216),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    locale: locale,
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

/// The 6-digit code input.
///
/// Deliberately not [AuthFieldDecoration]: a code is read as a single centred
/// token, so it is centred, monospaced by letter spacing and given a taller
/// frame than the text fields on the form behind it.
class _CodeField extends StatelessWidget {
  const _CodeField({
    required this.controller,
    required this.focusNode,
    required this.locale,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Locale? locale;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: true,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      textInputAction: TextInputAction.done,
      onSubmitted: onSubmitted,
      maxLength: 6,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        // Spaces are common in emailed codes ("123 456"); drop them so the
        // user can paste the code exactly as it appears.
        FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
      ],
      style: AppType.heading(
        const TextStyle(
          color: AuthBrand.panelText,
          fontSize: 24,
          letterSpacing: 10,
          fontWeight: FontWeight.w700,
        ),
        locale: locale,
        weight: AppType.buttonWeight,
      ),
      decoration: InputDecoration(
        counterText: '',
        hintText: '- - - - - -',
        hintStyle: AppType.heading(
          const TextStyle(
            color: Color(0xFFCBBD97),
            fontSize: 20,
            letterSpacing: 8,
          ),
          locale: locale,
          weight: AppType.buttonWeight,
        ),
        filled: true,
        fillColor: AuthBrand.fieldFill,
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
        floatingLabelBehavior: FloatingLabelBehavior.never,
        enabledBorder: const OutlineInputBorder(
          borderRadius: AuthBrand.fieldRadius,
          borderSide: BorderSide(color: AuthBrand.fieldBorder),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AuthBrand.fieldRadius,
          borderSide: BorderSide(color: AuthBrand.primary, width: 1.6),
        ),
      ),
    );
  }
}

/// Inline error / confirmation line under the code field.
class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.message,
    required this.isNotice,
    required this.locale,
  });

  final String message;
  final bool isNotice;
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    final color = isNotice ? MohajonWarm.green : AuthBrand.danger;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          isNotice ? Icons.check_circle_rounded : Icons.error_rounded,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: AppType.body(
              TextStyle(color: color, fontSize: 13),
              locale: locale,
            ),
          ),
        ),
      ],
    );
  }
}

/// Full-width gold action button, matching the primary buttons on the auth
/// screens so the dialog reads as part of the same kit.
class _VerifyButton extends StatelessWidget {
  const _VerifyButton({
    required this.busy,
    required this.enabled,
    required this.label,
    required this.onPressed,
  });

  final bool busy;
  final bool enabled;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AuthBrand.buttonRadius,
        gradient: AuthBrand.gradient,
        boxShadow: [
          BoxShadow(
            color: AuthBrand.buttonGlow.withValues(alpha: .38),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Ink(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: AuthBrand.buttonRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: .35),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: AuthBrand.buttonRadius,
          onTap: busy || !enabled ? null : onPressed,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(gradient: AuthBrand.buttonSheen),
              ),
              Center(
                child: busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AuthBrand.onGradient,
                        ),
                      )
                    : Text(
                        label,
                        style: AppType.heading(
                          const TextStyle(
                            color: AuthBrand.onGradient,
                            fontSize: 16,
                            letterSpacing: .4,
                          ),
                          locale: locale,
                          weight: AppType.buttonWeight,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
