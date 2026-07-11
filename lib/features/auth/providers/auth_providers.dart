import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/app/app_bootstrap.dart';
import '../../../core/app/app_providers.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/syncable.dart';
import '../../../core/services/device_session_service.dart';
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
  final _deviceSessionService = DeviceSessionService();
  Future<void>? _googleSignInInit;

  Future<void> signUpWithEmail({
    required String shopName,
    required String ownerName,
    required String email,
    required String mobile,
    required String password,
  }) async {
    if (!AppBootstrap.firebaseReady) {
      throw const AuthMessageException(
        'Account creation is temporarily unavailable. Please contact support.',
      );
    }

    final normalizedEmail = email.trim().toLowerCase();
    final credential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(
          email: normalizedEmail,
          password: password,
        );
    final user = credential.user;
    if (user == null) {
      throw const AuthMessageException(
        'We could not create your account. Please try again.',
      );
    }

    await user.updateDisplayName(shopName.trim());
    await user.sendEmailVerification();
    await FirebaseFirestore.instance
        .collection('pending_registrations')
        .doc(user.uid)
        .set({
          'userId': user.uid,
          'shopName': shopName.trim(),
          'ownerName': ownerName.trim(),
          'email': normalizedEmail,
          'phoneNumber': mobile.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
    await FirebaseAuth.instance.signOut();
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (!AppBootstrap.firebaseReady) {
      throw const AuthMessageException(
        'Login is temporarily unavailable. Please contact support.',
      );
    }

    final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    final user = credential.user;
    await user?.reload();
    final refreshed = FirebaseAuth.instance.currentUser;
    if (refreshed == null) {
      throw const AuthMessageException(
        'We could not sign you in. Please try again.',
      );
    }
    if (!refreshed.emailVerified) {
      await refreshed.sendEmailVerification();
      await FirebaseAuth.instance.signOut();
      throw const AuthMessageException(
        'Please verify your email first. We sent a fresh verification email.',
      );
    }
    await _upsertFirebaseUser();
    await _recordLoginSession();
    return credential;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    if (!AppBootstrap.firebaseReady) {
      throw const AuthMessageException(
        'Password reset is temporarily unavailable. Please contact support.',
      );
    }
    await FirebaseAuth.instance.sendPasswordResetEmail(
      email: email.trim().toLowerCase(),
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email?.trim().toLowerCase();
    if (user == null || email == null || email.isEmpty) {
      throw const AuthMessageException('No email account is signed in.');
    }
    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  Future<void> setPasswordForGoogleAccount(String newPassword) async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email?.trim().toLowerCase();
    if (user == null || email == null || email.isEmpty) {
      throw const AuthMessageException('No email account is signed in.');
    }
    final credential = EmailAuthProvider.credential(
      email: email,
      password: newPassword,
    );
    try {
      await user.linkWithCredential(credential);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'provider-already-linked' ||
          error.code == 'credential-already-in-use') {
        throw const AuthMessageException(
          'Password login is already enabled for this email.',
        );
      }
      rethrow;
    }
  }

  Future<UserCredential> signInWithGoogle() async {
    if (!AppBootstrap.firebaseReady) {
      throw const AuthMessageException(
        'Gmail sign-in is not available right now. Please try again later.',
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
          'Gmail sign-in could not start. Please try again.',
        );
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        throw const AuthMessageException(
          'Gmail sign-in could not be completed. Please try again.',
        );
      }
      if ((firebaseUser.email ?? '').trim().isEmpty ||
          !firebaseUser.emailVerified) {
        await signOut();
        throw const AuthMessageException(
          'Please verify your Gmail account email before signing in.',
        );
      }
      await _upsertFirebaseUser();
      await _recordLoginSession();
      return userCredential;
    } on GoogleSignInException catch (error) {
      throw AuthMessageException(_googleSignInErrorMessage(error));
    } on FirebaseAuthException catch (error) {
      throw AuthMessageException(authErrorMessage(error));
    } on AuthMessageException {
      rethrow;
    } catch (_) {
      throw const AuthMessageException(
        'Gmail sign-in could not be completed. Please try again.',
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
      onError(
        'Phone OTP login is temporarily unavailable. Please contact support.',
      );
      return;
    }
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(minutes: 2),
      verificationCompleted: (credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
        await _upsertFirebaseUser(phone: phone);
        await _recordLoginSession();
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
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    await FirebaseAuth.instance.signInWithCredential(credential);
    await _upsertFirebaseUser(phone: phone);
    await _recordLoginSession();
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
    final registrationRef = firestore
        .collection('registrations')
        .doc(firebaseUser.uid);
    final shopRef = firestore.collection('shops').doc(shopId);
    final phoneNumber = firebaseUser.phoneNumber ?? '';
    final pending = await firestore
        .collection('pending_registrations')
        .doc(firebaseUser.uid)
        .get();
    final pendingData = pending.data() ?? const <String, dynamic>{};
    final pendingShopName = (pendingData['shopName'] ?? '').toString().trim();
    final pendingPhone = (pendingData['phoneNumber'] ?? '').toString().trim();

    final now = FieldValue.serverTimestamp();
    await registrationRef.set({
      'userId': firebaseUser.uid,
      'shopId': shopId,
      'email': firebaseUser.email ?? '',
      'name': firebaseUser.displayName ?? '',
      'phoneNumber': phoneNumber.isNotEmpty ? phoneNumber : pendingPhone,
      'photoUrl': firebaseUser.photoURL ?? '',
      'createdAt': now,
      'updatedAt': now,
    }, SetOptions(merge: true));

    final existingShop = await shopRef.get();
    final existingData = existingShop.data() ?? const <String, dynamic>{};
    final existingName = (existingData['name'] ?? '').toString().trim();
    final existingLocation = (existingData['location'] ?? '').toString().trim();
    final existingPhone = (existingData['phoneNumber'] ?? '').toString().trim();
    final hasOwners =
        existingData['owners'] is List &&
        (existingData['owners'] as List).isNotEmpty;

    final payload = <String, dynamic>{
      'shopId': shopId,
      'ownerUserId': firebaseUser.uid,
      'ownerEmail': firebaseUser.email ?? '',
      'name': existingName.isNotEmpty
          ? existingName
          : pendingShopName.isNotEmpty
          ? pendingShopName
          : firebaseUser.displayName?.isNotEmpty == true
          ? firebaseUser.displayName
          : 'My Shop',
      'location': existingLocation,
      'phoneNumber': existingPhone.isNotEmpty
          ? existingPhone
          : phoneNumber.isNotEmpty
          ? phoneNumber
          : pendingPhone,
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

  Future<void> _recordLoginSession() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;
    final session = await _deviceSessionService.currentSession();
    await FirebaseFirestore.instance
        .collection('users')
        .doc(firebaseUser.uid)
        .collection('login_sessions')
        .doc(session.sessionId)
        .set({
          ...session.toMap(),
          'userId': firebaseUser.uid,
          'email': firebaseUser.email ?? '',
          'updatedAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }
}

String authErrorMessage(Object error) {
  if (error is AuthMessageException) {
    return error.message;
  }
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-verification-code':
        return 'That OTP code is not correct. Check the code and try again.';
      case 'invalid-verification-id':
        return 'This OTP session has expired. Please request a new code.';
      case 'session-expired':
        return 'This OTP session has expired. Please request a new code.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes and try again.';
      case 'network-request-failed':
        return 'No internet connection. Check your connection and try again.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'account-exists-with-different-credential':
        return 'This email already uses another sign-in method. Try Gmail or password login.';
      case 'invalid-credential':
        return 'The email or password is incorrect. Please check and try again.';
      case 'operation-not-allowed':
        return 'This sign-in method is not available right now. Please contact support.';
      case 'email-already-in-use':
        return 'This email already has an account. Please sign in instead.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'weak-password':
        return 'Use a stronger password with at least 6 characters.';
      case 'wrong-password':
        return 'The password is incorrect. Please try again.';
      case 'user-not-found':
        return 'No account was found for this email. Create an account first.';
      case 'requires-recent-login':
        return 'Please sign in again, then update your password.';
      case 'invalid-phone-number':
        return 'Enter a valid phone number with country code, like +8801XXXXXXXXX.';
      case 'missing-phone-number':
        return 'Enter your phone number to receive an OTP.';
      case 'quota-exceeded':
        return 'OTP limit reached for now. Please try again later.';
      case 'popup-closed-by-user':
      case 'web-context-cancelled':
        return 'Sign-in was cancelled before it finished.';
      case 'web-network-request-failed':
        return 'No internet connection. Check your connection and try again.';
      default:
        return 'We could not complete sign-in. Please try again.';
    }
  }
  if (error is GoogleSignInException) {
    return _googleSignInErrorMessage(error);
  }
  if (error is StateError) {
    return 'Sign-in is not ready yet. Please close the screen and try again.';
  }
  return 'We could not complete sign-in. Please try again.';
}

String _googleSignInErrorMessage(GoogleSignInException error) {
  switch (error.code) {
    case GoogleSignInExceptionCode.canceled:
      return 'Gmail sign-in was cancelled.';
    case GoogleSignInExceptionCode.interrupted:
      return 'Gmail sign-in was interrupted. Please try again.';
    case GoogleSignInExceptionCode.clientConfigurationError:
    case GoogleSignInExceptionCode.providerConfigurationError:
      return 'Gmail sign-in is not available right now. Please contact support.';
    case GoogleSignInExceptionCode.uiUnavailable:
      return 'Gmail sign-in cannot open right now. Please try again.';
    case GoogleSignInExceptionCode.userMismatch:
      return 'Please complete sign-in with the same Gmail account.';
    case GoogleSignInExceptionCode.unknownError:
      return 'Gmail sign-in could not be completed. Please try again.';
  }
}
