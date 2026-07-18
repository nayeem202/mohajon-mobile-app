import 'package:flutter/material.dart';

import '../models/report_item.dart';
import 'customer_ledger_screen.dart';
import 'inventory_report_screen.dart';
import 'sales_summary_screen.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/shop_avatar.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  static const _items = [
    ReportItem(
      icon: Icons.bar_chart_rounded,
      title: 'Sales Summary',
      description: 'Daily, weekly & monthly sales overview',
      color: Color(0xFF0F766E),
    ),
    ReportItem(
      icon: Icons.receipt_long_rounded,
      title: 'Customer Ledger',
      description: 'Customer-wise due & payment history',
      color: Color(0xFF2563EB),
    ),
    ReportItem(
      icon: Icons.inventory_2_rounded,
      title: 'Inventory Report',
      description: 'Stock levels, low stock & valuation',
      color: Color(0xFFF97316),
    ),
    ReportItem(
      icon: Icons.payment_rounded,
      title: 'Payment Methods',
      description: 'Cash, bKash, Nagad & card breakdown',
      color: Color(0xFF7C3AED),
    ),
    ReportItem(
      icon: Icons.receipt_rounded,
      title: 'Daily Transactions',
      description: 'All transactions recorded per day',
      color: Color(0xFF0891B2),
    ),
    ReportItem(
      icon: Icons.trending_up_rounded,
      title: 'Profit & Loss',
      description: 'Revenue, cost & net profit summary',
      color: Color(0xFF059669),
    ),
    ReportItem(
      icon: Icons.shopping_bag_rounded,
      title: 'Product-wise Sales',
      description: 'Quantity & revenue per product',
      color: Color(0xFFD97706),
    ),
    ReportItem(
      icon: Icons.warning_amber_rounded,
      title: 'Due Payments',
      description: 'Overdue and pending payment list',
      color: Color(0xFFDC2626),
    ),
    ReportItem(
      icon: Icons.calculate_rounded,
      title: 'VAT & Tax Report',
      description: 'VAT collected and tax summaries',
      color: Color(0xFF0891B2),
    ),
    ReportItem(
      icon: Icons.people_rounded,
      title: 'Staff Performance',
      description: 'Sales & transactions by staff',
      color: Color(0xFF7C3AED),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          const NotificationBell(),
          const SizedBox(width: 6),
          const ShopAvatar(),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const Text(
            'Select a report type to view details & download',
            style: TextStyle(
              color: Color(0xFF667085),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.15,
            ),
            itemBuilder: (context, index) => _ReportCard(
              item: _items[index],
              onTap: () {
                switch (index) {
                  case 0:
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SalesSummaryScreen(),
                      ),
                    );
                  case 1:
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CustomerLedgerScreen(),
                      ),
                    );
                  case 2:
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const InventoryReportScreen(),
                      ),
                    );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.item, required this.onTap});

  final ReportItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: item.color, size: 22),
              ),
              const SizedBox(height: 12),
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF101828),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF98A2B3),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
