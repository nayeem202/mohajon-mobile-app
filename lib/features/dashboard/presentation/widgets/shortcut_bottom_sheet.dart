import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/shortcut_providers.dart';
import '../models/shortcut_model.dart';

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

    if (current.contains(id)) {
      if (current.length <= 1) {
        _showSnackBar('Keep at least 1 shortcut');
        return;
      }
      notifier.toggle(id);
    } else {
      if (current.length >= 8) {
        _showSnackBar('Max 8 shortcuts allowed');
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
        backgroundColor: const Color(0xFF1C1917),
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
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: FadeTransition(
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
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(999),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Shortcuts',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      'Pick your favorites',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _CounterPill(count: selectedCount),
                  ],
                ),
              ],
            ),
          ),
          _IconButton(
            icon: Icons.swap_vert_rounded,
            onTap: onReorderTap,
            color: const Color(0xFF667085),
            bgColor: const Color(0xFFF5F2ED),
          ),
          const SizedBox(width: 8),
          _IconButton(
            icon: Icons.close_rounded,
            onTap: onClose,
            color: const Color(0xFF667085),
            bgColor: const Color(0xFFF5F2ED),
          ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rearrange',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Drag to reorder shortcuts',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          _IconButton(
            icon: Icons.check_rounded,
            onTap: onDone,
            color: Colors.white,
            bgColor: const Color(0xFFF97316),
          ),
          const SizedBox(width: 8),
          _IconButton(
            icon: Icons.close_rounded,
            onTap: onClose,
            color: const Color(0xFF667085),
            bgColor: const Color(0xFFF5F2ED),
          ),
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: count == 8
            ? const Color(0xFFF97316)
            : const Color(0xFFF5F2ED),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count/8',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: count == 8 ? Colors.white : const Color(0xFF9A9488),
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final Color bgColor;

  const _IconButton({
    required this.icon,
    required this.onTap,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bgColor,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: 20, color: color),
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
        separatorBuilder: (_, __) => const SizedBox(width: 8),
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
    return Container(
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: item.color.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 4),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(item.icon, size: 15, color: item.color),
          ),
          const SizedBox(width: 6),
          Text(
            item.title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: item.color,
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              margin: const EdgeInsets.only(left: 4, right: 4),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close_rounded,
                size: 13,
                color: item.color,
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

    return AnimatedScale(
      scale: isSelected ? 1.0 : 0.97,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isSelected ? item.color : Colors.white,
          border: Border.all(
            color: isSelected
                ? item.color
                : const Color(0xFFEBE4DA),
            width: isSelected ? 0 : 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: item.color.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.onTap,
            splashColor: (isSelected ? Colors.white : item.color)
                .withValues(alpha: 0.15),
            highlightColor: (isSelected ? Colors.white : item.color)
                .withValues(alpha: 0.08),
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
                          ? Colors.white.withValues(alpha: 0.2)
                          : item.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      item.icon,
                      size: 18,
                      color: isSelected ? Colors.white : item.color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF2D2921),
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
                            ? Colors.white.withValues(alpha: 0.25)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
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
      return const Center(
        child: Text(
          'No shortcuts selected',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFFB0A898),
          ),
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
      itemCount: selected.length,
      buildDefaultDragHandles: true,
      onReorder: (oldIndex, newIndex) {
        ref
            .read(selectedShortcutIdsProvider.notifier)
            .reorder(oldIndex, newIndex);
      },
      proxyDecorator: (child, index, animation) {
        return Material(
          elevation: 4 + 6 * animation.value,
          shadowColor: Colors.black.withValues(alpha: 0.12),
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
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFEBE4DA)),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
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
                  color: item.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: item.color, size: 19),
              ),
              const SizedBox(width: 12),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: item.color,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F2ED),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.drag_handle_rounded,
                  size: 18,
                  color: const Color(0xFFB0A898),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
