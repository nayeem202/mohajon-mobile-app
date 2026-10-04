/// Abstraction over the authentication backend (custom auth service).
/// auth service). The app only talks to this interface, so backends can be
/// swapped without touching screens or providers.
library;

/// Error raised by an [AuthBackend]. [code] mirrors the server error code
/// (e.g. `VERIFICATION_REQUIRED`, `EMAIL_ALREADY_EXISTS`) when available.
class AuthException implements Exception {
  const AuthException(this.message, {this.code = ''});

  final String message;
  final String code;

  @override
  String toString() => message;
}

/// A signed-in user session, provider agnostic.
class AuthSession {
  const AuthSession({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.phone,
    required this.photoUrl,
    required this.emailVerified,
    required this.isNewUser,
    this.provider = 'local',
    this.roles = const [],
  });

  final String userId;
  final String email;
  final String displayName;
  final String phone;
  final String photoUrl;
  final bool emailVerified;
  final bool isNewUser;

  /// How the account signs in: `local` (email+password) or `google`.
  final String provider;
  final List<String> roles;

  AuthSession copyWith({bool? emailVerified, bool? isNewUser}) => AuthSession(
    userId: userId,
    email: email,
    displayName: displayName,
    phone: phone,
    photoUrl: photoUrl,
    emailVerified: emailVerified ?? this.emailVerified,
    isNewUser: isNewUser ?? this.isNewUser,
    provider: provider,
    roles: roles,
  );
}

/// Authentication backend contract.
abstract class AuthBackend {
  /// Whether this backend can be used right now.
  bool get isReady;

  /// Current session or null when signed out.
  Future<AuthSession?> currentSession();

  /// Emits the session whenever it changes (sign in / sign out).
  Stream<AuthSession?> get sessionChanges;

  /// Sign up with email + password. [metadata] carries app-specific info
  /// (e.g. shopName) that some backends persist alongside the account.
  Future<AuthSession> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
    Map<String, String> metadata = const {},
  });

  /// Sign in with email + password.
  Future<AuthSession> signInWithEmail({
    required String email,
    required String password,
  });

  Future<AuthSession> signInWithGoogle();

  /// Sign in with a Facebook user access token obtained by the app from the
  /// Facebook SDK. The token is verified server-side; nothing about the user is
  /// trusted from the client.
  Future<AuthSession> signInWithFacebook();

  /// Send a verification code for [email].
  Future<void> sendEmailVerificationCode(String email);

  /// Confirm the verification code sent to [email].
  Future<void> verifyEmail({required String email, required String code});

  Future<void> sendPasswordResetEmail(String email);

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  });

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<void> setPasswordForGoogleAccount(String newPassword);

  /// Send an OTP to [phone]. [onCodeSent] receives the verification id.
  Future<void> sendOtp({
    required String phone,
    required void Function(String verificationId) onCodeSent,
    required void Function(String message) onError,
  });

  /// Complete sign-in with the OTP code.
  Future<AuthSession> verifyOtp({
    required String verificationId,
    required String smsCode,
    required String phone,
  });

  /// Resolve the app-level business/shop id for a session.
  Future<String> resolveShopId(AuthSession session);

  Future<void> signOut();
}
