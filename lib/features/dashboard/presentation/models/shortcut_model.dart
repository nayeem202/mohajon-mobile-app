import 'package:flutter/material.dart';

enum ShortcutAction {
  newSale,
  addProduct,
  addClient,
  pos,
  stock,
  clients,
  expenses,
  vendors,
  investors,
  reports,
  staff,
  settings,
  purchase,
  salesHistory,
  investments,
}

class ShortcutItem {
  final String id;
  final String title;
  final IconData icon;
  final Color color;
  final ShortcutAction action;

  const ShortcutItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.action,
  });
}

const List<ShortcutItem> allShortcutItems = [
  ShortcutItem(
    id: 'new_sale',
    title: 'New Sale',
    icon: Icons.add_circle_outline_rounded,
    color: Color(0xFFF97316),
    action: ShortcutAction.newSale,
  ),
  ShortcutItem(
    id: 'add_product',
    title: 'Add Product',
    icon: Icons.add_box_outlined,
    color: Color(0xFF0F766E),
    action: ShortcutAction.addProduct,
  ),
  ShortcutItem(
    id: 'add_client',
    title: 'Add Client',
    icon: Icons.person_add_alt_1_outlined,
    color: Color(0xFF8B6F47),
    action: ShortcutAction.addClient,
  ),
  ShortcutItem(
    id: 'pos',
    title: 'POS',
    icon: Icons.shopping_cart_rounded,
    color: Color(0xFFF97316),
    action: ShortcutAction.pos,
  ),
  ShortcutItem(
    id: 'stock',
    title: 'Stock',
    icon: Icons.inventory_2_rounded,
    color: Color(0xFF0F766E),
    action: ShortcutAction.stock,
  ),
  ShortcutItem(
    id: 'clients',
    title: 'Clients',
    icon: Icons.people_alt_rounded,
    color: Color(0xFF8B6F47),
    action: ShortcutAction.clients,
  ),
  ShortcutItem(
    id: 'expenses',
    title: 'Expenses',
    icon: Icons.payments_rounded,
    color: Color(0xFFF97316),
    action: ShortcutAction.expenses,
  ),
  ShortcutItem(
    id: 'vendors',
    title: 'Vendors',
    icon: Icons.store_rounded,
    color: Color(0xFF7C3AED),
    action: ShortcutAction.vendors,
  ),
  ShortcutItem(
    id: 'investors',
    title: 'Investors',
    icon: Icons.people_alt_rounded,
    color: Color(0xFF047857),
    action: ShortcutAction.investors,
  ),
  ShortcutItem(
    id: 'reports',
    title: 'Reports',
    icon: Icons.pie_chart_outline_rounded,
    color: Color(0xFFF97316),
    action: ShortcutAction.reports,
  ),
  ShortcutItem(
    id: 'staff',
    title: 'Staff',
    icon: Icons.badge_rounded,
    color: Color(0xFF0F766E),
    action: ShortcutAction.staff,
  ),
  ShortcutItem(
    id: 'settings',
    title: 'Settings',
    icon: Icons.settings_outlined,
    color: Color(0xFF98A2B3),
    action: ShortcutAction.settings,
  ),
  ShortcutItem(
    id: 'purchase',
    title: 'Purchase',
    icon: Icons.add_shopping_cart_rounded,
    color: Color(0xFF047857),
    action: ShortcutAction.purchase,
  ),
  ShortcutItem(
    id: 'sales_history',
    title: 'Sales History',
    icon: Icons.history_rounded,
    color: Color(0xFF0F766E),
    action: ShortcutAction.salesHistory,
  ),
  ShortcutItem(
    id: 'investments',
    title: 'Investments',
    icon: Icons.account_balance_rounded,
    color: Color(0xFF0F766E),
    action: ShortcutAction.investments,
  ),
];