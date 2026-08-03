import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../app/app_bootstrap.dart';
import 'auth_backend.dart';

/// AuthBackend backed by Firebase Auth. Kept so the app can run in the
/// legacy mode while the custom auth service takes over.
class FirebaseAuthBackend implements AuthBackend {
  FirebaseAuthBackend(this._ref);

  final Ref _ref;

  @override
  bool get isReady => AppBootstrap.firebaseReady;

  @override
  Future<AuthSession?> currentSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return null;
    return _sessionFromUser(user);
  }

  @override
  Stream<AuthSession?> get sessionChanges {
    return FirebaseAuth.instance.authStateChanges().asyncMap((user) async {
      if (user == null || user.isAnonymous) return null;
      return _sessionFromUser(user);
    });
  }

  AuthSession _sessionFromUser(User user) => AuthSession(
    userId: user.uid,
    email: user.email ?? '',
    displayName: user.displayName ?? '',
    phone: user.phoneNumber ?? '',
    photoUrl: user.photoURL ?? '',
    emailVerified: user.emailVerified,
    isNewUser: false,
    provider: _providerFor(user),
  );

  String _providerFor(User user) {
    final ids = user.providerData
        .map((p) => p.providerId)
        .toSet();
    if (ids.contains(GoogleAuthProvider.PROVIDER_ID) ||
        ids.contains('google.com')) {
      return 'google';
    }
    return 'local';
  }

  @override
  Future<AuthSession> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
    Map<String, String> metadata = const {},
  }) async {
    if (!isReady) {
      throw const AuthException(
        'Account creation is temporarily unavailable. Please contact support.',
      );
    }
    final credential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(
          email: email.trim().toLowerCase(),
          password: password,
        );
    final user = credential.user;
    if (user == null) {
      throw const AuthException(
        'We could not create your account. Please try again.',
      );
    }
    await user.updateDisplayName(name.trim());
    await user.sendEmailVerification();
    await FirebaseFirestore.instance
        .collection('pending_registrations')
        .doc(user.uid)
        .set({
          'userId': user.uid,
          'shopName': metadata['shopName'] ?? '',
          'ownerName': name.trim(),
          'email': email.trim().toLowerCase(),
          'phoneNumber': phone.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
    await FirebaseAuth.instance.signOut();
    return _sessionFromUser(user);
  }

  @override
  Future<void> sendEmailVerificationCode(String email) async {
    // Firebase sends the verification email automatically at sign-up and
    // re-sends it when sign-in is attempted with an unverified account.
  }

  @override
  Future<void> verifyEmail({required String email, required String code}) async {
    throw const AuthException(
      'Email verification code is not used with Firebase accounts.',
    );
  }

  @override
  Future<AuthSession> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (!isReady) {
      throw const AuthException(
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
      throw const AuthException('We could not sign you in. Please try again.');
    }
    if (!refreshed.emailVerified) {
      await refreshed.sendEmailVerification();
      await FirebaseAuth.instance.signOut();
      throw const AuthException(
        'Please verify your email first. We sent a fresh verification email.',
        code: 'VERIFICATION_REQUIRED',
      );
    }
    return _sessionFromUser(refreshed);
  }

  @override
  Future<AuthSession> signInWithGoogle() async {
    if (!isReady) {
      throw const AuthException(
        'Gmail sign-in is not available right now. Please try again later.',
      );
    }
    try {
      final googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize();
      try {
        await googleSignIn.disconnect();
      } catch (_) {
        // No active Google session.
      }
      final googleUser = await googleSignIn.authenticate();
      final idToken = googleUser.authentication.idToken;
      if (idToken == null) {
        throw const AuthException(
          'Gmail sign-in could not start. Please try again.',
        );
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final user = userCredential.user;
      if (user == null) {
        throw const AuthException(
          'Gmail sign-in could not be completed. Please try again.',
        );
      }
      if ((user.email ?? '').trim().isEmpty || !user.emailVerified) {
        await FirebaseAuth.instance.signOut();
        throw const AuthException(
          'Please verify your Gmail account email before signing in.',
        );
      }
      return _sessionFromUser(user);
    } on AuthException {
      rethrow;
    } catch (error) {
      if (error is FirebaseAuthException) {
        throw AuthException(
          firebaseErrorMessage(error),
          code: error.code,
        );
      }
      if (error is GoogleSignInException) {
        throw AuthException(googleSignInErrorMessage(error));
      }
      throw const AuthException(
        'Gmail sign-in could not be completed. Please try again.',
      );
    }
  }

  @override
  Future<void> sendOtp({
    required String phone,
    required void Function(String verificationId) onCodeSent,
    required void Function(String message) onError,
  }) async {
    if (!isReady) {
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
      },
      verificationFailed: (error) => onError(firebaseErrorMessage(error)),
      codeSent: (verificationId, _) => onCodeSent(verificationId),
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  @override
  Future<AuthSession> verifyOtp({
    required String verificationId,
    required String smsCode,
    required String phone,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final result = await FirebaseAuth.instance.signInWithCredential(credential);
    final user = result.user;
    if (user == null) {
      throw const AuthException('We could not sign you in. Please try again.');
    }
    return _sessionFromUser(user);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    if (!isReady) {
      throw const AuthException(
        'Password reset is temporarily unavailable. Please contact support.',
      );
    }
    await FirebaseAuth.instance.sendPasswordResetEmail(
      email: email.trim().toLowerCase(),
    );
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email?.trim().toLowerCase();
    if (user == null || email == null || email.isEmpty) {
      throw const AuthException('No email account is signed in.');
    }
    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  @override
  Future<void> setPasswordForGoogleAccount(String newPassword) async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email?.trim().toLowerCase();
    if (user == null || email == null || email.isEmpty) {
      throw const AuthException('No email account is signed in.');
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
        throw const AuthException(
          'Password login is already enabled for this email.',
        );
      }
      rethrow;
    }
  }

  @override
  Future<String> resolveShopId(AuthSession session) async {
    final firestore = FirebaseFirestore.instance;
    final shopId = 'shop_${session.userId}';
    final registrationRef = firestore
        .collection('registrations')
        .doc(session.userId);
    final shopRef = firestore.collection('shops').doc(shopId);
    final pending = await firestore
        .collection('pending_registrations')
        .doc(session.userId)
        .get();
    final pendingData = pending.data() ?? const <String, dynamic>{};
    final pendingShopName = (pendingData['shopName'] ?? '').toString().trim();
    final pendingPhone = (pendingData['phoneNumber'] ?? '').toString().trim();

    final now = FieldValue.serverTimestamp();
    await registrationRef.set({
      'userId': session.userId,
      'shopId': shopId,
      'email': session.email,
      'name': session.displayName,
      'phoneNumber': session.phone.isNotEmpty ? session.phone : pendingPhone,
      'photoUrl': session.photoUrl,
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
      'ownerUserId': session.userId,
      'ownerEmail': session.email,
      'name': existingName.isNotEmpty
          ? existingName
          : pendingShopName.isNotEmpty
          ? pendingShopName
          : session.displayName.isNotEmpty
          ? session.displayName
          : 'My Shop',
      'location': existingLocation,
      'phoneNumber': existingPhone.isNotEmpty
          ? existingPhone
          : session.phone.isNotEmpty
          ? session.phone
          : pendingPhone,
      'createdAt': now,
      'updatedAt': now,
    };

    if (!hasOwners) {
      payload.addAll({
        'owners': [
          {
            'ownerId': session.userId,
            'name': session.displayName.trim().isNotEmpty
                ? session.displayName.trim()
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

  @override
  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Google Sign-In may not have been initialized in this session.
    }
    try {
      await GoogleSignIn.instance.disconnect();
    } catch (_) {
      // Ignore if there is no Google session to revoke.
    }
  }
}

String firebaseErrorMessage(Object error) {
  if (error is AuthException) return error.message;
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
  return 'We could not complete sign-in. Please try again.';
}

String googleSignInErrorMessage(GoogleSignInException error) {
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
