import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local2local/features/triage_hub/providers/app_providers.dart';
import 'package:local2local/features/triage_hub/theme/admin_theme.dart';

/// Navigation item definition
class NavItem {
  final String label;
  final IconData icon;
  final String route;
  final bool showBadge;

  const NavItem({
    required this.label,
    required this.icon,
    required this.route,
    this.showBadge = false,
  });
}

/// Admin Sidebar navigation items
const List<NavItem> adminNavItems = [
  NavItem(
    label: 'Triage Hub',
    icon: Icons.dashboard_rounded,
    route: '/triage-hub',
    showBadge: true,
  ),
  NavItem(
    label: 'Health Grid',
    icon: Icons.monitor_heart_rounded,
    route: '/health-grid',
  ),
  NavItem(
    label: 'Fleet Map',
    icon: Icons.map_rounded,
    route: '/fleet-map',
  ),
  NavItem(
    label: 'Evolution Timeline',
    icon: Icons.history_rounded,
    route: '/evolution-timeline',
  ),
];

/// Persistent Left Sidebar for Super Admin Hub
class AdminSidebar extends ConsumerWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const AdminSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: AdminColors.slateDark,
        border: Border(
          right: BorderSide(color: AdminColors.borderDefault, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Logo/Brand Section
          _buildBrandHeader(),
          const Divider(height: 1),
          // Navigation Items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: adminNavItems.length,
              itemBuilder: (context, index) {
                final item = adminNavItems[index];
                final isSelected = selectedIndex == index;
                return _NavItemTile(
                  item: item,
                  isSelected: isSelected,
                  onTap: () => onItemSelected(index),
                );
              },
            ),
          ),
          // Footer
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AdminColors.emeraldGreen,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.hub_rounded,
              color: AdminColors.slateDarkest,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Super Admin',
                  style: TextStyle(
                    color: AdminColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Triage Hub',
                  style: TextStyle(
                    color: AdminColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AdminColors.borderDefault)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AdminColors.slateMedium,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: AdminColors.textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin User',
                  style: TextStyle(
                    color: AdminColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Super Admin',
                  style: TextStyle(
                    color: AdminColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 18),
            color: AdminColors.textSecondary,
            onPressed: () {},
            tooltip: 'Logout',
          ),
        ],
      ),
    );
  }
}

/// Individual navigation item tile with badge support
class _NavItemTile extends ConsumerWidget {
  final NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItemTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interventionCount = ref.watch(activeInterventionCountProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isSelected
            ? AdminColors.emeraldGreen.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          hoverColor: AdminColors.slateLight.withValues(alpha: 0.5),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: isSelected
                      ? AdminColors.emeraldGreen
                      : AdminColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: isSelected
                          ? AdminColors.emeraldGreen
                          : AdminColors.textPrimary,
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                // Intervention Badge
                if (item.showBadge)
                  interventionCount.when(
                    data: (count) => count > 0
                        ? _InterventionBadge(count: count)
                        : const SizedBox.shrink(),
                    loading: () => const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AdminColors.textMuted,
                      ),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Red badge showing active intervention count
class _InterventionBadge extends StatelessWidget {
  final int count;

  const _InterventionBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AdminColors.rubyRed,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
