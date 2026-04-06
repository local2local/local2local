import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local2local/core/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  bool firebaseReady = false;

  try {
    debugPrint("L2LAAF_BOOT: Handshaking v11.67.36...");
    await Firebase.initializeApp();
    await FirebaseAuth.instance.signInAnonymously();
    firebaseReady = true;
    debugPrint("L2LAAF_BOOT: Engine Synchronized.");
  } catch (e) {
    debugPrint("L2LAAF_BOOT_ERROR: $e");
    // Resume boot even on error; the UI will handle the lack of data gracefully
  }

  runApp(
    ProviderScope(
      overrides: [
        firebaseStatusProvider.overrideWith((ref) => firebaseReady),
      ],
      child: const L2LAAFApp(),
    ),
  );
}

final firebaseStatusProvider = Provider<bool>((ref) => false);