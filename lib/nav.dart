import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local2local/features/triage_hub/pages/admin_hub_page.dart';
import 'package:local2local/features/auth/presentation/login_screen.dart';
import 'package:local2local/features/auth/providers/auth_provider.dart';
import 'package:local2local/features/triage_hub/theme/admin_theme.dart';

class AppRouter {
  static final routerProvider = Provider<GoRouter>((ref) {
    final authState = ref.watch(authStateProvider);
    final isAdminAsync = ref.watch(isAdminProvider);

    return GoRouter(
      initialLocation: '/',
      redirect: (context, state) {
        // 1. Handle Loading States
        // While we are determining auth state or verifying claims, do not redirect.
        // This prevents "flashing" unauthorized screens while the token refreshes.
        if (authState.isLoading ||
            (authState.hasValue &&
                authState.value != null &&
                isAdminAsync.isLoading)) {
          return null;
        }

        final user = authState.value;
        final isAdmin = isAdminAsync.value ?? false;
        final isLoggingIn = state.matchedLocation == '/login';
        final isDenied = state.matchedLocation == '/unauthorized';

        // 2. Unauthenticated Gate
        if (user == null) {
          return isLoggingIn ? null : '/login';
        }

        // 3. Unauthorized Gate (Logged in but no claim)
        if (!isAdmin) {
          // If they aren't an admin and aren't already on the denied page, send them there.
          if (!isDenied) return '/unauthorized';
          return null;
        }

        // 4. Authenticated Admin Gate
        // If they are an admin and currently on restricted routes, send them home.
        if (isAdmin && (isLoggingIn || isDenied)) {
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
          path: '/unauthorized',
          builder: (context, state) => const UnauthorizedScreen(),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const AdminHubPage(),
        ),
      ],
    );
  });
}

class UnauthorizedScreen extends ConsumerWidget {
  const UnauthorizedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AdminColors.slateDarkest,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.gpp_bad_rounded,
                color: AdminColors.rubyRed, size: 64),
            const SizedBox(height: 24),
            const Text('Access Restricted',
                style: TextStyle(
                    color: AdminColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Your account lacks Super Admin privileges.',
                style: TextStyle(color: AdminColors.textSecondary)),
            const SizedBox(height: 32),
            OutlinedButton(
              onPressed: () => ref.read(authActionProvider.notifier).logout(),
              style: OutlinedButton.styleFrom(
                foregroundColor: AdminColors.textPrimary,
                side: const BorderSide(color: AdminColors.borderDefault),
              ),
              child: const Text('Return to Login'),
            ),
          ],
        ),
      ),
    );
  }
}
