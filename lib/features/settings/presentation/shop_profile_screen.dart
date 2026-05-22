import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/async_action_state.dart';
import '../providers/shop_profile_providers.dart';

class ShopProfileScreen extends ConsumerStatefulWidget {
  const ShopProfileScreen({super.key});

  @override
  ConsumerState<ShopProfileScreen> createState() => _ShopProfileScreenState();
}

class _ShopProfileScreenState extends ConsumerState<ShopProfileScreen>
    with AsyncActionState<ShopProfileScreen> {
  final _shopNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _profileInitialized = false;

  @override
  void dispose() {
    _shopNameController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shopProfile = ref.watch(shopProfileProvider);
    final profile = shopProfile.value;

    if (profile != null &&
        (!_profileInitialized || _shopNameController.text.isEmpty)) {
      _shopNameController.text = profile.shopName;
      _locationController.text = profile.location;
      _phoneController.text = profile.phoneNumber;
      _profileInitialized = true;
    }

    return withLoadingOverlay(
      Scaffold(
        appBar: AppBar(title: const Text('Shop Profile')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.store_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Edit shop details',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Saved to the current signed-in shop account.',
                    ),
                    const SizedBox(height: 16),
                    if (shopProfile.isLoading)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: LinearProgressIndicator(),
                      ),
                    if (shopProfile.hasError)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          shopProfile.error.toString(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    TextField(
                      controller: _shopNameController,
                      decoration: const InputDecoration(
                        labelText: 'Shop Name',
                        hintText: 'Enter shop name',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: 'Location',
                        hintText: 'Enter shop location',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        hintText: 'Enter shop phone number',
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: isBusy ? null : _saveProfile,
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Save Profile'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      label: 'Processing...',
    );
  }

  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();
    if (_shopNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shop name is required')),
      );
      return;
    }
    if (_locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location is required')),
      );
      return;
    }
    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number is required')),
      );
      return;
    }
    try {
      await runBusyAction(() async {
        await ref.read(shopProfileServiceProvider).updateProfile(
          shopName: _shopNameController.text,
          location: _locationController.text,
          phoneNumber: _phoneController.text,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shop profile updated')),
        );
        Navigator.of(context).pop();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }
}
