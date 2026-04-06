// File managed by L2LAAF Assistant.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    throw UnsupportedError('DefaultFirebaseOptions are not supported for this platform.');
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA88...', // PASTE YOUR VALID API KEY HERE
    authDomain: 'local2local-dev.firebaseapp.com',
    projectId: 'local2local-dev',
    storageBucket: 'local2local-dev.appspot.com',
    messagingSenderId: '24933902371',
    appId: '1:24933902371:web:5d2a71f084be7b7f1604a3',
    measurementId: 'G-74X1J2J8N7',
  );
}