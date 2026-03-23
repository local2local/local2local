import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local2local/features/triage_hub/triage_hub.dart';

/// Main Admin Hub Page that combines shell with content switching
class AdminHubPage extends ConsumerWidget {
  const AdminHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedNavIndexProvider);

    return AdminShell(
      child: _buildPageContent(selectedIndex),
    );
  }

  Widget _buildPageContent(int index) {
    switch (index) {
      case 0:
        return const TriageHubPage();
      case 1:
        return const HealthGridPage();
      case 2:
        return const FleetMapPage();
      case 3:
        return const EvolutionTimelinePage();
      default:
        return const TriageHubPage();
    }
  }
}
