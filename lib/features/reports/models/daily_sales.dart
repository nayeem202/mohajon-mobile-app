import 'package:flutter/material.dart';

class DailySales {
  const DailySales({
    required this.date,
    required this.label,
    required this.amount,
    required this.transactionCount,
    required this.maxAmount,
    this.color = const Color(0xFFF5B731),
  });

  final DateTime date;
  final String label;
  final double amount;
  final int transactionCount;
  final double maxAmount;
  final Color color;

  double get fraction => maxAmount > 0 ? amount / maxAmount : 0.0;

  double get average => transactionCount > 0 ? amount / transactionCount : 0;
}
