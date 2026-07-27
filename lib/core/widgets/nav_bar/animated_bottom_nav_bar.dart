import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'nav_destination.dart';
import 'nav_bar_theme.dart';

class AnimatedBottomNavBar extends StatefulWidget {
  const AnimatedBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.destinations,
    required this.onSelected,
    this.onMoreTap,
  });

  final int selectedIndex;
  final List<NavDestination> destinations;
  final ValueChanged<int> onSelected;
  final VoidCallback? onMoreTap;

  @override
  State<AnimatedBottomNavBar> createState() => _AnimatedBottomNavBarState();
}

class _AnimatedBottomNavBarState extends State<AnimatedBottomNavBar> {
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

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          NavBarTheme.horizontalPadding,
          0,
          NavBarTheme.horizontalPadding,
          NavBarTheme.bottomMargin,
        ),
        child: SizedBox(
          height: NavBarTheme.height,
          child: Container(
            decoration: BoxDecoration(
              color: NavBarTheme.background,
              borderRadius: BorderRadius.circular(NavBarTheme.cornerRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(NavBarTheme.indicatorInset),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth =
                      constraints.maxWidth / itemCount;
                  final indicatorLeft =
                      widget.selectedIndex * itemWidth;

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedPositioned(
                        duration: NavBarTheme.animationDuration,
                        curve: Curves.easeOutCubic,
                        left: indicatorLeft,
                        width: itemWidth,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: NavBarTheme.primary,
                            borderRadius: const BorderRadius.all(
                              Radius.circular(999),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: NavBarTheme.primary
                                    .withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Row(
                        children: List.generate(itemCount, (index) {
                          final selected =
                              widget.selectedIndex == index;

                          return Expanded(
                            child: _AnimatedNavItem(
                              destination:
                                  widget.destinations[index],
                              selected: selected,
                              onTap: () => _onTap(index),
                            ),
                          );
                        }),
                      ),
                    ],
                  );
                },
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
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
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
        tween: Tween(begin: 1.0, end: 0.9)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 33,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.9, end: 1.1)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 34,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.1, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 33,
      ),
    ]).animate(_bounceController);
  }

  void _onTap() {
    HapticFeedback.selectionClick();
    _bounceController
      ..value = 0.0
      ..forward();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.selected
        ? NavBarTheme.onPrimary
        : NavBarTheme.inactiveIcon;

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
            splashColor: NavBarTheme.primary.withValues(alpha: 0.15),
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
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.destination.icon,
                        color: iconColor,
                        size: NavBarTheme.iconSize,
                      ),
                      AnimatedSize(
                        duration: NavBarTheme.animationDuration,
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.centerLeft,
                        child: ClipRect(
                          child: widget.selected
                              ? TweenAnimationBuilder<double>(
                                  key: const ValueKey('label'),
                                  duration:
                                      NavBarTheme.animationDuration,
                                  curve: Curves.easeOutCubic,
                                  tween:
                                      Tween(begin: 0.0, end: 1.0),
                                  builder:
                                      (context, value, child) {
                                    return Opacity(
                                      opacity: value,
                                      child: Transform.translate(
                                        offset: Offset(
                                            20 * (1 - value), 0),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                        left: 4),
                                    child: Text(
                                      widget.destination.label,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
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
