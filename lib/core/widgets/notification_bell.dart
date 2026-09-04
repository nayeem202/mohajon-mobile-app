import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/notifications/providers/notification_providers.dart';
import '../theme/mohajon_warm_theme.dart';

class NotificationBell extends ConsumerWidget {
  const NotificationBell({
    super.key,
    this.onPressed,
    this.size = 24,
  });

  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(notificationsProvider).unreadCount;
    final hasUnread = unreadCount > 0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: onPressed ??
              () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  ),
          icon: Icon(
            Icons.notifications_none_rounded,
            size: size,
          ),
        ),
        if (hasUnread)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: MohajonWarm.orange,
                shape: BoxShape.circle,
                border: Border.fromBorderSide(
                  BorderSide(color: Colors.white, width: 1.5),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
