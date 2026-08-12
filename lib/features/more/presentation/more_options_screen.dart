import 'package:flutter/material.dart';

import '../../expenses/presentation/expenses_screen.dart';
import '../../investments/presentation/investment_dashboard_screen.dart';
import '../../pos/presentation/sales_history_screen.dart';
import '../../investors/presentation/investor_list_screen.dart';
import '../../reports/presentation/reports_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../staff/presentation/staff_list_screen.dart';
import '../../vendors/presentation/vendor_list_screen.dart';
import '../../../core/widgets/app_icon_asset.dart';
import '../../../core/widgets/flaticon_icons.dart';

class MoreOptionsScreen extends StatelessWidget {
  const MoreOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final items = [
      _MoreItem(
        label: 'Sales History',
        icon: FlaticonIcons.calendar,
        color: const Color(0xFF0F766E),
        screen: const SalesHistoryScreen(),
      ),
      _MoreItem(
        label: 'Investors',
        icon: FlaticonIcons.user,
        color: const Color(0xFF047857),
        screen: const InvestorListScreen(),
      ),
      _MoreItem(
        label: 'Vendors',
        icon: FlaticonIcons.store,
        color: const Color(0xFFB45309),
        screen: const VendorListScreen(),
      ),
      _MoreItem(
        label: 'Expenses',
        icon: FlaticonIcons.wallet,
        color: const Color(0xFFF97316),
        screen: const ExpensesScreen(),
      ),
      _MoreItem(
        label: 'Investments',
        icon: FlaticonIcons.bank,
        color: const Color(0xFF0F766E),
        screen: const InvestmentDashboardScreen(),
      ),
      _MoreItem(
        label: 'Reports',
        icon: FlaticonIcons.grid,
        color: const Color(0xFFF97316),
        screen: const ReportsScreen(),
      ),
      _MoreItem(
        label: 'Staff',
        icon: FlaticonIcons.user,
        color: const Color(0xFFB45309),
        screen: const StaffListScreen(),
      ),
      _MoreItem(
        label: 'Settings',
        icon: FlaticonIcons.settings,
        color: const Color(0xFF98A2B3),
        screen: const SettingsScreen(),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F1),
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Menu'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.62,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _MoreOptionTile(
              label: item.label,
              icon: item.icon,
              color: item.color,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => item.screen),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MoreItem {
  const _MoreItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.screen,
  });

  final String label;
  final String icon;
  final Color color;
  final Widget screen;
}

class _MoreOptionTile extends StatelessWidget {
  const _MoreOptionTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFCFBF8),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFECE7DF)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: AppIconAsset(assetPath: icon, color: color, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF101828),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
