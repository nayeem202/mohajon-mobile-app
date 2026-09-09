import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../theme/mohajon_warm_theme.dart';

/// Full-screen PIN pad in a premium warm style.
///
/// Used in three contexts:
///  1. Unlock overlay at app start / return to foreground (no back button,
///     no automatic pop — caller rebuilds from the lock state).
///  2. Verify flow pushed from Settings to turn App Lock off or change PIN
///     (pass [autoPopOnSuccess] = true so it pops with `true` on success).
class AppLockScreen extends StatefulWidget {
  const AppLockScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onSubmit,
    this.showBack = false,
    this.autoPopOnSuccess = false,
    this.lockoutRemaining,
  });

  final String title;
  final String subtitle;

  /// Returns true when [pin] is correct.
  final Future<bool> Function(String pin) onSubmit;
  final bool showBack;
  final bool autoPopOnSuccess;

  /// Reports any active brute-force lockout so the UI can block input and
  /// show the remaining wait (checked only after a failed attempt).
  final Duration Function()? lockoutRemaining;

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeController;

  String _pin = '';
  bool _busy = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _onKey(String digit) async {
    if (_busy || _pin.length >= 4) return;
    final l10n = AppLocalizations.of(context);
    final lockout = widget.lockoutRemaining?.call() ?? Duration.zero;
    if (lockout > Duration.zero) {
      setState(() {
        _error = l10n.tP(
          'lockoutMessage',
          {'seconds': '${lockout.inSeconds.ceil()}'},
        );
      });
      return;
    }
    setState(() {
      _pin += digit;
      _error = '';
    });
    if (_pin.length < 4) return;
    _busy = true;
    final ok = await widget.onSubmit(_pin);
    if (!mounted) return;
    _busy = false;
    if (ok) {
      if (widget.autoPopOnSuccess && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
      return;
    }
    final remaining = widget.lockoutRemaining?.call() ?? Duration.zero;
    setState(() {
      _error = remaining > Duration.zero
          ? l10n.tP(
              'lockoutMessage',
              {'seconds': '${remaining.inSeconds.ceil()}'},
            )
          : l10n.t('wrongPin');
      _pin = '';
    });
    _shakeController.forward(from: 0);
  }

  void _onBackspace() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final horizontalPad = size.width >= 480
        ? (size.width - 320) / 2
        : 24.0;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: MohajonWarm.pageGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPad,
                    28,
                    horizontalPad,
                    0,
                  ),
                  child: Column(
                    children: [
                      if (widget.showBack)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _CircleIconButton(
                            icon: Icons.close_rounded,
                            onTap: () => Navigator.of(context).pop(false),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [MohajonWarm.primary, MohajonWarm.orange],
                          ),
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(
                              color: MohajonWarm.goldText.withValues(
                                alpha: 0.28,
                              ),
                              blurRadius: 22,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 26),
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: MohajonWarm.ink,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: MohajonWarm.muted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
                      AnimatedBuilder(
                        animation: _shakeController,
                        builder: (context, child) {
                          final t = _shakeController.value;
                          final dx = t >= 1
                              ? 0.0
                              : math.sin(t * math.pi * 6) * 12 * (1 - t);
                          return Transform.translate(
                            offset: Offset(dx, 0),
                            child: child,
                          );
                        },
                        child: _PinDots(count: 4, filled: _pin.length),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 20,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _error.isEmpty
                              ? const SizedBox.shrink()
                              : Text(
                                  _error,
                                  key: ValueKey(_error),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: MohajonWarm.red,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
              _PinKeypad(
                enabled: !_busy,
                onDigit: _onKey,
                onBackspace: _onBackspace,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two-step PIN creation flow. Returns the new PIN via `Navigator.pop(pin)`.
class SetAppPinScreen extends StatefulWidget {
  const SetAppPinScreen({super.key});

  @override
  State<SetAppPinScreen> createState() => _SetAppPinScreenState();
}

class _SetAppPinScreenState extends State<SetAppPinScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeController;

  bool _isConfirming = false;
  String _firstPin = '';
  String _pin = '';
  bool _busy = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _fail(String message) {
    setState(() {
      _error = message;
      _pin = '';
      if (!_isConfirming) {
        _firstPin = '';
      }
    });
    _shakeController.forward(from: 0);
  }

  Future<void> _onKey(String digit) async {
    if (_busy || _pin.length >= 4) return;
    setState(() {
      _pin += digit;
      _error = '';
    });
    if (_pin.length < 4) return;
    final l10n = AppLocalizations.of(context);
    if (!_isConfirming) {
      _firstPin = _pin;
      _isConfirming = true;
      _pin = '';
      return;
    }
    _busy = true;
    if (_pin == _firstPin) {
      Navigator.of(context).pop(_pin);
      return;
    }
    _busy = false;
    _fail(l10n.t('pinMismatch'));
  }

  void _onBackspace() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _onBack() {
    if (!_isConfirming) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _isConfirming = false;
      _firstPin = '';
      _pin = '';
      _error = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final size = MediaQuery.sizeOf(context);
    final horizontalPad = size.width >= 480
        ? (size.width - 320) / 2
        : 24.0;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: MohajonWarm.pageGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPad,
                    28,
                    horizontalPad,
                    0,
                  ),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _CircleIconButton(
                          icon: _isConfirming
                              ? Icons.arrow_back_rounded
                              : Icons.close_rounded,
                          onTap: _onBack,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [MohajonWarm.primary, MohajonWarm.orange],
                          ),
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(
                              color: MohajonWarm.goldText.withValues(
                                alpha: 0.28,
                              ),
                              blurRadius: 22,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.lock_outline_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 26),
                      Text(
                        _isConfirming
                            ? l10n.t('confirmPinTitle')
                            : l10n.t('createPinTitle'),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: MohajonWarm.ink,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isConfirming
                            ? l10n.t('confirmPinSubtitle')
                            : l10n.t('createPinSubtitle'),
                        style: const TextStyle(
                          fontSize: 13,
                          color: MohajonWarm.muted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
                      AnimatedBuilder(
                        animation: _shakeController,
                        builder: (context, child) {
                          final t = _shakeController.value;
                          final dx = t >= 1
                              ? 0.0
                              : math.sin(t * math.pi * 6) * 12 * (1 - t);
                          return Transform.translate(
                            offset: Offset(dx, 0),
                            child: child,
                          );
                        },
                        child: _PinDots(count: 4, filled: _pin.length),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 20,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _error.isEmpty
                              ? const SizedBox.shrink()
                              : Text(
                                  _error,
                                  key: ValueKey(_error),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: MohajonWarm.red,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
              _PinKeypad(
                enabled: !_busy,
                onDigit: _onKey,
                onBackspace: _onBackspace,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinDots extends StatelessWidget {
  const _PinDots({required this.count, required this.filled});

  final int count;
  final int filled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < filled
                    ? MohajonWarm.orange
                    : const Color(0xFFEADCB9),
                boxShadow: i < filled
                    ? [
                        BoxShadow(
                          color: MohajonWarm.orange.withValues(alpha: 0.35),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

class _PinKeypad extends StatelessWidget {
  const _PinKeypad({
    required this.enabled,
    required this.onDigit,
    required this.onBackspace,
  });

  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    final horizontalPad = MediaQuery.sizeOf(context).width >= 480
        ? (MediaQuery.sizeOf(context).width - 320) / 2
        : 24.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var row = 0; row < 3; row++)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var col = 1; col <= 3; col++)
                  Expanded(
                    child: _PinKey(
                      label: '${row * 3 + col}',
                      enabled: enabled,
                      onTap: () => onDigit('${row * 3 + col}'),
                    ),
                  ),
              ],
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Expanded(child: SizedBox.shrink()),
              Expanded(
                child: _PinKey(
                  label: '0',
                  enabled: enabled,
                  onTap: () => onDigit('0'),
                ),
              ),
              Expanded(
                child: _PinKey(
                  icon: Icons.backspace_outlined,
                  onTap: onBackspace,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PinKey extends StatelessWidget {
  const _PinKey({
    this.label = '',
    this.icon,
    this.enabled = true,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          height: 62,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2620) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF4A443A)
                  : MohajonWarm.goldBorder,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? const [Color(0xFF2A2620), Color(0xFF221F1A)]
                  : [const Color(0xFFFFFFFF), const Color(0xFFFFFAEC)],
            ),
          ),
          child: Center(
            child: icon != null
                ? Icon(
                    icon,
                    color: enabled ? MohajonWarm.muted : MohajonWarm.muted,
                    size: 24,
                  )
                : Text(
                    label,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: enabled ? MohajonWarm.ink : MohajonWarm.muted,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: MohajonWarm.goldBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: MohajonWarm.ink, size: 20),
      ),
    );
  }
}