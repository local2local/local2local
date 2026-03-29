import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local2local/features/auth/providers/auth_provider.dart';
import 'package:local2local/features/triage_hub/pages/admin_shell.dart';
import 'package:local2local/features/triage_hub/pages/triage_queue_page.dart';
import 'package:local2local/features/triage_hub/pages/fleet_map_page.dart';
import 'package:local2local/features/triage_hub/pages/evolution_timeline_page.dart';
import 'package:local2local/features/triage_hub/pages/health_grid_page.dart'; // NEW IMPORT
import 'package:local2local/features/triage_hub/providers/app_providers.dart';
import 'package:local2local/features/triage_hub/theme/admin_theme.dart';

class AdminHubPage extends ConsumerWidget {
  const AdminHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdminAsync = ref.watch(isAdminProvider);

    return isAdminAsync.when(
      data: (isAdmin) {
        if (!isAdmin) {
          return const Scaffold(backgroundColor: AdminColors.slateDarkest);
        }

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
        return const HealthGridPage(); // UPDATED FROM PLACEHOLDER
      case 2:
        return const FleetMapPage();
      case 3:
        return const EvolutionTimelinePage();
      default:
        return const TriageQueuePage();
    }
  }
}
