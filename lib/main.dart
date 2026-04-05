import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local2local/core/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // RESILIENT BOOT: Do not crash the app if Firebase fails due to cache issues
  try {
    debugPrint("L2LAAF_BOOT: Initializing Firebase (v11.58.36)...");
    await Firebase.initializeApp();
    debugPrint("L2LAAF_BOOT: Authenticating...");
    await FirebaseAuth.instance.signInAnonymously();
    debugPrint("L2LAAF_BOOT: Security Handshake Complete.");
  } catch (e) {
    debugPrint("L2LAAF_BOOT_WARNING: Firebase initialization bypassed: $e");
  }

  runApp(
    const ProviderScope(
      child: L2LAAFApp(),
    ),
  );
}