import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../models/notification_model.dart';
import '../providers/notification_providers.dart';
import 'push_notification_sheet.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState
    extends ConsumerState<NotificationsScreen> {
  final Set<String> _deletingIds = {};

  Future<void> _deleteNotification(AppNotification notification) async {
    final l10n = AppLocalizations.of(context);
    final session = ref.read(authStateProvider).value;
    final canDeleteEveryone = session != null &&
        (session.userId == notification.senderUserId ||
            session.roles.any((role) =>
                role.toUpperCase() == 'OWNER' || role.toUpperCase() == 'ADMIN'));
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Text(
          l10n.t('deleteNotification'),
          style: const TextStyle(
            color: MohajonWarm.ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          canDeleteEveryone
              ? l10n.t('deleteChoiceMessage')
              : l10n.t('deleteChoiceMessageOnlyYou'),
          style: const TextStyle(
            color: MohajonWarm.muted,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'me'),
            child: Text(
              l10n.t('deleteForMe'),
              style: const TextStyle(
                color: MohajonWarm.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (canDeleteEveryone)
            TextButton(
              onPressed: () => Navigator.pop(context, 'everyone'),
              child: Text(
                l10n.t('deleteForEveryone'),
                style: const TextStyle(
                  color: MohajonWarm.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    setState(() => _deletingIds.add(notification.id));
    try {
      await ref.read(notificationsProvider.notifier).delete(
            notification.id,
            everyone: choice == 'everyone',
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('notAllowedDeleteEveryone'))),
        );
      }
    }
    if (mounted) setState(() => _deletingIds.remove(notification.id));
  }

  void _openPushSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PushNotificationSheet(
        onSubmit: (type, title, message) {
          return ref.read(notificationServiceProvider).sendPush(
                type: type,
                title: title,
                message: message,
              );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(notificationsProvider);
    final filtered = state.filtered;
    final totalUnread = state.unreadCount;

    return Theme(
      data: MohajonWarm.theme(base),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: const BoxDecoration(
            gradient: MohajonWarm.pageGradient,
          ),
          child: SafeArea(
            child: Column(
              children: [
                _Header(
                  l10n: l10n,
                  unreadCount: totalUnread,
                  onMarkAllRead: () {
                    ref.read(notificationsProvider.notifier).markAllAsRead();
                  },
                  onCompose: _openPushSheet,
                  onClose: () => Navigator.of(context).pop(),
                ),
                _FilterChips(
                  l10n: l10n,
                  selected: state.categoryFilter,
                  totalUnread: totalUnread,
                  shopUnread: state.shopUnreadCount,
                  platformUnread: state.platformUnreadCount,
                  onSelected: (cat) {
                    ref
                        .read(notificationsProvider.notifier)
                        .setCategoryFilter(cat);
                  },
                ),
                _SecondaryTabs(
                  l10n: l10n,
                  unreadOnly: state.unreadOnly,
                  onChanged: (v) {
                    ref
                        .read(notificationsProvider.notifier)
                        .setUnreadOnly(v);
                  },
                ),
                const Divider(height: 1, color: MohajonWarm.goldBorder),
                if (filtered.isEmpty)
                  Expanded(
                    child: _EmptyState(l10n: l10n),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final notification = filtered[index];
                        final isDeleting =
                            _deletingIds.contains(notification.id);
                        return _NotificationItem(
                          notification: notification,
                          isDeleting: isDeleting,
                          onMarkRead: () {
                            ref
                                .read(notificationsProvider.notifier)
                                .markAsRead(notification.id);
                          },
                          onDelete: () => _deleteNotification(notification),
                        );
                      },
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
  const _Header({
    required this.l10n,
    required this.unreadCount,
    required this.onMarkAllRead,
    required this.onCompose,
    required this.onClose,
  });

  final AppLocalizations l10n;
  final int unreadCount;
  final VoidCallback onMarkAllRead;
  final VoidCallback onCompose;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 20, right: 16, top: 12, bottom: 12),
      decoration: const BoxDecoration(
        color: MohajonWarm.primary,
        border: Border(
          bottom: BorderSide(color: MohajonWarm.primarySoft),
        ),
      ),
      child: Row(
        children: [
          Text(
            l10n.t('notificationsList'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: MohajonWarm.ink,
            ),
          ),
          const Spacer(),
          if (unreadCount > 0)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                l10n.tP('unreadNew', {'n': '$unreadCount'}),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: MohajonWarm.goldText,
                ),
              ),
            ),
          GestureDetector(
            onTap: onCompose,
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              child: const Icon(
                Icons.add_circle_outline_rounded,
                size: 20,
                color: MohajonWarm.ink,
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: unreadCount > 0 ? onMarkAllRead : null,
            child: Text(
              l10n.t('markAllRead'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: unreadCount > 0
                    ? MohajonWarm.ink
                    : MohajonWarm.ink.withValues(alpha: 0.35),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
            iconSize: 22,
            color: MohajonWarm.ink,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.l10n,
    required this.selected,
    required this.totalUnread,
    required this.shopUnread,
    required this.platformUnread,
    required this.onSelected,
  });

  final AppLocalizations l10n;
  final NotificationCategory? selected;
  final int totalUnread;
  final int shopUnread;
  final int platformUnread;
  final void Function(NotificationCategory?) onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _Chip(
              label: l10n.t('chipAll'),
              count: totalUnread,
              icon: Icons.trending_up_rounded,
              isActive: selected == null,
              onTap: () => onSelected(null),
            ),
            const SizedBox(width: 8),
            _Chip(
              label: l10n.t('chipShop'),
              count: shopUnread,
              icon: Icons.store_rounded,
              isActive: selected == NotificationCategory.shop,
              onTap: () => onSelected(NotificationCategory.shop),
            ),
            const SizedBox(width: 8),
            _Chip(
              label: l10n.t('chipPlatform'),
              count: platformUnread,
              icon: Icons.campaign_rounded,
              isActive: selected == NotificationCategory.platform,
              onTap: () => onSelected(NotificationCategory.platform),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.count,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final int count;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? MohajonWarm.primary : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isActive ? MohajonWarm.primary : MohajonWarm.goldBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? MohajonWarm.ink : MohajonWarm.muted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isActive ? MohajonWarm.ink : MohajonWarm.ink,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isActive
                    ? MohajonWarm.goldText
                    : MohajonWarm.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryTabs extends StatelessWidget {
  const _SecondaryTabs({
    required this.l10n,
    required this.unreadOnly,
    required this.onChanged,
  });

  final AppLocalizations l10n;
  final bool unreadOnly;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, top: 4, bottom: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => onChanged(false),
            child: Text(
              l10n.t('tabAll'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: !unreadOnly
                    ? MohajonWarm.goldText
                    : MohajonWarm.muted,
              ),
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () => onChanged(true),
            child: Text(
              l10n.t('tabUnread'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: unreadOnly
                    ? MohajonWarm.goldText
                    : MohajonWarm.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationItem extends StatelessWidget {
  const _NotificationItem({
    required this.notification,
    required this.isDeleting,
    required this.onMarkRead,
    required this.onDelete,
  });

  final AppNotification notification;
  final bool isDeleting;
  final VoidCallback onMarkRead;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isDeleting ? 0 : 1,
        child: isDeleting
            ? const SizedBox(height: 0)
            : Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ItemContent(
                  notification: notification,
                  onMarkRead: onMarkRead,
                  onDelete: onDelete,
                ),
              ),
      ),
    );
  }
}

class _ItemContent extends StatelessWidget {
  const _ItemContent({
    required this.notification,
    required this.onMarkRead,
    required this.onDelete,
  });

  final AppNotification notification;
  final VoidCallback onMarkRead;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isUnread = !notification.read;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isUnread ? MohajonWarm.tintYellow : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnread ? MohajonWarm.primaryPale : MohajonWarm.goldBorder,
          width: isUnread ? 1.4 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconCircle(type: notification.type),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              notification.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isUnread
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: MohajonWarm.ink,
                              ),
                            ),
                          ),
                          if (isUnread) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: MohajonWarm.orange,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _relativeTime(notification.timestamp, l10n),
                      style: const TextStyle(
                        fontSize: 11,
                        color: MohajonWarm.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  notification.description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: MohajonWarm.muted,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (isUnread)
                      GestureDetector(
                        onTap: onMarkRead,
                        child: Text(
                          l10n.t('markRead'),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: MohajonWarm.goldText,
                          ),
                        ),
                      ),
                    if (isUnread) const SizedBox(width: 14),
                    GestureDetector(
                      onTap: onDelete,
                      child: Text(
                        l10n.t('delete'),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: MohajonWarm.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconCircle extends StatelessWidget {
  const _IconCircle({required this.type});

  final NotificationType type;

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color iconColor;
    IconData icon;

    switch (type) {
      case NotificationType.sale:
      case NotificationType.summary:
        bgColor = MohajonWarm.tintOrange;
        iconColor = MohajonWarm.orange;
        icon = Icons.shopping_cart_rounded;
      case NotificationType.stock:
        bgColor = MohajonWarm.tintOrange;
        iconColor = MohajonWarm.orange;
        icon = Icons.inventory_2_rounded;
      case NotificationType.expense:
        bgColor = MohajonWarm.tintRed;
        iconColor = MohajonWarm.red;
        icon = Icons.receipt_rounded;
      case NotificationType.investment:
        bgColor = MohajonWarm.tintGreen;
        iconColor = MohajonWarm.green;
        icon = Icons.trending_up_rounded;
      case NotificationType.platform:
      case NotificationType.system:
        bgColor = MohajonWarm.goldBorder;
        iconColor = MohajonWarm.muted;
        icon = Icons.campaign_rounded;
      case NotificationType.payment:
        bgColor = MohajonWarm.tintGreen;
        iconColor = MohajonWarm.green;
        icon = Icons.payments_rounded;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white),
      ),
      child: Icon(icon, size: 18, color: iconColor),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_off_outlined,
                size: 36,
                color: MohajonWarm.goldBorder,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              l10n.t('noNotificationsYet'),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: MohajonWarm.ink,
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                l10n.t('noNotificationsHint'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: MohajonWarm.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _relativeTime(DateTime dt, AppLocalizations l10n) {
  final now = DateTime.now();
  final diff = now.difference(dt);

  if (diff.inMinutes < 1) return l10n.t('justNow');
  if (diff.inMinutes < 60) {
    return l10n.tP('minutesAgo', {'n': '${diff.inMinutes}'});
  }
  if (diff.inHours < 24) {
    return l10n.tP('hoursAgo', {'n': '${diff.inHours}'});
  }
  if (diff.inDays == 1) return l10n.t('yesterday');
  if (diff.inDays < 7) {
    return l10n.tP('daysAgo', {'n': '${diff.inDays}'});
  }

  return DateFormat('MMM d').format(dt);
}
