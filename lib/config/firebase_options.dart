import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    // Configura tus opciones de Firebase para Web
    apiKey: 'tu-api-key',
    appId: 'tu-app-id',
    messagingSenderId: 'tu-messaging-sender-id',
    projectId: 'tu-project-id',
    authDomain: 'tu-auth-domain',
    storageBucket: 'tu-storage-bucket',
  );

  static const FirebaseOptions android = FirebaseOptions(
    // Configura tus opciones de Firebase para Android
    apiKey: 'AIzaSyC5nM7Zc6lRfH7kiKnuXXglqFVqoSOxWTM',
    appId: '1:311948803861:android:d59be3385a94629038f31c',
    messagingSenderId: '311948803861',
    projectId: 'chordly-ce1c9',
    storageBucket: 'chordly-ce1c9.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    // Configura tus opciones de Firebase para iOS
    apiKey: 'AIzaSyCrsHfclWLqPrPk2gawQkSZDqBFfrngunw',
    appId: '1:311948803861:ios:d59be3385a94629038f31c',
    messagingSenderId: '311948803861',
    projectId: 'chordly-ce1c9',
    storageBucket: 'chordly-ce1c9.appspot.com',
    iosClientId:
        '311948803861-lklcjfegefev1s11hfoi4kl4h4alqld4.apps.googleusercontent.com',
    iosBundleId: 'com.example.chordly',
  );
}
