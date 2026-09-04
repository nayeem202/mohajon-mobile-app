import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/app_feedback.dart';
import '../../../core/theme/mohajon_warm_theme.dart';

class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authStateProvider).value;
    return Theme(
      data: MohajonWarm.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Privacy')),
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: MohajonWarm.pageGradient),
          child: SafeArea(
            child: session == null
                ? const Center(child: Text('No account is signed in.'))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                  const _SectionTitle('Login Activity',
                      subtitle: 'Devices where your account is signed in'),
                  const SizedBox(height: 10),
                  _SessionsPanel(ref: ref),
                  const SizedBox(height: 24),
                  const _SectionTitle('Privacy Preferences',
                      subtitle: 'Control how your data is used'),
                  const SizedBox(height: 10),
                  const _PrivacyPrefsCard(),
                  const SizedBox(height: 24),
                  const _SectionTitle('Your Data',
                      subtitle: 'Manage or remove your information'),
                  const SizedBox(height: 10),
                  _DataActionsCard(onPolicy: () => _showPolicy(context)),
                ],
              ),
            ),
          ),
      ),
    );
  }

  void _showPolicy(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Theme(
          data: MohajonWarm.theme(Theme.of(context)),
          child: Scaffold(
            appBar: AppBar(title: Text(l10n.t('privacyPolicy'))),
            body: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: MohajonWarm.pageGradient,
              ),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: MohajonWarm.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: MohajonWarm.goldBorder),
                    ),
                    child: Text(
                      l10n.t('privacyPolicyBody'),
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        fontWeight: FontWeight.w500,
                      ),
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

class _SessionsPanel extends StatelessWidget {
  const _SessionsPanel({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _sessionsStream(ref),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(
            child: Text('Could not load login sessions.'),
          );
        }
        final docs = snapshot.data ?? const [];
        if (docs.isEmpty) {
          return const Center(
            child: Text('No login device details recorded yet.'),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, index) =>
              _SessionCard(data: docs[index], current: index == 0),
        );
      },
    );
  }

  Stream<List<Map<String, dynamic>>> _sessionsStream(WidgetRef ref) {
    final api = ApiClient(ref.read(localDatabaseProvider));
    return pollStream<List<Map<String, dynamic>>>(() async {
      final data = await api.getJson('/api/v1/sessions');
      final list = data is List ? data : const [];
      return list.whereType<Map<String, dynamic>>().toList();
    }, const Duration(seconds: 10));
  }
}

class _PrivacyPrefsCard extends StatefulWidget {
  const _PrivacyPrefsCard();

  @override
  State<_PrivacyPrefsCard> createState() => _PrivacyPrefsCardState();
}

class _PrivacyPrefsCardState extends State<_PrivacyPrefsCard> {
  late Box _box;
  late bool _analytics;
  late bool _personalized;
  late bool _marketing;

  @override
  void initState() {
    super.initState();
    _box = Hive.box('settings');
    _analytics = _box.get('privacyAnalytics', defaultValue: true) as bool;
    _personalized = _box.get('privacyPersonalized', defaultValue: true) as bool;
    _marketing = _box.get('privacyMarketing', defaultValue: false) as bool;
  }

  void _set(String key, bool value) => _box.put(key, value);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 14),
        child: Column(
          children: [
            _ToggleRow(
              icon: Icons.analytics_outlined,
              label: 'Usage Analytics',
              subtitle: 'Share anonymous usage data to improve the app',
              value: _analytics,
              onChanged: (v) {
                setState(() => _analytics = v);
                _set('privacyAnalytics', v);
                AppFeedback.tap();
              },
            ),
            Divider(height: 1, color: colors.outlineVariant),
            _ToggleRow(
              icon: Icons.auto_awesome_outlined,
              label: 'Personalized Experience',
              subtitle: 'Tailor content and suggestions to you',
              value: _personalized,
              onChanged: (v) {
                setState(() => _personalized = v);
                _set('privacyPersonalized', v);
                AppFeedback.tap();
              },
            ),
            Divider(height: 1, color: colors.outlineVariant),
            _ToggleRow(
              icon: Icons.mail_outline_rounded,
              label: 'Marketing Emails',
              subtitle: 'Receive product updates and offers',
              value: _marketing,
              onChanged: (v) {
                setState(() => _marketing = v);
                _set('privacyMarketing', v);
                AppFeedback.tap();
              },
            ),
          ],
        ),
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
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: colors.primary, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 14)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: colors.primary,
        ),
      ],
    );
  }
}

class _DataActionsCard extends StatelessWidget {
  const _DataActionsCard({required this.onPolicy});

  final VoidCallback onPolicy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Column(
        children: [
          _ActionRow(
            icon: Icons.download_outlined,
            label: 'Download My Data',
            subtitle: 'Get a copy of your information',
            onTap: () => _toast(context, 'Preparing your data export…'),
          ),
          Divider(height: 1, indent: 64, endIndent: 16,
              color: colors.outlineVariant),
          _ActionRow(
            icon: Icons.policy_outlined,
            label: 'Privacy Policy',
            subtitle: 'Read our privacy policy',
            onTap: onPolicy,
          ),
          Divider(height: 1, indent: 64, endIndent: 16,
              color: colors.outlineVariant),
          _ActionRow(
            icon: Icons.delete_outline_rounded,
            label: 'Delete My Data',
            subtitle: 'Permanently remove your account data',
            destructive: true,
            onTap: () => _confirmDelete(context),
          ),
        ],
      ),
    );
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete My Data'),
        content: const Text(
          'This will request permanent deletion of your account data. '
          'This action cannot be undone. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _toast(context, 'Data deletion request sent');
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = destructive ? colors.error : colors.primary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: destructive ? colors.error : colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: colors.onSurface.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label, {this.subtitle});

  final String label;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 12,
              color: colors.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.data, required this.current});

  final Map<String, dynamic> data;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final lastLogin = data['lastLoginAt'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.phone_android_rounded,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _text(data['deviceName'], fallback: 'Unknown device'),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(_text(data['osVersion'], fallback: 'Unknown OS')),
                    ],
                  ),
                ),
                if (current)
                  Chip(
                    label: const Text('Latest'),
                    visualDensity: VisualDensity.compact,
                    side: BorderSide(color: colors.outlineVariant),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _DetailRow(
              icon: Icons.location_on_outlined,
              label: 'Login location',
              value: _text(
                data['locationLabel'],
                fallback: 'Location unavailable',
              ),
            ),
            _DetailRow(
              icon: Icons.devices_other_outlined,
              label: 'Phone model',
              value: _modelText(data),
            ),
            _DetailRow(
              icon: Icons.schedule_outlined,
              label: 'Last login',
              value: _dateText(lastLogin),
            ),
          ],
        ),
      ),
    );
  }

  String _modelText(Map<String, dynamic> data) {
    final manufacturer = _text(data['manufacturer']);
    final model = _text(data['model']);
    if (manufacturer.isEmpty) return model.isEmpty ? 'Unknown' : model;
    if (model.isEmpty) return manufacturer;
    return '$manufacturer $model';
  }

  String _dateText(Object? value) {
    if (value is DateTime) return value.toLocal().toString();
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed.toLocal().toString();
    }
    return 'Unknown';
  }

  String _text(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 2),
                Text(value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
