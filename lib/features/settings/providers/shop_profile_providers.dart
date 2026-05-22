import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_bootstrap.dart';
import '../../../core/app/app_providers.dart';
import '../../../core/models/shop_profile.dart';
import '../../../core/services/firestore_paths.dart';

final shopProfileServiceProvider = Provider<ShopProfileService>(
  (ref) => ShopProfileService(ref),
);

final shopProfileProvider = StreamProvider<ShopProfile?>((ref) {
  final authUser = ref.watch(authStateProvider).value;
  if (!AppBootstrap.firebaseReady || authUser == null || authUser.isAnonymous) {
    return Stream.value(null);
  }

  final shopId = ref.watch(shopIdProvider);
  final shopDoc = FirestorePaths(FirebaseFirestore.instance, shopId).shopDoc;
  return shopDoc.snapshots().map((snapshot) {
    final data = snapshot.data();
    if (data == null) return null;
    return ShopProfile.fromJson(data);
  });
});

class ShopProfileService {
  ShopProfileService(this._ref);

  final Ref _ref;

  Future<void> updateProfile({
    required String shopName,
    required String location,
    required String phoneNumber,
  }) async {
    if (!AppBootstrap.firebaseReady) {
      throw StateError('Firebase is not configured.');
    }

    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null || authUser.isAnonymous) {
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

    final shopId = _ref.read(shopIdProvider);
    final shopDoc = FirestorePaths(FirebaseFirestore.instance, shopId).shopDoc;
    await shopDoc.set({
      'shopId': shopId,
      'ownerUserId': authUser.uid,
      'name': trimmedShopName,
      'location': trimmedLocation,
      'phoneNumber': trimmedPhoneNumber,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
