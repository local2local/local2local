import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local2local/features/triage_hub/pages/admin_hub_page.dart';
import 'package:local2local/features/auth/presentation/login_screen.dart';
import 'package:local2local/features/auth/providers/auth_provider.dart';

// This file is lib/nav.dart

class AppRouter {
  static final routerProvider = Provider<GoRouter>((ref) {
    final authState = ref.watch(authStateProvider);

    return GoRouter(
      initialLocation: '/',
      redirect: (context, state) {
        final loggingIn = state.matchedLocation == '/login';
        final user = authState.value;

        // 1. Unauthenticated Gate
        if (user == null) {
          return loggingIn ? null : '/login';
        }

        // 2. Prevent Login page access if already authenticated
        if (loggingIn) {
          return '/';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const AdminHubPage(),
        ),
      ],
    );
  });
}
