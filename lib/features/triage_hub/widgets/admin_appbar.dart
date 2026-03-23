import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local2local/features/triage_hub/providers/app_providers.dart';
import 'package:local2local/features/triage_hub/theme/admin_theme.dart';

/// Top AppBar for Super Admin Hub with tenant selector
class AdminAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;

  const AdminAppBar({super.key, required this.title});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentApp = ref.watch(currentAppProvider);

    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: AdminColors.slateDark,
        border: Border(
          bottom: BorderSide(color: AdminColors.borderDefault, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Page Title
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AdminColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Tenant Selector
          _TenantSelector(
            currentApp: currentApp,
            onChanged: (tenant) {
              ref.read(currentAppProvider.notifier).setApp(tenant);
            },
          ),
          const SizedBox(width: 16),
          // Notification Bell
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            color: AdminColors.textSecondary,
            onPressed: () {},
            tooltip: 'Notifications',
          ),
          const SizedBox(width: 8),
          // Settings
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            color: AdminColors.textSecondary,
            onPressed: () {},
            tooltip: 'Settings',
          ),
        ],
      ),
    );
  }
}

/// Dropdown/Segmented button for tenant selection
class _TenantSelector extends StatelessWidget {
  final AppTenant currentApp;
  final Function(AppTenant) onChanged;

  const _TenantSelector({
    required this.currentApp,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.slateMedium,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AdminColors.borderDefault),
      ),
      child: SegmentedButton<AppTenant>(
        segments: AppTenant.values.map((tenant) {
          return ButtonSegment<AppTenant>(
            value: tenant,
            label: Text(tenant.displayName),
            icon: Icon(
              tenant == AppTenant.kaskflow
                  ? Icons.water_drop_rounded
                  : Icons.nightlight_round,
              size: 16,
            ),
          );
        }).toList(),
        selected: {currentApp},
        onSelectionChanged: (Set<AppTenant> selection) {
          if (selection.isNotEmpty) {
            onChanged(selection.first);
          }
        },
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AdminColors.emeraldGreen.withValues(alpha: 0.2);
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AdminColors.emeraldGreen;
            }
            return AdminColors.textSecondary;
          }),
          side: WidgetStateProperty.all(BorderSide.none),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
        showSelectedIcon: false,
      ),
    );
  }
}
