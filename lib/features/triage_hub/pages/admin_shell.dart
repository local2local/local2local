import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local2local/features/auth/providers/auth_provider.dart';
import 'package:local2local/features/triage_hub/providers/app_providers.dart';
import 'package:local2local/features/triage_hub/theme/admin_theme.dart';
import 'package:local2local/features/triage_hub/widgets/admin_appbar.dart';

class AdminShell extends ConsumerWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedNavIndexProvider);
    final activeInterventionsAsync = ref.watch(activeInterventionCountProvider);

    return Scaffold(
      backgroundColor: AdminColors.slateDarkest,
      appBar: const AdminAppBar(title: 'L2LAAF Cockpit'),
      body: Row(
        children: [
          // Sidebar Navigation
          NavigationRail(
            backgroundColor: AdminColors.slateDark,
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) =>
                ref.read(selectedNavIndexProvider.notifier).setIndex(index),
            labelType: NavigationRailLabelType.all,
            unselectedLabelTextStyle:
                const TextStyle(color: AdminColors.textSecondary, fontSize: 11),
            selectedLabelTextStyle: const TextStyle(
                color: AdminColors.emeraldGreen,
                fontSize: 11,
                fontWeight: FontWeight.bold),
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child:
                  Icon(Icons.radar, color: AdminColors.emeraldGreen, size: 32),
            ),
            // LOWER LEFT ACTIONS (Trailing)
            trailing: Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // This is the logout button you see in the lower left
                  IconButton(
                    tooltip: 'Sign Out',
                    icon: const Icon(Icons.exit_to_app_rounded,
                        color: AdminColors.rubyRed),
                    onPressed: () async {
                      // Handshake with Firebase Auth
                      await ref.read(authActionProvider.notifier).logout();
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            destinations: [
              NavigationRailDestination(
                icon: Badge(
                  label: activeInterventionsAsync.when(
                    data: (count) => Text(count.toString()),
                    loading: () => const Text('...'),
                    error: (_, __) => const Text('!'),
                  ),
                  backgroundColor: AdminColors.rubyRed,
                  isLabelVisible: activeInterventionsAsync.asData?.value != 0,
                  child: const Icon(Icons.list_alt_rounded),
                ),
                label: const Text('Triage'),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.grid_view_rounded),
                label: const Text('Health'),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.map_rounded),
                label: const Text('Fleet'),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.history_edu_rounded),
                label: const Text('Evolution'),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.troubleshoot_rounded),
                label: const Text('Diagnostics'),
              ),
            ],
          ),
          // Main Content Area
          const VerticalDivider(width: 1, color: AdminColors.borderDefault),
          Expanded(child: child),
        ],
      ),
    );
  }
}