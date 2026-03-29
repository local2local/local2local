import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local2local/features/triage_hub/theme/admin_theme.dart';
import 'package:local2local/nav.dart';

// FIX: Web requires explicit FirebaseOptions to avoid the "null options" assertion error

const firebaseOptions = FirebaseOptions(
    apiKey: "AIzaSyAy0umnBYiKPxxAIUT9WLYKG0Fs_zKtMQ8",
    authDomain: "local2local-dev.firebaseapp.com",
    projectId: "local2local-dev",
    storageBucket: "local2local-dev.firebasestorage.app",
    messagingSenderId: "849010982119",
    appId: "1:849010982119:web:f5af08a3214393b0943642",
    measurementId: "G-7KYLQM8T4C");

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: firebaseOptions,
    );
  } catch (e) {
    debugPrint("Firebase Init Error: $e");
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(AppRouter.routerProvider);

    return MaterialApp.router(
      title: 'Local2Local Super Admin Hub',
      debugShowCheckedModeBanner: false,
      theme: adminDarkTheme,
      darkTheme: adminDarkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
