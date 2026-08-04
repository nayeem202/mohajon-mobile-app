import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/staff_model.dart';
import '../models/staff_role.dart';
import '../providers/staff_providers.dart';
import '../services/staff_api_service.dart';

/// Full-screen staff creation/editing form. Roles and menu access lists are
/// fetched from the Java service (configurable from the DB), and the shop
/// owner picks the role plus which menus the staff member can access.
class StaffFormScreen extends ConsumerStatefulWidget {
  const StaffFormScreen({super.key, this.staff});

  final StaffMember? staff;

  @override
  ConsumerState<StaffFormScreen> createState() => _StaffFormScreenState();
}

class _StaffFormScreenState extends ConsumerState<StaffFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  String _selectedRole = '';
  final Set<String> _selectedMenus = {};
  bool _saving = false;

  bool get _isEditing => widget.staff != null;

  @override
  void initState() {
    super.initState();
    final s = widget.staff;
    if (s != null) {
      _nameCtrl.text = s.name;
      _phoneCtrl.text = s.phone;
      _emailCtrl.text = s.email;
      _selectedRole = s.role;
      _selectedMenus.addAll(s.menuCodes);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFDC2626) : null,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRole.isEmpty) {
      _showToast('Please select a role', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final api = ref.read(staffApiServiceProvider);
      if (_isEditing) {
        await api.updateStaff(
          userId: widget.staff!.id,
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          role: _selectedRole,
          menuCodes: _selectedMenus.toList(),
        );
      } else {
        await api.createStaff(
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          role: _selectedRole,
          menuCodes: _selectedMenus.toList(),
        );
      }
      ref.invalidate(staffListProvider);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showToast(
        error is StaffApiException
            ? error.message
            : 'Could not save staff member. Please try again.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rolesAsync = ref.watch(staffRolesProvider);
    final menusAsync = ref.watch(staffMenusProvider);

    final roles = rolesAsync.value ?? const <StaffRole>[];
    final menus = menusAsync.value ?? const <AppMenu>[];
    if (_selectedRole.isEmpty && roles.isNotEmpty) {
      _selectedRole = roles.first.code;
    }
    final loading = rolesAsync.isLoading || menusAsync.isLoading;
    final error =
        rolesAsync.hasError || menusAsync.hasError;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F1),
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(_isEditing ? 'Edit Staff Member' : 'Add Staff Member'),
        actions: [
          if (_isEditing)
            TextButton(
              onPressed: _saving ? null : _submit,
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFF97316)),
              child: const Text('Save'),
            ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error
              ? _errorState()
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    children: [
                      _InputField(
                        label: 'Full Name',
                        controller: _nameCtrl,
                        placeholder: 'e.g. Karim Uddin',
                        required: true,
                        validator: (v) =>
                            v?.trim().isEmpty == true ? 'Name is required' : null,
                      ),
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
                        enabled: !_isEditing,
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
                      if (!_isEditing) ...[
                        const SizedBox(height: 16),
                        _InputField(
                          label: 'Password',
                          controller: _passwordCtrl,
                          placeholder: 'Minimum 6 characters',
                          obscure: true,
                          required: true,
                          validator: (v) {
                            if (v?.trim().isEmpty == true) {
                              return 'Password is required';
                            }
                            if ((v?.length ?? 0) < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 24),
                      _roleSection(roles),
                      const SizedBox(height: 24),
                      _menuSection(menus),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _saving ? null : _submit,
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
                          child: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
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
                                        : 'Create Staff Member'),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: Color(0xFFD4D4D4),
            ),
            const SizedBox(height: 16),
            const Text(
              'Could not load roles and menus.\nPlease check your connection.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF525252),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                ref.invalidate(staffRolesProvider);
                ref.invalidate(staffMenusProvider);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleSection(List<StaffRole> roles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Role', required: true),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: roles.map((role) {
            final isSelected = role.code == _selectedRole;
            return GestureDetector(
              onTap: () => setState(() => _selectedRole = role.code),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFF97316)
                      : const Color(0xFFF0ECE6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  role.name,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : const Color(0xFF525252),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _menuSection(List<AppMenu> menus) {
    final sections = <String, List<AppMenu>>{};
    for (final menu in menus) {
      sections.putIfAbsent(menu.section, () => []).add(menu);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Menu Access'),
        const SizedBox(height: 4),
        const Text(
          'Select which menus this staff member can see after login.',
          style: TextStyle(fontSize: 12, color: Color(0xFF98A2B3)),
        ),
        const SizedBox(height: 8),
        for (final entry in sections.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Text(
              _sectionLabel(entry.key),
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: Color(0xFFF97316),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF0ECE6)),
            ),
            child: Column(
              children: [
                for (var i = 0; i < entry.value.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: Color(0xFFF0EAE2),
                    ),
                  _MenuCheckboxTile(
                    menu: entry.value[i],
                    checked: _selectedMenus.contains(entry.value[i].code),
                    onChanged: (checked) {
                      setState(() {
                        if (checked) {
                          _selectedMenus.add(entry.value[i].code);
                        } else {
                          _selectedMenus.remove(entry.value[i].code);
                        }
                      });
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _sectionTitle(String text, {bool required = false}) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1C1917),
          ),
        ),
        if (required)
          const Text(
            ' *',
            style: TextStyle(fontSize: 13, color: Color(0xFFEF5350)),
          ),
      ],
    );
  }

  String _sectionLabel(String section) {
    return switch (section) {
      'MAIN' => 'Main Menu',
      'OPERATIONS' => 'Operations',
      'FINANCE' => 'Finance',
      'APP' => 'App',
      _ => section,
    };
  }
}

class _MenuCheckboxTile extends StatelessWidget {
  const _MenuCheckboxTile({
    required this.menu,
    required this.checked,
    required this.onChanged,
  });

  final AppMenu menu;
  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!checked),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              checked
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: 22,
              color: checked
                  ? const Color(0xFFF97316)
                  : const Color(0xFFD4D4D4),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                menu.name,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1C1917),
                ),
              ),
            ),
          ],
        ),
      ),
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
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final String placeholder;
  final bool required;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF525252),
              ),
            ),
            if (required)
              const Text(
                ' *',
                style: TextStyle(fontSize: 12, color: Color(0xFFEF5350)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          enabled: enabled,
          validator: validator,
          style: const TextStyle(fontSize: 13, color: Color(0xFF1C1917)),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle:
                const TextStyle(fontSize: 13, color: Color(0xFFD4D4D4)),
            filled: true,
            fillColor: enabled
                ? const Color(0xFFFFF8F1)
                : const Color(0xFFF5F1EA),
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
