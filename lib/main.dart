import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local2local/core/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  bool initialized = false;
  String? error;

  try {
    debugPrint("L2LAAF_BOOT: Initializing via Dreamflow pattern v11.63.36...");
    await Firebase.initializeApp();
    await FirebaseAuth.instance.signInAnonymously();
    initialized = true;
    debugPrint("L2LAAF_BOOT: System Ready.");
  } catch (e) {
    error = e.toString();
    debugPrint("L2LAAF_BOOT_ERROR: $e");
  }

  runApp(
    ProviderScope(
      overrides: [
        firebaseReadyProvider.overrideWith((ref) => initialized),
      ],
      child: initialized 
        ? const L2LAAFApp() 
        : MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: const Color(0xFF0F0F1E),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                    const SizedBox(height: 24),
                    const Text("ENGINE INITIALIZATION ERROR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text(error ?? "Handshake Timeout", style: const TextStyle(color: Colors.white38, fontSize: 10)),
                  ],
                ),
              ),
            ),
          ),
    ),
  );
}

final firebaseReadyProvider = Provider<bool>((ref) => false);