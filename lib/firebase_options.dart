// File generated using FlutterFire CLI.
// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
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
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD-gR7ZV9EkQKpfRUwPdnXyB4NLb7Kj8QM',
    appId: '1:83995365801:web:23b104d813b51cdbc4f4b8',
    messagingSenderId: '83995365801',
    projectId: 'carona-universitiaria',
    authDomain: 'carona-universitiaria.firebaseapp.com',
    storageBucket: 'carona-universitiaria.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD-gR7ZV9EkQKpfRUwPdnXyB4NLb7Kj8QM',
    appId: '1:83995365801:android:23b104d813b51cdbc4f4b8',
    messagingSenderId: '83995365801',
    projectId: 'carona-universitiaria',
    storageBucket: 'carona-universitiaria.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD-gR7ZV9EkQKpfRUwPdnXyB4NLb7Kj8QM',
    appId: '1:83995365801:ios:23b104d813b51cdbc4f4b8',
    messagingSenderId: '83995365801',
    projectId: 'carona-universitiaria',
    storageBucket: 'carona-universitiaria.firebasestorage.app',
    iosBundleId: 'com.carona.universitaria',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyD-gR7ZV9EkQKpfRUwPdnXyB4NLb7Kj8QM',
    appId: '1:83995365801:ios:23b104d813b51cdbc4f4b8',
    messagingSenderId: '83995365801',
    projectId: 'carona-universitiaria',
    storageBucket: 'carona-universitiaria.firebasestorage.app',
    iosBundleId: 'com.carona.universitaria',
  );
}

