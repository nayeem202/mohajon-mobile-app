import 'package:flutter/material.dart';

class NavDestination {
  const NavDestination({
    required this.icon,
    required this.label,
    this.selectedIcon,
  });

  final IconData icon;
  final String label;
  final IconData? selectedIcon;
}
