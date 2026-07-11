import 'package:flutter/material.dart';

class AccountMenuTile extends StatelessWidget {
  const AccountMenuTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
    this.titleColor,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color? iconColor;
  final Color? titleColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final effectiveIconColor = iconColor ?? colors.primary;
    final effectiveTitleColor = titleColor ?? colors.onSurface;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: effectiveIconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: effectiveIconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: effectiveTitleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
