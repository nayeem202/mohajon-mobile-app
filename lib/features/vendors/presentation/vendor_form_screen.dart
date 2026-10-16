import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/app_error.dart';
import '../../../core/app/app_providers.dart';
import '../../../core/constants/shop_category_templates.dart';

import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/snackbar.dart';
import '../../../core/widgets/action_button.dart';
import '../../../core/widgets/async_action_state.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/shop_avatar.dart';
import '../models/vendor.dart';
import '../providers/vendor_providers.dart';

class VendorFormScreen extends ConsumerStatefulWidget {
  const VendorFormScreen({super.key, this.vendor});

  final Vendor? vendor;

  @override
  ConsumerState<VendorFormScreen> createState() => _VendorFormScreenState();
}

class _VendorFormScreenState extends ConsumerState<VendorFormScreen>
    with AsyncActionState<VendorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _productsCtrl = TextEditingController();

  String _category = '';

  @override
  void initState() {
    super.initState();
    final vendor = widget.vendor;
    if (vendor != null) {
      _companyCtrl.text = vendor.companyName;
      _contactCtrl.text = vendor.contactPerson;
      _phoneCtrl.text = vendor.phone;
      _emailCtrl.text = vendor.email;
      _addressCtrl.text = vendor.address;
      _productsCtrl.text = vendor.products;
      _category = vendor.category;
    }
  }

  @override
  void dispose() {
    _companyCtrl.dispose();
    _contactCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _productsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isEditing = widget.vendor != null;
    final businessType =
        ref.read(localDatabaseProvider).settings.get('profile_businessType')
            as String?;
    final supplierCategories = <String>[
      ...ShopCategoryTemplates.forId(businessType).supplierCategories,
      if (_category.trim().isNotEmpty &&
          !ShopCategoryTemplates.forId(
            businessType,
          ).supplierCategories.contains(_category))
        _category,
    ];
    return withLoadingOverlay(
      Theme(
        data: MohajonWarm.theme(Theme.of(context)),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: DecoratedBox(
            decoration: const BoxDecoration(gradient: MohajonWarm.pageGradient),
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
                            padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                            children: [
                              _FormHeader(
                                title: isEditing
                                    ? l10n.t('editVendor')
                                    : l10n.t('addVendor'),
                                subtitle: l10n.t('suppliersAndPurchases'),
                                onBack: () => Navigator.of(context).maybePop(),
                              ),
                              const SizedBox(height: 18),
                              _SectionCard(
                                icon: Icons.store_rounded,
                                iconColor: MohajonWarm.goldText,
                                iconBackground: MohajonWarm.tintYellow,
                                title: l10n.t('vendorDetails'),
                                children: [
                                  _FieldLabel(
                                    label: l10n.t('companyName'),
                                    required: true,
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _companyCtrl,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    decoration: InputDecoration(
                                      prefixIcon: const Icon(
                                        Icons.store_outlined,
                                        size: 20,
                                        color: MohajonWarm.muted,
                                      ),
                                      hintText: l10n.t('companyNameHint'),
                                    ),
                                    validator: (v) =>
                                        v == null || v.trim().isEmpty
                                        ? l10n.t('required')
                                        : null,
                                  ),
                                  const SizedBox(height: 14),
                                  _FieldLabel(
                                    label: l10n.t('contactPerson'),
                                    required: true,
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _contactCtrl,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    decoration: InputDecoration(
                                      prefixIcon: const Icon(
                                        Icons.person_outline_rounded,
                                        size: 20,
                                        color: MohajonWarm.muted,
                                      ),
                                      hintText: l10n.t('contactPersonHint'),
                                    ),
                                    validator: (v) =>
                                        v == null || v.trim().isEmpty
                                        ? l10n.t('required')
                                        : null,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _SectionCard(
                                icon: Icons.location_on_outlined,
                                iconColor: MohajonWarm.green,
                                iconBackground: MohajonWarm.tintGreen,
                                title: l10n.t('contactInformation'),
                                children: [
                                  _FieldLabel(
                                    label: l10n.t('phone'),
                                    required: true,
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _phoneCtrl,
                                    keyboardType: TextInputType.phone,
                                    decoration: InputDecoration(
                                      prefixIcon: const Icon(
                                        Icons.phone_outlined,
                                        size: 20,
                                        color: MohajonWarm.muted,
                                      ),
                                      hintText: l10n.t('phoneHint'),
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return l10n.t('required');
                                      }
                                      final phone = value.trim();
                                      if (phone.length < 10) {
                                        return l10n.t('invalidPhone');
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  _FieldLabel(label: l10n.t('email')),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _emailCtrl,
                                    keyboardType: TextInputType.emailAddress,
                                    autocorrect: false,
                                    decoration: InputDecoration(
                                      prefixIcon: const Icon(
                                        Icons.email_outlined,
                                        size: 20,
                                        color: MohajonWarm.muted,
                                      ),
                                      hintText: l10n.t('emailHint'),
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return null;
                                      }
                                      if (!RegExp(
                                        r'^[^@]+@[^@]+\.[^@]+$',
                                      ).hasMatch(value.trim())) {
                                        return l10n.t('invalidEmail');
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  _FieldLabel(label: l10n.t('address')),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _addressCtrl,
                                    maxLines: 2,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    decoration: InputDecoration(
                                      prefixIcon: const Padding(
                                        // Centers the icon on the FIRST text
                                        // line of the two-line field:
                                        // fieldH(~63) - 44.4 => bottom ~18.
                                        padding: EdgeInsets.only(bottom: 18),
                                        child: Icon(
                                          Icons.location_on_outlined,
                                          size: 20,
                                          color: MohajonWarm.muted,
                                        ),
                                      ),
                                      hintText: l10n.t('addressHint'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _SectionCard(
                                icon: Icons.inventory_outlined,
                                iconColor: MohajonWarm.orange,
                                iconBackground: MohajonWarm.tintOrange,
                                title: l10n.t('supplyInformation'),
                                children: [
                                  _FieldLabel(label: l10n.t('category')),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    initialValue: _category.isEmpty
                                        ? null
                                        : _category,
                                    style: const TextStyle(
                                      color: MohajonWarm.ink,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    dropdownColor: Colors.white,
                                    decoration: InputDecoration(
                                      prefixIcon: const Icon(
                                        Icons.category_outlined,
                                        size: 20,
                                        color: MohajonWarm.muted,
                                      ),
                                      hintText: l10n.t('selectCategory'),
                                    ),
                                    icon: const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: MohajonWarm.muted,
                                    ),
                                    items: supplierCategories.map((cat) {
                                      return DropdownMenuItem(
                                        value: cat,
                                        child: Text(
                                          ShopCategoryLabels.supplier(
                                            cat,
                                            l10n.locale.languageCode,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (v) =>
                                        setState(() => _category = v ?? ''),
                                  ),
                                  const SizedBox(height: 14),
                                  _FieldLabel(
                                    label: l10n.t('productsSupplied'),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _productsCtrl,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    decoration: InputDecoration(
                                      prefixIcon: const Icon(
                                        Icons.shopping_basket_outlined,
                                        size: 20,
                                        color: MohajonWarm.muted,
                                      ),
                                      hintText: l10n.t('productsSuppliedHint'),
                                      helperText: l10n.t('separateWithCommas'),
                                      helperStyle: const TextStyle(
                                        color: MohajonWarm.muted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      _SaveBar(
                        child: ActionButton(
                          onPressed: _save,
                          isBusy: isBusy,
                          icon: Icons.save_outlined,
                          label: isEditing
                              ? l10n.t('updateVendor')
                              : l10n.t('saveVendor'),
                          busyLabel: isEditing
                              ? l10n.t('updating')
                              : l10n.t('saving'),
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
      label: l10n.t('savingVendor'),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final vendors = ref.read(vendorsProvider).value ?? const <Vendor>[];
    final duplicate = vendors.any((v) {
      if (widget.vendor != null && v.vendorId == widget.vendor!.vendorId) {
        return false;
      }
      return v.companyName.toLowerCase() ==
          _companyCtrl.text.trim().toLowerCase();
    });
    if (duplicate) {
      showAppSnackBar(
        context,
        AppLocalizations.of(context).t('vendorExistsError'),
        isError: true,
      );
      return;
    }

    try {
      await runBusyAction(() async {
        await ref
            .read(vendorServiceProvider)
            .save(
              vendorId: widget.vendor?.vendorId,
              companyName: _companyCtrl.text.trim(),
              contactPerson: _contactCtrl.text.trim(),
              phone: _phoneCtrl.text.trim(),
              email: _emailCtrl.text.trim(),
              category: _category,
              address: _addressCtrl.text.trim(),
              products: _productsCtrl.text.trim(),
            );
        if (mounted) {
          Navigator.of(context).pop();
          showAppSnackBar(
            context,
            widget.vendor != null
                ? AppLocalizations.of(context).t('vendorUpdated')
                : AppLocalizations.of(context).t('vendorAdded'),
          );
        }
      });
    } catch (error) {
      if (mounted) {
        showAppSnackBar(
          context,
          friendlyErrorMessage(error, l10n: AppLocalizations.of(context)),
          isError: true,
        );
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
        border: const Border(top: BorderSide(color: MohajonWarm.goldBorder)),
        boxShadow: [
          BoxShadow(
            color: MohajonWarm.ink.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
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
            Icons.store_rounded,
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
