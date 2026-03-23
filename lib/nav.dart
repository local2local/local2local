import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:local2local/features/triage_hub/pages/admin_hub_page.dart';

/// GoRouter configuration for app navigation
///
/// This uses go_router for declarative routing, which provides:
/// - Type-safe navigation
/// - Deep linking support (web URLs, app links)
/// - Easy route parameters
/// - Navigation guards and redirects
class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.adminHub,
    routes: [
      GoRoute(
        path: AppRoutes.adminHub,
        name: 'admin-hub',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: AdminHubPage(),
        ),
      ),
    ],
  );
}

/// Route path constants
/// Use these instead of hard-coding route strings
class AppRoutes {
  static const String adminHub = '/';
}
