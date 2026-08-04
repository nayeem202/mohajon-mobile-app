import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/models/shop_profile.dart';
import '../../../core/services/api_client.dart';

final shopProfileServiceProvider = Provider<ShopProfileService>(
  (ref) => ShopProfileService(ref),
);

final shopProfileProvider = StreamProvider<ShopProfile?>((ref) {
  final authSession = ref.watch(authStateProvider).value;
  if (authSession == null) {
    return Stream.value(null);
  }

  final api = ApiClient(ref.watch(localDatabaseProvider));
  return pollStream<ShopProfile?>(() async {
    try {
      final json = await api.get('/api/v1/shops/me');
      final profile = ShopProfile.fromJson(json);
      final shopId = ref.read(shopIdProvider);
      if (profile.shopId.isNotEmpty && profile.shopId != shopId) {
        return null;
      }
      if (profile.ownerUserId.isNotEmpty &&
          profile.ownerUserId != authSession.userId) {
        return null;
      }
      return profile;
    } on ApiException catch (error) {
      if (error.statusCode == 401) return null;
      rethrow;
    }
  }, const Duration(seconds: 10));
});

class ShopProfileService {
  ShopProfileService(this._ref);

  final Ref _ref;

  Future<void> updateProfile({
    required String shopName,
    required String location,
    required String phoneNumber,
  }) async {
    final authSession = _ref.read(authStateProvider).value;
    if (authSession == null) {
      throw StateError('Sign in before updating the shop profile.');
    }

    final trimmedShopName = shopName.trim();
    final trimmedLocation = location.trim();
    final trimmedPhoneNumber = phoneNumber.trim();
    if (trimmedShopName.isEmpty) {
      throw StateError('Shop name is required.');
    }
    if (trimmedLocation.isEmpty) {
      throw StateError('Location is required.');
    }
    if (trimmedPhoneNumber.isEmpty) {
      throw StateError('Phone number is required.');
    }

    final api = ApiClient(_ref.read(localDatabaseProvider));
    await api.put('/api/v1/shops/me', {
      'name': trimmedShopName,
      'location': trimmedLocation,
      'phoneNumber': trimmedPhoneNumber,
    });
  }
}
