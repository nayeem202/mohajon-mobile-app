import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'dart:async';
import 'dart:convert';

import 'package:intl/intl.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/fcm_service.dart';
import '../../../core/services/notification_preferences.dart';
import '../../../core/services/app_feedback.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/widgets/async_action_state.dart';
import '../../../core/app/app_providers.dart';
import '../../../core/app/app_lock_controller.dart';
import '../../../core/app/app_lock_screen.dart';
import '../../../core/app/quick_tour_screen.dart';
import '../../../core/services/download_export_service.dart';
import '../../../core/services/sync_service.dart';
import '../../profile/presentation/widgets/animated_section.dart';
import 'account_security_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with AsyncActionState<SettingsScreen> {
  late Box _settingsBox;
  bool _pushEnabled = true;
  final Set<String> _selectedTypes = {
    'Sales', 'Stock', 'Expenses', 'Payments', 'Investment', 'Platform',
  };

  @override
  void initState() {
    super.initState();
    _settingsBox = Hive.box('settings');
    _pushEnabled = _settingsBox.get(
          notificationPushEnabledKey,
          defaultValue: true,
        ) as bool;
    final saved = _settingsBox.get('notifTypes', defaultValue: <String>[]) as List;
    if (saved.isNotEmpty) {
      _selectedTypes.clear();
      _selectedTypes.addAll(saved.cast<String>());
      // Older builds omitted Platform from the default selection. Migrate
      // that old preference once so manual/system notifications are received.
      final migrated = _settingsBox.get('notifTypesPlatformMigrated', defaultValue: false) as bool;
      if (!migrated) {
        _selectedTypes.add('Platform');
        _settingsBox.put('notifTypesPlatformMigrated', true);
        _settingsBox.put('notifTypes', _selectedTypes.toList());
      }
    }
  }

  void _togglePush(bool val) {
    setState(() => _pushEnabled = val);
    unawaited(setNotificationPushEnabled(val));
    unawaited(ref.read(fcmServiceProvider).setEnabled(val));
  }

  void _toggleType(String type) {
    if (!_pushEnabled) return;
    setState(() {
      if (_selectedTypes.contains(type)) {
        _selectedTypes.remove(type);
      } else {
        _selectedTypes.add(type);
      }
    });
    _settingsBox.put('notifTypes', _selectedTypes.toList());
    unawaited(ref.read(fcmServiceProvider).syncPreferences());
  }

  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
          ],
        ),
        backgroundColor: const Color(0xFF1C1917),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openLegal(String title, String body) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _LegalScreen(title: title, body: body)),
    );
  }

  void _openSupport() {
    const email = 'mohajon.support@gmail.com';
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: MohajonWarm.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: MohajonWarm.muted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: MohajonWarm.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.headset_mic_rounded,
                    color: MohajonWarm.primary, size: 28),
              ),
              const SizedBox(height: 12),
              Text(l10n.t('contactSupport'),
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: MohajonWarm.ink)),
              const SizedBox(height: 6),
              Text(
                l10n.t('replyWithin24'),
                style: const TextStyle(fontSize: 12, color: MohajonWarm.muted),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: MohajonWarm.goldBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.email_rounded,
                        color: MohajonWarm.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(email,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: MohajonWarm.ink)),
                    ),
                    IconButton(
                      onPressed: () {
                        Clipboard.setData(const ClipboardData(text: email));
                        Navigator.of(ctx).pop();
                        _showToast(l10n.t('emailCopied'));
                      },
                      icon: const Icon(Icons.copy_rounded, size: 20),
                      color: MohajonWarm.primary,
                      tooltip: l10n.t('copyEmail'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Clipboard.setData(const ClipboardData(text: email));
                    Navigator.of(ctx).pop();
                    _showToast(l10n.t('supportEmailCopied'));
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: Text(l10n.t('copyEmailAddress')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Theme(
      data: MohajonWarm.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: MohajonWarm.pageGradient),
          child: SafeArea(
            child: Column(
              children: [
                _Header(onBack: () => Navigator.of(context).pop()),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      AnimatedSection(
                        child: _ExpandableSection(
                          icon: Icons.notifications_outlined,
                          title: l10n.t('notifications'),
                          subtitle: l10n.t('controlAlerts'),
                          accentColor: MohajonWarm.orange,
                          initiallyExpanded: true,
                          status: _StatusChip(
                            _pushEnabled ? l10n.t('onKey') : l10n.t('offKey'),
                            active: _pushEnabled,
                          ),
                          child: _NotifBody(
                            pushEnabled: _pushEnabled,
                            selectedTypes: _selectedTypes,
                            onTogglePush: _togglePush,
                            onToggleType: _toggleType,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      AnimatedSection(
                        delay: const Duration(milliseconds: 60),
                        child: _ExpandableSection(
                          icon: Icons.tune_rounded,
                          title: l10n.t('appPreferences'),
                          subtitle: l10n.t('customizeApp'),
                          accentColor: MohajonWarm.primary,
                          child: _AppPrefsBody(onToast: _showToast),
                        ),
                      ),
                      const SizedBox(height: 14),
                      AnimatedSection(
                        delay: const Duration(milliseconds: 120),
                        child: _ExpandableSection(
                          icon: Icons.smartphone_rounded,
                          title: l10n.t('soundAndDisplay'),
                          subtitle: l10n.t('adjustSound'),
                          accentColor: MohajonWarm.green,
                          child: const _SoundDisplayBody(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      AnimatedSection(
                        delay: const Duration(milliseconds: 180),
                        child: _ExpandableSection(
                          icon: Icons.shield_outlined,
                          title: l10n.t('security'),
                          subtitle: l10n.t('protectAccount'),
                          accentColor: const Color(0xFF0F766E),
                          child: _SecurityBody(
                            onNavigate: (screen) => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => screen),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      AnimatedSection(
                        delay: const Duration(milliseconds: 240),
                        child: _ExpandableSection(
                          icon: Icons.storage_rounded,
                          title: l10n.t('dataAndBackup'),
                          subtitle: l10n.t('manageData'),
                          accentColor: const Color(0xFFB45309),
                          child: _DataBackupBody(onToast: _showToast),
                        ),
                      ),
                      const SizedBox(height: 14),
                      AnimatedSection(
                        delay: const Duration(milliseconds: 240),
                        child: _ExpandableSection(
                          icon: Icons.cloud_sync_rounded,
                          title: l10n.t('internetAndSync'),
                          subtitle: l10n.t('internetAndSyncDesc'),
                          accentColor: const Color(0xFF0F766E),
                          child: _InternetSyncBody(onToast: _showToast),
                        ),
                      ),
                      const SizedBox(height: 14),
                      AnimatedSection(
                        delay: const Duration(milliseconds: 300),
                        child: _ExpandableSection(
                          icon: Icons.info_outline_rounded,
                          title: l10n.t('aboutSection'),
                          subtitle: l10n.t('appInfo'),
                          accentColor: MohajonWarm.primary,
                          child: _AboutBody(
                            onTerms: () => _openLegal(l10n.t('termsOfService'), l10n.t('termsBody')),
                            onPrivacy: () => _openLegal(l10n.t('privacyPolicy'), l10n.t('privacyBody')),
                            onSupport: () => _openSupport(),
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
      ),
    );
  }
}

/* ========== Header ========== */

class _Header extends StatelessWidget {
  const _Header({
    required this.onBack,
    this.title,
  });

  final VoidCallback onBack;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final resolvedTitle = title ?? l10n.t('settingsTitle');
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
      child: Row(
        children: [
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(11),
            child: InkWell(
              borderRadius: BorderRadius.circular(11),
              onTap: onBack,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: MohajonWarm.goldBorder),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: MohajonWarm.ink,
                  size: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [MohajonWarm.primary, MohajonWarm.primaryPale],
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: MohajonWarm.primary.withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.settings_rounded, color: MohajonWarm.ink, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resolvedTitle,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: MohajonWarm.ink,
                  ),
                ),
                Text(
                  l10n.t('settingsSubtitle'),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF77735F),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ========== Expandable Section ========== */

class _ExpandableSection extends StatefulWidget {
  const _ExpandableSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.child,
    this.initiallyExpanded = false,
    this.status,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final Widget child;
  final bool initiallyExpanded;
  final Widget? status;

  @override
  State<_ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<_ExpandableSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _heightFactor;
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _heightFactor = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    if (_expanded) _controller.value = 1.0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: MohajonWarm.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MohajonWarm.goldBorder),
        boxShadow: [
          BoxShadow(
            color: MohajonWarm.ink.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(widget.icon, color: widget.accentColor, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: MohajonWarm.ink)),
                        const SizedBox(height: 2),
                        Text(widget.subtitle,
                            style: const TextStyle(
                                fontSize: 12,
                                color: MohajonWarm.muted,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  if (widget.status != null) ...[
                    widget.status!,
                    const SizedBox(width: 8),
                  ],
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 320),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        color: MohajonWarm.muted, size: 22),
                  ),
                ],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _heightFactor,
            builder: (context, child) => ClipRect(
              child: Align(
                heightFactor: _heightFactor.value,
                child: child,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Divider(height: 1, color: MohajonWarm.goldBorder),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                  child: widget.child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.label, {this.active = true});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? MohajonWarm.green : MohajonWarm.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

/* ========== Notifications Body ========== */

class _NotifBody extends StatelessWidget {
  const _NotifBody({
    required this.pushEnabled,
    required this.selectedTypes,
    required this.onTogglePush,
    required this.onToggleType,
  });

  final bool pushEnabled;
  final Set<String> selectedTypes;
  final ValueChanged<bool> onTogglePush;
  final ValueChanged<String> onToggleType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PushToggleRow(
          enabled: pushEnabled,
          onToggle: onTogglePush,
        ),
        const SizedBox(height: 14),
        ..._notifTypes.map((t) => _NotifTypeRow(
          type: t,
          selected: selectedTypes.contains(t),
          disabled: !pushEnabled,
          onTap: () => onToggleType(t),
        )),
      ],
    );
  }
}

const _notifTypes = ['Sales', 'Stock', 'Expenses', 'Payments', 'Investment', 'Platform'];

IconData _notifIcon(String type) {
  switch (type) {
    case 'Sales': return Icons.trending_up_rounded;
    case 'Stock': return Icons.inventory_2_rounded;
    case 'Expenses': return Icons.wallet_rounded;
    case 'Payments': return Icons.payments_rounded;
    case 'Investment': return Icons.account_balance_rounded;
    case 'Platform': return Icons.devices_rounded;
    default: return Icons.circle_rounded;
  }
}

String _notifTypeLabel(String type, AppLocalizations l10n) {
  switch (type) {
    case 'Sales': return l10n.t('notifSales');
    case 'Stock': return l10n.t('notifStock');
    case 'Expenses': return l10n.t('notifExpenses');
    case 'Payments': return l10n.t('notifPayments');
    case 'Investment': return l10n.t('notifInvestment');
    case 'Platform': return l10n.t('notifPlatform');
    default: return type;
  }
}

class _PushToggleRow extends StatelessWidget {
  const _PushToggleRow({required this.enabled, required this.onToggle});

  final bool enabled;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = MohajonWarm.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.notifications_active_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.t('pushNotifications'),
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: MohajonWarm.ink)),
                const SizedBox(height: 2),
                Text(
                  enabled ? l10n.t('allAlertsEnabled') : l10n.t('allAlertsSilenced'),
                  style: TextStyle(
                    fontSize: 11, color: MohajonWarm.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          _Switch(
            value: enabled,
            onChanged: onToggle,
          ),
        ],
      ),
    );
  }
}

class _NotifTypeRow extends StatelessWidget {
  const _NotifTypeRow({
    required this.type,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final String type;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = MohajonWarm.orange;
    final isActive = selected && !disabled;

    return Opacity(
      opacity: disabled ? 0.4 : 1.0,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? accent.withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isActive ? accent : const Color(0xFFF4EFE2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _notifIcon(type),
                  color: isActive ? Colors.white : MohajonWarm.muted,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _notifTypeLabel(type, l10n),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? MohajonWarm.ink : MohajonWarm.muted,
                  ),
                ),
              ),
              _CheckCircle(
                selected: selected,
                disabled: disabled,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckCircle extends StatelessWidget {
  const _CheckCircle({required this.selected, required this.disabled});

  final bool selected;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final accent = MohajonWarm.orange;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected && !disabled ? accent : Colors.transparent,
        border: Border.all(
          color: selected && !disabled
              ? accent
              : const Color(0xFFD8CBB2),
          width: 2,
        ),
      ),
      child: selected && !disabled
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
          : null,
    );
  }
}

/* ========== App Preferences Body ========== */

class _AppPrefsBody extends ConsumerWidget {
  const _AppPrefsBody({required this.onToast});

  final void Function(String) onToast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NavRow(
          icon: Icons.translate_rounded,
          label: l10n.t('languageSettings'),
          value: locale.languageCode == 'bn'
              ? l10n.t('bangla')
              : l10n.t('english'),
          trailing: SegmentedButton<String>(
            style: _segmentStyle(),
            segments: [
              ButtonSegment(value: 'en', label: Text(l10n.t('english'))),
              ButtonSegment(value: 'bn', label: Text(l10n.t('bangla'))),
            ],
            selected: {locale.languageCode},
            onSelectionChanged: (value) {
              final code = value.first;
              ref
                  .read(localDatabaseProvider)
                  .settings
                  .put('languageCode', code);
              ref.read(localeProvider.notifier).state = Locale(code);
            },
          ),
          onTap: null,
        ),
        _Divider(),
        _NavRow(
          icon: Icons.dark_mode_rounded,
          label: l10n.t('theme'),
          value: _themeLabel(l10n, themeMode),
          trailing: SegmentedButton<ThemeMode>(
            style: _segmentStyle(),
            segments: const [
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_outlined, size: 16),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.settings_suggest_outlined, size: 16),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined, size: 16),
              ),
            ],
            selected: {themeMode},
            onSelectionChanged: (value) {
              final mode = value.first;
              ref.read(themeModeProvider.notifier).state = mode;
              ref
                  .read(localDatabaseProvider)
                  .settings
                  .put('themeMode', mode.name);
            },
          ),
          onTap: null,
        ),
        _Divider(),
        _NavRow(
          icon: Icons.attach_money_rounded,
          label: l10n.t('currencySettings'),
          value: l10n.t('currencyValue'),
          onTap: () => onToast(l10n.t('currencyComing')),
        ),
        _Divider(),
        _NavRow(
          icon: Icons.calendar_today_rounded,
          label: l10n.t('dateFormatSettings'),
          value: l10n.t('dateFormatValue'),
          onTap: () => onToast(l10n.t('dateFormatComing')),
        ),
        _Divider(),
        _NavRow(
          icon: Icons.info_outline_rounded,
          label: l10n.t('viewTour'),
          value: l10n.t('viewTourDesc'),
          onTap: () {
            Hive.box('settings').put('hasSeenTour', false);
            Hive.box('settings').put('hasSeenOnboarding', false);
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => const QuickTourScreen(includeWelcome: false),
              ),
              (_) => false,
            );
          },
        ),
      ],
    );
  }
}

ButtonStyle _segmentStyle() {
  return SegmentedButton.styleFrom(
    visualDensity: VisualDensity.compact,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    backgroundColor: Colors.white,
    selectedBackgroundColor: MohajonWarm.primary,
    selectedForegroundColor: const Color(0xFF5D4A00),
    foregroundColor: MohajonWarm.muted,
    side: const BorderSide(color: MohajonWarm.goldBorder),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    textStyle: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w800,
    ),
  );
}

String _themeLabel(AppLocalizations l10n, ThemeMode mode) {
  return switch (mode) {
    ThemeMode.light => l10n.t('lightMode'),
    ThemeMode.dark => l10n.t('darkMode'),
    ThemeMode.system => l10n.t('systemTheme'),
  };
}

/* ========== Sound & Display Body ========== */

class _SoundDisplayBody extends StatefulWidget {
  const _SoundDisplayBody();

  @override
  State<_SoundDisplayBody> createState() => _SoundDisplayBodyState();
}

class _SoundDisplayBodyState extends State<_SoundDisplayBody> {
  late Box _box;
  bool _sound = true;
  bool _haptic = true;

  @override
  void initState() {
    super.initState();
    _box = Hive.box('settings');
    _sound = _box.get('soundEffects', defaultValue: true) as bool;
    _haptic = _box.get('hapticFeedback', defaultValue: true) as bool;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ToggleRow(
          icon: Icons.volume_up_rounded,
          label: l10n.t('soundEffects'),
          subtitle: l10n.t('playSoundOnKeyActions'),
          value: _sound,
          onChanged: (v) {
            setState(() => _sound = v);
            _box.put('soundEffects', v);
            AppFeedback.tap();
            _notify(v ? l10n.t('soundEffectsOn') : l10n.t('soundEffectsOff'));
          },
        ),
        _Divider(),
        _ToggleRow(
          icon: Icons.vibration_rounded,
          label: l10n.t('hapticFeedback'),
          subtitle: l10n.t('vibrateOnInteractions'),
          value: _haptic,
          onChanged: (v) {
            setState(() => _haptic = v);
            _box.put('hapticFeedback', v);
            AppFeedback.tap();
            _notify(v ? l10n.t('hapticOn') : l10n.t('hapticOff'));
          },
        ),
      ],
    );
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/* ========== Security Body ========== */

class _SecurityBody extends StatelessWidget {
  const _SecurityBody({required this.onNavigate});

  final void Function(Widget) onNavigate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NavRow(
          icon: Icons.lock_outline_rounded,
          label: l10n.t('changePassword'),
          value: '',
          onTap: () => onNavigate(const AccountSecurityScreen()),
        ),
        _Divider(),
        _AppLockRow(),
      ],
    );
  }
}

class _AppLockRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locked = ref.watch(appLockProvider).enabled;

    return Column(
      children: [
        _RowBase(
          leading: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFF4EFE2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.lock_outline_rounded,
              color: locked ? MohajonWarm.orange : MohajonWarm.muted,
              size: 16,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('appLock'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: MohajonWarm.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.t('requirePinToOpen'),
                      style: TextStyle(fontSize: 11, color: MohajonWarm.muted),
                    ),
                  ],
                ),
              ),
              _Switch(
                value: locked,
                onChanged: (v) => _onToggle(context, ref, v),
              ),
            ],
          ),
        ),
        if (locked)
          _NavRow(
            icon: Icons.password_rounded,
            label: l10n.t('changeAppPin'),
            value: '',
            onTap: () => _onChangePin(context, ref),
          ),
      ],
    );
  }

  Future<void> _onToggle(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(appLockProvider.notifier);

    if (value) {
      final pin = await Navigator.of(
        context,
      ).push<String>(MaterialPageRoute(builder: (_) => const SetAppPinScreen()));
      if (pin == null || !context.mounted) return;
      await controller.enable(pin: pin);
      if (context.mounted) _toast(context, l10n.t('appLockOn'));
      return;
    }

    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AppLockScreen(
          title: l10n.t('enterPinTitle'),
          subtitle: l10n.t('confirmPinToTurnOff'),
          showBack: true,
          autoPopOnSuccess: true,
          lockoutRemaining: () => controller.lockoutRemaining,
          onSubmit: (pin) async => controller.verify(pin),
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    await controller.disable();
    if (context.mounted) _toast(context, l10n.t('appLockOff'));
  }

  Future<void> _onChangePin(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(appLockProvider.notifier);

    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AppLockScreen(
          title: l10n.t('changePinTitle'),
          subtitle: l10n.t('enterCurrentPinSubtitle'),
          showBack: true,
          autoPopOnSuccess: true,
          lockoutRemaining: () => controller.lockoutRemaining,
          onSubmit: (pin) async => controller.verify(pin),
        ),
      ),
    );
    if (verified != true || !context.mounted) return;

    final pin = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const SetAppPinScreen()));
    if (pin == null || !context.mounted) return;
    await controller.enable(pin: pin);
    if (context.mounted) _toast(context, l10n.t('pinChanged'));
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
          ],
        ),
        backgroundColor: const Color(0xFF1C1917),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/* ========== Data & Backup Body ========== */

/* ========== Internet & Sync Body ========== */

class _InternetSyncBody extends ConsumerWidget {
  const _InternetSyncBody({required this.onToast});

  final void Function(String) onToast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(syncStateProvider);

    final (icon, color, label) = switch (state.phase) {
      SyncPhase.offline => (
        Icons.cloud_off_rounded,
        const Color(0xFFBE3A1A),
        l10n.t('offlineModeTitle'),
      ),
      SyncPhase.syncing => (
        Icons.cloud_sync_rounded,
        MohajonWarm.goldText,
        l10n.t('syncingNowTitle'),
      ),
      SyncPhase.failed => (
        Icons.sync_problem_rounded,
        MohajonWarm.red,
        l10n.t('syncFailed'),
      ),
      SyncPhase.idle => (
        state.pendingCount > 0
            ? Icons.cloud_upload_outlined
            : Icons.cloud_done_rounded,
        MohajonWarm.green,
        l10n.t('syncedKey'),
      ),
      SyncPhase.notSignedIn => (
        Icons.cloud_off_rounded,
        MohajonWarm.muted,
        l10n.t('signInToSync'),
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.30)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                    if (state.pendingCount > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        l10n.tP('pendingCount', {'count': '${state.pendingCount}'}),
                        style: TextStyle(fontSize: 11, color: MohajonWarm.muted),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(
                height: 34,
                child: FilledButton.icon(
                  onPressed: () =>
                      ref.read(syncStateProvider.notifier).syncNow(),
                  style: FilledButton.styleFrom(
                    backgroundColor: MohajonWarm.primary,
                    foregroundColor: MohajonWarm.ink,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.sync_rounded, size: 15),
                  label: Text(
                    l10n.t('syncNow'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.t('connectivityHowWorks'),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: MohajonWarm.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.t('connectivityHowWorksDesc'),
          style: const TextStyle(
            fontSize: 12,
            height: 1.5,
            color: MohajonWarm.muted,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          l10n.t('offlineWorksTitle'),
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
            color: MohajonWarm.green,
          ),
        ),
        const SizedBox(height: 6),
        _FeatureTag(
          icon: Icons.edit_note_rounded,
          label: l10n.t('offlineFeatureEntry'),
        ),
        const SizedBox(height: 6),
        _FeatureTag(
          icon: Icons.bar_chart_rounded,
          label: l10n.t('offlineFeatureReports'),
        ),
        const SizedBox(height: 6),
        _FeatureTag(
          icon: Icons.sd_storage_outlined,
          label: l10n.t('offlineFeatureBackup'),
        ),
        const SizedBox(height: 14),
        Text(
          l10n.t('onlineNeedsTitle'),
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
            color: Color(0xFFB45309),
          ),
        ),
        const SizedBox(height: 6),
        _FeatureTag(
          icon: Icons.sync_rounded,
          label: l10n.t('onlineFeatureSync'),
          online: true,
        ),
        const SizedBox(height: 6),
        _FeatureTag(
          icon: Icons.account_balance_wallet_outlined,
          label: l10n.t('onlineFeatureBkash'),
          online: true,
        ),
        const SizedBox(height: 6),
        _FeatureTag(
          icon: Icons.workspace_premium_outlined,
          label: l10n.t('onlineFeatureSubscription'),
          online: true,
        ),
        const SizedBox(height: 6),
        _FeatureTag(
          icon: Icons.chat_outlined,
          label: l10n.t('onlineFeatureWhatsApp'),
          online: true,
        ),
        const SizedBox(height: 6),
        _FeatureTag(
          icon: Icons.mic_none_rounded,
          label: l10n.t('onlineFeatureVoice'),
          online: true,
        ),
        const SizedBox(height: 6),
        _FeatureTag(
          icon: Icons.login_rounded,
          label: l10n.t('onlineFeatureLogin'),
          online: true,
        ),
      ],
    );
  }
}

class _FeatureTag extends StatelessWidget {
  const _FeatureTag({required this.icon, required this.label, this.online = false});

  final IconData icon;
  final String label;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final color = online ? const Color(0xFFB45309) : MohajonWarm.green;
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: MohajonWarm.ink,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            l10n.t(online ? 'badgeOnline' : 'badgeOffline'),
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _DataBackupBody extends ConsumerWidget {
  const _DataBackupBody({required this.onToast});

  final void Function(String) onToast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NavRow(
          icon: Icons.file_download_outlined,
          label: l10n.t('exportData'),
          value: '',
          onTap: () async {
            onToast(l10n.t('dataExportStarted'));
            try {
              await _exportBackup(ref);
              if (context.mounted) onToast(l10n.t('dataExportComplete'));
            } catch (_) {
              if (context.mounted) onToast(l10n.t('dataExportFailed'));
            }
          },
        ),
        _Divider(),
        _NavRow(
          icon: Icons.cleaning_services_outlined,
          label: l10n.t('clearCache'),
          value: '',
          onTap: () => onToast(l10n.t('cacheCleared')),
        ),
      ],
    );
  }
}

/// Writes all local business collections to a single JSON file in Downloads.
/// Auth tokens, the app-lock PIN, and other credentials are deliberately
/// excluded so a backup never carries secrets.
Future<void> _exportBackup(WidgetRef ref) async {
  final db = ref.read(localDatabaseProvider);
  final backup = <String, Object>{
    'app': 'Mohajon',
    'exportedAt': DateTime.now().toIso8601String(),
    'products': db.products.values(includeDeleted: true).map((e) => e.toJson()).toList(),
    'customers': db.customers.values(includeDeleted: true).map((e) => e.toJson()).toList(),
    'sales': db.sales.values(includeDeleted: true).map((e) => e.toJson()).toList(),
    'customerLedgerEntries': db.customerLedgerEntries
        .values(includeDeleted: true)
        .map((e) => e.toJson())
        .toList(),
    'payments': db.payments.values(includeDeleted: true).map((e) => e.toJson()).toList(),
    'purchases': db.purchases.values(includeDeleted: true).map((e) => e.toJson()).toList(),
    'suppliers': db.suppliers.values(includeDeleted: true).map((e) => e.toJson()).toList(),
    'vendors': db.vendors.values(includeDeleted: true).map((e) => e.toJson()).toList(),
    'vendorPurchases': db.vendorPurchases
        .values(includeDeleted: true)
        .map((e) => e.toJson())
        .toList(),
    'vendorPayments': db.vendorPayments
        .values(includeDeleted: true)
        .map((e) => e.toJson())
        .toList(),
    'expenses': db.expenses.values(includeDeleted: true).map((e) => e.toJson()).toList(),
    'users': db.users.values(includeDeleted: true).map((e) => e.toJson()).toList(),
  };
  final json = const JsonEncoder.withIndent('  ').convert(backup);
  final fileName =
      'mohajon-backup-${DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now())}.json';
  await DownloadExportService().saveFileToDownloads(
    fileName: fileName,
    mimeType: 'application/json',
    bytes: Uint8List.fromList(utf8.encode(json)),
  );
}

/* ========== About Body ========== */

class _AboutBody extends StatelessWidget {
  const _AboutBody({
    required this.onTerms,
    required this.onPrivacy,
    required this.onSupport,
  });

  final VoidCallback onTerms;
  final VoidCallback onPrivacy;
  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NavRow(
          icon: Icons.smartphone_rounded,
          label: l10n.t('appVersion'),
          value: '1.0.0',
          trailing: Text('1.0.0',
              style: TextStyle(
                  fontSize: 12, color: MohajonWarm.muted,
                  fontWeight: FontWeight.w500)),
          readOnly: true,
          onTap: null,
        ),
        _Divider(),
        _NavRow(
          icon: Icons.description_outlined,
          label: l10n.t('termsOfService'),
          value: '',
          onTap: onTerms,
        ),
        _Divider(),
        _NavRow(
          icon: Icons.privacy_tip_outlined,
          label: l10n.t('privacyPolicy'),
          value: '',
          onTap: onPrivacy,
        ),
        _Divider(),
        _NavRow(
          icon: Icons.headset_mic_outlined,
          label: l10n.t('contactSupport'),
          value: '',
          onTap: onSupport,
        ),
      ],
    );
  }
}

/* ========== Legal Screen ========== */

class _LegalScreen extends StatelessWidget {
  const _LegalScreen({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final paragraphs = body
        .split('\n\n')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    return Theme(
      data: MohajonWarm.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: MohajonWarm.pageGradient),
          child: SafeArea(
            child: Column(
              children: [
                _Header(onBack: () => Navigator.of(context).pop(), title: title),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: MohajonWarm.card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: MohajonWarm.goldBorder),
                          boxShadow: [
                            BoxShadow(
                              color: MohajonWarm.ink.withValues(alpha: 0.06),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: paragraphs
                              .map((p) => Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 14),
                                    child: Text(
                                      p,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        height: 1.6,
                                        color: MohajonWarm.ink,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                    ],
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

/* ========== Shared Widgets ========== */

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
    this.readOnly = false,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _RowBase(
      leading: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFFF4EFE2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: MohajonWarm.muted, size: 16),
      ),
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500,
                        color: MohajonWarm.ink)),
                if (value.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(value,
                      style: TextStyle(fontSize: 11, color: MohajonWarm.muted)),
                ],
              ],
            ),
          ),
          trailing ??
              Icon(Icons.chevron_right_rounded,
                  color: MohajonWarm.muted.withValues(alpha: 0.5), size: 20),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _RowBase(
      leading: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFFF4EFE2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: MohajonWarm.muted, size: 16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500,
                        color: MohajonWarm.ink)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(fontSize: 11, color: MohajonWarm.muted)),
              ],
            ),
          ),
          _Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _RowBase extends StatelessWidget {
  const _RowBase({
    required this.leading,
    this.child,
    this.onTap,
  });

  final Widget leading;
  final Widget? child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(child: child ?? const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 26,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            color: value
                ? MohajonWarm.orange
                : const Color(0xFFD8CBB2),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.all(3),
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 2,
                    offset: Offset(0, 1),
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

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: const Color(0xFFF0E8D6),
    );
  }
}
