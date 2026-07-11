import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/customer.dart';
import '../../../core/widgets/async_action_state.dart';
import '../providers/customer_providers.dart';

class CustomerProfileScreen extends ConsumerStatefulWidget {
  const CustomerProfileScreen({super.key, required this.customer});

  final Customer customer;

  @override
  ConsumerState<CustomerProfileScreen> createState() =>
      _CustomerProfileScreenState();
}

class _CustomerProfileScreenState
    extends ConsumerState<CustomerProfileScreen>
    with AsyncActionState<CustomerProfileScreen> {
  final _picker = ImagePicker();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  String? _imagePath;
  late Customer _customer;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
    _seedControllers(_customer);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _seedControllers(Customer customer) {
    _nameController.text = customer.name;
    _phoneController.text = customer.phone;
    _emailController.text = customer.email;
    _addressController.text = customer.address;
    _notesController.text = customer.notes;
    _imagePath = customer.imagePath;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return withLoadingOverlay(
      Scaffold(
        appBar: AppBar(
          title: const Text('Customer Profile'),
          actions: [
            if (_isEditing)
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Cancel',
                onPressed: () {
                  setState(() {
                    _isEditing = false;
                    _seedControllers(_customer);
                  });
                },
              )
            else
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit',
                onPressed: () => setState(() => _isEditing = true),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _ProfileHeader(
              customer: _customer,
              imagePath: _imagePath,
              isEditing: _isEditing,
              onTapImage: _isEditing ? _pickImage : null,
            ),
            const SizedBox(height: 6),
            _InfoRow(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: _customer.phone,
              visible: !_isEditing,
            ),
            if (_isEditing) ...[
              const SizedBox(height: 16),
              _SectionLabel(label: 'CONTACT INFORMATION'),
              const SizedBox(height: 10),
              _buildTextField(
                controller: _nameController,
                label: 'Full Name',
                icon: Icons.person_outline,
                required: true,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _phoneController,
                label: 'Phone',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                required: true,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _emailController,
                label: 'Email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _addressController,
                label: 'Address',
                icon: Icons.location_on_outlined,
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _notesController,
                label: 'Notes',
                icon: Icons.notes_rounded,
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: isBusy ? null : _saveCustomer,
                  icon: isBusy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(
                    isBusy ? 'Saving...' : 'Save Changes',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      label: 'Saving...',
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool required = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: colors.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              required ? '$label *' : label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: 'Enter $label',
          ),
        ),
      ],
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

  Future<void> _saveCustomer() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.isEmpty) {
      _showError('Name is required');
      return;
    }
    if (phone.isEmpty) {
      _showError('Phone is required');
      return;
    }

    await runBusyAction(() async {
      await ref.read(customerServiceProvider).save(
        customerId: _customer.customerId,
        name: name,
        phone: phone,
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        notes: _notesController.text.trim(),
        imagePath: _imagePath,
      );
      if (!mounted) return;
      setState(() {
        _customer = _customer.copyWith(
          name: name,
          phone: phone,
          email: _emailController.text.trim(),
          address: _addressController.text.trim(),
          notes: _notesController.text.trim(),
          imagePath: _imagePath,
        );
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Customer updated'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.customer,
    required this.imagePath,
    required this.isEditing,
    this.onTapImage,
  });

  final Customer customer;
  final String? imagePath;
  final bool isEditing;
  final VoidCallback? onTapImage;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        GestureDetector(
          onTap: onTapImage,
          child: Stack(
            children: [
              _AvatarWidget(name: customer.name, imagePath: imagePath),
              if (isEditing)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          customer.name,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          customer.phone,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _AvatarWidget extends StatelessWidget {
  const _AvatarWidget({required this.name, this.imagePath});

  final String name;
  final String? imagePath;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || name.trim().isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const size = 100.0;

    if (imagePath != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: colors.outlineVariant, width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size / 2),
          child: Image.file(
            File(imagePath!),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, stk) => _initialsAvatar(colors, size),
          ),
        ),
      );
    }

    return _initialsAvatar(colors, size);
  }

  Widget _initialsAvatar(ColorScheme colors, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: colors.outlineVariant, width: 2),
      ),
      child: Center(
        child: Text(
          _initials,
          style: TextStyle(
            color: colors.primary,
            fontSize: 32,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.visible = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: colors.onSurfaceVariant,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
