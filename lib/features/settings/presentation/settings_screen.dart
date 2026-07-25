import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/admin_service.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/widgets/async_action_state.dart';
import '../../auth/presentation/login_screen.dart';
import '../../auth/providers/auth_providers.dart';
import '../../staff/presentation/staff_list_screen.dart';
import 'account_security_screen.dart';
import 'customer_rules_settings_screen.dart';
import 'privacy_settings_screen.dart';

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
    'Sales', 'Stock', 'Expenses', 'Payments', 'Investment',
  };

  @override
  void initState() {
    super.initState();
    _settingsBox = Hive.box('settings');
    _pushEnabled = _settingsBox.get('pushEnabled', defaultValue: true) as bool;
    final saved = _settingsBox.get('notifTypes', defaultValue: <String>[]) as List;
    if (saved.isNotEmpty) {
      _selectedTypes.clear();
      _selectedTypes.addAll(saved.cast<String>());
    }
  }

  void _togglePush(bool val) {
    setState(() => _pushEnabled = val);
    _settingsBox.put('pushEnabled', val);
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F1),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Settings',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 20),
            child: Text(
              'Manage your app preferences and notifications',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          _NotifCard(
            pushEnabled: _pushEnabled,
            selectedTypes: _selectedTypes,
            onTogglePush: _togglePush,
            onToggleType: _toggleType,
          ),
          const SizedBox(height: 16),
          _AppPrefsCard(onToast: _showToast),
          const SizedBox(height: 16),
          _SoundDisplayCard(),
          const SizedBox(height: 16),
          _StaffCard(
            onNavigate: (screen) => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => screen),
            ),
          ),
          const SizedBox(height: 16),
          _SecurityCard(
            onNavigate: (screen) => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => screen),
            ),
          ),
          const SizedBox(height: 16),
          _DataBackupCard(onToast: _showToast),
          const SizedBox(height: 16),
          _AboutCard(onToast: _showToast),
          const SizedBox(height: 16),
          _DangerZoneCard(
            onSignOut: () async {
              await runBusyAction(() async {
                await ref.read(authServiceProvider).signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false,
                  );
                }
              });
            },
            onToast: _showToast,
          ),
        ],
      ),
    );
  }
}

/* ========== Notifications Card ========== */

class _NotifCard extends StatelessWidget {
  const _NotifCard({
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
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8DDD2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Control what alerts you receive',
            iconColor: colors.primary,
          ),
          const SizedBox(height: 14),
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
      ),
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

class _PushToggleRow extends StatelessWidget {
  const _PushToggleRow({required this.enabled, required this.onToggle});

  final bool enabled;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = const Color(0xFFF97316);

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
                Text('Push Notifications',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: colors.onSurface)),
                const SizedBox(height: 2),
                Text(
                  enabled ? 'All alerts enabled' : 'All alerts silenced',
                  style: TextStyle(
                    fontSize: 11, color: colors.onSurfaceVariant,
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
    final colors = Theme.of(context).colorScheme;
    final accent = const Color(0xFFF97316);
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
                  color: isActive ? accent : const Color(0xFFF2EFE9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _notifIcon(type),
                  color: isActive ? Colors.white : colors.onSurfaceVariant,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  type,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? colors.onSurface : colors.onSurfaceVariant,
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
    final accent = const Color(0xFFF97316);
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
              : const Color(0xFFD4C5B5),
          width: 2,
        ),
      ),
      child: selected && !disabled
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
          : null,
    );
  }
}

/* ========== App Preferences Card ========== */

class _AppPrefsCard extends StatelessWidget {
  const _AppPrefsCard({required this.onToast});

  final void Function(String) onToast;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.settings_rounded,
            title: 'App Preferences',
            subtitle: 'Customise your app experience',
            iconColor: colors.tertiary,
          ),
          const SizedBox(height: 8),
          _NavRow(
            icon: Icons.language_rounded,
            label: 'Language',
            value: 'English',
            onTap: () => onToast('Language settings coming soon'),
          ),
          _Divider(),
          _NavRow(
            icon: Icons.attach_money_rounded,
            label: 'Currency',
            value: 'BDT (৳)',
            onTap: () => onToast('Currency settings coming soon'),
          ),
          _Divider(),
          _NavRow(
            icon: Icons.calendar_today_rounded,
            label: 'Date Format',
            value: 'DD/MM/YYYY',
            onTap: () => onToast('Date format settings coming soon'),
          ),
        ],
      ),
    );
  }
}

/* ========== Sound & Display Card ========== */

class _SoundDisplayCard extends StatefulWidget {
  @override
  State<_SoundDisplayCard> createState() => _SoundDisplayCardState();
}

class _SoundDisplayCardState extends State<_SoundDisplayCard> {
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
    final colors = Theme.of(context).colorScheme;
    return _SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.smartphone_rounded,
            title: 'Sound & Display',
            subtitle: 'Adjust sound and visual feedback',
            iconColor: const Color(0xFF047857),
          ),
          const SizedBox(height: 8),
          _ToggleRow(
            icon: Icons.volume_up_rounded,
            label: 'Sound Effects',
            subtitle: 'Play sounds on key actions',
            value: _sound,
            onChanged: (v) {
              setState(() => _sound = v);
              _box.put('soundEffects', v);
            },
          ),
          _Divider(),
          _ToggleRow(
            icon: Icons.vibration_rounded,
            label: 'Haptic Feedback',
            subtitle: 'Vibrate on interactions',
            value: _haptic,
            onChanged: (v) {
              setState(() => _haptic = v);
              _box.put('hapticFeedback', v);
            },
          ),
        ],
      ),
    );
  }
}

/* ========== Staff Card ========== */

class _StaffCard extends StatelessWidget {
  const _StaffCard({required this.onNavigate});

  final void Function(Widget) onNavigate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.group_outlined,
            title: 'Staff Management',
            subtitle: 'Add and manage team members',
            iconColor: const Color(0xFF7C3AED),
          ),
          const SizedBox(height: 8),
          _NavRow(
            icon: Icons.people_alt_rounded,
            label: 'Shop Staff',
            value: '',
            onTap: () => onNavigate(const StaffListScreen()),
          ),
        ],
      ),
    );
  }
}

/* ========== Security Card ========== */

class _SecurityCard extends StatelessWidget {
  const _SecurityCard({required this.onNavigate});

  final void Function(Widget) onNavigate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.shield_outlined,
            title: 'Security',
            subtitle: 'Protect your account and data',
            iconColor: const Color(0xFF2563EB),
          ),
          const SizedBox(height: 8),
          _NavRow(
            icon: Icons.lock_outline_rounded,
            label: 'Change Password',
            value: '',
            onTap: () => onNavigate(const AccountSecurityScreen()),
          ),
          _Divider(),
          _AppLockRow(),
        ],
      ),
    );
  }
}

class _AppLockRow extends StatefulWidget {
  @override
  State<_AppLockRow> createState() => _AppLockRowState();
}

class _AppLockRowState extends State<_AppLockRow> {
  late Box _box;
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    _box = Hive.box('settings');
    _locked = _box.get('appLock', defaultValue: false) as bool;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _RowBase(
      leading: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFFF2EFE9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.lock_outline_rounded,
            color: colors.onSurfaceVariant, size: 16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('App Lock',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500,
                        color: colors.onSurface)),
                const SizedBox(height: 2),
                Text('Require PIN to open app',
                    style: TextStyle(
                        fontSize: 11, color: colors.onSurfaceVariant)),
              ],
            ),
          ),
          _Switch(
            value: _locked,
            onChanged: (v) {
              setState(() => _locked = v);
              _box.put('appLock', v);
            },
          ),
        ],
      ),
    );
  }
}

/* ========== Data & Backup Card ========== */

class _DataBackupCard extends StatelessWidget {
  const _DataBackupCard({required this.onToast});

  final void Function(String) onToast;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.storage_rounded,
            title: 'Data & Backup',
            subtitle: 'Manage your data and storage',
            iconColor: const Color(0xFF7C3AED),
          ),
          const SizedBox(height: 8),
          _NavRow(
            icon: Icons.file_download_outlined,
            label: 'Export Data',
            value: '',
            onTap: () => onToast('Data export started'),
          ),
          _Divider(),
          _NavRow(
            icon: Icons.cleaning_services_outlined,
            label: 'Clear Cache',
            value: '',
            onTap: () => onToast('Cache cleared successfully'),
          ),
        ],
      ),
    );
  }
}

/* ========== About Card ========== */

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.onToast});

  final void Function(String) onToast;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.info_outline_rounded,
            title: 'About',
            subtitle: 'App information and resources',
            iconColor: colors.primary,
          ),
          const SizedBox(height: 8),
          _NavRow(
            icon: Icons.smartphone_rounded,
            label: 'App Version',
            value: '1.0.0',
            trailing: Text('1.0.0',
                style: TextStyle(
                    fontSize: 12, color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w500)),
            readOnly: true,
            onTap: null,
          ),
          _Divider(),
          _NavRow(
            icon: Icons.description_outlined,
            label: 'Terms of Service',
            value: '',
            onTap: () => onToast('Opening Terms of Service...'),
          ),
          _Divider(),
          _NavRow(
            icon: Icons.privacy_tip_outlined,
            label: 'Privacy Policy',
            value: '',
            onTap: () => onToast('Opening Privacy Policy...'),
          ),
          _Divider(),
          _NavRow(
            icon: Icons.headset_mic_outlined,
            label: 'Contact Support',
            value: '',
            onTap: () => onToast('Opening support...'),
          ),
        ],
      ),
    );
  }
}

/* ========== Danger Zone Card ========== */

class _DangerZoneCard extends StatelessWidget {
  const _DangerZoneCard({
    required this.onSignOut,
    required this.onToast,
  });

  final VoidCallback onSignOut;
  final void Function(String) onToast;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.error.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.warning_amber_rounded,
            title: 'Danger Zone',
            subtitle: 'Irreversible account actions',
            iconColor: colors.error,
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onSignOut,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: colors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.logout_rounded,
                        color: colors.error, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Sign Out',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: colors.error)),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: colors.error, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ========== Shared Widgets ========== */

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8DDD2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 15),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700)),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }
}

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
    final colors = Theme.of(context).colorScheme;
    return _RowBase(
      leading: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFFF2EFE9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: colors.onSurfaceVariant, size: 16),
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
                        color: colors.onSurface)),
                if (value.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(value,
                      style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
                ],
              ],
            ),
          ),
          trailing ??
              Icon(Icons.chevron_right_rounded,
                  color: colors.onSurfaceVariant.withValues(alpha: 0.5), size: 20),
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
    final colors = Theme.of(context).colorScheme;
    return _RowBase(
      leading: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFFF2EFE9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: colors.onSurfaceVariant, size: 16),
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
                        color: colors.onSurface)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
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
                ? const Color(0xFFF97316)
                : const Color(0xFFD4C5B5),
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
      color: const Color(0xFFF0ECE4),
    );
  }
}
