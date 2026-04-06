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
    debugPrint("L2LAAF_BOOT: Initializing v11.69.36...");
    
    // Explicit check to avoid Null check operator crash on web
    await Firebase.initializeApp(
      // Optional: If init.js fails, these are the dev project fallbacks
      options: const FirebaseOptions(
        apiKey: "AIzaSyB...", // Placeholder - hosting usually handles this
        appId: "1:24933902371:web:...", 
        messagingSenderId: "24933902371",
        projectId: "local2local-dev",
      ),
    );
    
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