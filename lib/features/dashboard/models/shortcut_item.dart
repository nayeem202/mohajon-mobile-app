import 'package:flutter/material.dart';
import '../../../core/widgets/app_icon_asset.dart';
import '../../../core/widgets/flaticon_icons.dart';

class ShortcutItem {
  final String id;
  final String title;
  final String icon;
  final Color backgroundColor;
  final Color iconColor;

  const ShortcutItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
  });

  static const int maxCount = 8;

  static const List<ShortcutItem> all = [
    ShortcutItem(
      id: 'new_sale',
      title: 'New Sale',
      icon: FlaticonIcons.plus,
      backgroundColor: Color(0xFFFFF0E0),
      iconColor: Color(0xFFF97316),
    ),
    ShortcutItem(
      id: 'add_product',
      title: 'Add Product',
      icon: FlaticonIcons.box,
      backgroundColor: Color(0xFFE0F2F1),
      iconColor: Color(0xFF0F766E),
    ),
    ShortcutItem(
      id: 'stock',
      title: 'Stock',
      icon: FlaticonIcons.box,
      backgroundColor: Color(0xFFFFF0E0),
      iconColor: Color(0xFFF97316),
    ),
    ShortcutItem(
      id: 'add_client',
      title: 'Add Client',
      icon: FlaticonIcons.personAdd,
      backgroundColor: Color(0xFFF3E8E0),
      iconColor: Color(0xFF8B6F47),
    ),
    ShortcutItem(
      id: 'clients',
      title: 'Clients',
      icon: FlaticonIcons.user,
      backgroundColor: Color(0xFFE0EAFF),
      iconColor: Color(0xFF2563EB),
    ),
    ShortcutItem(
      id: 'pos',
      title: 'POS',
      icon: FlaticonIcons.cart,
      backgroundColor: Color(0xFFFFF0E0),
      iconColor: Color(0xFFF97316),
    ),
    ShortcutItem(
      id: 'expenses',
      title: 'Expenses',
      icon: FlaticonIcons.wallet,
      backgroundColor: Color(0xFFFFF0E0),
      iconColor: Color(0xFFF97316),
    ),
    ShortcutItem(
      id: 'vendors',
      title: 'Vendors',
      icon: FlaticonIcons.store,
      backgroundColor: Color(0xFFF0E6FF),
      iconColor: Color(0xFF7C3AED),
    ),
    ShortcutItem(
      id: 'investors',
      title: 'Investors',
      icon: FlaticonIcons.user,
      backgroundColor: Color(0xFFE0F5E9),
      iconColor: Color(0xFF047857),
    ),
    ShortcutItem(
      id: 'reports',
      title: 'Reports',
      icon: FlaticonIcons.grid,
      backgroundColor: Color(0xFFFFE8E8),
      iconColor: Color(0xFFDC2626),
    ),
    ShortcutItem(
      id: 'staff',
      title: 'Staff',
      icon: FlaticonIcons.user,
      backgroundColor: Color(0xFFF0E6FF),
      iconColor: Color(0xFF7C3AED),
    ),
    ShortcutItem(
      id: 'settings',
      title: 'Settings',
      icon: FlaticonIcons.settings,
      backgroundColor: Color(0xFFF0F0F0),
      iconColor: Color(0xFF525252),
    ),
  ];
}
