import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local2local/core/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    debugPrint("L2LAAF_BOOT: Handshaking with Engine v11.66.36...");
    await Firebase.initializeApp();
    await FirebaseAuth.instance.signInAnonymously();
    debugPrint("L2LAAF_BOOT: Stack Verified.");
  } catch (e) {
    debugPrint("L2LAAF_BOOT_WARNING: $e");
    // Standard Dreamflow resilience: Continue and let the UI handle empty states
  }

  runApp(
    const ProviderScope(
      child: L2LAAFApp(),
    ),
  );
}