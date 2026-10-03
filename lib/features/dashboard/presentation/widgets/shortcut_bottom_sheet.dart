import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../providers/shortcut_providers.dart';
import '../models/shortcut_model.dart';

const _kAmber = Color(0xFFFFC800);
const _kAmberLight = Color(0xFFFFD83D);
const _kInk = Color(0xFF2F3028);
const _kMuted = Color(0xFF77735F);
const _kCard = Color(0xFFFFFDF7);
const _kSheetBg = Color(0xFFFFFCF0);
const _kBorder = Color(0xFFEADFAE);
const _kSoftFill = Color(0xFFFFF4BF);
const _kSelGradientLight = Color(0xFFFFDF57);
const _kSelGradientDeep = Color(0xFFF3BC00);
const _kBronzeText = Color(0xFF8A6500);

String shortcutTitle(AppLocalizations l10n, ShortcutItem item) {
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

class ShortcutBottomSheet extends ConsumerStatefulWidget {
  const ShortcutBottomSheet({super.key});

  @override
  ConsumerState<ShortcutBottomSheet> createState() =>
      _ShortcutBottomSheetState();
}

class _ShortcutBottomSheetState extends ConsumerState<ShortcutBottomSheet>
    with SingleTickerProviderStateMixin {
  bool _reorderMode = false;
  late AnimationController _entryCtrl;
  late Animation<double> _entryAnim;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _entryAnim = CurvedAnimation(
      parent: _entryCtrl,
      curve: Curves.easeOutCubic,
    );
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  void _toggle(String id) {
    final notifier = ref.read(selectedShortcutIdsProvider.notifier);
    final current = ref.read(selectedShortcutIdsProvider);
    final l10n = AppLocalizations.of(context);

    if (current.contains(id)) {
      if (current.length <= 1) {
        _showSnackBar(l10n.t('keepMinShortcut'));
        return;
      }
      notifier.toggle(id);
    } else {
      if (current.length >= 8) {
        _showSnackBar(l10n.t('maxShortcuts'));
        return;
      }
      notifier.toggle(id);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: _kInk,
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedIds = ref.watch(selectedShortcutIdsProvider);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final map = {for (final s in allShortcutItems) s.id: s};
    final selectedItems = [
      for (final id in selectedIds)
        if (map.containsKey(id)) map[id]!,
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Container(
          height: MediaQuery.sizeOf(context).height * 0.86,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.26],
              colors: [Color(0xFFFFF6D5), _kSheetBg],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            child: Stack(
              children: [
                Positioned(
                  right: -46,
                  top: -70,
                  child: Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _kAmber.withValues(alpha: 0.09),
                    ),
                  ),
                ),
                Positioned(
                  left: -60,
                  top: -90,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _kAmber.withValues(alpha: 0.16),
                        width: 24,
                      ),
                    ),
                  ),
                ),
                FadeTransition(
                  opacity: _entryAnim,
                  child: Column(
                    children: [
                      _DragHandle(),
                      if (!_reorderMode) ...[
                        _Header(
                          selectedCount: selectedIds.length,
                          onReorderTap: () =>
                              setState(() => _reorderMode = true),
                          onClose: () => Navigator.of(context).pop(),
                        ),
                        if (selectedItems.isNotEmpty)
                          _ActiveSelectionStrip(
                            items: selectedItems,
                            selectedIds: selectedIds,
                            onRemove: (id) => _toggle(id),
                          ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: _SelectorGrid(
                            selectedIds: selectedIds,
                            onToggle: _toggle,
                          ),
                        ),
                      ] else ...[
                        _ReorderHeader(
                          count: selectedIds.length,
                          onDone: () =>
                              setState(() => _reorderMode = false),
                          onClose: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: _ReorderList(selectedIds: selectedIds),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 2),
      child: Center(
        child: Container(
          width: 42,
          height: 4.5,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_kAmber, _kAmberLight],
            ),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

class _BrandBadge extends StatelessWidget {
  final IconData icon;

  const _BrandBadge({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kAmber, _kAmberLight],
        ),
        borderRadius: BorderRadius.circular(13),
        boxShadow: [
          BoxShadow(
            color: _kAmber.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, size: 21, color: _kInk),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool emphasized;

  const _IconButton({
    required this.icon,
    required this.onTap,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: emphasized ? Colors.transparent : const Color(0xFFFFFBEC),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: emphasized
          ? _EmphasizedButton(icon: icon, onTap: onTap)
          : InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(9),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 20, color: _kMuted),
                ),
              ),
            ),
    );
  }
}

class _EmphasizedButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _EmphasizedButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kAmber, _kAmberLight],
        ),
        shape: BoxShape.circle,
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: _kAmber.withValues(alpha: 0.32),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(icon, size: 20, color: _kInk),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onReorderTap;
  final VoidCallback onClose;

  const _Header({
    required this.selectedCount,
    required this.onReorderTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 0),
      child: Row(
        children: [
          const _BrandBadge(icon: Icons.tune_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('quickShortcuts'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: _kInk,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      l10n.t('pickFavorites'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: _kMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _CounterPill(count: selectedCount),
                  ],
                ),
              ],
            ),
          ),
          _IconButton(icon: Icons.swap_vert_rounded, onTap: onReorderTap),
          const SizedBox(width: 8),
          _IconButton(icon: Icons.close_rounded, onTap: onClose),
        ],
      ),
    );
  }
}

class _ReorderHeader extends StatelessWidget {
  final int count;
  final VoidCallback onDone;
  final VoidCallback onClose;

  const _ReorderHeader({
    required this.count,
    required this.onDone,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 0),
      child: Row(
        children: [
          const _BrandBadge(icon: Icons.swap_vert_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('rearrange'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: _kInk,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      l10n.t('dragToReorder'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: _kMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _CounterPill(count: count),
                  ],
                ),
              ],
            ),
          ),
          _IconButton(icon: Icons.check_rounded, onTap: onDone, emphasized: true),
          const SizedBox(width: 8),
          _IconButton(icon: Icons.close_rounded, onTap: onClose),
        ],
      ),
    );
  }
}

class _CounterPill extends StatelessWidget {
  final int count;

  const _CounterPill({required this.count});

  @override
  Widget build(BuildContext context) {
    final isMax = count == 8;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: isMax ? const Color(0xFFEF4444) : _kSoftFill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isMax
              ? const Color(0xFFEF4444).withValues(alpha: 0.35)
              : _kBorder,
        ),
      ),
      child: Text(
        '$count/8',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: isMax ? Colors.white : _kMuted,
        ),
      ),
    );
  }
}

class _ActiveSelectionStrip extends StatelessWidget {
  final List<ShortcutItem> items;
  final List<String> selectedIds;
  final void Function(String id) onRemove;

  const _ActiveSelectionStrip({
    required this.items,
    required this.selectedIds,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      margin: const EdgeInsets.fromLTRB(22, 10, 22, 0),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          return _ActiveChip(
            item: item,
            onRemove: () => onRemove(item.id),
          );
        },
      ),
    );
  }
}

class _ActiveChip extends StatelessWidget {
  final ShortcutItem item;
  final VoidCallback onRemove;

  const _ActiveChip({
    required this.item,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _kAmber.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: _kAmber.withValues(alpha: 0.14),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 4),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _kSoftFill,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(item.icon, size: 15, color: _kBronzeText),
          ),
          const SizedBox(width: 6),
          Text(
            shortcutTitle(l10n, item),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: _kInk,
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              margin: const EdgeInsets.only(left: 4, right: 4),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: _kAmber.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 13,
                color: _kInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectorGrid extends StatelessWidget {
  final List<String> selectedIds;
  final void Function(String id) onToggle;

  const _SelectorGrid({
    required this.selectedIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
      child: GridView.builder(
        itemCount: allShortcutItems.length,
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.6,
        ),
        itemBuilder: (context, index) {
          final item = allShortcutItems[index];
          final isSelected = selectedIds.contains(item.id);
          return _SelectionTile(
            key: ValueKey('${item.id}-$isSelected'),
            item: item,
            isSelected: isSelected,
            onTap: () => onToggle(item.id),
          );
        },
      ),
    );
  }
}

class _SelectionTile extends StatefulWidget {
  final ShortcutItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectionTile({
    super.key,
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_SelectionTile> createState() => _SelectionTileState();
}

class _SelectionTileState extends State<_SelectionTile>
    with TickerProviderStateMixin {
  late AnimationController _checkCtrl;
  late Animation<double> _checkAnim;

  @override
  void initState() {
    super.initState();
    _checkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _checkAnim = CurvedAnimation(
      parent: _checkCtrl,
      curve: Curves.easeOutBack,
    );
    if (widget.isSelected) {
      _checkCtrl.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant _SelectionTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _checkCtrl.forward();
      } else {
        _checkCtrl.reverse();
      }
    }
  }

  @override
  void dispose() {
    _checkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isSelected = widget.isSelected;
    final l10n = AppLocalizations.of(context);

    return AnimatedScale(
      scale: isSelected ? 1.0 : 0.97,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isSelected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_kSelGradientLight, _kSelGradientDeep],
                )
              : null,
          color: isSelected ? null : _kCard,
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : _kBorder,
            width: isSelected ? 0 : 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _kAmber.withValues(alpha: 0.38),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : [
                  BoxShadow(
                    color: _kInk.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.onTap,
            splashColor: (isSelected ? _kInk : item.color)
                .withValues(alpha: 0.12),
            highlightColor: (isSelected ? _kInk : item.color)
                .withValues(alpha: 0.06),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.34)
                          : item.color.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(
                              color: Colors.white.withValues(alpha: 0.45),
                            )
                          : null,
                    ),
                    child: Icon(
                      item.icon,
                      size: 18,
                      color: isSelected ? _kInk : item.color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      shortcutTitle(l10n, item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w900 : FontWeight.w700,
                        color: _kInk,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ScaleTransition(
                    scale: _checkAnim,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: isSelected ? 24 : 0,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check_rounded,
                              color: _kInk,
                              size: 15,
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReorderList extends ConsumerWidget {
  final List<String> selectedIds;

  const _ReorderList({required this.selectedIds});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final map = {for (final s in allShortcutItems) s.id: s};
    final selected = [
      for (final id in selectedIds)
        if (map.containsKey(id)) map[id]!,
    ];

    if (selected.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context).t('noShortcutsSelected'),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: _kMuted,
          ),
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
      itemCount: selected.length,
      buildDefaultDragHandles: true,
      onReorderItem: (oldIndex, newIndex) {
        ref
            .read(selectedShortcutIdsProvider.notifier)
            .reorder(oldIndex, newIndex);
      },
      proxyDecorator: (child, index, animation) {
        return Material(
          elevation: 4 + 6 * animation.value,
          shadowColor: _kAmber.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(18),
          child: Transform.scale(
            scale: 1.0 + 0.03 * animation.value,
            child: child,
          ),
        );
      },
      itemBuilder: (context, index) {
        final item = selected[index];
        return _ReorderTile(
          key: ValueKey(item.id),
          item: item,
          index: index,
          total: selected.length,
        );
      },
    );
  }
}

class _ReorderTile extends StatelessWidget {
  final ShortcutItem item;
  final int index;
  final int total;

  const _ReorderTile({
    super.key,
    required this.item,
    required this.index,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: _kCard,
          border: Border.all(color: _kBorder),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _kInk.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: item.color, size: 19),
              ),
              const SizedBox(width: 12),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: _kSoftFill,
                  border: Border.all(color: _kBorder),
                  borderRadius: BorderRadius.circular(7),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: _kMuted,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  shortcutTitle(l10n, item),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _kInk,
                    fontSize: 14,
                  ),
                ),
              ),
              if (index == 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _kAmber.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: _kAmber.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    l10n.t('top'),
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.7,
                      color: _kInk,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _kSoftFill,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.drag_handle_rounded,
                  size: 18,
                  color: _kMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
