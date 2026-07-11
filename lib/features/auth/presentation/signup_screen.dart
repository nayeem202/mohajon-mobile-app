import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/async_action_state.dart';
import 'auth_brand.dart';
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
    _password.addListener(() => setState(() {}));
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

  @override
  Widget build(BuildContext context) {
    final authTheme = AuthBrand.theme(Theme.of(context));
    return withLoadingOverlay(
      Theme(
        data: authTheme,
        child: Scaffold(
          body: Stack(
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  color: AuthBrand.backgroundColor,
                ),
                child: SizedBox.expand(),
              ),
              SafeArea(
                child: CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      pinned: false,
                      floating: true,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: AuthBrand.secondary,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: _submitted
                                ? _VerificationNotice(email: _email.text.trim())
                                : _buildForm(context),
                          ),
                        ),
                      ),
                    ),
                  ],
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
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AuthHero(
          icon: Icons.storefront_rounded,
          badge: 'Create account',
          title: 'Set up your shop',
          subtitle: 'Start managing sales, inventory and customers in minutes.',
        ),
        const SizedBox(height: 18),
        Container(
          decoration: BoxDecoration(
            color: AuthBrand.panelBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AuthBrand.panelBorder),
            boxShadow: [
              BoxShadow(
                color: AuthBrand.shadow.withValues(alpha: 0.06),
                blurRadius: 28,
                spreadRadius: -8,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _shopName,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Shop name',
                    hintText: 'e.g. Bondhu Stores',
                    prefixIcon: Icon(Icons.store_outlined),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _ownerName,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Owner name',
                    hintText: 'e.g. Ranbir Kapoor',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'you@example.com',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                  validator: _emailValidator,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _mobile,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  decoration: const InputDecoration(
                    labelText: 'Mobile number',
                    hintText: '+8801XXXXXXXXX',
                    prefixIcon: Icon(Icons.phone_iphone_rounded),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'At least 6 characters',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword
                          ? 'Show password'
                          : 'Hide password',
                      onPressed: () => setState(
                        () => _obscurePassword = !_obscurePassword,
                      ),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                  validator: _passwordValidator,
                ),
                if (_password.text.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _PasswordStrengthIndicator(password: _password.text),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmPassword,
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'Confirm password',
                    prefixIcon: const Icon(Icons.lock_reset_rounded),
                    suffixIcon: IconButton(
                      tooltip: _obscureConfirm
                          ? 'Show password'
                          : 'Hide password',
                      onPressed: () => setState(
                        () => _obscureConfirm = !_obscureConfirm,
                      ),
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
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
                  child: _message == null
                      ? const SizedBox(height: 0)
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
                  onPressed: isBusy ? null : _signup,
                  icon: Icons.mark_email_read_outlined,
                  label: 'Send verification email',
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account?',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text(
                        'Sign in',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
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

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
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
        if (mounted) setState(() => _submitted = true);
      } catch (error) {
        if (mounted) {
          setState(() {
            _message = authErrorMessage(error);
            _messageIsError = true;
          });
        }
      }
    });
  }
}

class _AuthHero extends StatelessWidget {
  const _AuthHero({
    required this.icon,
    required this.badge,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String badge;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: AuthBrand.primary,
              boxShadow: [
                BoxShadow(
                  color: AuthBrand.primary.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 36),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AuthBrand.secondary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AuthBrand.secondary.withValues(alpha: 0.18),
              ),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                color: AuthBrand.secondary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _PasswordStrengthIndicator extends StatelessWidget {
  const _PasswordStrengthIndicator({required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final score = _score(password);
    final labels = ['Too weak', 'Weak', 'Okay', 'Strong', 'Excellent'];
    final colors = [
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
                  height: 6,
                  decoration: BoxDecoration(
                    color: active
                        ? color
                        : AuthBrand.panelBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.shield_outlined, color: color, size: 14),
            const SizedBox(width: 6),
            Text(
              'Password strength: $label',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
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
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: disabled ? AuthBrand.buttonDisabled : AuthBrand.primary,
          boxShadow: disabled
              ? null
              : [
                  BoxShadow(
                    color: AuthBrand.primary.withValues(alpha: 0.35),
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
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone.withValues(alpha: 0.28)),
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

class _VerificationNotice extends StatelessWidget {
  const _VerificationNotice({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: AuthBrand.panelBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AuthBrand.panelBorder),
        boxShadow: [
          BoxShadow(
            color: AuthBrand.shadow.withValues(alpha: 0.06),
            blurRadius: 28,
            spreadRadius: -8,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: AuthBrand.primary,
                boxShadow: [
                  BoxShadow(
                    color: AuthBrand.primary.withValues(alpha: 0.32),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.mark_email_read_outlined,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Verify your email',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.onSurface,
                height: 1.4,
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
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AuthBrand.secondary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AuthBrand.secondary.withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.tips_and_updates_outlined,
                  color: AuthBrand.secondary,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tip: check your spam folder if you don\'t see the email.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AuthBrand.secondary,
                      fontWeight: FontWeight.w700,
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
