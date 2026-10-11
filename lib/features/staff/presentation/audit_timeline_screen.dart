import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/audit_event.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../branches/providers/branch_providers.dart';
import '../services/audit_timeline_service.dart';

class AuditTimelineScreen extends ConsumerStatefulWidget {
  const AuditTimelineScreen({super.key});

  @override
  ConsumerState<AuditTimelineScreen> createState() =>
      _AuditTimelineScreenState();
}

class _AuditTimelineScreenState extends ConsumerState<AuditTimelineScreen> {
  static const _pageSize = 30;
  final _scrollController = ScrollController();
  final List<AuditEvent> _events = [];
  String? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  bool _initialLoadComplete = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    ref.listenManual<String?>(currentBranchIdProvider, (previous, next) {
      if (previous != next) _refresh();
    });
    Future<void>.microtask(_refresh);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 280) {
      return;
    }
    _loadMore();
  }

  Future<void> _refresh() async {
    if (_loading) return;
    _cursor = null;
    _hasMore = true;
    _events.clear();
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final page = await ref
          .read(auditTimelineServiceProvider)
          .fetchPage(cursor: _cursor, limit: _pageSize);
      if (!mounted) return;
      final knownIds = _events.map((event) => event.eventId).toSet();
      setState(() {
        _events.addAll(
          page.events.where((event) => knownIds.add(event.eventId)),
        );
        _cursor = page.nextCursor;
        _hasMore = page.hasMore && page.nextCursor != null;
        _initialLoadComplete = true;
      });
    } catch (_) {
      if (!mounted) return;
      final shopId = ref.read(shopIdProvider);
      final branchId = ref.read(currentBranchIdProvider) ?? '$shopId-main';
      final cached = ref
          .read(localDatabaseProvider)
          .auditEvents
          .valuesForShop(shopId)
          .where((event) => (event.branchId ?? '$shopId-main') == branchId)
          .take(_pageSize)
          .toList();
      setState(() {
        _events
          ..clear()
          ..addAll(cached);
        _hasMore = false;
        _initialLoadComplete = true;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: MohajonWarm.primary,
      appBar: AppBar(
        backgroundColor: MohajonWarm.primary,
        foregroundColor: MohajonWarm.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(l10n.t('auditTimeline')),
        // NotificationBell already includes the single app-wide sync status
        // control. Adding another one here made the network indicator appear
        // twice on this screen.
        actions: const [NotificationBell()],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: MohajonWarm.pageGradient),
        child: !_initialLoadComplete && _events.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _events.isEmpty
            ? _AuditEmptyState(message: l10n.t('noAuditEvents'))
            : RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                  itemCount: _events.length + (_hasMore ? 2 : 1),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _AuditTimelineIntro(
                        subtitle: l10n.t('auditTimelineSubtitle'),
                      );
                    }
                    final eventIndex = index - 1;
                    if (eventIndex == _events.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return _AuditEventTile(
                      event: _events[eventIndex],
                      isLast: eventIndex == _events.length - 1 && !_hasMore,
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _AuditEmptyState extends StatelessWidget {
  const _AuditEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MohajonWarm.card.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MohajonWarm.goldBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: MohajonWarm.tintYellow,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.fact_check_rounded,
              color: MohajonWarm.goldText,
              size: 30,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: MohajonWarm.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}

class _AuditTimelineIntro extends StatelessWidget {
  const _AuditTimelineIntro({required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 18),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: MohajonWarm.card.withValues(alpha: .8),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: MohajonWarm.goldBorder),
    ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: MohajonWarm.tintYellow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.history_rounded,
            color: MohajonWarm.goldText,
            size: 21,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            subtitle,
            style: const TextStyle(
              color: MohajonWarm.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );
}

class _AuditEventInfo {
  const _AuditEventInfo({
    required this.title,
    required this.summary,
    required this.actor,
    required this.shortId,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String summary;
  final String actor;
  final String shortId;
  final IconData icon;
  final Color accent;

  factory _AuditEventInfo.from(AuditEvent event, AppLocalizations l10n) {
    final details = event.details;
    final actorName = '${details['actorName'] ?? ''}'.trim();
    final actor = actorName.isNotEmpty
        ? actorName
        : event.actorId == 'local-owner'
        ? l10n.t('auditYou')
        : _shortReference(event.actorId);
    final shortId = _shortReference(event.eventId);
    final amount = _number(
      details['amount'] ?? details['totalAmount'] ?? details['refundAmount'],
    );
    final delta = _number(details['delta']);
    final reason = '${details['reason'] ?? ''}'.trim();
    final method = '${details['method'] ?? details['paymentMethod'] ?? ''}'
        .trim();
    final itemCount = details['items'] is List
        ? (details['items'] as List).length
        : 0;
    final summary = switch (event.action) {
      'SALE_CREATED' => _join([
        if (amount != null) money(amount),
        if (method.isNotEmpty) _paymentMethod(l10n, method),
      ]),
      'PAYMENT_RECORDED' => _join([
        if (amount != null) money(amount),
        if (method.isNotEmpty) _paymentMethod(l10n, method),
      ]),
      'PURCHASE_RECEIVED' =>
        itemCount > 0
            ? l10n.tP('auditItemsReceived', {'count': '$itemCount'})
            : '',
      'SALE_RETURN_CREATED' => amount == null ? '' : money(amount),
      'SUPPLIER_RETURN_CREATED' => _join([
        if (amount != null) money(amount),
        if (reason.isNotEmpty) reason,
      ]),
      'STOCK_ADJUSTMENT_REQUESTED' ||
      'STOCK_ADJUSTMENT_APPROVED' ||
      'STOCK_ADJUSTMENT_REJECTED' => _join([
        if (delta != null) '${delta > 0 ? '+' : ''}${_compactNumber(delta)}',
        if (reason.isNotEmpty) reason,
      ]),
      _ => '',
    };
    final (title, icon, accent) = switch (event.action) {
      'SALE_CREATED' => (
        l10n.t('auditSaleCreated'),
        Icons.point_of_sale_rounded,
        MohajonWarm.green,
      ),
      'PAYMENT_RECORDED' => (
        l10n.t('auditPaymentRecorded'),
        Icons.payments_rounded,
        MohajonWarm.green,
      ),
      'PURCHASE_RECEIVED' => (
        l10n.t('auditPurchaseReceived'),
        Icons.inventory_rounded,
        MohajonWarm.orange,
      ),
      'SALE_RETURN_CREATED' => (
        l10n.t('auditSaleReturnCreated'),
        Icons.assignment_return_rounded,
        MohajonWarm.red,
      ),
      'SUPPLIER_RETURN_CREATED' => (
        l10n.t('auditSupplierReturnCreated'),
        Icons.reply_all_rounded,
        MohajonWarm.red,
      ),
      'STOCK_ADJUSTMENT_REQUESTED' => (
        l10n.t('auditStockAdjustmentRequested'),
        Icons.tune_rounded,
        MohajonWarm.orange,
      ),
      'STOCK_ADJUSTMENT_APPROVED' => (
        l10n.t('auditStockAdjustmentApproved'),
        Icons.verified_rounded,
        MohajonWarm.green,
      ),
      'STOCK_ADJUSTMENT_REJECTED' => (
        l10n.t('auditStockAdjustmentRejected'),
        Icons.cancel_rounded,
        MohajonWarm.red,
      ),
      _ => (
        l10n.t('auditOtherActivity'),
        Icons.history_rounded,
        MohajonWarm.goldText,
      ),
    };
    return _AuditEventInfo(
      title: title,
      summary: summary,
      actor: actor,
      shortId: shortId,
      icon: icon,
      accent: accent,
    );
  }

  static num? _number(Object? value) =>
      value is num ? value : num.tryParse('$value');

  static String _compactNumber(num value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);

  static String _shortReference(String value) => value.length <= 8
      ? value
      : value.substring(value.length - 8).toUpperCase();

  static String _join(Iterable<String> values) =>
      values.where((value) => value.trim().isNotEmpty).join(' • ');

  static String _paymentMethod(AppLocalizations l10n, String method) =>
      switch (method.toUpperCase()) {
        'CASH' => l10n.t('refundCash'),
        'BKASH' => l10n.t('refundBkash'),
        'NAGAD' => l10n.t('refundNagad'),
        'BANK' => l10n.t('refundBank'),
        'OTHER' => l10n.t('refundOther'),
        _ => method,
      };
}

class _AuditEventTile extends StatelessWidget {
  const _AuditEventTile({required this.event, required this.isLast});

  final AuditEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final date = DateFormat(
      'd MMM, h:mm a',
      l10n.locale.languageCode,
    ).format(event.createdAt.toLocal());
    final info = _AuditEventInfo.from(event, l10n);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: info.accent,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 7,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(info.icon, color: Colors.white, size: 17),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      color: MohajonWarm.goldBorder,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
              decoration: BoxDecoration(
                color: MohajonWarm.card.withValues(alpha: .95),
                borderRadius: BorderRadius.circular(19),
                border: Border.all(color: MohajonWarm.goldBorder),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 13,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          info.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: MohajonWarm.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        date,
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          color: MohajonWarm.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  if (info.summary.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(
                      info.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MohajonWarm.ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 7,
                    runSpacing: 6,
                    children: [
                      _AuditMetaChip(
                        icon: Icons.person_rounded,
                        text: l10n.tP('auditRecordedBy', {'name': info.actor}),
                      ),
                      _AuditMetaChip(
                        icon: Icons.tag_rounded,
                        text: l10n.tP('auditReference', {'id': info.shortId}),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditMetaChip extends StatelessWidget {
  const _AuditMetaChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 190),
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: MohajonWarm.tintYellow,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: MohajonWarm.goldText),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: MohajonWarm.goldText,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}
