import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/snackbar.dart';
import '../models/shortcut_item.dart';
import '../providers/shortcut_provider.dart';
import 'shortcut_tile.dart';

class ShortcutBottomSheet extends ConsumerStatefulWidget {
  const ShortcutBottomSheet({super.key});

  @override
  ConsumerState<ShortcutBottomSheet> createState() => _ShortcutBottomSheetState();
}

class _ShortcutBottomSheetState extends ConsumerState<ShortcutBottomSheet>
    with SingleTickerProviderStateMixin {
  late List<String> _draft;
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _draft = List.from(ref.read(selectedShortcutsProvider));
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _toggle(String id) {
    if (_draft.contains(id)) {
      setState(() => _draft.remove(id));
    } else if (_draft.length < ShortcutItem.maxCount) {
      setState(() => _draft.add(id));
    } else {
      showAppSnackBar(context, 'Maximum ${ShortcutItem.maxCount} shortcuts allowed', isError: true);
    }
  }

  void _save() {
    ref.read(selectedShortcutsProvider.notifier).updateOrder(_draft);
    ref.read(selectedShortcutsProvider.notifier).save(ref);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _draft.length;
    final progress = selected / ShortcutItem.maxCount;

    return FadeTransition(
      opacity: _animCtrl,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            _buildHandle(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(selected),
                    const SizedBox(height: 18),
                    _buildProgressBar(progress, selected),
                    const SizedBox(height: 24),
                    _buildGrid(),
                  ],
                ),
              ),
            ),
            _buildBottomButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }

  Widget _buildHeader(int selected) {
    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (context, _) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customize Shortcuts',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1C1917),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select up to ${ShortcutItem.maxCount} shortcuts for your home screen',
                  style: TextStyle(
                    fontSize: 13,
                    color: const Color(0xFF98A2B3),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$selected/${ShortcutItem.maxCount}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: selected == ShortcutItem.maxCount
                  ? const Color(0xFF16A34A)
                  : const Color(0xFF1C1917),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(double progress, int selected) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          return LinearProgressIndicator(
            value: value,
            minHeight: 6,
            backgroundColor: const Color(0xFFF0ECE6),
            valueColor: AlwaysStoppedAnimation<Color>(
              selected == ShortcutItem.maxCount
                  ? const Color(0xFF16A34A)
                  : const Color(0xFFF97316),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: ShortcutItem.all.length,
      itemBuilder: (context, index) {
        final item = ShortcutItem.all[index];
        return ShortcutTile(
          item: item,
          isSelected: _draft.contains(item.id),
          onTap: () => _toggle(item.id),
        );
      },
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: Color(0xFFE8DDD2)),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF525252),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: _draft.isEmpty ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF97316),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: const Color(0xFFF0ECE6),
                ),
                child: const Text(
                  'Save Changes',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
