import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/app_feedback.dart';
import 'nav_destination.dart';
import 'nav_bar_theme.dart';

class AnimatedBottomNavBar extends StatefulWidget {
  const AnimatedBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.destinations,
    required this.onSelected,
    this.onMoreTap,
    this.itemKeys,
    this.trailing,
  }) : assert(destinations.length > 1),
       assert(selectedIndex >= 0 && selectedIndex < destinations.length);

  final int selectedIndex;
  final List<NavDestination> destinations;
  final ValueChanged<int> onSelected;
  final VoidCallback? onMoreTap;
  final List<GlobalKey>? itemKeys;
  final Widget? trailing;

  @override
  State<AnimatedBottomNavBar> createState() => _AnimatedBottomNavBarState();
}

class _AnimatedBottomNavBarState extends State<AnimatedBottomNavBar> {
  static const _navBackground = Colors.white;
  static const _navActive = Color(0xFFFFC800);
  static const _navInactive = Color(0xFF77735F);

  void _onTap(int index) {
    if (index == widget.destinations.length - 1 && widget.onMoreTap != null) {
      widget.onMoreTap!();
      return;
    }
    widget.onSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = widget.destinations.length;
    final colors = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          NavBarTheme.horizontalPadding,
          0,
          NavBarTheme.horizontalPadding,
          NavBarTheme.bottomMargin,
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: NavBarTheme.maxWidth),
            child: SizedBox(
              height: NavBarTheme.height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _navBackground,
                  borderRadius: BorderRadius.circular(NavBarTheme.cornerRadius),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2F3028).withValues(alpha: 0.16),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: colors.shadow.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(NavBarTheme.indicatorInset),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final availableWidth = constraints.maxWidth;
                      final trailingWidth =
                          widget.trailing == null ? 0.0 : 46.0;
                      final navWidth = availableWidth - trailingWidth;
                      final maxAllowedActiveWidth =
                          navWidth -
                          (NavBarTheme.minInactiveWidth * (itemCount - 1));
                      final desiredActiveWidth =
                          (navWidth * NavBarTheme.activeWidthFraction).clamp(
                            NavBarTheme.minActiveWidth,
                            NavBarTheme.maxActiveWidth,
                          );
                      final activeWidth =
                          maxAllowedActiveWidth < NavBarTheme.minInactiveWidth
                          ? navWidth / itemCount
                          : desiredActiveWidth
                                .clamp(
                                  NavBarTheme.minInactiveWidth,
                                  maxAllowedActiveWidth,
                                )
                                .toDouble();
                      final inactiveWidth =
                          (navWidth - activeWidth) / (itemCount - 1);
                      final indicatorLeft = widget.selectedIndex * inactiveWidth;

                      double itemLeft(int index) {
                        if (index <= widget.selectedIndex) {
                          return index * inactiveWidth;
                        }
                        return activeWidth + ((index - 1) * inactiveWidth);
                      }

                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedPositioned(
                            key: const ValueKey('nav-indicator'),
                            duration: NavBarTheme.animationDuration,
                            curve: Curves.easeOutCubic,
                            left: indicatorLeft,
                            width: activeWidth,
                            top: 0,
                            bottom: 0,
                            child: Container(
                              margin: const EdgeInsets.all(1),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [_navActive, const Color(0xFFFFE36E)],
                                ),
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(999),
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.30),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _navActive.withValues(alpha: 0.30),
                                    blurRadius: 14,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          for (var index = 0; index < itemCount; index++)
                            AnimatedPositioned(
                              key: ValueKey('nav-position-$index'),
                              duration: NavBarTheme.animationDuration,
                              curve: Curves.easeOutCubic,
                              left: itemLeft(index),
                              width: widget.selectedIndex == index
                                  ? activeWidth
                                  : inactiveWidth,
                              top: 0,
                              bottom: 0,
                              child: _AnimatedNavItem(
                                key: widget.itemKeys?[index] ?? ValueKey('nav-item-$index'),
                                destination: widget.destinations[index],
                                selected: widget.selectedIndex == index,
                                showLabel:
                                    widget.selectedIndex == index &&
                                    activeWidth >=
                                        NavBarTheme.minActiveWidth * 0.82,
                                activeColor: const Color(0xFF2F3028),
                                inactiveColor: _navInactive,
                                onTap: () => _onTap(index),
                              ),
                            ),
                          if (widget.trailing != null)
                            Positioned(
                              key: const ValueKey('nav-trailing'),
                              right: 0,
                              top: 0,
                              bottom: 0,
                              child: Center(child: widget.trailing),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedNavItem extends StatefulWidget {
  const _AnimatedNavItem({
    super.key,
    required this.destination,
    required this.selected,
    required this.showLabel,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final bool showLabel;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  State<_AnimatedNavItem> createState() => _AnimatedNavItemState();
}

class _AnimatedNavItemState extends State<_AnimatedNavItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      duration: NavBarTheme.iconBounceDuration,
      vsync: this,
    );
    _bounceAnimation = _buildBounceAnimation();
  }

  Animation<double> _buildBounceAnimation() {
    return TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.9,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 33,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.9,
          end: 1.1,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 34,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.1,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 33,
      ),
    ]).animate(_bounceController);
  }

  void _onTap() {
    AppFeedback.tap();
    _bounceController
      ..value = 0.0
      ..forward();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.selected
        ? widget.activeColor
        : widget.inactiveColor;
    final icon = widget.selected
        ? widget.destination.selectedIcon ?? widget.destination.icon
        : widget.destination.icon;

    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.destination.label,
      child: RepaintBoundary(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: const BorderRadius.all(Radius.circular(999)),
            onTap: _onTap,
            splashColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.14),
            highlightColor: Colors.transparent,
            child: Center(
              child: AnimatedBuilder(
                animation: _bounceAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _bounceAnimation.value,
                    child: child,
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(
                              scale: animation,
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            ),
                        child: Icon(
                          icon,
                          key: ValueKey(icon),
                          color: iconColor,
                          size: NavBarTheme.iconSize,
                        ),
                      ),
                      AnimatedSize(
                        duration: NavBarTheme.animationDuration,
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.centerLeft,
                        child: ClipRect(
                          child: widget.showLabel
                              ? TweenAnimationBuilder<double>(
                                  key: const ValueKey('label'),
                                  duration: NavBarTheme.animationDuration,
                                  curve: Curves.easeOutCubic,
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  builder: (context, value, child) {
                                    return Opacity(
                                      opacity: value,
                                      child: Transform.translate(
                                        offset: Offset(20 * (1 - value), 0),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Text(
                                      widget.destination.label,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: TextStyle(
                                        color: widget.activeColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.1,
                                      ),
                                    ),
                                  ),
                                )
                              : const SizedBox(width: 0),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }
}
