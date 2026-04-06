import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:js' as js;
import 'package:local2local/core/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  bool initialized = false;
  String? initError;

  try {
    debugPrint("L2LAAF_BOOT: Checking JS Environment v11.62.36...");
    
    // Explicitly check for the 'firebase' object in the JS context
    final hasFirebase = js.context.hasProperty('firebase');
    
    if (!hasFirebase) {
      throw "FIREBASE_JS_NOT_FOUND: The global 'firebase' object is missing. The index.html scripts failed to execute.";
    }

    debugPrint("L2LAAF_BOOT: Initializing FlutterFire Core...");
    await Firebase.initializeApp();
    
    debugPrint("L2LAAF_BOOT: Authenticating Anonymously...");
    await FirebaseAuth.instance.signInAnonymously();
    
    initialized = true;
    debugPrint("L2LAAF_BOOT: Handshake Success.");
  } catch (e) {
    initError = e.toString();
    if (initError.contains("Null check operator")) {
      initError = "FIREBASE_DART_BRIDGE_FAILURE: The Dart plugin failed to find the initialized JS app. This is likely a caching conflict.";
    }
    debugPrint("L2LAAF_BOOT_FATAL: $initError");
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
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.webhook, size: 80, color: Colors.blueAccent),
                      const SizedBox(height: 32),
                      const Text(
                        "L2LAAF BOOT ERROR", 
                        style: TextStyle(
                          color: Colors.white, 
                          fontSize: 16, 
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3
                        )
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10)
                        ),
                        child: Text(
                          initError ?? "Connection Refused", 
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.6, fontFamily: 'monospace')
                        ),
                      ),
                      const SizedBox(height: 40),
                      TextButton.icon(
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text("RETRY ENGINE START"),
                        onPressed: () => main(),
                        style: TextButton.styleFrom(foregroundColor: Colors.blueAccent),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    ),
  );
}

final firebaseReadyProvider = Provider<bool>((ref) => false);