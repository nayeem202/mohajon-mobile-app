import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  late final TextEditingController _email;
  String? _message;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail.trim());
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return withLoadingOverlay(
      Scaffold(
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
                          constraints: const BoxConstraints(maxWidth: 460),
                          child: _buildCard(context),
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
      label: 'Sending...',
    );
  }

  Widget _buildCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: _sent ? AuthBrand.secondary : AuthBrand.primary,
              boxShadow: [
                BoxShadow(
                  color: (_sent ? AuthBrand.secondary : AuthBrand.primary)
                      .withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              _sent
                  ? Icons.mark_email_read_outlined
                  : Icons.lock_reset_rounded,
              color: _sent ? AuthBrand.onGold.withValues(alpha: 0.9) : AuthBrand.onGold,
              size: 36,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _sent ? 'Email on its way' : 'Reset password',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _sent
              ? 'Open the email and follow the link to set a new password.'
              : 'Enter your registered email and we will send a password reset link.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(22),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                enabled: !_sent,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'you@example.com',
                  prefixIcon: const Icon(Icons.alternate_email_rounded),
                ),
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
                          isError: !_sent,
                        ),
                      ),
              ),
              const SizedBox(height: 18),
              _PrimaryActionButton(
                onPressed: _sent ? () => Navigator.of(context).maybePop() : _send,
                isBusy: isBusy,
                icon: _sent
                    ? Icons.arrow_back_rounded
                    : Icons.send_rounded,
                label: _sent ? 'Back to sign in' : 'Send reset email',
                busyLabel: 'Sending...',
              ),
              if (!_sent) ...[
                const SizedBox(height: 10),
                Center(
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.login_rounded, size: 18),
                    label: const Text('Back to sign in'),
                    style: TextButton.styleFrom(
                      foregroundColor: AuthBrand.secondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _send() async {
    await runBusyAction(() async {
      setState(() {
        _message = null;
        _sent = false;
      });
      try {
        await ref.read(authServiceProvider).sendPasswordResetEmail(_email.text);
        if (mounted) {
          setState(() {
            _sent = true;
            _message = 'Password reset email sent to ${_email.text.trim()}.';
          });
        }
      } catch (error) {
        if (mounted) setState(() => _message = authErrorMessage(error));
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
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: disabled
              ? const LinearGradient(
                  colors: [Color(0xFF2A2A22), Color(0xFF262621)],
                )
              : AuthBrand.gradient,
          boxShadow: disabled
              ? null
              : [
                  BoxShadow(
                    color: AuthBrand.primary.withValues(alpha: 0.28),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: disabled ? null : onPressed,
          child: SizedBox(
            height: 54,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isBusy ? (busyLabel ?? 'Sending...') : label,
                  style: TextStyle(
                    color: disabled
                        ? Colors.white.withValues(alpha: 0.5)
                        : AuthBrand.onGold,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: 0.2,
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
                              ? Colors.white.withValues(alpha: 0.5)
                              : AuthBrand.primaryDeep,
                        ),
                      )
                    : Icon(icon, color: AuthBrand.onGold, size: 20),
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
        color: tone.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone.withValues(alpha: 0.38)),
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
