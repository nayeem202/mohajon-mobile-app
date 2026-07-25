import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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

  void _openPushSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PushNotificationSheet(
        onSubmit: (type, title, message) {
          ref.read(notificationsProvider.notifier).addNotification(
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
    final state = ref.watch(notificationsProvider);
    final filtered = state.filtered;
    final colors = Theme.of(context).colorScheme;
    final totalUnread = state.unreadCount;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F1),
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              unreadCount: totalUnread,
              onMarkAllRead: () {
                ref.read(notificationsProvider.notifier).markAllAsRead();
              },
              onCompose: _openPushSheet,
              onClose: () => Navigator.of(context).pop(),
            ),
            _FilterChips(
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
              unreadOnly: state.unreadOnly,
              onChanged: (v) {
                ref
                    .read(notificationsProvider.notifier)
                    .setUnreadOnly(v);
              },
            ),
            const Divider(height: 1, color: Color(0xFFF0ECE6)),
            if (filtered.isEmpty)
              const Expanded(
                child: _EmptyState(),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final notification = filtered[index];
                    final isDeleting =
                        _deletingIds.contains(notification.id);
                    final isLast = index == filtered.length - 1;
                    return _NotificationItem(
                      notification: notification,
                      isDeleting: isDeleting,
                      showDivider: !isLast,
                      onMarkRead: () {
                        ref
                            .read(notificationsProvider.notifier)
                            .markAsRead(notification.id);
                      },
                      onDelete: () {
                        setState(() => _deletingIds.add(notification.id));
                        Future.delayed(
                          const Duration(milliseconds: 200),
                          () {
                            if (!mounted) return;
                            ref
                                .read(notificationsProvider.notifier)
                                .delete(notification.id);
                            setState(
                                () => _deletingIds.remove(notification.id));
                          },
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.unreadCount,
    required this.onMarkAllRead,
    required this.onCompose,
    required this.onClose,
  });

  final int unreadCount;
  final VoidCallback onMarkAllRead;
  final VoidCallback onCompose;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.only(left: 20, right: 16, top: 12, bottom: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFF0ECE6)),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Notifications',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: colors.onSurface,
            ),
          ),
          const Spacer(),
          if (unreadCount > 0)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$unreadCount new',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                ),
              ),
            ),
          GestureDetector(
            onTap: onCompose,
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              child: Icon(
                Icons.add_circle_outline_rounded,
                size: 20,
                color: colors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: unreadCount > 0 ? onMarkAllRead : null,
            child: Text(
              'Mark all read',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: unreadCount > 0
                    ? colors.primary
                    : colors.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
            iconSize: 22,
            color: const Color(0xFF98A2B3),
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
    required this.selected,
    required this.totalUnread,
    required this.shopUnread,
    required this.platformUnread,
    required this.onSelected,
  });

  final NotificationCategory? selected;
  final int totalUnread;
  final int shopUnread;
  final int platformUnread;
  final void Function(NotificationCategory?) onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _Chip(
              label: 'All',
              count: totalUnread,
              icon: Icons.trending_up_rounded,
              isActive: selected == null,
              onTap: () => onSelected(null),
            ),
            const SizedBox(width: 8),
            _Chip(
              label: 'Shop',
              count: shopUnread,
              icon: Icons.store_rounded,
              isActive: selected == NotificationCategory.shop,
              onTap: () => onSelected(NotificationCategory.shop),
            ),
            const SizedBox(width: 8),
            _Chip(
              label: 'Platform',
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
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? colors.primary : const Color(0xFFF0ECE6),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? Colors.white : const Color(0xFF525252),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isActive ? Colors.white : const Color(0xFF525252),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isActive
                    ? Colors.white
                    : const Color(0xFF98A2B3),
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
    required this.unreadOnly,
    required this.onChanged,
  });

  final bool unreadOnly;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 20, top: 4, bottom: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => onChanged(false),
            child: Text(
              'All',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: !unreadOnly
                    ? colors.primary
                    : const Color(0xFF98A2B3),
              ),
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () => onChanged(true),
            child: Text(
              'Unread',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: unreadOnly
                    ? colors.primary
                    : const Color(0xFF98A2B3),
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
    required this.showDivider,
    required this.onMarkRead,
    required this.onDelete,
  });

  final AppNotification notification;
  final bool isDeleting;
  final bool showDivider;
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
            : _ItemContent(
                notification: notification,
                showDivider: showDivider,
                onMarkRead: onMarkRead,
                onDelete: onDelete,
              ),
      ),
    );
  }
}

class _ItemContent extends StatelessWidget {
  const _ItemContent({
    required this.notification,
    required this.showDivider,
    required this.onMarkRead,
    required this.onDelete,
  });

  final AppNotification notification;
  final bool showDivider;
  final VoidCallback onMarkRead;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isUnread = !notification.read;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: showDivider
          ? const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFF0ECE6)),
              ),
            )
          : null,
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
                                fontSize: 13,
                                fontWeight: isUnread
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: colors.onSurface,
                              ),
                            ),
                          ),
                          if (isUnread) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF97316),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _relativeTime(notification.timestamp),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF98A2B3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notification.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF525252),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (isUnread)
                      GestureDetector(
                        onTap: onMarkRead,
                        child: Text(
                          'Mark read',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: colors.primary,
                          ),
                        ),
                      ),
                    if (isUnread) const SizedBox(width: 12),
                    GestureDetector(
                      onTap: onDelete,
                      child: const Text(
                        'Delete',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF98A2B3),
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
        bgColor = const Color(0xFFFFF1E6);
        iconColor = const Color(0xFFF97316);
        icon = Icons.shopping_cart_rounded;
      case NotificationType.stock:
        bgColor = const Color(0xFFFFF3E0);
        iconColor = Colors.orange;
        icon = Icons.inventory_2_rounded;
      case NotificationType.expense:
        bgColor = const Color(0xFFFFEBEE);
        iconColor = Colors.red;
        icon = Icons.receipt_rounded;
      case NotificationType.investment:
        bgColor = const Color(0xFFE8F5E9);
        iconColor = Colors.green;
        icon = Icons.trending_up_rounded;
      case NotificationType.platform:
      case NotificationType.system:
        bgColor = const Color(0xFFF0ECE6);
        iconColor = const Color(0xFF525252);
        icon = Icons.campaign_rounded;
      case NotificationType.payment:
        bgColor = const Color(0xFFE8F5E9);
        iconColor = Colors.green;
        icon = Icons.payments_rounded;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Icon(icon, size: 18, color: iconColor),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.notifications_off_outlined,
              size: 40,
              color: Color(0xFFD4D4D4),
            ),
            const SizedBox(height: 16),
            const Text(
              'No notifications yet',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF525252),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'We\u2019ll notify you when something important happens.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF98A2B3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _relativeTime(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);

  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';

  return DateFormat('MMM d').format(dt);
}
