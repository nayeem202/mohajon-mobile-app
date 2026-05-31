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

class AuthMessageException implements Exception {
  const AuthMessageException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService {
  AuthService(this._ref);

  final Ref _ref;
  Future<void>? _googleSignInInit;

  Future<UserCredential> signInWithGoogle() async {
    if (!AppBootstrap.firebaseReady) {
      throw const AuthMessageException(
        'Google sign-in is not available right now. Please try again later.',
      );
    }

    try {
      final googleSignIn = GoogleSignIn.instance;
      _googleSignInInit ??= googleSignIn.initialize();
      await _googleSignInInit;
      try {
        await googleSignIn.disconnect();
      } catch (_) {
        // Ignore when there is no active Google session to disconnect.
      }

      final googleUser = await googleSignIn.authenticate();
      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        throw const AuthMessageException(
          'Google sign-in failed. Please try again.',
        );
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        throw const AuthMessageException(
          'Google sign-in failed. Please try again.',
        );
      }
      if ((firebaseUser.email ?? '').trim().isEmpty || !firebaseUser.emailVerified) {
        await signOut();
        throw const AuthMessageException(
          'Please verify your Google account email before signing in.',
        );
      }
      await _upsertFirebaseUser();
      return userCredential;
    } on GoogleSignInException catch (error) {
      throw AuthMessageException(_googleSignInErrorMessage(error));
    } on FirebaseAuthException catch (error) {
      throw AuthMessageException(authErrorMessage(error));
    } on AuthMessageException {
      rethrow;
    } catch (_) {
      throw const AuthMessageException(
        'Google sign-in failed. Please try again.',
      );
    }
  }

  Future<void> signOut() async {
    await _ref.read(localDatabaseProvider).clearBusinessData();
    await FirebaseAuth.instance.signOut();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Google Sign-In may not have been initialized in this app session.
    }
    try {
      await GoogleSignIn.instance.disconnect();
    } catch (_) {
      // Ignore if there is no Google session to revoke.
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
      verificationFailed: (error) => onError(authErrorMessage(error)),
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
    final hasOwners = existingData['owners'] is List &&
        (existingData['owners'] as List).isNotEmpty;

    final payload = <String, dynamic>{
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
    };

    if (!hasOwners) {
      payload.addAll({
        'owners': [
          {
            'ownerId': firebaseUser.uid,
            'name': firebaseUser.displayName?.trim().isNotEmpty == true
                ? firebaseUser.displayName!.trim()
                : 'Owner',
            'investmentAmount': 0,
          },
        ],
        'ownerCount': 1,
        'totalInvestment': 0,
      });
    }

    await shopRef.set(payload, SetOptions(merge: true));
    return shopId;
  }
}

String authErrorMessage(Object error) {
  if (error is AuthMessageException) {
    return error.message;
  }
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-verification-code':
        return 'The OTP code is invalid. Please try again.';
      case 'invalid-verification-id':
        return 'This OTP session has expired. Please request a new code.';
      case 'session-expired':
        return 'This OTP session has expired. Please request a new code.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'account-exists-with-different-credential':
        return 'This email is already linked to another sign-in method.';
      case 'invalid-credential':
        return 'The sign-in credentials are invalid. Please try again.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled for the app.';
      default:
        return error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'Authentication failed. Please try again.';
    }
  }
  if (error is GoogleSignInException) {
    return _googleSignInErrorMessage(error);
  }
  if (error is StateError) {
    return error.toString().replaceFirst('Bad state: ', '').trim();
  }
  return 'Authentication failed. Please try again.';
}

String _googleSignInErrorMessage(GoogleSignInException error) {
  switch (error.code) {
    case GoogleSignInExceptionCode.canceled:
      return 'Google sign-in was canceled.';
    case GoogleSignInExceptionCode.interrupted:
      return 'Google sign-in was interrupted. Please try again.';
    case GoogleSignInExceptionCode.clientConfigurationError:
    case GoogleSignInExceptionCode.providerConfigurationError:
      return 'Google sign-in is not configured correctly for this app.';
    case GoogleSignInExceptionCode.uiUnavailable:
      return 'Google sign-in cannot open right now. Please try again.';
    case GoogleSignInExceptionCode.userMismatch:
      return 'Please complete sign-in with the same Google account.';
    case GoogleSignInExceptionCode.unknownError:
      return error.description?.trim().isNotEmpty == true
          ? error.description!.trim()
          : 'Google sign-in failed. Please try again.';
  }
}
