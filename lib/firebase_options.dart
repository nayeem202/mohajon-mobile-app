import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Firebase Web options are not configured.');
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'Firebase options are only configured for Android.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAr0vM4G_i7dx2RSctd1R5PRkXRECCWfdE',
    appId: '1:273885941339:android:01215fb4163db9cb0f797e',
    messagingSenderId: '273885941339',
    projectId: 'banglapos-4f592',
    storageBucket: 'banglapos-4f592.firebasestorage.app',
  );
}
