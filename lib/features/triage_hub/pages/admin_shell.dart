import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local2local/features/triage_hub/theme/admin_theme.dart';
import 'package:local2local/features/triage_hub/widgets/admin_sidebar.dart';
import 'package:local2local/features/triage_hub/widgets/admin_appbar.dart';

/// Notifier for tracking selected navigation index
class SelectedNavIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) => state = index;
}

/// Provider for tracking selected navigation index
final selectedNavIndexProvider = NotifierProvider<SelectedNavIndexNotifier, int>(
  SelectedNavIndexNotifier.new,
);

/// Main shell layout for Super Admin Hub
/// Provides persistent sidebar and top appbar with child content area
class AdminShell extends ConsumerWidget {
  final Widget child;

  const AdminShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedNavIndexProvider);

    // Get the current page title based on selected index
    final pageTitle = adminNavItems[selectedIndex].label;

    return Scaffold(
      backgroundColor: AdminColors.slateDarkest,
      body: Row(
        children: [
          // Persistent Left Sidebar
          AdminSidebar(
            selectedIndex: selectedIndex,
            onItemSelected: (index) {
              ref.read(selectedNavIndexProvider.notifier).setIndex(index);
            },
          ),
          // Main Content Area
          Expanded(
            child: Column(
              children: [
                // Top AppBar
                AdminAppBar(title: pageTitle),
                // Page Content
                Expanded(
                  child: Container(
                    color: AdminColors.slateDarkest,
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
