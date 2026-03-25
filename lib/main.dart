import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local2local/features/triage_hub/theme/admin_theme.dart';
import 'package:local2local/nav.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (Options automatically loaded from DefaultFirebaseOptions if configured)
  await Firebase.initializeApp();

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
