import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local2local/core/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    debugPrint("L2LAAF_BOOT: Initializing v11.64.36...");
    await Firebase.initializeApp();
    await FirebaseAuth.instance.signInAnonymously();
    debugPrint("L2LAAF_BOOT: Handshake Complete.");
  } catch (e) {
    debugPrint("L2LAAF_BOOT_ERROR: $e");
  }

  runApp(
    const ProviderScope(
      child: L2LAAFApp(),
    ),
  );
}