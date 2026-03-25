import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local2local/features/triage_hub/theme/admin_theme.dart';
import 'package:local2local/nav.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase with explicit options (Required for Flutter Web)
  // These are production/development keys for the local2local-dev project
  await Firebase.initializeApp(
    options: const FirebaseOptions(
        apiKey: "AIzaSyAy0umnBYiKPxxAIUT9WLYKG0Fs_zKtMQ8",
        authDomain: "local2local-dev.firebaseapp.com",
        projectId: "local2local-dev",
        storageBucket: "local2local-dev.firebasestorage.app",
        messagingSenderId: "849010982119",
        appId: "1:849010982119:web:f5af08a3214393b0943642",
        measurementId: "G-7KYLQM8T4C"),
  );

  // 2. Sign in Anonymously to clear Firestore permission gates
  try {
    await FirebaseAuth.instance.signInAnonymously();
    // FIX: debugPrint instead of print
    debugPrint("DEBUG: Authenticated Anonymously");
  } catch (e) {
    debugPrint("DEBUG: Auth Error: $e");
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Local2Local Super Admin',
      debugShowCheckedModeBanner: false,
      theme: adminDarkTheme,
      darkTheme: adminDarkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: AppRouter.router,
    );
  }
}
