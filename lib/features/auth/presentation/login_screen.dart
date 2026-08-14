import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/app/app_shell.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_backend.dart';
import '../../../core/widgets/async_action_state.dart';
import '../providers/auth_providers.dart';
import 'auth_brand.dart';
import 'email_verification_dialog.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with AsyncActionState<LoginScreen>, TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;
  bool _rememberMe = true;
  String? _message;
  bool _messageIsError = true;
  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return withLoadingOverlay(
      Theme(
        data: AuthBrand.theme(Theme.of(context)),
        child: Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxHeight < 720;
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(20, compact ? 12 : 20, 20, 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: FadeTransition(
                        opacity: CurvedAnimation(
                          parent: _entrance,
                          curve: Curves.easeOut,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _LanguageSelector(),
                            SizedBox(height: compact ? 10 : 18),
                            _HeroSection(compact: compact),
                            SizedBox(height: compact ? 16 : 24),
                            _LoginCard(
                              formKey: _formKey,
                              email: _email,
                              password: _password,
                              emailFocus: _emailFocus,
                              passwordFocus: _passwordFocus,
                              obscurePassword: _obscurePassword,
                              rememberMe: _rememberMe,
                              message: _message,
                              messageIsError: _messageIsError,
                              onTogglePassword: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              onRememberChanged: (value) =>
                                  setState(() => _rememberMe = value),
                              onForgotPassword: _openForgotPassword,
                              onSignIn: _signIn,
                              onGoogleSignIn: _signInWithGoogle,
                              onSignup: _openSignup,
                              isBusy: isBusy,
                            ),
                            SizedBox(height: compact ? 18 : 26),
                            const _FeatureStrip(),
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

  Future<void> _signIn() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      _showMessage('Please enter your email address');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      _showMessage('Please enter a valid email address');
      return;
    }
    if (_password.text.isEmpty) {
      _showMessage('Please enter your password');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    await runBusyAction(() async {
      setState(() => _message = null);
      try {
        await ref
            .read(authServiceProvider)
            .signInWithEmail(
              email: _email.text.trim(),
              password: _password.text,
            );
        if (mounted) _openApp();
      } catch (error) {
        if (error is AuthException &&
            error.code == 'VERIFICATION_REQUIRED' &&
            mounted) {
          final verified = await showEmailVerificationDialog(
            context,
            ref,
            email: _email.text.trim(),
          );
          if (verified && mounted) await _signIn();
          return;
        }
        _showMessage(authErrorMessage(error));
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
        _showMessage(authErrorMessage(error));
      }
    });
  }

  void _showMessage(String message, {bool isError = true}) {
    if (!mounted) return;
    setState(() => _message = null);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        backgroundColor: isError
            ? const Color(0xFFD64545)
            : const Color(0xFF238B57),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openApp() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => AppShell(key: ValueKey(ref.read(shopIdProvider))),
      ),
    );
  }

  void _openForgotPassword() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ForgotPasswordScreen(initialEmail: _email.text),
      ),
    );
  }

  Future<void> _openSignup() async {
    final email = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const SignupScreen()));
    if (email != null && mounted) _email.text = email;
  }
}

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {},
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AuthBrand.panelBorder),
              boxShadow: [
                BoxShadow(
                  color: AuthBrand.shadow.withValues(alpha: 0.10),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.language_rounded,
                  color: AuthBrand.panelText,
                  size: 19,
                ),
                SizedBox(width: 7),
                Text(
                  'English',
                  style: TextStyle(
                    color: AuthBrand.panelText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: 5),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AuthBrand.panelMuted,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: compact ? 2 : 8),
        _CommerceIllustration(compact: compact),
        SizedBox(height: compact ? 8 : 14),
        Text(
          AppConstants.appName,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            color: AuthBrand.panelText,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.6,
            height: 1,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Manage your shop, grow your business',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AuthBrand.panelMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CommerceIllustration extends StatelessWidget {
  const _CommerceIllustration({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final height = compact ? 128.0 : 164.0;
    return SizedBox(
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: compact ? 220 : 280,
            height: height * .78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AuthBrand.secondarySoft,
                  AuthBrand.secondarySoft.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          Positioned(
            left: compact ? 30 : 66,
            bottom: 16,
            child: _IllustrationTile(
              color: const Color(0xFFE4F6E8),
              iconColor: const Color(0xFF2BA05A),
              icon: Icons.inventory_2_rounded,
              size: compact ? 48 : 58,
              rotation: -.12,
            ),
          ),
          Positioned(
            right: compact ? 28 : 62,
            bottom: 19,
            child: _IllustrationTile(
              color: const Color(0xFFFFEED7),
              iconColor: AuthBrand.gold,
              icon: Icons.shopping_cart_rounded,
              size: compact ? 48 : 58,
              rotation: .12,
            ),
          ),
          Container(
            width: compact ? 98 : 118,
            height: compact ? 98 : 118,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: AuthBrand.panelBorder),
              boxShadow: [
                BoxShadow(
                  color: AuthBrand.shadow.withValues(alpha: 0.17),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: AuthBrand.primary,
              size: 58,
            ),
          ),
        ],
      ),
    );
  }
}

class _IllustrationTile extends StatelessWidget {
  const _IllustrationTile({
    required this.color,
    required this.iconColor,
    required this.icon,
    required this.size,
    required this.rotation,
  });

  final Color color;
  final Color iconColor;
  final IconData icon;
  final double size;
  final double rotation;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(icon, color: iconColor, size: size * .48),
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.formKey,
    required this.email,
    required this.password,
    required this.emailFocus,
    required this.passwordFocus,
    required this.obscurePassword,
    required this.rememberMe,
    required this.message,
    required this.messageIsError,
    required this.onTogglePassword,
    required this.onRememberChanged,
    required this.onForgotPassword,
    required this.onSignIn,
    required this.onGoogleSignIn,
    required this.onSignup,
    required this.isBusy,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController email;
  final TextEditingController password;
  final FocusNode emailFocus;
  final FocusNode passwordFocus;
  final bool obscurePassword;
  final bool rememberMe;
  final String? message;
  final bool messageIsError;
  final VoidCallback onTogglePassword;
  final ValueChanged<bool> onRememberChanged;
  final VoidCallback onForgotPassword;
  final VoidCallback onSignIn;
  final VoidCallback onGoogleSignIn;
  final VoidCallback onSignup;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AuthBrand.panelBorder),
        boxShadow: [
          BoxShadow(
            color: AuthBrand.shadow.withValues(alpha: 0.14),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Welcome Back! 👋',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: AuthBrand.panelText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Sign in to continue to your account',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AuthBrand.panelMuted),
            ),
            const SizedBox(height: 20),
            LoginTextField(
              controller: email,
              focusNode: emailFocus,
              hintText: 'Email address',
              icon: Icons.person_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => passwordFocus.requestFocus(),
              validator: (value) {
                if (value == null || value.trim().isEmpty)
                  return 'Please enter your email address';
                if (!value.contains('@') || !value.contains('.'))
                  return 'Please enter a valid email address';
                return null;
              },
            ),
            const SizedBox(height: 14),
            LoginTextField(
              controller: password,
              focusNode: passwordFocus,
              hintText: 'Password',
              icon: Icons.lock_outline_rounded,
              obscureText: obscurePassword,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onSignIn(),
              onToggleVisibility: onTogglePassword,
              validator: (value) => value == null || value.isEmpty
                  ? 'Please enter your password'
                  : null,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Checkbox(
                  value: rememberMe,
                  onChanged: isBusy
                      ? null
                      : (value) => onRememberChanged(value ?? false),
                ),
                const Text(
                  'Remember me',
                  style: TextStyle(
                    color: AuthBrand.panelMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onForgotPassword,
                  child: const Text('Forgot Password?'),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    onPressed: isBusy ? null : onSignIn,
                    isLoading: isBusy,
                    compact: true,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 9),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      color: AuthBrand.panelMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SocialLoginButton(
                  compact: true,
                  onPressed: isBusy ? null : onGoogleSignIn,
                ),
              ],
            ),
            if (message != null) ...[
              const SizedBox(height: 12),
              _MessageBanner(message: message!, isError: messageIsError),
            ],
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Don't have an account?",
                  style: TextStyle(color: AuthBrand.panelMuted),
                ),
                TextButton(
                  onPressed: isBusy ? null : onSignup,
                  child: const Text(
                    'Sign Up',
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

class LoginTextField extends StatelessWidget {
  const LoginTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.onToggleVisibility,
    this.validator,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onToggleVisibility;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: _FieldIcon(icon: icon),
        suffixIcon: onToggleVisibility == null
            ? null
            : IconButton(
                onPressed: onToggleVisibility,
                icon: Icon(
                  obscureText
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
      ),
    );
  }
}

class _FieldIcon extends StatelessWidget {
  const _FieldIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(9),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AuthBrand.secondarySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: AuthBrand.primary, size: 22),
    );
  }
}

class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.compact = false,
  });

  final VoidCallback? onPressed;
  final bool isLoading;
  final bool compact;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.isLoading;
    return AnimatedScale(
      scale: _pressed ? .985 : 1,
      duration: const Duration(milliseconds: 120),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        child: Ink(
          height: widget.compact ? 52 : 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: enabled ? AuthBrand.gradient : null,
            color: enabled ? null : AuthBrand.buttonDisabled,
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AuthBrand.primary.withValues(alpha: .22),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: enabled ? widget.onPressed : null,
            onHighlightChanged: (value) => setState(() => _pressed = value),
            child: Center(
              child: widget.isLoading
                  ? const SizedBox(
                      width: 23,
                      height: 23,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.login_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Sign In',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
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

class SocialLoginButton extends StatelessWidget {
  const SocialLoginButton({
    super.key,
    required this.onPressed,
    this.compact = false,
  });

  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return SizedBox(
        width: 48,
        height: 52,
        child: IconButton(
          onPressed: onPressed,
          tooltip: 'Continue with Google',
          padding: EdgeInsets.zero,
          icon: const _GoogleIcon(),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const _GoogleIcon(),
      label: compact
          ? const SizedBox.shrink()
          : const Text('Continue with Google'),
      style: OutlinedButton.styleFrom(
        minimumSize: compact ? const Size(52, 52) : const Size.fromHeight(52),
        padding: compact ? EdgeInsets.zero : null,
        backgroundColor: Colors.white,
        foregroundColor: AuthBrand.panelText,
        side: const BorderSide(color: AuthBrand.panelBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AuthBrand.panelMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
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
      child: SvgPicture.asset(
        'assets/brand/google_g.svg',
        width: 22,
        height: 22,
        fit: BoxFit.contain,
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
    final color = isError ? AuthBrand.danger : const Color(0xFF2BA05A);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Row(
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureStrip extends StatelessWidget {
  const _FeatureStrip();

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        Icons.bar_chart_rounded,
        'Sales',
        'Track sales\nin real-time',
        Color(0xFFE1EBFF),
      ),
      (
        Icons.inventory_2_rounded,
        'Inventory',
        'Manage stock\neffortlessly',
        Color(0xFFDDF7EB),
      ),
      (
        Icons.groups_rounded,
        'Customers',
        'Build stronger\nrelationships',
        Color(0xFFFFECD8),
      ),
      (
        Icons.pie_chart_rounded,
        'Analytics',
        'Grow with\ninsights',
        Color(0xFFEDE3FF),
      ),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .82),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AuthBrand.panelBorder),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: _FeatureItem(
                icon: items[i].$1,
                title: items[i].$2,
                subtitle: items[i].$3,
                background: items[i].$4,
                showDivider: i != items.length - 1,
              ),
            ),
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.background,
    required this.showDivider,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color background;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(right: BorderSide(color: AuthBrand.panelBorder))
            : null,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: AuthBrand.primary, size: 21),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: AuthBrand.panelText,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AuthBrand.panelMuted,
              fontSize: 8.5,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}
