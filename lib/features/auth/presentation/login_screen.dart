import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_shell.dart';
import '../../../core/app/app_providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/async_action_state.dart';
import '../providers/auth_providers.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';

enum _LoginMode { email, phone }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with AsyncActionState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController(text: '+880');
  final _otp = TextEditingController();
  bool _obscurePassword = true;
  String? _verificationId;
  String? _message;
  bool _messageIsError = true;
  _LoginMode _mode = _LoginMode.email;
  Timer? _otpTimer;
  int _otpSecondsRemaining = 0;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    _otp.dispose();
    _otpTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return withLoadingOverlay(
      Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFEFFAF5), Color(0xFFFFFFFF), Color(0xFFFFF7ED)],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWide ? 32 : 16,
                    vertical: isWide ? 28 : 16,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1040),
                        child: Flex(
                          direction: isWide ? Axis.horizontal : Axis.vertical,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (isWide) const Expanded(child: _BrandPanel()),
                            if (isWide) const SizedBox(width: 24),
                            SizedBox(
                              width: isWide ? 440 : double.infinity,
                              child: _LoginPanel(
                                mode: _mode,
                                message: _message,
                                messageIsError: _messageIsError,
                                onModeChanged: (mode) {
                                  setState(() {
                                    _mode = mode;
                                    _message = null;
                                  });
                                },
                                emailForm: _buildEmailForm(context),
                                phoneForm: _buildPhoneForm(context),
                                onGoogleSignIn: isBusy
                                    ? null
                                    : _signInWithGoogle,
                                onSignup: isBusy ? null : _openSignup,
                                onForgotPassword: isBusy
                                    ? null
                                    : _openForgotPassword,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
      label: 'Signing in...',
    );
  }

  Widget _buildEmailForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(
            labelText: 'Email address',
            hintText: 'you@example.com',
            prefixIcon: Icon(Icons.alternate_email_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => isBusy ? null : _signInWithEmail(),
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              tooltip: _obscurePassword ? 'Show password' : 'Hide password',
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: isBusy ? null : _signInWithEmail,
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('Sign in securely'),
        ),
      ],
    );
  }

  Widget _buildPhoneForm(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          decoration: const InputDecoration(
            labelText: 'Phone number',
            hintText: '+8801XXXXXXXXX',
            prefixIcon: Icon(Icons.phone_iphone_rounded),
          ),
        ),
        const SizedBox(height: 12),
        if (_verificationId != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _otp,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => isBusy ? null : _submit(),
                decoration: const InputDecoration(
                  labelText: 'OTP code',
                  hintText: 'Enter 6 digit code',
                  prefixIcon: Icon(Icons.password_rounded),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.timer_outlined, size: 16, color: colors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'OTP expires in ${_otpCountdownText()}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        if (_verificationId == null &&
            _otpSecondsRemaining == 0 &&
            _otp.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'OTP expired. Request a new code to continue.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: isBusy ? null : _submit,
          icon: Icon(
            _verificationId == null
                ? Icons.sms_outlined
                : Icons.verified_user_outlined,
          ),
          label: Text(_verificationId == null ? 'Send OTP' : 'Verify OTP'),
        ),
      ],
    );
  }

  void _setMessage(String message, {bool isError = true}) {
    if (!mounted) return;
    setState(() {
      _message = message;
      _messageIsError = isError;
    });
  }

  bool _validateEmailInput() {
    final email = _email.text.trim();
    if (email.isEmpty) {
      _setMessage('Enter your email address to sign in.');
      return false;
    }
    if (!email.contains('@') || !email.contains('.')) {
      _setMessage('Enter a valid email address, for example name@gmail.com.');
      return false;
    }
    if (_password.text.isEmpty) {
      _setMessage('Enter your password to continue.');
      return false;
    }
    return true;
  }

  bool _validatePhoneInput() {
    final phone = _phone.text.trim();
    if (phone.isEmpty || phone == '+880') {
      _setMessage('Enter your phone number to receive an OTP.');
      return false;
    }
    if (!phone.startsWith('+')) {
      _setMessage(
        'Use country code with your phone number, like +8801XXXXXXXXX.',
      );
      return false;
    }
    if (_verificationId != null && _otp.text.trim().length < 4) {
      _setMessage('Enter the OTP code sent to your phone.');
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_validatePhoneInput()) return;
    await runBusyAction(() async {
      setState(() => _message = null);
      try {
        if (_verificationId == null) {
          await ref
              .read(authServiceProvider)
              .sendOtp(
                phone: _phone.text.trim(),
                onCodeSent: (id) {
                  if (!mounted) return;
                  setState(() {
                    _verificationId = id;
                    _otp.clear();
                    _message = 'OTP sent. Check your phone messages.';
                    _messageIsError = false;
                  });
                  _startOtpTimer();
                },
                onError: (message) => _setMessage(message),
              );
        } else {
          if (_otpSecondsRemaining <= 0) {
            setState(() {
              _verificationId = null;
              _message = 'OTP expired. Please request a new code.';
              _messageIsError = true;
            });
            return;
          }
          await ref
              .read(authServiceProvider)
              .verifyOtp(
                verificationId: _verificationId!,
                smsCode: _otp.text.trim(),
                phone: _phone.text.trim(),
              );
          if (mounted) _openApp();
          _otpTimer?.cancel();
        }
      } catch (error) {
        _setMessage(authErrorMessage(error));
      }
    });
  }

  Future<void> _signInWithEmail() async {
    if (!_validateEmailInput()) return;
    await runBusyAction(() async {
      setState(() => _message = null);
      try {
        await ref
            .read(authServiceProvider)
            .signInWithEmail(email: _email.text, password: _password.text);
        if (mounted) _openApp();
      } catch (error) {
        _setMessage(authErrorMessage(error));
      }
    });
  }

  Future<void> _signInWithGoogle() async {
    await runBusyAction(() async {
      setState(() => _message = null);
      try {
        await ref.read(authServiceProvider).signInWithGoogle();
        if (mounted) _openApp();
      } catch (error) {
        _setMessage(authErrorMessage(error));
      }
    });
  }

  void _openApp() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => AppShell(key: ValueKey(ref.read(shopIdProvider))),
      ),
    );
  }

  void _startOtpTimer() {
    _otpTimer?.cancel();
    setState(() => _otpSecondsRemaining = 120);
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_otpSecondsRemaining <= 1) {
        timer.cancel();
        setState(() {
          _otpSecondsRemaining = 0;
          _verificationId = null;
          _message = 'OTP expired. Please request a new code.';
          _messageIsError = true;
        });
        return;
      }
      setState(() => _otpSecondsRemaining--);
    });
  }

  String _otpCountdownText() {
    final minutes = _otpSecondsRemaining ~/ 60;
    final seconds = _otpSecondsRemaining % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _openSignup() async {
    final email = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const SignupScreen()));
    if (email != null && mounted) {
      _email.text = email;
      setState(() {
        _mode = _LoginMode.email;
        _message = 'Email verified? Enter your password to sign in.';
        _messageIsError = false;
      });
    }
  }

  void _openForgotPassword() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ForgotPasswordScreen(initialEmail: _email.text),
      ),
    );
  }
}

class _LoginPanel extends StatelessWidget {
  const _LoginPanel({
    required this.mode,
    required this.message,
    required this.messageIsError,
    required this.onModeChanged,
    required this.emailForm,
    required this.phoneForm,
    required this.onGoogleSignIn,
    required this.onSignup,
    required this.onForgotPassword,
  });

  final _LoginMode mode;
  final String? message;
  final bool messageIsError;
  final ValueChanged<_LoginMode> onModeChanged;
  final Widget emailForm;
  final Widget phoneForm;
  final VoidCallback? onGoogleSignIn;
  final VoidCallback? onSignup;
  final VoidCallback? onForgotPassword;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 12,
      shadowColor: colors.shadow.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const _MobileBrandHeader(),
            Text(
              'Welcome back',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'Sign in to manage sales, inventory, customers, and dues.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            SegmentedButton<_LoginMode>(
              segments: const [
                ButtonSegment(
                  value: _LoginMode.email,
                  icon: Icon(Icons.mail_outline_rounded),
                  label: Text('Email'),
                ),
                ButtonSegment(
                  value: _LoginMode.phone,
                  icon: Icon(Icons.sms_outlined),
                  label: Text('Phone OTP'),
                ),
              ],
              selected: {mode},
              showSelectedIcon: false,
              onSelectionChanged: (selection) => onModeChanged(selection.first),
            ),
            const SizedBox(height: 18),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: KeyedSubtree(
                key: ValueKey(mode),
                child: mode == _LoginMode.email ? emailForm : phoneForm,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: Divider(color: colors.outlineVariant)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'or',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: colors.outlineVariant)),
              ],
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onGoogleSignIn,
              icon: const _GoogleIcon(),
              label: const Text('Continue with Gmail'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 50),
                foregroundColor: colors.onSurface,
                side: BorderSide(color: colors.outline),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 16),
              _MessageBanner(message: message!, isError: messageIsError),
            ],
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: [
                TextButton(
                  onPressed: onSignup,
                  child: const Text('Create account'),
                ),
                Text('|', style: TextStyle(color: colors.outline)),
                TextButton(
                  onPressed: onForgotPassword,
                  child: const Text('Forgot password?'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF0F3D2E),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.14),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const _AppMark(size: 54),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  AppConstants.appName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 44),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your shop dashboard starts here.',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Secure access for sales, stock, receipts, customers, payments, and owner investments.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _FeaturePill(icon: Icons.inventory_2_outlined, label: 'Stock'),
              _FeaturePill(icon: Icons.point_of_sale_rounded, label: 'POS'),
              _FeaturePill(
                icon: Icons.receipt_long_outlined,
                label: 'Receipts',
              ),
              _FeaturePill(icon: Icons.groups_2_outlined, label: 'Customers'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MobileBrandHeader extends StatelessWidget {
  const _MobileBrandHeader();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 420) return const SizedBox.shrink();
        return const Column(
          children: [_AppMark(size: 58), SizedBox(height: 14)],
        );
      },
    );
  }
}

class _AppMark extends StatelessWidget {
  const _AppMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Center(
        child: Text(
          'HB',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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
    final tone = isError ? colors.error : colors.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tone.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline,
            color: tone,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: tone,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _GoogleIconPainter()),
    );
  }
}

class _GoogleIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.17;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(strokeWidth / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(arcRect, -0.05, 1.45, false, paint);
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(arcRect, 1.45, 1.25, false, paint);
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(arcRect, 2.7, 1.05, false, paint);
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(arcRect, 3.75, 1.4, false, paint);

    final centerY = size.height * 0.52;
    paint
      ..color = const Color(0xFF4285F4)
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(
      Offset(size.width * 0.52, centerY),
      Offset(size.width * 0.92, centerY),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.88, centerY),
      Offset(size.width * 0.88, size.height * 0.42),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
