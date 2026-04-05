import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local2local/core/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Rule 3: Initialize Firebase and Authenticate before mounting the UI
  await Firebase.initializeApp();
  
  try {
    await FirebaseAuth.instance.signInAnonymously();
  } catch (e) {
    debugPrint("Firebase Auth Error: $e");
  }

  runApp(
    const ProviderScope(
      child: L2LAAFApp(),
    ),
  );
}