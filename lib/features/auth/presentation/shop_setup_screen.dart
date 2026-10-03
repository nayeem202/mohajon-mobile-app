import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/constants/shop_category_templates.dart';
import '../../../core/services/api_client.dart';
import '../../../core/theme/mohajon_warm_theme.dart';

class ShopSetupScreen extends ConsumerStatefulWidget {
  const ShopSetupScreen({super.key, required this.onCompleted});

  final VoidCallback onCompleted;

  @override
  ConsumerState<ShopSetupScreen> createState() => _ShopSetupScreenState();
}

class _ShopSetupScreenState extends ConsumerState<ShopSetupScreen> {
  late final TextEditingController _shopName;
  late final TextEditingController _mobile;
  String _businessType = 'general';
  bool _saving = false;
  String? _error;

  bool get _isBangla => ref.watch(localeProvider).languageCode == 'bn';

  @override
  void initState() {
    super.initState();
    final settings = ref.read(localDatabaseProvider).settings;
    final session = ref.read(authStateProvider).value;
    _shopName = TextEditingController(
      text: (settings.get('profile_storeName') as String?) ?? '',
    );
    _mobile = TextEditingController(
      text: ((settings.get('profile_phone') as String?) ?? '').isNotEmpty
          ? settings.get('profile_phone') as String
          : (session?.phone ?? ''),
    );
  }

  @override
  void dispose() {
    _shopName.dispose();
    _mobile.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final templates = ShopCategoryTemplates.all;
    return Theme(
      data: MohajonWarm.theme(Theme.of(context)),
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: MohajonWarm.pageGradient),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
              children: [
                const Icon(Icons.storefront_rounded, size: 54, color: MohajonWarm.goldText),
                const SizedBox(height: 16),
                Text(
                  _isBangla ? 'আপনার ব্যবসা সেটআপ করুন' : 'Set up your business',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  _isBangla
                      ? 'আপনার জন্য সঠিক ক্যাটাগরি ও ফিচার সাজাতে এই তথ্যগুলো দিন।'
                      : 'Tell us a few details so we can personalize your categories and tools.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700, height: 1.45),
                ),
                const SizedBox(height: 26),
                TextField(
                  controller: _shopName,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: _isBangla ? 'দোকানের নাম' : 'Shop name',
                    hintText: _isBangla ? 'যেমন: বন্ধুর স্টোর' : 'e.g. Bondhu Stores',
                    prefixIcon: const Icon(Icons.store_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _mobile,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: _isBangla ? 'মোবাইল নম্বর' : 'Mobile number',
                    hintText: '+8801XXXXXXXXX',
                    prefixIcon: const Icon(Icons.phone_iphone_rounded),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  _isBangla ? 'আপনার ব্যবসার ধরন' : 'Your business type',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const SizedBox(height: 10),
                for (final template in templates)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _TypeTile(
                      template: template,
                      selected: template.id == _businessType,
                      bangla: _isBangla,
                      onTap: () => setState(() => _businessType = template.id),
                    ),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 6),
                  Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.arrow_forward_rounded),
                  label: Text(_isBangla ? 'সেটআপ সম্পন্ন করুন' : 'Continue to Mohajon'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final shopName = _shopName.text.trim();
    final mobile = _mobile.text.trim();
    if (shopName.isEmpty || mobile.isEmpty) {
      setState(() => _error = _isBangla ? 'দোকানের নাম ও মোবাইল নম্বর দিন।' : 'Shop name and mobile number are required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final db = ref.read(localDatabaseProvider);
    await Future.wait([
      db.settings.put('profile_storeName', shopName),
      db.settings.put('profile_phone', mobile),
      db.settings.put('profile_businessType', _businessType),
      db.settings.put('profile_setupComplete', true),
    ]);
    try {
      await ApiClient(db).put('/api/v1/shops/me', {
        'name': shopName,
        'phoneNumber': mobile,
        'businessType': _businessType,
      });
    } catch (_) {
      // Local setup remains authoritative for offline-first startup. The
      // profile can be retried from settings when the service is reachable.
    }
    if (!mounted) return;
    widget.onCompleted();
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({required this.template, required this.selected, required this.bangla, required this.onTap});

  final ShopCategoryTemplate template;
  final bool selected;
  final bool bangla;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? MohajonWarm.tintYellow : Colors.white.withValues(alpha: .82),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? MohajonWarm.goldText : Colors.black12, width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? MohajonWarm.goldText : Colors.grey),
            const SizedBox(width: 10),
            Expanded(child: Text(bangla ? template.nameBn : template.nameEn, style: const TextStyle(fontWeight: FontWeight.w800))),
            Text('${template.categories.length}', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
