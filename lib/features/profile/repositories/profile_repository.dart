import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/app_user.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/file_upload_service.dart';
import '../models/profile.dart';

class ProfileRepository {
  ProfileRepository(this._ref);

  final Ref _ref;

  static const _keyStoreName = 'profile_storeName';
  static const _keyOwnerName = 'profile_ownerName';
  static const _keyPhone = 'profile_phone';
  static const _keyEmail = 'profile_email';
  static const _keyAddress = 'profile_address';
  static const _keyImagePath = 'profile_imagePath';
  static const _keyTin = 'profile_tin';
  static const _keyBin = 'profile_bin';

  Profile _buildFromSettings(AppUser? user) {
    final db = _ref.read(localDatabaseProvider);
    final settings = db.settings;
    final session = _ref.read(authStateProvider).value;

    return Profile(
      userId: user?.userId ?? AppConstants.demoShopId,
      storeName: (settings.get(_keyStoreName) as String?) ?? '',
      ownerName:
          (settings.get(_keyOwnerName) as String?) ?? user?.name ?? '',
      phone: (settings.get(_keyPhone) as String?) ?? user?.phone ?? '',
      email: (settings.get(_keyEmail) as String?) ?? session?.email ?? '',
      address: (settings.get(_keyAddress) as String?) ?? '',
      imagePath: settings.get(_keyImagePath) as String?,
      tin: (settings.get(_keyTin) as String?) ?? '',
      bin: (settings.get(_keyBin) as String?) ?? '',
    );
  }

  Future<Profile> getProfile() async {
    final user = _ref.read(currentUserProvider);
    return _buildFromSettings(user);
  }

  Future<void> saveProfile(Profile profile) async {
    final db = _ref.read(localDatabaseProvider);
    final settings = db.settings;

    final imagePath = await FileUploadService(db).uploadIfNeeded(profile.imagePath);
    if (_ref.read(authStateProvider).value != null &&
        profile.userId != 'local-owner') {
      await ApiClient(db).put('/api/v1/shops/me', {
        'imagePath': imagePath ?? '',
        'tin': profile.tin,
        'bin': profile.bin,
      });
    }
    await settings.put(_keyStoreName, profile.storeName);
    await settings.put(_keyOwnerName, profile.ownerName);
    await settings.put(_keyPhone, profile.phone);
    await settings.put(_keyEmail, profile.email);
    await settings.put(_keyAddress, profile.address);
    await settings.put(_keyTin, profile.tin);
    await settings.put(_keyBin, profile.bin);
    if (imagePath != null) {
      await settings.put(_keyImagePath, imagePath);
    } else {
      await settings.delete(_keyImagePath);
    }
  }
}
