import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/async_action_state.dart';
import 'auth_brand.dart';
import '../providers/auth_providers.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen>
    with AsyncActionState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email;
  final _code = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  String? _message;
  bool _messageIsError = false;
  bool _sent = false;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail.trim());
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return withLoadingOverlay(
      Theme(
        data: AuthBrand.theme(Theme.of(context)),
        child: Scaffold(
          backgroundColor: AuthBrand.backgroundColor,
          body: Stack(
            children: [
              const Positioned.fill(child: AuthDecorativeBackdrop()),
              SafeArea(
                // The photo header supplies its own top inset so it can run
                // edge-to-edge, under the status bar, instead of leaving a
                // strip of page gradient above it.
                top: false,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxHeight < 740;
                    return SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.only(bottom: compact ? 22 : 34),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 460),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AuthPhotoHeader(
                                topInset: MediaQuery.paddingOf(context).top,
                                minHeight: compact ? 150 : 170,
                                child: const AuthBackButton(),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: _buildCard(context),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      label: 'Sending...',
    );
  }

  Widget _buildCard(BuildContext context) {
    final bangla = ref.watch(localeProvider).languageCode == 'bn';
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthHeading(
            title: _completed
                ? (bangla ? 'পাসওয়ার্ড আপডেট হয়েছে' : 'Password updated')
                : (_sent
                      ? (bangla ? 'রিসেট কোড লিখুন' : 'Enter reset code')
                      : (bangla ? 'পাসওয়ার্ড রিসেট করুন' : 'Reset password')),
            subtitle: _sent
                ? (bangla
                      ? 'ইমেইলে পাঠানো কোড লিখে নতুন পাসওয়ার্ড নির্বাচন করুন।'
                      : 'Enter the code from your email and choose a new password.')
                : (bangla
                      ? 'রেজিস্টার করা ইমেইল লিখলে আমরা রিসেট কোড পাঠাব।'
                      : 'Enter your registered email and we will send you a reset link.'),
          ),
          if (_sent) ...[
            const SizedBox(height: 14),
            TextFormField(
              controller: _code,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              maxLength: 6,
              decoration: AuthFieldDecoration(
                hint: bangla ? '৬ সংখ্যার রিসেট কোড' : '6-digit reset code',
                icon: Icons.pin_outlined,
              ).copyWith(counterText: ''),
              validator: (value) => (value?.trim().length ?? 0) == 6
                  ? null
                  : (bangla
                        ? '৬ সংখ্যার রিসেট কোড লিখুন'
                        : 'Enter the 6-digit reset code'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _newPassword,
              obscureText: true,
              textInputAction: TextInputAction.next,
              decoration: AuthFieldDecoration(
                hint: bangla ? 'নতুন পাসওয়ার্ড' : 'New password',
                icon: Icons.lock_outline_rounded,
              ),
              validator: (value) => (value?.length ?? 0) >= 6
                  ? null
                  : (bangla
                        ? 'কমপক্ষে ৬টি অক্ষর ব্যবহার করুন'
                        : 'Use at least 6 characters'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirmPassword,
              obscureText: true,
              textInputAction: TextInputAction.done,
              decoration: AuthFieldDecoration(
                hint: bangla
                    ? 'নতুন পাসওয়ার্ড নিশ্চিত করুন'
                    : 'Confirm new password',
                icon: Icons.lock_reset_outlined,
              ),
              validator: (value) => value == _newPassword.text
                  ? null
                  : (bangla ? 'পাসওয়ার্ড মিলছে না' : 'Passwords do not match'),
            ),
          ],
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            enabled: !_sent,
            decoration: AuthFieldDecoration(
              hint: bangla ? 'ইমেইল' : 'Email address',
              icon: Icons.alternate_email_rounded,
            ),
            validator: _validateEmail,
            onFieldSubmitted: (_) => _send(),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _message == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: _MessageBanner(
                      message: _message!,
                      isError: _messageIsError,
                    ),
                  ),
          ),
          const SizedBox(height: 18),
          _PrimaryActionButton(
            onPressed: _completed
                ? () => Navigator.of(context).maybePop()
                : (_sent ? _reset : _send),
            isBusy: isBusy,
            icon: _completed ? Icons.arrow_back_rounded : Icons.lock_reset,
            label: _completed
                ? (bangla ? 'সাইন ইন-এ ফিরুন' : 'Back to sign in')
                : (_sent
                      ? (bangla ? 'পাসওয়ার্ড রিসেট করুন' : 'Reset password')
                      : (bangla ? 'রিসেট কোড পাঠান' : 'Send reset code')),
            busyLabel: _sent ? 'Updating...' : 'Sending...',
          ),
          if (!_sent || _completed) ...[
            const SizedBox(height: 6),
            AuthFooterLink(
              prompt: bangla
                  ? 'পাসওয়ার্ড মনে পড়েছে?'
                  : 'Remembered your password?',
              action: bangla ? 'সাইন ইন' : 'Sign in',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ],
      ),
    );
  }

  /// Rejects an empty or malformed address before it can reach the API.
  ///
  /// Without this the field submitted whatever happened to be typed, including
  /// nothing at all, and the backend replied with a bare "Invalid request
  /// payload" that named neither the field nor the problem.
  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Please enter your email address';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  Future<void> _send() async {
    if (_sent) return;
    // Validating again here, rather than relying on the field alone, means the
    // action button and the keyboard's done key behave identically and the
    // request is never fired with an unusable address.
    final form = _formKey.currentState;
    if (form != null && !form.validate()) return;
    final email = _email.text.trim();
    await runBusyAction(() async {
      setState(() => _message = null);
      try {
        await ref.read(authServiceProvider).sendPasswordResetEmail(email);
        if (mounted) {
          setState(() {
            _sent = true;
            _messageIsError = false;
            _message = 'Reset code sent to $email. It expires in 3 minutes.';
          });
        }
      } catch (error) {
        if (mounted) {
          setState(() {
            _message = authErrorMessage(
              error,
              l10n: AppLocalizations.of(context),
            );
            _messageIsError = true;
          });
        }
      }
    });
  }

  Future<void> _reset() async {
    final form = _formKey.currentState;
    if (form != null && !form.validate()) return;
    await runBusyAction(() async {
      setState(() => _message = null);
      try {
        await ref
            .read(authServiceProvider)
            .resetPassword(
              email: _email.text.trim(),
              code: _code.text.trim(),
              newPassword: _newPassword.text,
            );
        if (mounted) {
          setState(() {
            _completed = true;
            _messageIsError = false;
            _message = 'Password updated successfully.';
          });
        }
      } catch (error) {
        if (mounted) {
          setState(() {
            _message = authErrorMessage(
              error,
              l10n: AppLocalizations.of(context),
            );
            _messageIsError = true;
          });
        }
      }
    });
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.isBusy = false,
    this.busyLabel,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final bool isBusy;
  final String? busyLabel;

  @override
  Widget build(BuildContext context) {
    final disabled = isBusy || onPressed == null;
    return Material(
      color: Colors.transparent,
      borderRadius: AuthBrand.buttonRadius,
      child: Ink(
        height: 58,
        decoration: BoxDecoration(
          borderRadius: AuthBrand.buttonRadius,
          gradient: disabled ? null : AuthBrand.gradient,
          color: disabled ? AuthBrand.buttonDisabled : null,
        ),
        child: InkWell(
          borderRadius: AuthBrand.buttonRadius,
          onTap: disabled ? null : onPressed,
          child: SizedBox(
            height: 58,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (!disabled)
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AuthBrand.buttonSheen,
                      ),
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isBusy ? (busyLabel ?? 'Sending...') : label,
                      style: TextStyle(
                        color: disabled
                            ? AuthBrand.onGradient.withValues(alpha: 0.40)
                            : AuthBrand.onGradient,
                        fontWeight: FontWeight.w600,
                        fontSize: 15.5,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(width: 10),
                    isBusy
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: disabled
                                  ? AuthBrand.onGradient.withValues(alpha: 0.40)
                                  : AuthBrand.onGradient,
                            ),
                          )
                        : Icon(icon, color: Colors.white, size: 20),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tone = isError ? colors.error : AuthBrand.secondary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone.withValues(alpha: .25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline,
            color: tone,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: tone,
                fontWeight: FontWeight.w700,
                height: 1.35,
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
