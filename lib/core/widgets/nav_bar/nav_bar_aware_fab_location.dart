import 'package:flutter/material.dart';

import 'nav_bar_theme.dart';

class NavBarAwareFabLocation extends FloatingActionButtonLocation {
  const NavBarAwareFabLocation();

  static const double _fabMargin = 16;
  static const double _gap = 40;
  static const double _wideThreshold = 900;

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final fab = scaffoldGeometry.floatingActionButtonSize;
    final isWide = scaffoldGeometry.scaffoldSize.width >= _wideThreshold;
    final extraBottom = isWide
        ? 0.0
        : NavBarTheme.height + NavBarTheme.bottomMargin + _gap;
    return Offset(
      scaffoldGeometry.scaffoldSize.width - fab.width - _fabMargin,
      scaffoldGeometry.scaffoldSize.height -
          fab.height -
          _fabMargin -
          extraBottom -
          scaffoldGeometry.minInsets.bottom,
    );
  }
}
