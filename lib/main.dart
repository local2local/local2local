import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local2local/core/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  bool firebaseReady = false;
  String? initMessage;

  try {
    debugPrint("L2LAAF_BOOT: Initializing v11.68.36...");
    await Firebase.initializeApp();
    
    // Auth Handshake
    try {
      await FirebaseAuth.instance.signInAnonymously();
      firebaseReady = true;
      debugPrint("L2LAAF_BOOT: Handshake SUCCESS.");
    } catch (authError) {
      initMessage = "AUTH_DEGRADED: Using restricted guest access.";
      debugPrint("L2LAAF_BOOT_WARNING: $authError");
      firebaseReady = true; // Proceed with limited access
    }
  } catch (e) {
    initMessage = "INIT_ERROR: Firestore connectivity limited.";
    debugPrint("L2LAAF_BOOT_ERROR: $e");
    firebaseReady = true; // Fallback: Allow UI to load even if Firebase is delayed
  }

  runApp(
    ProviderScope(
      overrides: [
        firebaseStatusProvider.overrideWith((ref) => firebaseReady),
        bootMessageProvider.overrideWith((ref) => initMessage),
      ],
      child: const L2LAAFApp(),
    ),
  );
}

final firebaseStatusProvider = Provider<bool>((ref) => false);
final bootMessageProvider = Provider<String?>((ref) => null);