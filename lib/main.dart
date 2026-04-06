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
    debugPrint("L2LAAF_BOOT: Initializing v11.70.36 via automatic config...");
    
    // Dreamflow Pattern: No options passed on web to use Hosting auto-init
    await Firebase.initializeApp();
    
    await FirebaseAuth.instance.signInAnonymously();
    initialized = true;
    debugPrint("L2LAAF_BOOT: Handshake SUCCESS.");
  } catch (e) {
    errorMessage = e.toString();
    debugPrint("L2LAAF_BOOT_ERROR: $e");
  }

  runApp(
    ProviderScope(
      overrides: [
        firebaseReadyProvider.overrideWith((ref) => initialized),
        initErrorProvider.overrideWith((ref) => errorMessage),
      ],
      child: const L2LAAFApp(),
    ),
  );
}

final firebaseReadyProvider = Provider<bool>((ref) => false);
final initErrorProvider = Provider<String?>((ref) => null);