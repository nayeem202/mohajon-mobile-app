import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/app/app_bootstrap.dart';
import '../../../core/app/app_providers.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/syncable.dart';
import '../../../core/services/sync_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService(ref));

class AuthService {
  AuthService(this._ref);

  final Ref _ref;
  Future<void>? _googleSignInInit;

  Future<UserCredential> signInWithGoogle() async {
    if (!AppBootstrap.firebaseReady) {
      throw StateError('Firebase is not configured.');
    }

    final googleSignIn = GoogleSignIn.instance;
    _googleSignInInit ??= googleSignIn.initialize();
    await _googleSignInInit;

    final googleUser = await googleSignIn.authenticate();
    final googleAuth = googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) {
      throw StateError('Google sign-in did not return an ID token.');
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final userCredential = await FirebaseAuth.instance.signInWithCredential(
      credential,
    );
    await _upsertFirebaseUser();
    return userCredential;
  }

  Future<void> signOut() async {
    await _ref.read(localDatabaseProvider).clearBusinessData();
    await FirebaseAuth.instance.signOut();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Google Sign-In may not have been initialized in this app session.
    }
    _ref.read(currentUserProvider.notifier).state = null;
  }

  Future<void> sendOtp({
    required String phone,
    required void Function(String verificationId) onCodeSent,
    required void Function(String message) onError,
  }) async {
    if (!AppBootstrap.firebaseReady) {
      onError('Firebase is not configured. Add Firebase options to enable OTP.');
      return;
    }
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
        await _upsertFirebaseUser(phone: phone);
      },
      verificationFailed: (error) => onError(error.message ?? error.code),
      codeSent: (verificationId, _) => onCodeSent(verificationId),
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<void> verifyOtp({
    required String verificationId,
    required String smsCode,
    required String phone,
  }) async {
    final credential = PhoneAuthProvider.credential(verificationId: verificationId, smsCode: smsCode);
    await FirebaseAuth.instance.signInWithCredential(credential);
    await _upsertFirebaseUser(phone: phone);
  }

  Future<void> _upsertFirebaseUser({String phone = ''}) async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;
    final shopId = await _ensureRegistration(firebaseUser);
    final db = _ref.read(localDatabaseProvider);
    await db.setActiveAccount(userId: firebaseUser.uid, shopId: shopId);
    final appUser = AppUser(
      userId: firebaseUser.uid,
      name: firebaseUser.displayName ?? '',
      phone: firebaseUser.phoneNumber ?? phone,
      shopId: shopId,
      role: UserRole.owner,
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
    );
    await db.users.put(appUser);
    _ref.read(currentUserProvider.notifier).state = appUser;
    final syncService = SyncService(db);
    if (await syncService.isOnline) {
      await syncService.sync(shopId: shopId);
    }
  }

  Future<String> _ensureRegistration(User firebaseUser) async {
    final shopId = 'shop_${firebaseUser.uid}';
    final firestore = FirebaseFirestore.instance;
    final registrationRef = firestore.collection('registrations').doc(
          firebaseUser.uid,
        );
    final shopRef = firestore.collection('shops').doc(shopId);
    final phoneNumber = firebaseUser.phoneNumber ?? '';

    final now = FieldValue.serverTimestamp();
    await registrationRef.set({
      'userId': firebaseUser.uid,
      'shopId': shopId,
      'email': firebaseUser.email ?? '',
      'name': firebaseUser.displayName ?? '',
      'phoneNumber': phoneNumber,
      'photoUrl': firebaseUser.photoURL ?? '',
      'createdAt': now,
      'updatedAt': now,
    }, SetOptions(merge: true));

    final existingShop = await shopRef.get();
    final existingData = existingShop.data() ?? const <String, dynamic>{};
    final existingName = (existingData['name'] ?? '').toString().trim();
    final existingLocation = (existingData['location'] ?? '').toString().trim();
    final existingPhone = (existingData['phoneNumber'] ?? '')
        .toString()
        .trim();

    await shopRef.set({
      'shopId': shopId,
      'ownerUserId': firebaseUser.uid,
      'ownerEmail': firebaseUser.email ?? '',
      'name': existingName.isNotEmpty
          ? existingName
          : firebaseUser.displayName?.isNotEmpty == true
              ? firebaseUser.displayName
              : 'My Shop',
      'location': existingLocation,
      'phoneNumber': existingPhone.isNotEmpty
          ? existingPhone
          : phoneNumber,
      'createdAt': now,
      'updatedAt': now,
    }, SetOptions(merge: true));
    return shopId;
  }
}
