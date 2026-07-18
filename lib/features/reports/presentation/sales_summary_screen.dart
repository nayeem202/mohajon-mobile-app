import 'package:flutter/material.dart';

import '../../../core/utils/money.dart';
import '../models/daily_sales.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/shop_avatar.dart';

class SalesSummaryScreen extends StatelessWidget {
  const SalesSummaryScreen({super.key});

  static const _summaryCards = [
    _SummaryCardData(label: 'Total Sales', amount: 458500),
    _SummaryCardData(label: 'Transactions', amount: 672),
    _SummaryCardData(label: 'Average Order', amount: 682),
  ];

  static final _dailySales = [
    DailySales(
      date: DateTime(2026, 7, 10),
      label: 'Jul 10',
      amount: 45850,
      transactionCount: 67,
      maxAmount: 46500,
    ),
    DailySales(
      date: DateTime(2026, 7, 9),
      label: 'Jul 9',
      amount: 46500,
      transactionCount: 71,
      maxAmount: 46500,
    ),
    DailySales(
      date: DateTime(2026, 7, 8),
      label: 'Jul 8',
      amount: 38200,
      transactionCount: 55,
      maxAmount: 46500,
    ),
    DailySales(
      date: DateTime(2026, 7, 7),
      label: 'Jul 7',
      amount: 42100,
      transactionCount: 63,
      maxAmount: 46500,
    ),
    DailySales(
      date: DateTime(2026, 7, 6),
      label: 'Jul 6',
      amount: 35400,
      transactionCount: 52,
      maxAmount: 46500,
    ),
    DailySales(
      date: DateTime(2026, 7, 5),
      label: 'Jul 5',
      amount: 28700,
      transactionCount: 41,
      maxAmount: 46500,
    ),
    DailySales(
      date: DateTime(2026, 7, 4),
      label: 'Jul 4',
      amount: 31200,
      transactionCount: 46,
      maxAmount: 46500,
    ),
    DailySales(
      date: DateTime(2026, 7, 3),
      label: 'Jul 3',
      amount: 39800,
      transactionCount: 58,
      maxAmount: 46500,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Summary'),
        actions: [
          const NotificationBell(),
          const SizedBox(width: 6),
          const ShopAvatar(),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Row(
            children: [
              const Text(
                'July 1 – July 10, 2026',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF667085),
                ),
              ),
              const Spacer(),
              _ExportButton(
                label: 'XLSX',
                icon: Icons.table_chart_outlined,
                color: const Color(0xFF059669),
                onTap: () => debugPrint('Export XLSX'),
              ),
              const SizedBox(width: 8),
              _ExportButton(
                label: 'PDF',
                icon: Icons.picture_as_pdf_rounded,
                color: const Color(0xFFF97316),
                onTap: () => debugPrint('Export PDF'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (var i = 0; i < _summaryCards.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: _SummaryCard(data: _summaryCards[i])),
              ],
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Daily Sales',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF101828),
            ),
          ),
          const SizedBox(height: 12),
          for (final day in _dailySales) ...[
            _DailySalesRow(day: day),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCardData {
  const _SummaryCardData({required this.label, required this.amount});

  final String label;
  final num amount;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.data});

  final _SummaryCardData data;

  @override
  Widget build(BuildContext context) {
    final formatted = data.label == 'Transactions'
        ? '${data.amount.toInt()}'
        : money(data.amount);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8DDD2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF98A2B3),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formatted,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF101828),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailySalesRow extends StatelessWidget {
  const _DailySalesRow({required this.day});

  final DailySales day;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8DDD2)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: Color(0xFF101828),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${day.transactionCount} txns',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF98A2B3),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  money(day.amount),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: Color(0xFF101828),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Avg ${money(day.average)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF98A2B3),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 72,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: day.fraction,
                minHeight: 8,
                backgroundColor: const Color(0xFFFFE4BF),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF97316)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
