import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local2local/features/auth/providers/auth_provider.dart';
import 'package:local2local/features/triage_hub/pages/admin_shell.dart';
import 'package:local2local/features/triage_hub/pages/triage_queue_page.dart';
import 'package:local2local/features/triage_hub/pages/fleet_map_page.dart';
import 'package:local2local/features/triage_hub/providers/app_providers.dart';
import 'package:local2local/features/triage_hub/theme/admin_theme.dart';

/// The Entry point for the Admin workspace.
/// Now implements a Page-Level Guard to prevent "Flashing" sensitive content.
class AdminHubPage extends ConsumerWidget {
  const AdminHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdminAsync = ref.watch(isAdminProvider);

    // Page-Level Guard: If we are loading or not an admin, we render a neutral loading screen.
    // This ensures that even if the router "leaks" a single frame, no sensitive data is shown.
    return isAdminAsync.when(
      data: (isAdmin) {
        if (!isAdmin) {
          return const Scaffold(backgroundColor: AdminColors.slateDarkest);
        }

        // Only if confirmed as Admin do we build the sensitive Shell and Children
        return AdminShell(
          child: _buildCurrentPage(ref.watch(selectedNavIndexProvider)),
        );
      },
      loading: () => const Scaffold(
        backgroundColor: AdminColors.slateDarkest,
        body: Center(
            child: CircularProgressIndicator(color: AdminColors.emeraldGreen)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AdminColors.slateDarkest,
        body: Center(
            child: Text('Auth Error: $e',
                style: const TextStyle(color: AdminColors.rubyRed))),
      ),
    );
  }

  Widget _buildCurrentPage(int index) {
    switch (index) {
      case 0:
        return const TriageQueuePage();
      case 1:
        return const Center(child: Text('Health Grid Coming Soon'));
      case 2:
        return const FleetMapPage();
      case 3:
        return const Center(child: Text('Evolution Timeline Coming Soon'));
      default:
        return const TriageQueuePage();
    }
  }
}
