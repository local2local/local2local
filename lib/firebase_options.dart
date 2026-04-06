// File managed by L2LAAF Assistant.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    throw UnsupportedError('DefaultFirebaseOptions are not supported for this platform.');
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAy0umnBYiKPxxAIUT9WLYKG0Fs_zKtMQ8',
    appId: '1:849010982119:web:f5af08a3214393b0943642',
    messagingSenderId: '849010982119',
    projectId: 'local2local-dev',
    authDomain: 'local2local-dev.firebaseapp.com',
    storageBucket: 'local2local-dev.firebasestorage.app',
    measurementId: 'G-7KYLQM8T4C',
  );
}