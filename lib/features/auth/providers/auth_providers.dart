import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/syncable.dart';
import '../../../core/services/auth_backend.dart';
import '../../../core/services/custom_auth_backend.dart';
import '../../../core/services/device_session_service.dart';
import '../../../core/services/firebase_auth_backend.dart';
import '../../../core/services/sync_service.dart';

/// The active auth backend, chosen by [AppConfig.useCustomAuth].
final authBackendProvider = Provider<AuthBackend>((ref) {
  return AppConfig.useCustomAuth
      ? CustomAuthBackend(ref)
      : FirebaseAuthBackend(ref);
});

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

  AuthBackend get backend => _ref.read(authBackendProvider);

  /// Restores the locally persisted session (JWT or Firebase) after app
  /// restart so the app can reopen directly on the home screen.
  Future<bool> restoreSession() async {
    final session = await backend.currentSession();
    if (session == null) return false;
    await _establishLocalSession(session);
    return true;
  }

  Future<void> signUpWithEmail({
    required String shopName,
    required String ownerName,
    required String email,
    required String mobile,
    required String password,
  }) async {
    if (!backend.isReady) {
      throw const AuthMessageException(
        'Account creation is temporarily unavailable. Please contact support.',
      );
    }
    await backend.signUp(
      name: ownerName.trim(),
      email: email,
      phone: mobile,
      password: password,
      metadata: {'shopName': shopName.trim()},
    );
  }

  /// Sends an email verification code (custom backend) or a fresh
  /// verification email (Firebase backend).
  Future<void> sendEmailVerificationCode(String email) {
    return backend.sendEmailVerificationCode(email);
  }

  Future<void> verifyEmail({
    required String email,
    required String code,
  }) {
    return backend.verifyEmail(email: email, code: code);
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (!backend.isReady) {
      throw const AuthMessageException(
        'Login is temporarily unavailable. Please contact support.',
      );
    }
    final session = await backend.signInWithEmail(
      email: email,
      password: password,
    );
    await _establishLocalSession(session);
  }

  Future<void> signInWithGoogle() async {
    if (!backend.isReady) {
      throw const AuthMessageException(
        'Gmail sign-in is not available right now. Please try again later.',
      );
    }
    final session = await backend.signInWithGoogle();
    await _establishLocalSession(session);
  }

  Future<void> signOut() async {
    await _ref.read(localDatabaseProvider).clearBusinessData();
    await backend.signOut();
    _ref.read(currentUserProvider.notifier).state = null;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    if (!backend.isReady) {
      throw const AuthMessageException(
        'Password reset is temporarily unavailable. Please contact support.',
      );
    }
    await backend.sendPasswordResetEmail(email);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return backend.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  Future<void> setPasswordForGoogleAccount(String newPassword) {
    return backend.setPasswordForGoogleAccount(newPassword);
  }

  Future<void> sendOtp({
    required String phone,
    required void Function(String verificationId) onCodeSent,
    required void Function(String message) onError,
  }) {
    return backend.sendOtp(
      phone: phone,
      onCodeSent: onCodeSent,
      onError: onError,
    );
  }

  Future<void> verifyOtp({
    required String verificationId,
    required String smsCode,
    required String phone,
  }) async {
    if (!backend.isReady) {
      throw const AuthMessageException(
        'Phone OTP login is temporarily unavailable. Please contact support.',
      );
    }
    final session = await backend.verifyOtp(
      verificationId: verificationId,
      smsCode: smsCode,
      phone: phone,
    );
    await _establishLocalSession(session);
  }

  /// Bridges a backend session into the app's local (Hive) account state:
  /// active account, AppUser record and currentUserProvider.
  Future<void> _establishLocalSession(AuthSession session) async {
    if (session.userId.isEmpty) return;
    final shopId = await backend.resolveShopId(session);
    final db = _ref.read(localDatabaseProvider);
    await db.setActiveAccount(userId: session.userId, shopId: shopId);
    final appUser = AppUser(
      userId: session.userId,
      name: session.displayName,
      phone: session.phone,
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
}

String authErrorMessage(Object error) {
  if (error is AuthMessageException) {
    return error.message;
  }
  if (error is AuthException) {
    return error.message;
  }
  if (error is StateError) {
    return 'Sign-in is not ready yet. Please close the screen and try again.';
  }
  return 'We could not complete sign-in. Please try again.';
}
