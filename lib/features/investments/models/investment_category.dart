import 'package:flutter/material.dart';

class InvestmentCategory {
  final String id;
  final String name;
  final String icon;
  final int color;
  final String shopId;
  final DateTime createdAt;

  const InvestmentCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.shopId = '',
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'icon': icon,
    'color': color,
    'shopId': shopId,
    'createdAt': createdAt.toIso8601String(),
  };

  factory InvestmentCategory.fromJson(String id, Map<String, dynamic> json) =>
      InvestmentCategory(
        id: id,
        name: json['name'] as String? ?? '',
        icon: json['icon'] as String? ?? '',
        color: json['color'] as int? ?? 0xFF98A2B3,
        shopId: json['shopId'] as String? ?? '',
        createdAt: (json['createdAt'] as dynamic) is String
            ? DateTime.parse(json['createdAt'] as String)
            : (json['createdAt'] as DateTime?) ?? DateTime(2020),
      );

  static final defaults = [
    InvestmentCategory(
      id: 'setup',
      name: 'Setup',
      icon: 'construction',
      color: 0xFFF97316,
      createdAt: DateTime(2020),
    ),
    InvestmentCategory(
      id: 'equipment',
      name: 'Equipment',
      icon: 'precision_manufacturing',
      color: 0xFF0F766E,
      createdAt: DateTime(2020),
    ),
    InvestmentCategory(
      id: 'technology',
      name: 'Technology',
      icon: 'computer',
      color: 0xFF059669,
      createdAt: DateTime(2020),
    ),
    InvestmentCategory(
      id: 'inventory',
      name: 'Inventory',
      icon: 'inventory_2',
      color: 0xFFB45309,
      createdAt: DateTime(2020),
    ),
    InvestmentCategory(
      id: 'vehicle',
      name: 'Vehicle',
      icon: 'local_shipping',
      color: 0xFFDC2626,
      createdAt: DateTime(2020),
    ),
    InvestmentCategory(
      id: 'marketing',
      name: 'Marketing',
      icon: 'campaign',
      color: 0xFFF59E0B,
      createdAt: DateTime(2020),
    ),
    InvestmentCategory(
      id: 'other',
      name: 'Other',
      icon: 'account_balance',
      color: 0xFF98A2B3,
      createdAt: DateTime(2020),
    ),
  ];

  IconData get iconData {
    switch (icon) {
      case 'construction':
        return Icons.construction_rounded;
      case 'precision_manufacturing':
        return Icons.precision_manufacturing_rounded;
      case 'computer':
        return Icons.computer_rounded;
      case 'inventory_2':
        return Icons.inventory_2_rounded;
      case 'local_shipping':
        return Icons.local_shipping_rounded;
      case 'campaign':
        return Icons.campaign_rounded;
      case 'account_balance':
        return Icons.account_balance_rounded;
      default:
        return Icons.category_rounded;
    }
  }
}
