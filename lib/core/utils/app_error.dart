import 'package:flutter/foundation.dart';

/// Logs the full technical error for developers and returns a short,
/// human-friendly message safe to show to the user.
String friendlyErrorMessage(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  debugPrint('APP_ERROR >>> ${error.runtimeType}: $error');
  final s = error.toString().toLowerCase();
  if (s.contains('socketexception') ||
      s.contains('connection refused') ||
      s.contains('clientexception') ||
      s.contains('failed host lookup') ||
      s.contains('network is unreachable') ||
      s.contains('connection aborted') ||
      s.contains('connection reset')) {
    return "Can't reach the server. Check your internet connection and try again.";
  }
  if (s.contains('timeout') || s.contains('timed out')) {
    return 'The server took too long to respond. Please try again.';
  }
  if (s.contains('401') || s.contains('unauthorized')) {
    return 'Your session has expired. Please sign in again.';
  }
  if (s.contains('403') || s.contains('forbidden')) {
    return "You don't have permission to do this.";
  }
  if (s.contains('404') || s.contains('not found')) {
    return 'This item no longer exists on the server.';
  }
  if (s.contains('409') || s.contains('conflict') || s.contains('duplicate')) {
    return 'This item already exists.';
  }
  if (s.contains('500') ||
      s.contains('502') ||
      s.contains('503') ||
      s.contains('internal server error')) {
    return 'Server error. Please try again in a moment.';
  }
  return fallback;
}
