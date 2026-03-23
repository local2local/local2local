import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local2local/features/triage_hub/theme/admin_theme.dart';
import 'package:local2local/nav.dart';

/// Main entry point for the Local2Local Super Admin Hub
///
/// This sets up:
/// - Riverpod state management
/// - go_router navigation
/// - Slate/Dark theme with Emerald Green and Ruby Red accents
void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Local2Local Super Admin',
      debugShowCheckedModeBanner: false,
      // Use the admin dark theme
      theme: adminDarkTheme,
      darkTheme: adminDarkTheme,
      themeMode: ThemeMode.dark,
      // Router configuration
      routerConfig: AppRouter.router,
    );
  }
}
