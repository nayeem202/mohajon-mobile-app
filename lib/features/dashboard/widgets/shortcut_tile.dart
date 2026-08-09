import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/widgets/app_icon_asset.dart';
import '../../../core/widgets/flaticon_icons.dart';
import '../models/shortcut_item.dart';

class ShortcutTile extends StatelessWidget {
  const ShortcutTile({
    super.key,
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final ShortcutItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isSelected ? 1.0 : 0.97,
      duration: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF0FDE7) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? const Color(0xFF16A34A) : const Color(0xFFE8DDD2),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: item.backgroundColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: AppIconAsset(assetPath: item.icon, color: const Color(0xFF1C1917), size: 22),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? const Color(0xFF16A34A) : const Color(0xFF1C1917),
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Positioned(
                  left: 10,
                  bottom: 10,
                  child: AnimatedOpacity(
                    opacity: isSelected ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Color(0xFF16A34A),
                        shape: BoxShape.circle,
                      ),
                      child: const AppIconAsset(assetPath: FlaticonIcons.check, color: Colors.white, size: 14),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
