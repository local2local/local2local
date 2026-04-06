import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local2local/core/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  bool initialized = false;
  String? errorMessage;

  try {
    debugPrint("L2LAAF_BOOT: Handshaking v11.71.36...");
    
    // Standard Dreamflow init: No options on web (uses Hosting config)
    await Firebase.initializeApp();
    
    // Safety delay to allow JS Auth bridge to attach
    Future.delayed(const Duration(milliseconds: 100), () async {
      try {
        await FirebaseAuth.instance.signInAnonymously();
        debugPrint("L2LAAF_BOOT: Auth Synchronized.");
      } catch (e) {
        debugPrint("L2LAAF_BOOT_WARNING: Auth delayed: $e");
      }
    });

    initialized = true;
    debugPrint("L2LAAF_BOOT: Core Ready.");
  } catch (e) {
    errorMessage = e.toString();
    debugPrint("L2LAAF_BOOT_ERROR: $e");
  }

  runApp(
    ProviderScope(
      overrides: [
        firebaseReadyProvider.overrideWith((ref) => initialized),
        bootErrorProvider.overrideWith((ref) => errorMessage),
      ],
      child: const L2LAAFApp(),
    ),
  );
}

final firebaseReadyProvider = Provider<bool>((ref) => false);
final bootErrorProvider = Provider<String?>((ref) => null);