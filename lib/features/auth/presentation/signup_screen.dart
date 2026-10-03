import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/async_action_state.dart';
import 'auth_brand.dart';
import 'email_verification_dialog.dart';
import '../providers/auth_providers.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen>
    with AsyncActionState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopName = TextEditingController();
  final _ownerName = TextEditingController();
  final _email = TextEditingController();
  final _mobile = TextEditingController(text: '+880');
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _submitted = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _message;
  bool _messageIsError = true;

  @override
  void initState() {
    super.initState();
    _password.addListener(_refresh);
    _email.addListener(_refresh);
  }

  /// Live feedback for the password meter and the email confirmation tick.
  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _shopName.dispose();
    _ownerName.dispose();
    _email.dispose();
    _mobile.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  bool get _emailLooksValid {
    final text = _email.text.trim();
    return text.contains('@') && text.contains('.') && text.length > 5;
  }

  @override
  Widget build(BuildContext context) {
    final authTheme = AuthBrand.theme(Theme.of(context));
    return withLoadingOverlay(
      Theme(
        data: authTheme,
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
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    AuthHeading(
                                      title: 'Register',
                                      subtitle: 'Create your new account',
                                      topPadding: compact ? 2 : 8,
                                    ),
                                    _submitted
                                        ? _VerificationNotice(
                                            email: _email.text.trim(),
                                          )
                                        : _buildForm(context),
                                  ],
                                ),
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
      label: 'Creating account...',
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _field(
            controller: _shopName,
            hint: 'Shop name',
            icon: Icons.storefront_outlined,
            textInputAction: TextInputAction.next,
            validator: _required,
          ),
          const SizedBox(height: 14),
          _field(
            controller: _ownerName,
            hint: 'Full name',
            icon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            validator: _required,
          ),
          const SizedBox(height: 14),
          _field(
            controller: _email,
            hint: 'Email address',
            icon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            // Small green tick once the address looks usable.
            suffix: _emailLooksValid
                ? const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: AuthBrand.primary,
                      size: 20,
                    ),
                  )
                : null,
            validator: _emailValidator,
          ),
          const SizedBox(height: 14),
          _field(
            controller: _mobile,
            hint: 'Mobile number',
            icon: Icons.phone_iphone_rounded,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.telephoneNumber],
            validator: _required,
          ),
          const SizedBox(height: 14),
          _field(
            controller: _password,
            hint: 'Password',
            icon: Icons.lock_outline_rounded,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            suffixIcon: IconButton(
              tooltip: _obscurePassword ? 'Show password' : 'Hide password',
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 21,
              ),
            ),
            validator: _passwordValidator,
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _password.text.isEmpty
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _PasswordStrengthIndicator(password: _password.text),
                  ),
          ),
          const SizedBox(height: 14),
          _field(
            controller: _confirmPassword,
            hint: 'Confirm password',
            icon: Icons.lock_reset_rounded,
            obscureText: _obscureConfirm,
            textInputAction: TextInputAction.done,
            suffixIcon: IconButton(
              tooltip: _obscureConfirm ? 'Show password' : 'Hide password',
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
              icon: Icon(
                _obscureConfirm
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 21,
              ),
            ),
            validator: (value) {
              if (value != _password.text) {
                return 'Passwords do not match.';
              }
              return null;
            },
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
          const SizedBox(height: 20),
          _PrimaryActionButton(
            onPressed: _signup,
            isBusy: isBusy,
            icon: Icons.person_add_alt_1_rounded,
            label: 'Create account',
          ),
          const SizedBox(height: 4),
          AuthFooterLink(
            prompt: 'Already have an account?',
            action: 'Sign in',
            onPressed: isBusy ? null : () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(height: 22),
          const AuthOrDivider(label: 'Or continue with'),
          const SizedBox(height: 18),
          SocialAuthRow(
            onGoogle: isBusy ? null : _continueWithGoogle,
            onFacebook: isBusy ? null : _continueWithFacebook,
          ),
        ],
      ),
    );
  }

  /// Single entry point for every signup field so the styling can never drift
  /// between the six inputs.
  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    Iterable<String>? autofillHints,
    bool obscureText = false,
    Widget? suffix,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      obscureText: obscureText,
      validator: validator,
      decoration: AuthFieldDecoration(
        hint: hint,
        icon: icon,
        locale: Localizations.localeOf(context),
        suffix: suffix,
        suffixIcon: suffixIcon,
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'This field is required.';
    return null;
  }

  String? _emailValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Email is required.';
    if (!text.contains('@') || !text.contains('.')) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _passwordValidator(String? value) {
    final text = value ?? '';
    if (text.length < 6) return 'Use at least 6 characters.';
    return null;
  }

  Future<void> _continueWithGoogle() async {
    await runBusyAction(() async {
      setState(() => _message = null);
      try {
        await ref.read(authServiceProvider).signInWithGoogle();
      } catch (error) {
        _showError(authErrorMessage(error));
      }
    });
  }

  Future<void> _continueWithFacebook() async {
    await runBusyAction(() async {
      setState(() => _message = null);
      try {
        await ref.read(authServiceProvider).signInWithFacebook();
      } catch (error) {
        _showError(authErrorMessage(error));
      }
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _message = message;
      _messageIsError = true;
    });
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await runBusyAction(() async {
      setState(() => _message = null);
      try {
        await ref
            .read(authServiceProvider)
            .signUpWithEmail(
              shopName: _shopName.text,
              ownerName: _ownerName.text,
              email: _email.text,
              mobile: _mobile.text,
              password: _password.text,
            );
        if (!mounted) return;
        if (AppConfig.useCustomAuth) {
          final verified = await showEmailVerificationDialog(
            context,
            ref,
            email: _email.text.trim(),
          );
          if (verified && mounted) {
            Navigator.of(context).pop(_email.text.trim());
            return;
          }
        }
        if (mounted) setState(() => _submitted = true);
      } catch (error) {
        _showError(authErrorMessage(error));
      }
    });
  }
}

class _PasswordStrengthIndicator extends StatelessWidget {
  const _PasswordStrengthIndicator({required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final score = _score(password);
    const labels = ['Too weak', 'Weak', 'Okay', 'Strong', 'Excellent'];
    const colors = [
      AuthBrand.danger,
      AuthBrand.primaryDeep,
      AuthBrand.primary,
      AuthBrand.secondary,
      AuthBrand.secondary,
    ];
    final color = colors[score];
    final label = labels[score];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: List.generate(4, (i) {
            final active = i < score;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == 3 ? 0 : 6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 5,
                  decoration: BoxDecoration(
                    color: active ? color : AuthBrand.fieldBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            Icon(Icons.shield_outlined, color: color, size: 14),
            const SizedBox(width: 6),
            Text(
              'Password strength: $label',
              style: const TextStyle(
                color: AuthBrand.panelMuted,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ],
    );
  }

  int _score(String password) {
    if (password.isEmpty) return 0;
    var score = 0;
    if (password.length >= 6) score++;
    if (password.length >= 10) score++;
    if (password.contains(RegExp(r'[A-Z]')) &&
        password.contains(RegExp(r'[a-z]'))) {
      score++;
    }
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=/\\\[\];]'))) {
      score++;
    }
    if (score > 4) score = 4;
    return score;
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.isBusy = false,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final bool isBusy;

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
          boxShadow: disabled
              ? null
              : [
                  BoxShadow(
                    color: AuthBrand.buttonGlow.withValues(alpha: .38),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: AuthBrand.buttonGlow.withValues(alpha: .20),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
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
                    if (isBusy)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AuthBrand.onGradient,
                        ),
                      )
                    else
                      Icon(
                        icon,
                        color: AuthBrand.onGradient.withValues(
                          alpha: disabled ? .45 : 1,
                        ),
                        size: 20,
                      ),
                    const SizedBox(width: 10),
                    Text(
                      isBusy ? 'Creating account...' : label,
                      style: AppType.heading(
                        TextStyle(
                          color: AuthBrand.onGradient.withValues(
                            alpha: disabled ? .5 : 1,
                          ),
                          fontSize: 16,
                          letterSpacing: .5,
                        ),
                        locale: Localizations.localeOf(context),
                        weight: AppType.buttonWeight,
                      ),
                    ),
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

class _VerificationNotice extends StatelessWidget {
  const _VerificationNotice({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: AuthBrand.fieldFill,
        borderRadius: AuthBrand.panelRadius,
        border: Border.all(color: AuthBrand.fieldBorder),
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AuthBrand.primary,
                boxShadow: [
                  BoxShadow(
                    color: AuthBrand.primary.withValues(alpha: .28),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.mark_email_read_outlined,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Verify your email',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AuthBrand.panelText,
              fontSize: 22,
              letterSpacing: -.4,
            ),
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              style: TextStyle(
                color: colors.onSurface,
                height: 1.45,
                fontSize: 13.5,
              ),
              children: [
                const TextSpan(text: 'We sent a verification email to\n'),
                TextSpan(
                  text: email,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const TextSpan(
                  text:
                      '.\nOpen that email, verify the account, then return to sign in.',
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AuthBrand.secondary.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AuthBrand.secondary.withValues(alpha: .18),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.tips_and_updates_outlined,
                  color: AuthBrand.secondary,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Tip: check your spam folder if you don't see the email.",
                    style: const TextStyle(
                      color: AuthBrand.secondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _PrimaryActionButton(
            onPressed: () => Navigator.of(context).pop(email),
            icon: Icons.arrow_back_rounded,
            label: 'Back to ${AppConstants.appName}',
          ),
        ],
      ),
    );
  }
}
