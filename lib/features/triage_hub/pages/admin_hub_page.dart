import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Use direct relative imports to bypass the barrel file completely
import '../providers/app_providers.dart';
import 'admin_shell.dart';
import 'triage_queue_page.dart';
import 'health_grid_page.dart';
import 'fleet_map_page.dart';
import 'evolution_timeline_page.dart';

/// Main Admin Hub Page that combines shell with content switching
class AdminHubPage extends ConsumerWidget {
  const AdminHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the centralized navigation provider from app_providers.dart
    final selectedIndex = ref.watch(selectedNavIndexProvider);

    return AdminShell(
      child: _buildPageContent(selectedIndex),
    );
  }

  Widget _buildPageContent(int index) {
    switch (index) {
      case 0:
        return const TriageQueuePage();
      case 1:
        return const HealthGridPage();
      case 2:
        return const FleetMapPage();
      case 3:
        return const EvolutionTimelinePage();
      default:
        return const TriageQueuePage();
    }
  }
}
