import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_icon_asset.dart';
import '../../../core/widgets/flaticon_icons.dart';

import '../../customers/presentation/customer_form_screen.dart';
import '../../customers/presentation/customer_list_screen.dart';
import '../../expenses/presentation/expenses_screen.dart';
import '../../investors/presentation/investor_list_screen.dart';
import '../../pos/presentation/pos_screen.dart';
import '../../products/presentation/product_form_screen.dart';
import '../../products/presentation/product_list_screen.dart';
import '../../reports/presentation/reports_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../staff/presentation/staff_list_screen.dart';
import '../../vendors/presentation/vendor_list_screen.dart';
import '../models/shortcut_item.dart';
import '../providers/shortcut_provider.dart';
import 'shortcut_bottom_sheet.dart';

class HomeShortcuts extends ConsumerWidget {
  const HomeShortcuts({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIds = ref.watch(selectedShortcutsProvider);
    final items = selectedIds
        .map((id) => ShortcutItem.all.where((s) => s.id == id).firstOrNull)
        .whereType<ShortcutItem>()
        .toList();

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ShortcutHeader(
            onEdit: () => _openSheet(context),
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            _buildEmpty(context)
          else
            _buildShortcutRow(context, items),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openSheet(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: const Color(0xFFFCFBF8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFECE7DF)),
        ),
        child: Column(
          children: [
            AppIconAsset(assetPath: FlaticonIcons.grid, color: const Color(0xFFD4D4D4), size: 32),
            const SizedBox(height: 8),
            Text(
              'No shortcuts selected',
              style: TextStyle(
                color: const Color(0xFF98A2B3),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap to customize',
              style: TextStyle(
                color: const Color(0xFFF97316),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShortcutRow(BuildContext context, List<ShortcutItem> items) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in items) ...[
            _ShortcutButton(
              item: item,
              onTap: () => _handleTap(context, item),
              onLongPress: () => _openSheet(context),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  void _openSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ShortcutBottomSheet(),
    );
  }

  void _handleTap(BuildContext context, ShortcutItem item) {
    final route = _routeFor(item.id);
    if (route != null) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => route));
    }
  }

  Widget? _routeFor(String id) {
    switch (id) {
      case 'new_sale':
        return const PosScreen();
      case 'add_product':
        return const ProductFormScreen();
      case 'stock':
        return const ProductListScreen();
      case 'add_client':
        return const CustomerFormScreen();
      case 'clients':
        return const CustomerListScreen();
      case 'pos':
        return const PosScreen();
      case 'expenses':
        return const ExpensesScreen();
      case 'vendors':
        return const VendorListScreen();
      case 'investors':
        return const InvestorListScreen();
      case 'reports':
        return const ReportsScreen();
      case 'staff':
        return const StaffListScreen();
      case 'settings':
        return const SettingsScreen();
      default:
        return null;
    }
  }
}

class _ShortcutHeader extends StatelessWidget {
  const _ShortcutHeader({required this.onEdit});

  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            'Shortcuts',
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            child: Text(
              'Edit',
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ShortcutButton extends StatelessWidget {
  const _ShortcutButton({
    required this.item,
    required this.onTap,
    required this.onLongPress,
  });

  final ShortcutItem item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: item.backgroundColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: AppIconAsset(assetPath: item.icon, color: item.iconColor, size: 26),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 64,
          child: Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF525252),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFECE7DF)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}
