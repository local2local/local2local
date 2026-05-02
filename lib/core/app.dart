import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local2local/nav.dart';
import 'package:local2local/features/triage_hub/theme/admin_theme.dart';

class L2LAAFApp extends ConsumerWidget {
  const L2LAAFApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(AppRouter.routerProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'L2LAAF Cockpit',
      theme: adminDarkTheme,
      routerConfig: router,
    );
  }
}