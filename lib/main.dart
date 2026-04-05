import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local2local/core/app.dart';

void main() async {
  // CRITICAL: Catch errors during bootstrap to prevent white screen silence
  runApp(const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator()))));

  try {
    WidgetsFlutterBinding.ensureInitialized();
    debugPrint("L2LAAF_BOOT: Initializing Firebase...");
    await Firebase.initializeApp();
    
    debugPrint("L2LAAF_BOOT: Authenticating...");
    await FirebaseAuth.instance.signInAnonymously();
    
    debugPrint("L2LAAF_BOOT: Launching Core Engine v11.57.36");
    runApp(
      const ProviderScope(
        child: L2LAAFApp(),
      ),
    );
  } catch (e, stack) {
    debugPrint("FATAL_BOOT_ERROR: $e");
    debugPrint(stack.toString());
    // Fallback UI for fatal errors
    runApp(MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFFD32F2F),
        body: Center(
          child: Text("BOOT ERROR: $e", style: const TextStyle(color: Colors.white)),
        ),
      ),
    ));
  }
}