import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/snackbar.dart';
import '../../../core/utils/app_error.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/widgets/action_button.dart';
import '../../../core/widgets/async_action_state.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/shop_avatar.dart';
import '../models/expense.dart';
import '../providers/expense_providers.dart';

class ExpenseFormScreen extends ConsumerStatefulWidget {
  const ExpenseFormScreen({super.key, this.expense});

  final Expense? expense;

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen>
    with AsyncActionState<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descriptionController;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;
  String? _categoryId;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    _descriptionController = TextEditingController(
      text: expense?.description ?? '',
    );
    _amountController = TextEditingController(
      text: expense == null ? '' : expense.amount.toStringAsFixed(2),
    );
    _notesController = TextEditingController(text: expense?.notes ?? '');
    _selectedDate = expense?.date ?? DateTime.now();
    _categoryId = expense?.categoryId;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _previewAmount =>
      double.tryParse(_amountController.text.trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(expenseCategoriesProvider);
    if (_categoryId == null && categories.isNotEmpty) {
      _categoryId = categories.first.id;
    }
    final isEditing = widget.expense != null;

    return withLoadingOverlay(
      Theme(
        data: MohajonWarm.theme(Theme.of(context)),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: MohajonWarm.pageGradient,
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -70,
                  right: -50,
                  child: IgnorePointer(
                    child: Container(
                      width: 190,
                      height: 190,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 34,
                  right: 96,
                  child: IgnorePointer(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 110,
                  left: -60,
                  child: IgnorePointer(
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      Expanded(
                        child: Form(
                          key: _formKey,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(
                              18,
                              12,
                              18,
                              16,
                            ),
                            children: [
                              _FormHeader(
                                title: isEditing
                                    ? 'Edit Expense'
                                    : 'Add Expense',
                                subtitle: 'Record shop spending',
                                onBack: () =>
                                    Navigator.of(context).maybePop(),
                              ),
                              const SizedBox(height: 18),
                              _SectionCard(
                                icon: Icons.receipt_long_rounded,
                                iconColor: MohajonWarm.goldText,
                                iconBackground: MohajonWarm.tintYellow,
                                title: 'Expense Details',
                                children: [
                                  const _FieldLabel(
                                    label: 'Description',
                                    required: true,
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _descriptionController,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      prefixIcon: Icon(
                                        Icons.edit_note_rounded,
                                        size: 20,
                                        color: MohajonWarm.muted,
                                      ),
                                      hintText: 'e.g. Electricity bill',
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Enter a short description';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  const _FieldLabel(
                                    label: 'Amount',
                                    required: true,
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _amountController,
                                    keyboardType: const TextInputType
                                        .numberWithOptions(decimal: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9.]'),
                                      ),
                                    ],
                                    onChanged: (_) => setState(() {}),
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      prefixIcon: Padding(
                                        padding: EdgeInsets.only(
                                          left: 14,
                                          right: 8,
                                        ),
                                        child: Text(
                                          '৳',
                                          style: TextStyle(
                                            color: MohajonWarm.muted,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      prefixIconConstraints:
                                          BoxConstraints(
                                        minWidth: 0,
                                        minHeight: 0,
                                      ),
                                      hintText: '0.00',
                                    ),
                                    validator: (value) {
                                      final amount =
                                          double.tryParse(value ?? '');
                                      if (amount == null || amount <= 0) {
                                        return 'Enter a valid amount';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _SectionCard(
                                icon: Icons.category_outlined,
                                iconColor: MohajonWarm.green,
                                iconBackground: MohajonWarm.tintGreen,
                                title: 'Category & Date',
                                children: [
                                  const _FieldLabel(
                                    label: 'Category',
                                    required: true,
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    initialValue: _categoryId,
                                    style: const TextStyle(
                                      color: MohajonWarm.ink,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    dropdownColor: Colors.white,
                                    decoration: const InputDecoration(
                                      prefixIcon: Icon(
                                        Icons.category_outlined,
                                        size: 20,
                                        color: MohajonWarm.muted,
                                      ),
                                    ),
                                    items: categories
                                        .map(
                                          (category) => DropdownMenuItem(
                                            value: category.id,
                                            child: Text(category.label),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      setState(
                                        () => _categoryId = value,
                                      );
                                    },
                                    validator: (value) {
                                      if (value == null ||
                                          value.isEmpty) {
                                        return 'Choose a category';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  const _FieldLabel(label: 'Date'),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    readOnly: true,
                                    controller: TextEditingController(
                                      text: DateFormat('dd MMM yyyy')
                                          .format(_selectedDate),
                                    ),
                                    decoration: const InputDecoration(
                                      prefixIcon: Icon(
                                        Icons.calendar_month_rounded,
                                        size: 20,
                                        color: MohajonWarm.muted,
                                      ),
                                      suffixIcon: Icon(
                                        Icons
                                            .keyboard_arrow_down_rounded,
                                        color: MohajonWarm.muted,
                                      ),
                                    ),
                                    onTap: () async {
                                      final picked =
                                          await showDatePicker(
                                        context: context,
                                        initialDate: _selectedDate,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2035),
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          _selectedDate = picked;
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _SectionCard(
                                icon: Icons.notes_outlined,
                                iconColor: MohajonWarm.orange,
                                iconBackground: MohajonWarm.tintOrange,
                                title: 'Notes',
                                children: [
                                  TextFormField(
                                    controller: _notesController,
                                    minLines: 3,
                                    maxLines: 5,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    decoration: const InputDecoration(
                                      hintText:
                                          'Any extra details about this expense...',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      _SaveBar(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 4,
                                bottom: 8,
                              ),
                              child: Text(
                                'Preview: ${_previewAmount <= 0 ? '—' : '৳${_previewAmount.toStringAsFixed(2)}'}',
                                style: const TextStyle(
                                  color: MohajonWarm.muted,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            ActionButton(
                              onPressed: _save,
                              isBusy: isBusy,
                              icon: Icons.save_outlined,
                              label: isEditing
                                  ? 'Update Expense'
                                  : 'Save Expense',
                              busyLabel: isEditing
                                  ? 'Updating...'
                                  : 'Saving...',
                            ),
                          ],
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
      label: 'Saving expense...',
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountController.text.trim());
    final categoryId = _categoryId!;
    final categoryLabel = ref
        .read(expenseCategoriesProvider)
        .firstWhere((category) => category.id == categoryId)
        .label;
    final service = ref.read(expenseServiceProvider);
    try {
      await runBusyAction(() async {
        if (widget.expense == null) {
          await service.addExpense(
            description: _descriptionController.text.trim(),
            amount: amount,
            categoryId: categoryId,
            categoryLabel: categoryLabel,
            date: _selectedDate,
            notes: _notesController.text.trim(),
          );
        } else {
          await service.updateExpense(
            existing: widget.expense!,
            description: _descriptionController.text.trim(),
            amount: amount,
            categoryId: categoryId,
            categoryLabel: categoryLabel,
            date: _selectedDate,
            notes: _notesController.text.trim(),
          );
        }
      });
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        showAppSnackBar(context, friendlyErrorMessage(error), isError: true);
      }
    }
  }
}

/// Pinned bottom bar so the save action is always reachable.
class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MohajonWarm.card,
        border: const Border(
          top: BorderSide(color: MohajonWarm.goldBorder),
        ),
        boxShadow: [
          BoxShadow(
            color: MohajonWarm.ink.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 10),
        child: child,
      ),
    );
  }
}

/// Custom warm header matching the Stock screen top bar.
class _FormHeader extends StatelessWidget {
  const _FormHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
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
          child: const Icon(
            Icons.wallet_rounded,
            color: MohajonWarm.ink,
            size: 17,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: MohajonWarm.ink,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: MohajonWarm.muted,
                ),
              ),
            ],
          ),
        ),
        const NotificationBell(),
        const SizedBox(width: 14),
        const ShopAvatar(
          radius: 17,
          backgroundColor: Color(0xFFFFFDF7),
          textColor: MohajonWarm.ink,
        ),
      ],
    );
  }
}

/// White card panel with gold border matching the Stock search panel.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MohajonWarm.card,
        border: Border.all(color: MohajonWarm.goldBorder),
        borderRadius: BorderRadius.circular(20),
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
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [
                    BoxShadow(
                      color: iconColor.withValues(alpha: 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MohajonWarm.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, this.required = false});

  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: MohajonWarm.ink,
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
        ),
        children: [
          TextSpan(text: label),
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: MohajonWarm.red),
            ),
        ],
      ),
    );
  }
}
