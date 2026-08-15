import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/widgets/action_button.dart';
import '../../../core/widgets/async_action_state.dart';
import '../models/investor.dart';
import '../providers/investor_providers.dart';

class InvestorFormSheet extends ConsumerStatefulWidget {
  const InvestorFormSheet({super.key, this.investor});

  final Investor? investor;

  @override
  ConsumerState<InvestorFormSheet> createState() => _InvestorFormSheetState();
}

class _InvestorFormSheetState extends ConsumerState<InvestorFormSheet>
    with AsyncActionState<InvestorFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _picker = ImagePicker();
  File? _photo;

  bool get isEditing => widget.investor != null;

  @override
  void initState() {
    super.initState();
    final investor = widget.investor;
    _nameCtrl.text = investor?.name ?? '';
    _phoneCtrl.text = investor?.phone ?? '';
    _emailCtrl.text = investor?.email ?? '';
    _addressCtrl.text = investor?.address ?? '';
    _notesCtrl.text = investor?.notes ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final investor = widget.investor;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              shrinkWrap: true,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD0D5DD),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(Icons.person_rounded, color: colors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isEditing ? 'Update Investor' : 'Add Investor',
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF101828),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: isBusy ? null : _pickImage,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFF97316).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: colors.primary.withValues(alpha: 0.12),
                          backgroundImage: _photo != null
                              ? FileImage(_photo!)
                              : (investor?.photoUrl.isNotEmpty == true
                                    ? NetworkImage(investor!.photoUrl)
                                    : null) as ImageProvider?,
                          child: _photo == null &&
                                  (investor?.photoUrl.isNotEmpty != true)
                              ? Icon(Icons.person_rounded,
                                  size: 30, color: colors.primary)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Investor photo',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF101828))),
                              SizedBox(height: 4),
                              Text('Tap to upload from gallery',
                                  style: TextStyle(
                                      fontSize: 12, color: Color(0xFF667085))),
                            ],
                          ),
                        ),
                        Icon(Icons.camera_alt_outlined, color: colors.primary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _field(_nameCtrl, 'Full name', Icons.badge_outlined,
                    required: true),
                _field(_phoneCtrl, 'Phone number', Icons.phone_outlined,
                    type: TextInputType.phone),
                _field(_emailCtrl, 'Email address', Icons.email_outlined,
                    type: TextInputType.emailAddress),
                _field(_addressCtrl, 'Address', Icons.location_on_outlined,
                    maxLines: 2),
                _field(_notesCtrl, 'Notes', Icons.notes_rounded, maxLines: 3),
                const SizedBox(height: 8),
                ActionButton(
                  onPressed: _save,
                  isBusy: isBusy,
                  icon: isEditing ? Icons.save_rounded : Icons.person_add_rounded,
                  label: isEditing ? 'Update Investor' : 'Save Investor',
                  busyLabel: isEditing ? 'Updating...' : 'Saving...',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool required = false,
    TextInputType? type,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        maxLines: maxLines,
        validator: required
            ? (value) => value == null || value.trim().isEmpty
                ? 'Please enter $label'
                : null
            : null,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          prefixIcon: Icon(icon, size: 20),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1200,
    );
    if (picked != null) setState(() => _photo = File(picked.path));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await runBusyAction(() async {
        final service = ref.read(investorServiceProvider);
        if (isEditing) {
          await service.update(
            id: widget.investor!.id,
            name: _nameCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            address: _addressCtrl.text.trim(),
            notes: _notesCtrl.text.trim(),
            photoUrl: widget.investor!.photoUrl,
            photoFile: _photo,
          );
        } else {
          await service.save(
            name: _nameCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            address: _addressCtrl.text.trim(),
            notes: _notesCtrl.text.trim(),
            photoFile: _photo,
          );
        }
      });
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save investor: $error')));
      }
    }
  }
}
