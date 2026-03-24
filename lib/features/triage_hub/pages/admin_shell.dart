import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_sidebar.dart';
import '../widgets/admin_appbar.dart';
import '../providers/app_providers.dart';

/// Main shell layout for Super Admin Hub
/// Re-uses the centralized selectedNavIndexProvider
class AdminShell extends ConsumerWidget {
  final Widget child;

  const AdminShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedNavIndexProvider);
    final pageTitle = adminNavItems[selectedIndex].label;

    return Scaffold(
      backgroundColor: AdminColors.slateDarkest,
      body: Row(
        children: [
          AdminSidebar(
            selectedIndex: selectedIndex,
            onItemSelected: (index) {
              ref.read(selectedNavIndexProvider.notifier).setIndex(index);
            },
          ),
          Expanded(
            child: Column(
              children: [
                AdminAppBar(title: pageTitle),
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
