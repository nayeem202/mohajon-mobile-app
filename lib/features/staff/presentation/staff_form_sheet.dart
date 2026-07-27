import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/staff_constants.dart';
import '../models/staff_model.dart';

class StaffFormSheet extends StatefulWidget {
  const StaffFormSheet({super.key, this.staff});

  final StaffMember? staff;

  @override
  State<StaffFormSheet> createState() => _StaffFormSheetState();
}

class _StaffFormSheetState extends State<StaffFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _picker = ImagePicker();

  String? _imagePath;
  String _selectedRole = '';
  bool _active = true;

  bool get _isEditing => widget.staff != null;

  @override
  void initState() {
    super.initState();
    final s = widget.staff;
    if (s != null) {
      _nameCtrl.text = s.name;
      _phoneCtrl.text = s.phone;
      _emailCtrl.text = s.email;
      _usernameCtrl.text = s.username;
      _selectedRole = s.role;
      _active = s.active;
      _imagePath = s.imagePath;
    } else {
      _selectedRole = staffRoles.first;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  StaffMember _buildMember() {
    final now = DateTime.now();
    return StaffMember(
      id: _isEditing
          ? widget.staff!.id
          : 'staff-${now.millisecondsSinceEpoch}',
      name: _nameCtrl.text.trim(),
      role: _selectedRole,
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      username: _usernameCtrl.text.trim().toLowerCase(),
      password: _passwordCtrl.text.isNotEmpty
          ? _passwordCtrl.text
          : (_isEditing ? widget.staff!.password : ''),
      active: _active,
      createdAt: _isEditing
          ? widget.staff!.createdAt
          : now.toIso8601String().substring(0, 10),
      imagePath: _imagePath,
    );
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Profile Photo',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take a photo'),
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() => _imagePath = picked.path);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not pick image')),
        );
      }
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRole.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a role')),
      );
      return;
    }
    Navigator.of(context).pop(_buildMember());
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _imagePickerSection(),
                const SizedBox(height: 16),
                _header(),
                const SizedBox(height: 20),
                _InputField(
                  label: 'Full Name',
                  controller: _nameCtrl,
                  placeholder: 'e.g. Karim Uddin',
                  required: true,
                  validator: (v) =>
                      v?.trim().isEmpty == true ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),
                _roleSelector(),
                const SizedBox(height: 16),
                _InputField(
                  label: 'Phone Number',
                  controller: _phoneCtrl,
                  placeholder: 'e.g. 01712-345678',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                _InputField(
                  label: 'Email',
                  controller: _emailCtrl,
                  placeholder: 'e.g. karim@hishabbondhu.com',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final emailRegex =
                        RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                    if (!emailRegex.hasMatch(v.trim())) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _InputField(
                  label: 'Username',
                  controller: _usernameCtrl,
                  placeholder: 'e.g. karim.sales',
                  required: true,
                  onChanged: (v) {
                    final cleaned = v.toLowerCase().replaceAll(' ', '');
                    if (cleaned != v) {
                      _usernameCtrl.value = TextEditingValue(
                        text: cleaned,
                        selection: TextSelection.collapsed(offset: cleaned.length),
                      );
                    }
                  },
                  validator: (v) {
                    if (v?.trim().isEmpty == true) return 'Username is required';
                    if ((v?.trim().length ?? 0) < 4) {
                      return 'Username must be at least 4 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _InputField(
                  label: _isEditing
                      ? 'New Password (leave blank to keep current)'
                      : 'Password',
                  controller: _passwordCtrl,
                  placeholder: _isEditing
                      ? 'Leave blank to keep current'
                      : 'Minimum 6 characters',
                  obscure: true,
                  required: !_isEditing,
                  validator: (v) {
                    if (_isEditing) {
                      if (v != null && v.isNotEmpty && v.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    }
                    if (v?.trim().isEmpty == true) {
                      return 'Password is required';
                    }
                    if ((v?.length ?? 0) < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _activeToggle(),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF97316),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isEditing
                              ? Icons.save_rounded
                              : Icons.person_add_rounded,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(_isEditing
                            ? 'Save Changes'
                            : 'Add Staff Member'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _imagePickerSection() {
    const size = 80.0;
    final initials = widget.staff?.initials ?? '?';
    return Center(
      child: GestureDetector(
        onTap: _pickImage,
        child: Stack(
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF0ECE6),
                border: Border.all(color: const Color(0xFFE8DDD2), width: 2),
              ),
              child: _imagePath != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(size / 2),
                      child: Image.file(
                        File(_imagePath!),
                        width: size,
                        height: size,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _initialsCircle(size, initials),
                      ),
                    )
                  : _initialsCircle(size, initials),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Color(0xFFF97316),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _initialsCircle(double size, String initials) {
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          color: const Color(0xFF525252),
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Text(
          _isEditing ? 'Staff Member' : 'Add Staff Member',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1C1917),
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Color(0xFFF0ECE6),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF525252)),
          ),
        ),
      ],
    );
  }

  Widget _roleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Role', required: true),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: staffRoles.map((role) {
            final isSelected = role == _selectedRole;
            return GestureDetector(
              onTap: () => setState(() => _selectedRole = role),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color:
                      isSelected ? const Color(0xFFF97316) : const Color(0xFFF0ECE6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  role,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : const Color(0xFF525252),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _activeToggle() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Active',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1C1917),
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Staff can access the shop immediately',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF98A2B3),
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => setState(() => _active = !_active),
          child: Container(
            width: 40,
            height: 22,
            decoration: BoxDecoration(
              color: _active
                  ? const Color(0xFFF97316)
                  : const Color(0xFFD4D4D4),
              borderRadius: BorderRadius.circular(999),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              alignment:
                  _active ? Alignment.centerRight : Alignment.centerLeft,
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
    );
  }

  static Widget _fieldLabel(String text, {bool required = false}) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF525252),
          ),
        ),
        if (required)
          const Text(
            ' *',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFFEF5350),
            ),
          ),
      ],
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.label,
    required this.controller,
    required this.placeholder,
    this.required = false,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String placeholder;
  final bool required;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StaffFormSheetState._fieldLabel(label, required: required),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          onChanged: onChanged,
          validator: validator,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF1C1917),
          ),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: const TextStyle(
              fontSize: 13,
              color: Color(0xFFD4D4D4),
            ),
            filled: true,
            fillColor: const Color(0xFFFFF8F1),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE8DDD2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE8DDD2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFFFFC089), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDC2626)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
