import 'package:flutter/material.dart';

import '../theme/mohajon_warm_theme.dart';
import 'premium_header.dart';

/// Premium building blocks shared by the analytics screens (Purchase Planner,
/// Cashflow Radar, Business Guardian, Day Closing and Customer Growth) so they
/// all speak the same gold/cream language as Dashboard, Staff and Investments.
class InsightTokens {
  InsightTokens._();

  /// Outer decoration shared by premium insight cards. Match the Clients and
  /// Stock stat cards: a very soft semantic pastel fading into warm cream.
  static BoxDecoration cardDecoration({double radius = 18, Color? accent}) {
    final tint = switch (accent) {
      final color when color == MohajonWarm.green => MohajonWarm.tintGreen,
      final color when color == MohajonWarm.orange => MohajonWarm.tintOrange,
      final color when color == MohajonWarm.red => MohajonWarm.tintRed,
      _ => MohajonWarm.tintYellow,
    };
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [tint, MohajonWarm.card],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: MohajonWarm.goldBorder),
      boxShadow: [
        BoxShadow(
          color: (accent ?? MohajonWarm.ink).withValues(
            alpha: accent == null ? 0.06 : 0.09,
          ),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  /// Soft accent-tinted decoration used for hero/banner surfaces.
  static BoxDecoration heroDecoration(Color accent, {double radius = 20}) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          accent.withValues(alpha: 0.16),
          accent.withValues(alpha: 0.03),
        ],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: accent.withValues(alpha: 0.24)),
      boxShadow: [
        BoxShadow(
          color: accent.withValues(alpha: 0.12),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }
}

/// Page shell that applies the MohajonWarm theme, the signature gold page
/// gradient, safe-area insets and the shared [PremiumHeader].
class PremiumInsightPage extends StatelessWidget {
  const PremiumInsightPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
    this.onRefresh,
    this.headerTrailing,
    this.padding = const EdgeInsets.fromLTRB(18, 12, 18, 28),
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final Widget? headerTrailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      padding: padding,
      children: [
        PremiumHeader(
          title: title,
          subtitle: subtitle,
          icon: icon,
          trailing: headerTrailing,
        ),
        ...children,
      ],
    );

    return Theme(
      data: MohajonWarm.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: MohajonWarm.pageGradient),
          child: SafeArea(
            child: onRefresh == null
                ? list
                : RefreshIndicator(onRefresh: onRefresh!, child: list),
          ),
        ),
      ),
    );
  }
}

/// Accent-tinted hero banner: icon pill, headline, supporting copy and an
/// optional large trailing value with a status badge.
class InsightHeroCard extends StatelessWidget {
  const InsightHeroCard({
    super.key,
    required this.icon,
    required this.accent,
    required this.title,
    required this.body,
    this.trailingValue,
    this.trailingLabel,
    this.badge,
    this.badgeAccent,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String body;
  final String? trailingValue;
  final String? trailingLabel;
  final String? badge;
  final Color? badgeAccent;

  @override
  Widget build(BuildContext context) {
    final hasTrailing = trailingValue != null || trailingLabel != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: InsightTokens.heroDecoration(accent),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Stack(
          children: [
            Positioned(
              top: -26,
              right: -26,
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.1),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [accent, accent.withValues(alpha: 0.62)],
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                          color: MohajonWarm.ink,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: MohajonWarm.muted,
                          height: 1.35,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(height: 9),
                        InsightBadge(
                          label: badge!,
                          accent: badgeAccent ?? accent,
                        ),
                      ],
                    ],
                  ),
                ),
                if (hasTrailing) ...[
                  const SizedBox(width: 10),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (trailingValue != null)
                        Text(
                          trailingValue!,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: accent,
                            letterSpacing: -0.6,
                          ),
                        ),
                      if (trailingLabel != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          trailingLabel!,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: MohajonWarm.muted,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Small uppercase status pill.
class InsightBadge extends StatelessWidget {
  const InsightBadge({
    super.key,
    required this.label,
    required this.accent,
    this.filled = false,
  });

  final String label;
  final Color accent;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 9.5,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.5,
        color: filled ? Colors.white : accent,
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: filled ? accent : accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: filled ? accent : accent.withValues(alpha: 0.3),
        ),
      ),
      child: text,
    );
  }
}

/// Compact premium metric tile: accent icon pill, small label, bold value.
class InsightMetricTile extends StatelessWidget {
  const InsightMetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.caption,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      // Keep metric cards aligned when one tile has an optional caption
      // (for example the Cashflow Radar "Runway/Cholbe" tile).
      constraints: const BoxConstraints(minHeight: 130),
      padding: const EdgeInsets.all(14),
      decoration: InsightTokens.cardDecoration(radius: 20, accent: accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, size: 17, color: accent),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: MohajonWarm.ink,
                letterSpacing: -0.3,
              ),
            ),
          ),
          // Reserve the footer line in every tile. Without it, a tile such
          // as Cashflow Radar's Runway (which has a caption) becomes taller
          // than the three adjacent metric cards.
          const SizedBox(height: 3),
          SizedBox(
            height: 12,
            child: caption == null
                ? null
                : Text(
                    caption!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: MohajonWarm.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Responsive grid of [InsightMetricTile]s (2 columns on phones, 4 on tablets).
class InsightMetricGrid extends StatelessWidget {
  const InsightMetricGrid({super.key, required this.tiles, this.spacing = 10});

  final List<Widget> tiles;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720
            ? 4
            : constraints.maxWidth >= 380
            ? 2
            : 1;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }
}

/// Section heading with optional leading icon and trailing widget.
class InsightSectionTitle extends StatelessWidget {
  const InsightSectionTitle({
    super.key,
    required this.title,
    this.icon,
    this.accent = MohajonWarm.primary,
    this.trailing,
  });

  final String title;
  final IconData? icon;
  final Color accent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: accent.withValues(alpha: 0.28)),
              ),
              child: Icon(icon, size: 15, color: accent),
            ),
            const SizedBox(width: 9),
          ],
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: MohajonWarm.ink,
                letterSpacing: -0.2,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Premium row card used for alerts, signals and audit events.
class InsightRowTile extends StatelessWidget {
  const InsightRowTile({
    super.key,
    required this.icon,
    required this.accent,
    required this.title,
    this.body,
    this.leading,
    this.trailing,
    this.dense = false,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String? body;
  final Widget? leading;
  final Widget? trailing;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(dense ? 12 : 14),
      decoration: InsightTokens.cardDecoration(radius: 18, accent: accent),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          leading ??
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withValues(alpha: 0.22)),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: MohajonWarm.ink,
                  ),
                ),
                if (body != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    body!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: MohajonWarm.muted,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
  }
}

/// Premium empty state card.
class InsightEmptyCard extends StatelessWidget {
  const InsightEmptyCard({
    super.key,
    required this.message,
    this.caption,
    this.icon = Icons.inbox_outlined,
    this.accent = MohajonWarm.green,
  });

  final String message;
  final String? caption;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: InsightTokens.cardDecoration(accent: accent),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: accent.withValues(alpha: 0.24)),
            ),
            child: Icon(icon, size: 19, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: MohajonWarm.ink,
                  ),
                ),
                if (caption != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    caption!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: MohajonWarm.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded accent meter used for risk scores and growth bars.
class InsightMeter extends StatelessWidget {
  const InsightMeter({
    super.key,
    required this.value,
    required this.accent,
    this.height = 10,
  });

  /// Progress between 0 and 1.
  final double value;
  final Color accent;
  final double height;

  @override
  Widget build(BuildContext context) {
    final factor = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: accent.withValues(alpha: 0.14)),
            ),
            FractionallySizedBox(
              widthFactor: factor,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent, accent.withValues(alpha: 0.6)],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
