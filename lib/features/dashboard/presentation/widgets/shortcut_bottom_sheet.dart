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

class _ShortcutBottomSheetState extends ConsumerState<ShortcutBottomSheet> {
  bool _reorderMode = false;

  void _toggle(String id) {
    final notifier = ref.read(selectedShortcutIdsProvider.notifier);
    final current = ref.read(selectedShortcutIdsProvider);

    if (current.contains(id)) {
      if (current.length <= 1) {
        _showSnackBar('At least 1 shortcut required');
        return;
      }
      notifier.toggle(id);
    } else {
      if (current.length >= 8) {
        _showSnackBar('Maximum 8 shortcuts allowed');
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: const Color(0xFF1C1917),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedIds = ref.watch(selectedShortcutIdsProvider);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Container(
          height: MediaQuery.sizeOf(context).height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              _DragIndicator(),
              _SheetHeader(
                selectedCount: selectedIds.length,
                reorderMode: _reorderMode,
                onReorderToggle: () =>
                    setState(() => _reorderMode = !_reorderMode),
                onClose: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: _reorderMode
                    ? _ReorderList(selectedIds: selectedIds)
                    : _ShortcutGrid(
                        selectedIds: selectedIds,
                        onToggle: _toggle,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DragIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Center(
        child: Container(
          width: 44,
          height: 5,
          decoration: BoxDecoration(
            color: const Color(0xFFD4C5B5),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final int selectedCount;
  final bool reorderMode;
  final VoidCallback onReorderToggle;
  final VoidCallback onClose;

  const _SheetHeader({
    required this.selectedCount,
    required this.reorderMode,
    required this.onReorderToggle,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reorderMode ? 'Reorder Shortcuts' : 'Customize Shortcuts',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      reorderMode
                          ? 'Drag to reorder'
                          : 'Select up to 8 shortcuts',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: selectedCount == 8
                            ? const Color(0xFFF97316)
                            : const Color(0xFFF3F0EA),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$selectedCount/8',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: selectedCount == 8
                              ? Colors.white
                              : colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!reorderMode)
            Material(
              color: const Color(0xFFF3F0EA),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onReorderToggle,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    size: 20,
                    color: Color(0xFF667085),
                  ),
                ),
              ),
            ),
          if (!reorderMode) const SizedBox(width: 6),
          Material(
            color: reorderMode
                ? const Color(0xFFF97316)
                : const Color(0xFFF3F0EA),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onClose,
              child: Padding(
                padding: EdgeInsets.all(8),
                child: Icon(
                  reorderMode ? Icons.check_rounded : Icons.close_rounded,
                  size: 20,
                  color:
                      reorderMode ? Colors.white : const Color(0xFF667085),
                ),
              ),
            ),
          ),
        ],
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
          style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF98A2B3)),
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: selected.length,
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) {
        ref
            .read(selectedShortcutIdsProvider.notifier)
            .reorder(oldIndex, newIndex);
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFECE7DF)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ReorderableDragStartListener(
              index: index,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, color: item.color, size: 18),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        title: Text(
          item.title,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: colors.onSurface,
          ),
        ),
        trailing: Icon(
          Icons.drag_handle_rounded,
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ShortcutGrid extends StatelessWidget {
  final List<String> selectedIds;
  final void Function(String id) onToggle;

  const _ShortcutGrid({
    required this.selectedIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: GridView.builder(
        itemCount: allShortcutItems.length,
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.85,
        ),
        itemBuilder: (context, index) {
          final item = allShortcutItems[index];
          final isSelected = selectedIds.contains(item.id);
          return _SelectorTile(
            item: item,
            isSelected: isSelected,
            onTap: () => onToggle(item.id),
          );
        },
      ),
    );
  }
}

class _SelectorTile extends StatelessWidget {
  final ShortcutItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectorTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
        border: Border.all(
          color:
              isSelected ? const Color(0xFF22C55E) : const Color(0xFFECE7DF),
          width: isSelected ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Stack(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: item.color
                            .withValues(alpha: isSelected ? 0.15 : 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        item.icon,
                        color: item.color,
                        size: 18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w700,
                        color: isSelected
                            ? const Color(0xFF166534)
                            : colors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Color(0xFF22C55E),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}