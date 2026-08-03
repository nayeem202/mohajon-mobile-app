import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_providers.dart';

class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authStateProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: session == null
          ? const Center(child: Text('No account is signed in.'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(session.userId)
                  .collection('login_sessions')
                  .orderBy('lastLoginAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Could not load login sessions.'),
                  );
                }
                final docs = snapshot.data?.docs ?? const [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('No login device details recorded yet.'),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    return _SessionCard(data: data, current: index == 0);
                  },
                );
              },
            ),
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
    if (value is Timestamp) return value.toDate().toLocal().toString();
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
