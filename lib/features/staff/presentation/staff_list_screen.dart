import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/staff_model.dart';
import '../providers/staff_providers.dart';
import 'delete_staff_dialog.dart';
import 'staff_form_sheet.dart';

class StaffListScreen extends ConsumerStatefulWidget {
  const StaffListScreen({super.key});

  @override
  ConsumerState<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends ConsumerState<StaffListScreen> {
  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1C1917),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openForm({StaffMember? staff}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StaffFormSheet(staff: staff),
    ).then((result) {
      if (result == null || !mounted) return;
      final member = result as StaffMember;
      if (staff == null) {
        ref.read(staffListProvider.notifier).add(member);
        _showToast('Staff member added');
      } else {
        ref.read(staffListProvider.notifier).update(staff.id, member);
        _showToast('${member.name} updated');
      }
    });
  }

  void _confirmDelete(StaffMember staff) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => DeleteStaffDialog(
        onConfirm: () {
          ref.read(staffListProvider.notifier).delete(staff.id);
          _showToast('${staff.name} removed');
        },
      ),
    );
  }

  void _toggleActive(StaffMember staff) {
    ref.read(staffListProvider.notifier).toggleActive(staff.id);
    if (!staff.active) {
      _showToast('${staff.name} activated');
    } else {
      _showToast('${staff.name} deactivated');
    }
  }

  @override
  Widget build(BuildContext context) {
    final staff = ref.watch(staffListProvider);
    final activeCount = staff.where((s) => s.active).length;
    final inactiveCount = staff.length - activeCount;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F1),
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Shop Staff'),
      ),
      body: Column(
        children: [
          if (staff.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                '${staff.length} staff \u2014 $activeCount active'
                '${inactiveCount > 0 ? ", $inactiveCount inactive" : ""}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF98A2B3),
                ),
              ),
            ),
          Expanded(
            child: staff.isEmpty
                ? _emptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: staff.length,
                    itemBuilder: (context, index) =>
                        _StaffCard(
                          staff: staff[index],
                          onEdit: () => _openForm(staff: staff[index]),
                          onDelete: () => _confirmDelete(staff[index]),
                          onToggle: () => _toggleActive(staff[index]),
                        ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        backgroundColor: const Color(0xFFF97316),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.person_add_rounded, size: 26),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFF0ECE6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.group_outlined,
                size: 28,
                color: Color(0xFFD4D4D4),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No staff members yet',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF525252),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Add your team members and give them\naccess to the shop',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF98A2B3),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({
    required this.staff,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final StaffMember staff;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: staff.active
              ? const Color(0xFFF0ECE6)
              : const Color(0xFFF0ECE6).withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: staff.avatarColor,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              staff.initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  staff.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: staff.active
                        ? const Color(0xFF1C1917)
                        : const Color(0xFF1C1917).withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  staff.role,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF98A2B3),
                  ),
                ),
                if (staff.phone.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    staff.phone,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF98A2B3),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onEdit,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFF0ECE6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.edit_rounded,
                size: 16,
                color: Color(0xFF525252),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDelete,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                size: 16,
                color: Color(0xFFEF5350),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: 40,
              height: 22,
              decoration: BoxDecoration(
                color: staff.active
                    ? const Color(0xFFF97316)
                    : const Color(0xFFD4D4D4),
                borderRadius: BorderRadius.circular(999),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: staff.active
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  width: 16,
                  height: 16,
                  margin: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
