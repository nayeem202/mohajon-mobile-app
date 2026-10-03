import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/syncable.dart';
import '../../../core/services/auth_backend.dart';
import '../../../core/services/custom_auth_backend.dart';
import '../../../core/services/sync_service.dart';

/// The auth backend. The app authenticates against the self-hosted
/// auth service (Spring Boot); there is no Firebase backend anymore.
final authBackendProvider = Provider<AuthBackend>(
  (ref) => CustomAuthBackend(ref),
);

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

  static const _kProfileStoreName = 'profile_storeName';
  static const _kProfileOwnerName = 'profile_ownerName';
  static const _kProfilePhone = 'profile_phone';
  static const _kProfileEmail = 'profile_email';
  static const _kProfileUserId = 'profile_userId';
  static const kProfileBusinessType = 'profile_businessType';

  AuthBackend get backend => _ref.read(authBackendProvider);

  /// Restores the locally persisted session (JWT) after app
  /// restart so the app can reopen directly on the home screen.
  Future<bool> restoreSession() async {
    final session = await backend.currentSession();
    if (session == null) return false;
    // Startup must never wait for the network. The splash screen can open
    // the local account immediately; the app shell already starts a guarded
    // background sync after navigation.
    await _establishLocalSession(session, syncNow: false);
    return true;
  }

  Future<void> signUpWithEmail({
    required String shopName,
    required String ownerName,
    required String email,
    required String mobile,
    required String password,
    String businessType = 'general',
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
      metadata: {'shopName': shopName.trim(), 'businessType': businessType},
    );
    await _persistSignupProfile(
      shopName: shopName,
      ownerName: ownerName,
      email: email,
      mobile: mobile,
      businessType: businessType,
    );
  }

  /// Stores the registration values locally so the profile / store
  /// information screens show them right away, even before the shop
  /// profile exists on the backend.
  Future<void> _persistSignupProfile({
    required String shopName,
    required String ownerName,
    required String email,
    required String mobile,
    required String businessType,
  }) async {
    final settings = _ref.read(localDatabaseProvider).settings;
    await Future.wait([
      settings.put(_kProfileStoreName, shopName.trim()),
      settings.put(_kProfileOwnerName, ownerName.trim()),
      settings.put(_kProfilePhone, mobile.trim()),
      settings.put(_kProfileEmail, email.trim().toLowerCase()),
      settings.put(kProfileBusinessType, businessType),
    ]);
  }

  /// Sends an email verification code through the custom backend.
  Future<void> sendEmailVerificationCode(String email) {
    return backend.sendEmailVerificationCode(email);
  }

  Future<void> verifyEmail({required String email, required String code}) {
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

  Future<void> signInWithFacebook() async {
    if (!backend.isReady) {
      throw const AuthMessageException(
        'Facebook sign-in is not available right now. Please try again later.',
      );
    }
    final session = await backend.signInWithFacebook();
    await _establishLocalSession(session);
  }

  Future<void> signOut() async {
    final db = _ref.read(localDatabaseProvider);
    final syncService = SyncService(db);
    final shopId = _ref.read(shopIdProvider);
    if (syncService.pendingCount(shopId: shopId) > 0) {
      // Flush offline changes first so none are lost on sign-out.
      if (await syncService.isOnline) {
        await syncService.sync(shopId: shopId);
      }
      if (syncService.pendingCount(shopId: shopId) > 0) {
        throw const AuthMessageException(
          'You have unsynced offline data. Connect to the internet, sync, '
          'and try signing out again so no data is lost.',
        );
      }
    }
    await db.clearBusinessData();
    // Store information is account-specific. Do not show the previous
    // account's owner/email after another user signs in on this device.
    await db.settings.deleteAll([
      _kProfileStoreName,
      _kProfileOwnerName,
      _kProfilePhone,
      _kProfileEmail,
      _kProfileUserId,
      kProfileBusinessType,
      'profile_setupComplete',
      'profile_address',
      'profile_imagePath',
    ]);
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
  Future<void> _establishLocalSession(
    AuthSession session, {
    bool syncNow = true,
  }) async {
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
    // Remembered across sign-outs on purpose: the login screen uses it to tell
    // a returning customer apart from a first-time one, and "welcome back"
    // should stop being the greeting for someone who has genuinely been here.
    Hive.box<dynamic>(HiveBoxes.settings).put('hasSignedInBefore', true);
    await _prepareProfileForSession(session);
    await _fillMissingProfileFromSession(session);
    if (syncNow) {
      final syncService = SyncService(db);
      if (await syncService.isOnline) {
        await syncService.sync(shopId: shopId);
      }
    }
  }

  Future<void> _prepareProfileForSession(AuthSession session) async {
    final settings = _ref.read(localDatabaseProvider).settings;
    final savedUserId = settings.get(_kProfileUserId) as String?;
    final savedEmail = (settings.get(_kProfileEmail) as String?) ?? '';
    final belongsToSession =
        savedUserId == session.userId ||
        (savedUserId == null &&
            savedEmail.trim().toLowerCase() ==
                session.email.trim().toLowerCase());

    if (!belongsToSession && (savedUserId != null || savedEmail.isNotEmpty)) {
      await settings.deleteAll([
        _kProfileStoreName,
        _kProfileOwnerName,
        _kProfilePhone,
        _kProfileEmail,
        'profile_address',
        'profile_imagePath',
        kProfileBusinessType,
        'profile_setupComplete',
      ]);
    }
    await settings.put(_kProfileUserId, session.userId);
  }

  /// Backfills profile fields from the signed-in session, but never
  /// overwrites values the user already saved or that were captured at
  /// registration.
  Future<void> _fillMissingProfileFromSession(AuthSession session) async {
    final settings = _ref.read(localDatabaseProvider).settings;
    final ownerName = (settings.get(_kProfileOwnerName) as String?) ?? '';
    final phone = (settings.get(_kProfilePhone) as String?) ?? '';
    final email = (settings.get(_kProfileEmail) as String?) ?? '';
    await Future.wait([
      if (ownerName.trim().isEmpty && session.displayName.trim().isNotEmpty)
        settings.put(_kProfileOwnerName, session.displayName.trim()),
      if (phone.trim().isEmpty && session.phone.trim().isNotEmpty)
        settings.put(_kProfilePhone, session.phone.trim()),
      if (email.trim().isEmpty && session.email.trim().isNotEmpty)
        settings.put(_kProfileEmail, session.email.trim().toLowerCase()),
    ]);
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
