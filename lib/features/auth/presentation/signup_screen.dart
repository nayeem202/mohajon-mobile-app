import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/async_action_state.dart';
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
  final _email = TextEditingController();
  final _mobile = TextEditingController(text: '+880');
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _submitted = false;
  bool _obscurePassword = true;
  String? _message;

  @override
  void dispose() {
    _shopName.dispose();
    _email.dispose();
    _mobile.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return withLoadingOverlay(
      Scaffold(
        appBar: AppBar(title: const Text('Create account')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: _submitted
                        ? _VerificationNotice(email: _email.text.trim())
                        : Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Signup',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _shopName,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'Shop name',
                                    prefixIcon: Icon(Icons.store_outlined),
                                  ),
                                  validator: _required,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                    prefixIcon: Icon(Icons.email_outlined),
                                  ),
                                  validator: _emailValidator,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _mobile,
                                  keyboardType: TextInputType.phone,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'Mobile no',
                                    prefixIcon: Icon(Icons.phone_outlined),
                                  ),
                                  validator: _required,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _password,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.next,
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
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
                                  validator: _passwordValidator,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _confirmPassword,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  decoration: const InputDecoration(
                                    labelText: 'Confirm password',
                                    prefixIcon: Icon(Icons.lock_reset_outlined),
                                  ),
                                  validator: (value) {
                                    if (value != _password.text) {
                                      return 'Passwords do not match.';
                                    }
                                    return null;
                                  },
                                ),
                                if (_message != null) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    _message!,
                                    style: TextStyle(color: colors.error),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: isBusy ? null : _signup,
                                  icon: const Icon(
                                    Icons.mark_email_read_outlined,
                                  ),
                                  label: const Text('Send verification email'),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      label: 'Creating account...',
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
              email: _email.text,
              mobile: _mobile.text,
              password: _password.text,
            );
        if (mounted) setState(() => _submitted = true);
      } catch (error) {
        if (mounted) setState(() => _message = authErrorMessage(error));
      }
    });
  }
}

class _VerificationNotice extends StatelessWidget {
  const _VerificationNotice({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.mark_email_read_outlined, size: 56),
        const SizedBox(height: 16),
        Text(
          'Verify your email',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Text(
          'A verification email was sent to $email. Open that email and verify the account, then return to login with your email and password.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(email),
          child: const Text('Back to login'),
        ),
      ],
    );
  }
}
