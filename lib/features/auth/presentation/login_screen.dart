import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../core/app/authenticated_entry.dart';
import '../../../core/app/app_providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/auth_backend.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
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
  final bool _messageIsError = true;
  late final AnimationController _entrance;

  /// Whether this device has ever held a Mohajon session.
  ///
  /// Read once up front so the greeting does not flip while the user types.
  late final bool _isReturningUser = _hasSignedInBefore();

  /// "Welcome back" is only true for someone who has been here before; a first
  /// time visitor is greeted as a newcomer instead of being told they are
  /// returning to an app they have never used.
  static bool _hasSignedInBefore() {
    try {
      return Hive.box<dynamic>(
            HiveBoxes.settings,
          ).get('hasSignedInBefore', defaultValue: false) ==
          true;
    } catch (_) {
      // Storage not open yet; treat as a first-time visitor rather than
      // failing the screen.
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    final settings = ref.read(localDatabaseProvider).settings;
    _rememberMe =
        settings.get('rememberLoginEmail', defaultValue: true) as bool;
    _email.text =
        settings.get('rememberedLoginEmail', defaultValue: '') as String;
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
    final isBangla = ref.watch(localeProvider).languageCode == 'bn';
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
                          child: FadeTransition(
                            opacity: CurvedAnimation(
                              parent: _entrance,
                              curve: Curves.easeOut,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                AuthPhotoHeader(
                                  topInset: MediaQuery.paddingOf(context).top,
                                  minHeight: compact ? 150 : 170,
                                  child: const _BrandDisc(),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: _LanguageSwitcher(
                                      isBangla: isBangla,
                                      onChanged: _setLanguage,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  child: AuthHeading(
                                    title: _isReturningUser
                                        ? (isBangla
                                              ? 'আবার স্বাগতম'
                                              : 'Welcome back')
                                        : (isBangla
                                              ? 'মহাজনে আপনাকে স্বাগতম'
                                              : 'Welcome to Mohajon'),
                                    subtitle: _isReturningUser
                                        ? (isBangla
                                              ? 'যেখানে শেষ করেছিলেন, সেখান থেকেই শুরু করুন'
                                              : 'Sign in to pick up where you left off')
                                        : (isBangla
                                              ? 'সাইন ইন করুন, অথবা বিনামূল্যে অ্যাকাউন্ট তৈরি করুন'
                                              : 'Sign in, or create a free account'),
                                    topPadding: compact ? 2 : 8,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  child: _LoginForm(
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
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                    onRememberChanged: _setRememberMe,
                                    onForgotPassword: _openForgotPassword,
                                    onSignIn: _signIn,
                                    onGoogleSignIn: _signInWithGoogle,
                                    onFacebookSignIn: _signInWithFacebook,
                                    onSignup: _openSignup,
                                    isBusy: isBusy,
                                    bangla: isBangla,
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
      ),
      label: 'Signing in...',
    );
  }

  Future<void> _setLanguage(bool bangla) async {
    final language = bangla ? 'bn' : 'en';
    ref.read(localeProvider.notifier).state = Locale(language);
    await ref
        .read(localDatabaseProvider)
        .settings
        .put('languageCode', language);
  }

  Future<void> _setRememberMe(bool value) async {
    setState(() => _rememberMe = value);
    final settings = ref.read(localDatabaseProvider).settings;
    await settings.put('rememberLoginEmail', value);
    if (!value) await settings.delete('rememberedLoginEmail');
  }

  Future<void> _signIn() async {
    final l10n = AppLocalizations.of(context);
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
        final settings = ref.read(localDatabaseProvider).settings;
        if (_rememberMe) {
          await settings.put('rememberedLoginEmail', _email.text.trim());
          await settings.put('rememberLoginEmail', true);
        } else {
          await settings.delete('rememberedLoginEmail');
          await settings.put('rememberLoginEmail', false);
        }
        if (mounted) _openApp();
      } catch (error) {
        debugPrint('AUTH UI: email sign-in failed: $error');
        debugPrintStack();
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
        _showMessage(authErrorMessage(error, l10n: l10n));
      }
    });
  }

  Future<void> _signInWithGoogle() async {
    final l10n = AppLocalizations.of(context);
    await runBusyAction(() async {
      setState(() => _message = null);
      try {
        await ref.read(authServiceProvider).signInWithGoogle();
        if (mounted) _openApp();
      } catch (error) {
        _showMessage(authErrorMessage(error, l10n: l10n));
      }
    });
  }

  Future<void> _signInWithFacebook() async {
    final l10n = AppLocalizations.of(context);
    await runBusyAction(() async {
      setState(() => _message = null);
      try {
        await ref.read(authServiceProvider).signInWithFacebook();
        if (mounted) _openApp();
      } catch (error) {
        _showMessage(authErrorMessage(error, l10n: l10n));
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
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        backgroundColor: isError ? AuthBrand.danger : MohajonWarm.green,
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
      MaterialPageRoute(builder: (_) => const AuthenticatedEntry()),
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
    if (email == '__authenticated__' && mounted) {
      _openApp();
    } else if (email != null && mounted) {
      _email.text = email;
    }
  }
}

/// Brand mark shown in the header circle. Login is usually the entry route, so
/// there is nothing to go "back" to - the disc keeps the header balanced
/// instead of showing a dead arrow.
class _LanguageSwitcher extends StatelessWidget {
  const _LanguageSwitcher({required this.isBangla, required this.onChanged});

  final bool isBangla;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .86),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AuthBrand.fieldBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LanguageChoice(
            label: 'BN',
            selected: isBangla,
            onTap: () => onChanged(true),
          ),
          _LanguageChoice(
            label: 'EN',
            selected: !isBangla,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _LanguageChoice extends StatelessWidget {
  const _LanguageChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AuthBrand.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AuthBrand.primaryDeep,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: .5,
          ),
        ),
      ),
    );
  }
}

class _BrandDisc extends StatelessWidget {
  const _BrandDisc();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Mohajon',
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .90),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x1A5C4400)),
        ),
        child: const Icon(
          Icons.storefront_rounded,
          size: 19,
          color: AuthBrand.primary,
        ),
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
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
    required this.onFacebookSignIn,
    required this.onSignup,
    required this.isBusy,
    required this.bangla,
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
  final VoidCallback onFacebookSignIn;
  final VoidCallback onSignup;
  final bool isBusy;
  final bool bangla;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LoginTextField(
            controller: email,
            focusNode: emailFocus,
            hintText: bangla ? 'ইমেইল' : 'Email address',
            icon: Icons.person_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            onSubmitted: (_) => passwordFocus.requestFocus(),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return bangla
                    ? 'আপনার ইমেইল লিখুন'
                    : 'Please enter your email address';
              }
              if (!value.contains('@') || !value.contains('.')) {
                return bangla
                    ? 'সঠিক ইমেইল লিখুন'
                    : 'Please enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          LoginTextField(
            controller: password,
            focusNode: passwordFocus,
            hintText: bangla ? 'পাসওয়ার্ড' : 'Password',
            icon: Icons.lock_outline_rounded,
            obscureText: obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => onSignIn(),
            onToggleVisibility: onTogglePassword,
            validator: (value) => value == null || value.isEmpty
                ? (bangla
                      ? 'আপনার পাসওয়ার্ড লিখুন'
                      : 'Please enter your password')
                : null,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _RememberToggle(
                value: rememberMe,
                enabled: !isBusy,
                onChanged: onRememberChanged,
                bangla: bangla,
              ),
              const Spacer(),
              TextButton(
                onPressed: onForgotPassword,
                style: TextButton.styleFrom(
                  foregroundColor: AuthBrand.primaryDeep,
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  bangla ? 'পাসওয়ার্ড ভুলে গেছেন?' : 'Forgot Password ?',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          PrimaryButton(
            onPressed: isBusy ? null : onSignIn,
            isLoading: isBusy,
            label: bangla ? 'সাইন ইন' : 'Login',
          ),
          if (message != null) ...[
            const SizedBox(height: 14),
            _MessageBanner(message: message!, isError: messageIsError),
          ],
          const SizedBox(height: 4),
          AuthFooterLink(
            prompt: bangla ? 'অ্যাকাউন্ট নেই?' : "Don't have an account?",
            action: bangla ? 'সাইন আপ' : 'Sign up',
            onPressed: isBusy ? null : onSignup,
          ),
          const SizedBox(height: 22),
          AuthOrDivider(
            label: bangla ? 'অথবা ব্যবহার করুন' : 'Or continue with',
          ),
          const SizedBox(height: 18),
          SocialAuthRow(
            onGoogle: isBusy ? null : onGoogleSignIn,
            onFacebook: isBusy ? null : onFacebookSignIn,
          ),
        ],
      ),
    );
  }
}

/// Compact circular check used for "Remember me" instead of the stock square
/// Material checkbox, which looked heavy next to the soft sage fields.
class _RememberToggle extends StatelessWidget {
  const _RememberToggle({
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.bangla,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final bool bangla;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: value,
      enabled: enabled,
      label: bangla ? 'আমাকে মনে রাখুন' : 'Remember me',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: enabled ? () => onChanged(!value) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value ? AuthBrand.primary : Colors.transparent,
                  border: Border.all(
                    color: value
                        ? AuthBrand.primary
                        : AuthBrand.panelMuted.withValues(alpha: .55),
                    width: 1.6,
                  ),
                ),
                child: value
                    ? const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 9),
              Text(
                bangla ? 'আমাকে মনে রাখুন' : 'Remember me',
                style: AppType.body(
                  const TextStyle(
                    color: AuthBrand.panelMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                  locale: Localizations.localeOf(context),
                ),
              ),
            ],
          ),
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
    this.autofillHints,
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
  final Iterable<String>? autofillHints;
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
      autofillHints: autofillHints,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      decoration: AuthFieldDecoration(
        hint: hintText,
        icon: icon,
        locale: Localizations.localeOf(context),
        suffixIcon: onToggleVisibility == null
            ? null
            : IconButton(
                tooltip: obscureText ? 'Show password' : 'Hide password',
                onPressed: onToggleVisibility,
                icon: Icon(
                  obscureText
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 21,
                ),
              ),
      ),
    );
  }
}

class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.label = 'Login',
  });

  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;

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
        borderRadius: AuthBrand.buttonRadius,
        child: Ink(
          height: 58,
          decoration: BoxDecoration(
            borderRadius: AuthBrand.buttonRadius,
            gradient: enabled ? AuthBrand.gradient : null,
            color: enabled ? null : AuthBrand.buttonDisabled,
          ),
          child: InkWell(
            borderRadius: AuthBrand.buttonRadius,
            onTap: enabled ? widget.onPressed : null,
            onHighlightChanged: (value) => setState(() => _pressed = value),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (enabled)
                  const DecoratedBox(
                    decoration: BoxDecoration(gradient: AuthBrand.buttonSheen),
                  ),
                Center(
                  child: widget.isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AuthBrand.onGradient,
                          ),
                        )
                      : Text(
                          widget.label,
                          style: AppType.heading(
                            const TextStyle(
                              color: AuthBrand.onGradient,
                              fontSize: 16,
                              letterSpacing: .6,
                            ),
                            locale: Localizations.localeOf(context),
                            weight: AppType.buttonWeight,
                          ),
                        ),
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
    final color = isError ? AuthBrand.danger : MohajonWarm.green;
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
