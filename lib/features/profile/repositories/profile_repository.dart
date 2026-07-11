import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/app_user.dart';
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

  Profile _buildFromSettings(AppUser? user) {
    final db = _ref.read(localDatabaseProvider);
    final settings = db.settings;

    return Profile(
      userId: user?.userId ?? AppConstants.demoShopId,
      storeName: (settings.get(_keyStoreName) as String?) ?? '',
      ownerName:
          (settings.get(_keyOwnerName) as String?) ?? user?.name ?? '',
      phone: (settings.get(_keyPhone) as String?) ?? user?.phone ?? '',
      email: (settings.get(_keyEmail) as String?) ??
          FirebaseAuth.instance.currentUser?.email ??
          '',
      address: (settings.get(_keyAddress) as String?) ?? '',
      imagePath: settings.get(_keyImagePath) as String?,
    );
  }

  Future<Profile> getProfile() async {
    final user = _ref.read(currentUserProvider);
    return _buildFromSettings(user);
  }

  Future<void> saveProfile(Profile profile) async {
    final db = _ref.read(localDatabaseProvider);
    final settings = db.settings;

    await settings.put(_keyStoreName, profile.storeName);
    await settings.put(_keyOwnerName, profile.ownerName);
    await settings.put(_keyPhone, profile.phone);
    await settings.put(_keyEmail, profile.email);
    await settings.put(_keyAddress, profile.address);
    if (profile.imagePath != null) {
      await settings.put(_keyImagePath, profile.imagePath);
    } else {
      await settings.delete(_keyImagePath);
    }
  }
}
