import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/api_client.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../models/notification_model.dart';

class PushNotificationSheet extends StatefulWidget {
  const PushNotificationSheet({super.key, required this.onSubmit});

  final Future<void> Function(
    NotificationType type,
    String title,
    String message,
  )
  onSubmit;

  @override
  State<PushNotificationSheet> createState() => _PushNotificationSheetState();
}

class _PushNotificationSheetState extends State<PushNotificationSheet> {
  NotificationType _selectedType = NotificationType.system;
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        _selectedType,
        _titleController.text.trim(),
        _messageController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('notificationSentSuccess'))),
      );
      Navigator.of(context).pop();
    } catch (error, stackTrace) {
      debugPrint('Notification send failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => _submitting = false);
      final message = switch (error) {
        ApiException(:final statusCode)
            when statusCode == 401 || statusCode == 403 =>
          l10n.t('sessionExpiredRetry'),
        ApiException(:final code) when code == 'FCM_NOT_CONFIGURED' =>
          l10n.t('fcmNotConfigured'),
        ApiException(:final code) when code == 'FCM_CONFIG_INVALID' =>
          l10n.t('fcmConfigInvalid'),
        ApiException(:final message) => message,
        _ => l10n.t('unableSendNotification'),
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [MohajonWarm.primaryPale, Color(0xFFFFFDF7)],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: MohajonWarm.primary, width: 2),
          ),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _Header(l10n: l10n, onClose: () => Navigator.of(context).pop()),
                const SizedBox(height: 20),
                _TypeSelector(l10n: l10n, selected: _selectedType, onSelected: (t) => setState(() => _selectedType = t)),
                const SizedBox(height: 16),
                _FormField(
                  label: l10n.t('notificationTitle'),
                  controller: _titleController,
                  placeholder: l10n.t('notificationTitleHint'),
                  validator: (v) =>
                      v?.trim().isEmpty == true ? l10n.t('titleRequired') : null,
                ),
                const SizedBox(height: 16),
                _FormField(
                  label: l10n.t('notificationMessage'),
                  controller: _messageController,
                  placeholder: l10n.t('notificationMessageHint'),
                  maxLines: 4,
                  validator: (v) =>
                      v?.trim().isEmpty == true ? l10n.t('messageRequired') : null,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 16),
                    label: Text(_submitting
                        ? l10n.t('sendingDots')
                        : l10n.t('sendNotification')),
                    style: FilledButton.styleFrom(
                      backgroundColor: MohajonWarm.primary,
                      foregroundColor: MohajonWarm.ink,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
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

class _Header extends StatelessWidget {
  const _Header({required this.l10n, required this.onClose});

  final AppLocalizations l10n;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: MohajonWarm.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.notifications_active_rounded,
            color: MohajonWarm.ink,
            size: 19,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            l10n.t('pushNewNotification'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: MohajonWarm.ink,
            ),
          ),
        ),
        GestureDetector(
          onTap: onClose,
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            child: const Icon(
              Icons.close_rounded,
              size: 20,
              color: MohajonWarm.muted,
            ),
          ),
        ),
      ],
    );
  }
}

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({
    required this.l10n,
    required this.selected,
    required this.onSelected,
  });

  final AppLocalizations l10n;
  final NotificationType selected;
  final void Function(NotificationType) onSelected;

  String _label(NotificationType type) => switch (type) {
        NotificationType.sale => l10n.t('typeSale'),
        NotificationType.stock => l10n.t('typeStock'),
        NotificationType.expense => l10n.t('typeExpense'),
        NotificationType.investment => l10n.t('typeInvestment'),
        NotificationType.due => l10n.t('typeDue'),
        NotificationType.system => l10n.t('typeSystem'),
        NotificationType.payment => l10n.t('typePayment'),
        NotificationType.summary => l10n.t('typeSale'),
        NotificationType.platform => l10n.t('typeSystem'),
      };

  static const _options = <NotificationType>[
    NotificationType.sale,
    NotificationType.stock,
    NotificationType.expense,
    NotificationType.investment,
    NotificationType.system,
    NotificationType.payment,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(l10n.t('typeLabel')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _options.map((type) {
            final isActive = type == selected;
            return GestureDetector(
              onTap: () => onSelected(type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isActive ? MohajonWarm.primary : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isActive
                        ? MohajonWarm.primary
                        : MohajonWarm.goldBorder,
                  ),
                ),
                child: Text(
                  _label(type),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isActive
                        ? MohajonWarm.ink
                        : MohajonWarm.muted,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: MohajonWarm.ink,
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  const _FormField({
    required this.label,
    required this.controller,
    required this.placeholder,
    this.maxLines = 1,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final String placeholder;
  final int maxLines;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          style: const TextStyle(fontSize: 13, color: MohajonWarm.ink),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: const TextStyle(
              fontSize: 13,
              color: MohajonWarm.muted,
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }
}