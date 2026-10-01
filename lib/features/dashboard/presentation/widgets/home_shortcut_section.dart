import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../providers/shortcut_providers.dart';
import '../models/shortcut_model.dart';
import 'shortcut_bottom_sheet.dart';

class HomeShortcutSection extends ConsumerWidget {
  const HomeShortcutSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shortcuts = ref.watch(selectedShortcutsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(onEdit: () => _showEditor(context)),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            );
          },
          child: shortcuts.isEmpty
              ? _EmptyShortcuts(
                  key: const ValueKey('empty'),
                  onTap: () => _showEditor(context),
                )
              : _ShortcutRow(
                  key: ValueKey(shortcuts.map((s) => s.id).join(',')),
                  shortcuts: shortcuts,
                ),
        ),
      ],
    );
  }

  void _showEditor(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ShortcutBottomSheet(),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.onEdit});

  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 330;
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.t('quickActions'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              l10n.t('quickActionsSubtitle'),
              maxLines: compact ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.onSurfaceVariant.withValues(alpha: 0.72),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
        final edit = Material(
          color: const Color(0xFFFFC800),
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onEdit,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 9 : 11,
                vertical: 7,
              ),
              child: compact
                  ? const Icon(
                      Icons.tune_rounded,
                      size: 17,
                      color: Color(0xFF2F3028),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.tune_rounded,
                          size: 15,
                          color: Color(0xFF2F3028),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          l10n.t('customize'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF2F3028),
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [Expanded(child: title), edit]),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [Expanded(child: title), edit],
        );
      },
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  final List<ShortcutItem> shortcuts;

  const _ShortcutRow({super.key, required this.shortcuts});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.78),
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.055),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.hasBoundedWidth
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width;
            final columns = availableWidth >= 520
                ? 5
                : availableWidth >= 360
                    ? 4
                    : availableWidth >= 240
                        ? 3
                        : availableWidth >= 160
                            ? 2
                            : 1;
            const gap = 4.0;
            final width =
                ((availableWidth - (columns - 1) * gap) / columns)
                    .clamp(48.0, 180.0);
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: shortcuts
                  .map(
                    (item) => SizedBox(
                      width: width,
                      height: 82,
                      child: _ShortcutCard(
                        item: item,
                        onTap: () => navigateToShortcut(context, item),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ),
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({required this.item, required this.onTap});

  final ShortcutItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: item.color.withValues(alpha: 0.12),
        highlightColor: item.color.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                key: ValueKey('shortcut-icon-${item.id}'),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: item.color, size: 22),
              ),
              const SizedBox(height: 6),
              Text(
                _shortcutLabel(l10n, item),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _shortcutLabel(AppLocalizations l10n, ShortcutItem item) {
  final key = switch (item.id) {
    'new_sale' => 'newSale',
    'add_product' => 'addProductItem',
    'add_client' => 'addClient',
    'pos' => 'pos',
    'stock' => 'stock',
    'clients' => 'clients',
    'expenses' => 'expenses',
    'vendors' => 'vendors',
    'investors' => 'investors',
    'reports' => 'reports',
    'staff' => 'staff',
    'settings' => 'settings',
    'purchase' => 'purchase',
    'sales_history' => 'salesHistory',
    'investments' => 'investments',
    _ => item.id,
  };
  return l10n.t(key);
}

class _EmptyShortcuts extends StatelessWidget {
  const _EmptyShortcuts({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.add_rounded, size: 24, color: colors.primary),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.t('addFirstQuickAction'),
              style: TextStyle(
                color: colors.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
