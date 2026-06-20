import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    with AsyncActionState<LoginScreen>, TickerProviderStateMixin {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController(text: '+880');
  final _otp = TextEditingController();
  final _otpFocus = FocusNode();
  bool _obscurePassword = true;
  bool _rememberMe = true;
  String? _verificationId;
  String? _message;
  bool _messageIsError = true;
  _LoginMode _mode = _LoginMode.email;
  Timer? _otpTimer;
  int _otpSecondsRemaining = 0;
  late final AnimationController _ambientController;

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    _otp.dispose();
    _otpFocus.dispose();
    _otpTimer?.cancel();
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return withLoadingOverlay(
      Scaffold(
        body: Stack(
          children: [
            const _GradientBackdrop(),
            _AmbientBlobs(animation: _ambientController),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 900;
                  return SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isWide ? 32 : 18,
                      vertical: isWide ? 28 : 18,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1080),
                          child: Flex(
                            direction: isWide ? Axis.horizontal : Axis.vertical,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (isWide) const Expanded(child: _BrandPanel()),
                              if (isWide) const SizedBox(width: 28),
                              SizedBox(
                                width: isWide ? 460 : double.infinity,
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
          ],
        ),
      ),
      label: 'Signing in...',
    );
  }

  Widget _buildEmailForm(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: isBusy
                    ? null
                    : () => setState(() => _rememberMe = !_rememberMe),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        height: 22,
                        width: 22,
                        child: Checkbox(
                          value: _rememberMe,
                          onChanged: isBusy
                              ? null
                              : (value) => setState(
                                  () => _rememberMe = value ?? false,
                                ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Remember me',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _PrimaryActionButton(
          onPressed: isBusy ? null : _signInWithEmail,
          icon: Icons.arrow_forward_rounded,
          label: 'Sign in securely',
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
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _verificationId != null
              ? Column(
                  key: const ValueKey('otp'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _OtpSlotsField(
                      controller: _otp,
                      focusNode: _otpFocus,
                      onCompleted: (_) {
                        if (!isBusy) _submit();
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 16,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Expires in ${_otpCountdownText()}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: colors.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: isBusy ? null : _resendOtp,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Resend'),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : const SizedBox.shrink(key: ValueKey('no-otp')),
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
        _PrimaryActionButton(
          onPressed: isBusy ? null : _submit,
          icon: _verificationId == null
              ? Icons.sms_outlined
              : Icons.verified_user_outlined,
          label: _verificationId == null ? 'Send OTP' : 'Verify OTP',
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
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _otpFocus.requestFocus();
                  });
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

  Future<void> _resendOtp() async {
    setState(() {
      _verificationId = null;
      _otp.clear();
      _otpSecondsRemaining = 0;
      _message = null;
    });
    _otpTimer?.cancel();
    await _submit();
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

class _GradientBackdrop extends StatelessWidget {
  const _GradientBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFEAF7F1),
            Color(0xFFF6FBF9),
            Color(0xFFFFF6EC),
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}

class _AmbientBlobs extends StatelessWidget {
  const _AmbientBlobs({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = animation.value;
          return Stack(
            children: [
              Positioned(
                left: -120 + 30 * _wave(t, 0),
                top: -80 + 20 * _wave(t, 0.25),
                child: _Blob(
                  size: 320,
                  color: const Color(0xFF34D399).withValues(alpha: 0.28),
                ),
              ),
              Positioned(
                right: -100 + 24 * _wave(t, 0.5),
                top: 80 + 16 * _wave(t, 0.75),
                child: _Blob(
                  size: 260,
                  color: const Color(0xFFFBBF24).withValues(alpha: 0.22),
                ),
              ),
              Positioned(
                right: -60 + 18 * _wave(t, 0.1),
                bottom: -100 + 22 * _wave(t, 0.6),
                child: _Blob(
                  size: 300,
                  color: const Color(0xFF60A5FA).withValues(alpha: 0.18),
                ),
              ),
              Positioned(
                left: -40 + 16 * _wave(t, 0.85),
                bottom: -40 + 18 * _wave(t, 0.35),
                child: _Blob(
                  size: 220,
                  color: const Color(0xFF6EE7B7).withValues(alpha: 0.20),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  double _wave(double t, double phase) {
    return math.sin((t + phase) * 2 * math.pi);
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0.0)],
          stops: const [0.0, 1.0],
        ),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2EDE8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B1F17).withValues(alpha: 0.08),
            blurRadius: 36,
            spreadRadius: -6,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: const Color(0xFF34D399).withValues(alpha: 0.06),
            blurRadius: 24,
            spreadRadius: -8,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const _MobileBrandHeader(),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.shield_moon_outlined,
                        size: 14,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Secure login',
                        style: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Welcome back',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Sign in to manage sales, inventory, customers, and dues.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 22),
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
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: colors.primary.withValues(alpha: 0.10),
                selectedForegroundColor: colors.primary,
                foregroundColor: colors.onSurfaceVariant,
                side: BorderSide(
                  color: colors.outlineVariant.withValues(alpha: 0.9),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.04),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey(mode),
                  child: mode == _LoginMode.email ? emailForm : phoneForm,
                ),
              ),
            ),
            if (mode == _LoginMode.email) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onForgotPassword,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('Forgot password?'),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: Divider(color: colors.outlineVariant)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'or continue with',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: colors.outlineVariant)),
              ],
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onGoogleSignIn,
              icon: const _GoogleIcon(),
              label: const Text('Continue with Google'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 52),
                foregroundColor: colors.onSurface,
                side: BorderSide(color: colors.outline),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: message == null
                  ? const SizedBox(height: 0)
                  : Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: _MessageBanner(
                        message: message!,
                        isError: messageIsError,
                      ),
                    ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Don't have an account?",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                TextButton(
                  onPressed: onSignup,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text(
                    'Create one',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final disabled = onPressed == null;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: disabled
                ? [
                    colors.primary.withValues(alpha: 0.4),
                    colors.primary.withValues(alpha: 0.4),
                  ]
                : const [Color(0xFF059669), Color(0xFF0F766E)],
          ),
          boxShadow: disabled
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFF047857).withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: SizedBox(
            height: 52,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(icon, color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OtpSlotsField extends StatefulWidget {
  const _OtpSlotsField({
    required this.controller,
    required this.focusNode,
    required this.onCompleted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onCompleted;

  @override
  State<_OtpSlotsField> createState() => _OtpSlotsFieldState();
}

class _OtpSlotsFieldState extends State<_OtpSlotsField> {
  static const _length = 6;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onChange() {
    if (widget.controller.text.length == _length) {
      widget.onCompleted(widget.controller.text);
    }
    setState(() {});
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final value = widget.controller.text;
    final hasFocus = widget.focusNode.hasFocus;
    return Stack(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(_length, (i) {
            final char = i < value.length ? value[i] : '';
            final isActive = hasFocus && i == value.length;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == _length - 1 ? 0 : 8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isActive
                          ? colors.primary
                          : colors.outlineVariant.withValues(alpha: 0.9),
                      width: isActive ? 1.6 : 1.0,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: colors.primary.withValues(alpha: 0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    char,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: colors.onSurface,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        Positioned.fill(
          child: TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            maxLength: _length,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              color: Colors.transparent,
              height: 1,
            ),
            cursorColor: Colors.transparent,
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF064E3B),
                    Color(0xFF065F46),
                    Color(0xFF0F766E),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: -80,
            top: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.10),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: -60,
            bottom: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFBBF24).withValues(alpha: 0.18),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const _AppMark(size: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppConstants.appName,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.2,
                                ),
                          ),
                          Text(
                            AppConstants.appTagline,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your shop\ndashboard\nstarts here.',
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              height: 1.05,
                              letterSpacing: -0.5,
                            ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Track sales, stock, receipts, customers, payments and owner investments — online or offline.',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white.withValues(alpha: 0.82),
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: const [
                        _FeaturePill(
                          icon: Icons.inventory_2_outlined,
                          label: 'Stock',
                        ),
                        _FeaturePill(
                          icon: Icons.point_of_sale_rounded,
                          label: 'POS',
                        ),
                        _FeaturePill(
                          icon: Icons.receipt_long_outlined,
                          label: 'Receipts',
                        ),
                        _FeaturePill(
                          icon: Icons.groups_2_outlined,
                          label: 'Customers',
                        ),
                        _FeaturePill(
                          icon: Icons.payments_outlined,
                          label: 'Payments',
                        ),
                        _FeaturePill(
                          icon: Icons.cloud_off_rounded,
                          label: 'Offline-first',
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFFBBF24,
                              ).withValues(alpha: 0.20),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.workspace_premium_rounded,
                              color: Color(0xFFFBBF24),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Made for Bangladeshi shops',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'Bangla-friendly UI, Taka (৳) ready, works offline.',
                                  style: TextStyle(
                                    color: Colors.white.withValues(
                                      alpha: 0.78,
                                    ),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 420) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            children: [
              const _AppMark(size: 58),
              const SizedBox(height: 12),
              Text(
                AppConstants.appName,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                AppConstants.appTagline,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
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
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFBBF24), Color(0xFFF97316)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF97316).withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'HB',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: size * 0.38,
            letterSpacing: -0.5,
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
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
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
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline,
              color: tone,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: tone,
                fontWeight: FontWeight.w700,
                height: 1.35,
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
