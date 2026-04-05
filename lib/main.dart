import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local2local/core/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  bool initialized = false;
  String? initError;

  try {
    debugPrint("L2LAAF_BOOT: Requesting Firebase init v11.59.36...");
    await Firebase.initializeApp();
    
    debugPrint("L2LAAF_BOOT: Handshaking with Auth...");
    await FirebaseAuth.instance.signInAnonymously();
    
    initialized = true;
    debugPrint("L2LAAF_BOOT: Environment Verified.");
  } catch (e) {
    initError = e.toString();
    debugPrint("L2LAAF_BOOT_FATAL: $e");
  }

  runApp(
    ProviderScope(
      overrides: [
        // Flag to tell the UI if Firebase is actually available
        firebaseReadyProvider.overrideWith((ref) => initialized),
      ],
      child: initialized 
        ? const L2LAAFApp() 
        : MaterialApp(
            home: Scaffold(
              backgroundColor: const Color(0xFF1E1E2C),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_off, size: 64, color: Colors.redAccent),
                      const SizedBox(height: 24),
                      const Text("FIREBASE INITIALIZATION ERROR", 
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Text(initError ?? "Unknown Failure", 
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),
    ),
  );
}

// Global provider to track initialization state
final firebaseReadyProvider = Provider<bool>((ref) => false);