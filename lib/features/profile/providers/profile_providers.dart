import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/shop_profile.dart';
import '../../auth/providers/auth_providers.dart';
import '../../settings/providers/shop_profile_providers.dart';
import '../models/profile.dart';
import '../repositories/profile_repository.dart';

final profileVersionProvider = StateProvider<int>((ref) => 0);

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref);
});

final profileProvider = Provider<Profile?>((ref) {
  ref.watch(profileVersionProvider);

  final db = ref.watch(localDatabaseProvider);
  final settings = db.settings;

  final user = ref.watch(currentUserProvider);
  final shopProfile = ref.watch(shopProfileProvider).value;
  final authUser = ref.watch(authStateProvider).value;

  if (user == null) return null;

  return Profile(
    userId: user.userId,
    storeName: shopProfile?.shopName ?? '',
    ownerName: shopProfile == null
        ? _deriveOwnerName(user, shopProfile)
        : (shopProfile.effectiveOwners.first.name.isNotEmpty
            ? shopProfile.effectiveOwners.first.name
            : 'Store Owner'),
    phone:
        shopProfile?.phoneNumber ?? user.phone,
    email: shopProfile?.ownerEmail.isNotEmpty == true
        ? shopProfile!.ownerEmail
        : (authUser?.email ?? ''),
    address: shopProfile?.location ?? '',
    imagePath: settings.get('profile_imagePath') as String?,
  );
});

final profileLoadingProvider = Provider<bool>((ref) {
  final shopProfile = ref.watch(shopProfileProvider);
  return shopProfile.isLoading;
});

final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService(ref);
});

final profileErrorProvider = Provider<String?>((ref) {
  final shopProfile = ref.watch(shopProfileProvider);
  if (shopProfile.hasError) return shopProfile.error.toString();
  return null;
});

String _resolveUserId(Ref ref) {
  final user = ref.read(currentUserProvider);
  return user?.userId ?? 'local-user';
}

String _deriveOwnerName(AppUser user, ShopProfile? shopProfile) {
  if (user.name.isNotEmpty) return user.name;
  if (shopProfile != null && shopProfile.effectiveOwners.isNotEmpty) {
    return shopProfile.effectiveOwners.first.name;
  }
  return 'Store Owner';
}

class ProfileService {
  ProfileService(this._ref);

  final Ref _ref;

  Future<Profile> getProfile() async {
    return _ref.read(profileRepositoryProvider).getProfile();
  }

  Future<void> updateProfile(Profile profile) async {
    await _ref.read(profileRepositoryProvider).saveProfile(profile);
    _ref.read(profileVersionProvider.notifier).state++;
  }

  Future<void> logout() async {
    await _ref.read(authServiceProvider).signOut();
  }
}
