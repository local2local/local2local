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
    debugPrint("L2LAAF_BOOT: Starting Firebase Handshake v11.61.36...");
    
    // Attempting standard initialization. 
    // If this fails with Null check, it means the window.firebase object is missing.
    await Firebase.initializeApp();
    
    debugPrint("L2LAAF_BOOT: Handshaking with Auth Service...");
    await FirebaseAuth.instance.signInAnonymously();
    
    initialized = true;
    debugPrint("L2LAAF_BOOT: System Ready.");
  } catch (e) {
    initError = e.toString();
    if (initError.contains("Null check operator")) {
      initError = "FIREBASE_JS_SDK_MISSING: The browser failed to load the required Firebase scripts. Please check your network or refresh the page.";
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
              backgroundColor: const Color(0xFF1E1E2C),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(48),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 80, color: Color(0xFFFF5252)),
                      const SizedBox(height: 32),
                      const Text(
                        "SYSTEM BOOT FAILURE", 
                        style: TextStyle(
                          color: Colors.white, 
                          fontSize: 18, 
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2
                        )
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(8)
                        ),
                        child: Text(
                          initError ?? "Initialization Timeout", 
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.5)
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text("RETRY CONNECTION"),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                        onPressed: () => main(),
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