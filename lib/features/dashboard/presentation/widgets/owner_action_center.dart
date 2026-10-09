import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app/app_providers.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/api_client.dart';
import '../../../../core/utils/money.dart';
import '../../../customers/presentation/customer_list_screen.dart';
import '../../../pos/presentation/sales_history_screen.dart';
import '../../../products/presentation/product_list_screen.dart';
import '../../../reports/presentation/reports_screen.dart';
import '../../providers/dashboard_providers.dart';
import '../day_closing_screen.dart';

/// A small live read for the only owner action that is not in local sales
/// data. Failing to load it must not make the dashboard feel blocked.
final ownerDayClosingProvider = FutureProvider<Map<String, dynamic>?>((
  ref,
) async {
  try {
    return await ApiClient(
      ref.read(localDatabaseProvider),
    ).get('/api/v1/day-closing');
  } catch (_) {
    // Offline owners can still use every locally-derived action below.
  }
  return null;
});

/// One decision-first dashboard section assembled from existing business data.
/// It intentionally replaces separate, competing alert cards with only the
/// actions that deserve the owner's attention today.
class OwnerActionCenter extends ConsumerWidget {
  const OwnerActionCenter({super.key, required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final closing = ref.watch(ownerDayClosingProvider).asData?.value;
    final actions = _actions(context, l10n, closing);
    if (actions.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2B519B), Color(0xFF172B5C)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFB9CEFF).withValues(alpha: 0.32),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF172B5C).withValues(alpha: 0.26),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD83D),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Color(0xFF173F3A),
                  size: 22,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('ownerActionCenter').toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFFFFD83D),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.t('ownerActionCenterSubtitle'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              _CountPill(
                label: l10n.tP('ownerActionsCount', {
                  'count': '${actions.length}',
                }),
              ),
            ],
          ),
          const SizedBox(height: 13),
          for (var index = 0; index < actions.length; index++) ...[
            _ActionTile(action: actions[index]),
            if (index != actions.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  List<_OwnerAction> _actions(
    BuildContext context,
    AppLocalizations l10n,
    Map<String, dynamic>? closing,
  ) {
    final actions = <_OwnerAction>[];
    final status = closing?['status']?.toString();
    final variance = (closing?['variance'] as num?)?.toDouble();
    if (status == 'CLOSED' && variance != null && variance.abs() >= 1) {
      actions.add(
        _OwnerAction(
          icon: Icons.account_balance_wallet_rounded,
          accent: const Color(0xFFFF8B67),
          title: l10n.t('ownerCashVarianceTitle'),
          detail: l10n.tP('ownerCashVarianceBody', {
            'amount': money(variance.abs()),
          }),
          onTap: () => _open(context, const DayClosingScreen()),
        ),
      );
    } else if (status != null && status != 'CLOSED') {
      actions.add(
        _OwnerAction(
          icon: Icons.fact_check_rounded,
          accent: const Color(0xFFFFD83D),
          title: l10n.t('ownerCloseCashTitle'),
          detail: l10n.t('ownerCloseCashBody'),
          onTap: () => _open(context, const DayClosingScreen()),
        ),
      );
    }

    if (summary.dueCustomers.isNotEmpty) {
      final customer = summary.dueCustomers.first;
      actions.add(
        _OwnerAction(
          icon: Icons.person_search_rounded,
          accent: const Color(0xFFFFA554),
          title: l10n.tP('ownerDueFollowUpTitle', {'name': customer.name}),
          detail: l10n.tP('ownerDueFollowUpBody', {
            'amount': money(customer.dueAmount),
          }),
          onTap: () => _open(context, const CustomerListScreen()),
        ),
      );
    }

    if (summary.topSelling.isNotEmpty) {
      final product = summary.topSelling.first;
      actions.add(
        _OwnerAction(
          icon: Icons.workspace_premium_rounded,
          accent: const Color(0xFF74D6AE),
          title: l10n.tP('ownerTopSellerTitle', {'name': product.name}),
          detail: l10n.tP('ownerTopSellerBody', {
            'quantity': product.quantity.toStringAsFixed(0),
          }),
          onTap: () => _open(context, const ProductListScreen()),
        ),
      );
    }

    final change = summary.weekChangePercent;
    if (change != null) {
      final up = change >= 0;
      actions.add(
        _OwnerAction(
          icon: up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
          accent: up ? const Color(0xFF74D6AE) : const Color(0xFFFF8B67),
          title: l10n.tP(
            up ? 'ownerWeeklySalesUpTitle' : 'ownerWeeklySalesDownTitle',
            {'percent': change.abs().toStringAsFixed(0)},
          ),
          detail: l10n.tP('ownerWeeklySalesBody', {
            'current': money(summary.thisWeekSales),
            'previous': money(summary.lastWeekSales),
          }),
          onTap: () => _open(context, const SalesHistoryScreen()),
        ),
      );
    }

    if (summary.topStaff.isNotEmpty) {
      final staff = summary.topStaff.first;
      actions.add(
        _OwnerAction(
          icon: Icons.groups_rounded,
          accent: const Color(0xFF9BB8FF),
          title: l10n.tP('ownerStaffLeaderTitle', {'name': staff.name}),
          detail: l10n.tP('ownerStaffLeaderBody', {
            'amount': money(staff.sales),
          }),
          onTap: () => _open(context, const ReportsScreen()),
        ),
      );
    }

    return actions.take(5).toList();
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action});

  final _OwnerAction action;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: 0.09),
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: action.onTap,
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: action.accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(action.icon, color: action.accent, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    action.detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.52),
            ),
          ],
        ),
      ),
    ),
  );
}

class _OwnerAction {
  const _OwnerAction({
    required this.icon,
    required this.accent,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String detail;
  final VoidCallback onTap;
}
