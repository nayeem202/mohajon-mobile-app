import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/audit_event.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
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
      appBar: AppBar(
        title: Text(l10n.t('auditTimeline')),
        actions: const [SyncStatusIndicator(), NotificationBell()],
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
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                  itemCount: _events.length + (_hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _events.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return _AuditEventTile(
                      event: _events[index],
                      isLast: index == _events.length - 1 && !_hasMore,
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

class _AuditEventTile extends StatelessWidget {
  const _AuditEventTile({required this.event, required this.isLast});

  final AuditEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat(
      'dd MMM, hh:mm a',
    ).format(event.createdAt.toLocal());
    final entity = event.entityType.trim().isEmpty
        ? event.entityId
        : event.entityType;
    final actor = event.actorId.trim().isEmpty ? '—' : event.actorId;
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
                    color: MohajonWarm.ink,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 7,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    color: MohajonWarm.primary,
                    size: 17,
                  ),
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
                          event.action,
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
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 7,
                    runSpacing: 6,
                    children: [
                      _AuditMetaChip(
                        icon: Icons.category_rounded,
                        text: entity,
                      ),
                      _AuditMetaChip(icon: Icons.person_rounded, text: actor),
                    ],
                  ),
                  if (event.details.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    Text(
                      event.details.entries
                          .take(2)
                          .map((entry) => '${entry.key}: ${entry.value}')
                          .join(' • '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MohajonWarm.muted,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ],
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
