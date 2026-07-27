import 'dart:io';

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
  final _searchController = TextEditingController();
  bool _showSearch = false;

  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
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
    final query = _searchController.text.toLowerCase();
    final filtered = query.isEmpty
        ? staff
        : staff.where((s) =>
            s.name.toLowerCase().contains(query) ||
            s.role.toLowerCase().contains(query) ||
            s.phone.contains(query)).toList();
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
          if (_showSearch)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search staff...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.clear_rounded),
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE8DDD2)),
                  ),
                ),
              ),
            ),
          if (staff.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(20, _showSearch ? 4 : 4, 20, 12),
              child: Text(
                '${filtered.length} of ${staff.length} staff \u2014 $activeCount active'
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
                : filtered.isEmpty
                    ? _emptySearchState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) =>
                            _StaffCard(
                              staff: filtered[index],
                              onEdit: () => _openForm(staff: filtered[index]),
                              onDelete: () => _confirmDelete(filtered[index]),
                              onToggle: () => _toggleActive(filtered[index]),
                            ),
                      ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'search',
            onPressed: () {
              setState(() => _showSearch = !_showSearch);
              if (!_showSearch) {
                _searchController.clear();
              }
            },
            backgroundColor: const Color(0xFFF97316),
            foregroundColor: Colors.white,
            elevation: 4,
            shape: const CircleBorder(),
            child: Icon(_showSearch ? Icons.search_off_rounded : Icons.search_rounded, size: 24),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'add',
            onPressed: () => _openForm(),
            backgroundColor: const Color(0xFFF97316),
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
            child: const Icon(Icons.add_rounded, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _emptySearchState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 48, color: Color(0xFFD4D4D4)),
            const SizedBox(height: 16),
            const Text(
              'No staff match your search',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF525252),
              ),
            ),
          ],
        ),
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

  Widget _staffAvatar(StaffMember member) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: member.avatarColor,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        member.initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

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
          if (staff.imagePath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                File(staff.imagePath!),
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _staffAvatar(staff),
              ),
            )
          else
            _staffAvatar(staff),
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
