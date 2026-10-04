import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/syncable.dart';
import '../../../core/services/auth_backend.dart';
import '../../../core/services/custom_auth_backend.dart';
import '../../../core/services/api_client.dart';
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
  static const kProfileIdentityComplete = 'profile_identityComplete';

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
    String businessType = '',
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
      if (businessType.trim().isNotEmpty)
        settings.put(kProfileBusinessType, businessType.trim())
      else
        settings.delete(kProfileBusinessType),
      // Email registration already collected the shop identity fields. The
      // post-login setup will only ask for the missing business category.
      settings.put(kProfileIdentityComplete, true),
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
    // Keep the profile snapshot across logout so the same account can reopen
    // without being treated as a brand-new business. If another account is
    // used later, _prepareProfileForSession clears this snapshot after the
    // user-id mismatch check, before any UI is rendered.
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

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) {
    return backend.resetPassword(
      email: email,
      code: code,
      newPassword: newPassword,
    );
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
    await _syncPendingShopProfile();
    await _hydrateShopProfile();
    if (syncNow) {
      final syncService = SyncService(db);
      if (await syncService.isOnline) {
        await syncService.sync(shopId: shopId);
      }
    }
  }

  /// Business profile data belongs to Haalkhata, not the generic auth
  /// service. Sync the locally captured registration fields only after a
  /// valid authenticated session exists.
  Future<void> _syncPendingShopProfile() async {
    final db = _ref.read(localDatabaseProvider);
    final settings = db.settings;
    final name = (settings.get(_kProfileStoreName) as String?)?.trim() ?? '';
    final phone = (settings.get(_kProfilePhone) as String?)?.trim() ?? '';
    final businessType =
        (settings.get(kProfileBusinessType) as String?)?.trim() ?? '';
    final payload = <String, dynamic>{
      if (name.isNotEmpty) 'name': name,
      if (phone.isNotEmpty) 'phoneNumber': phone,
      if (businessType.isNotEmpty) 'businessType': businessType,
    };
    if (payload.isEmpty) return;
    try {
      await ApiClient(db).put('/api/v1/shops/me', payload);
    } catch (_) {
      // The local profile remains available offline; the next authenticated
      // startup retries this write.
    }
  }

  /// Recovers shop identity/category after a cache clear or reinstall. The
  /// registration screen already collected these values, so the server is the
  /// source of truth when local Hive data is unavailable.
  Future<void> _hydrateShopProfile() async {
    final db = _ref.read(localDatabaseProvider);
    try {
      final profile = await ApiClient(db)
          .get('/api/v1/shops/me', timeout: const Duration(seconds: 3));
      final settings = db.settings;
      final shopName = (profile['name'] ?? '').toString().trim();
      final phone = (profile['phoneNumber'] ?? '').toString().trim();
      final businessType = (profile['businessType'] ?? '').toString().trim();
      if (shopName.isNotEmpty) await settings.put(_kProfileStoreName, shopName);
      if (phone.isNotEmpty) await settings.put(_kProfilePhone, phone);
      if (shopName.isNotEmpty && phone.isNotEmpty) {
        await settings.put(kProfileIdentityComplete, true);
      }
      // Haalkhata assigns `general` as the database default for a newly
      // created shop. That value does not mean the user completed category
      // setup; otherwise a fresh Google signup would skip the category UI.
      // A user who explicitly selects General is marked complete by
      // ShopSetupScreen locally after pressing Continue.
      final isDefaultBusinessType = businessType == 'general';
      if (businessType.isNotEmpty &&
          (!isDefaultBusinessType ||
              settings.get('profile_setupComplete', defaultValue: false) ==
                  true)) {
        await settings.put(kProfileBusinessType, businessType);
        await settings.put('profile_setupComplete', true);
      }
    } catch (_) {
      // Offline startup remains usable; the next authenticated sync retries.
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
        kProfileIdentityComplete,
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
    final storeName = (settings.get(_kProfileStoreName) as String?) ?? '';
    final phone = (settings.get(_kProfilePhone) as String?) ?? '';
    final email = (settings.get(_kProfileEmail) as String?) ?? '';
    await Future.wait([
      if (ownerName.trim().isEmpty && session.displayName.trim().isNotEmpty)
        settings.put(_kProfileOwnerName, session.displayName.trim()),
      if (phone.trim().isEmpty && session.phone.trim().isNotEmpty)
        settings.put(_kProfilePhone, session.phone.trim()),
      if (email.trim().isEmpty && session.email.trim().isNotEmpty)
        settings.put(_kProfileEmail, session.email.trim().toLowerCase()),
      // Migration for email users created before the setup gate was added.
      // Google users intentionally do not qualify because their shop name
      // and mobile number were never collected during authentication.
      if (session.provider.toLowerCase() != 'google' &&
          storeName.trim().isNotEmpty &&
          phone.trim().isNotEmpty)
        settings.put(kProfileIdentityComplete, true),
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
