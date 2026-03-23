import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local2local/features/triage_hub/providers/app_providers.dart';
import 'package:local2local/features/triage_hub/theme/admin_theme.dart';

/// Top AppBar for Super Admin Hub with tenant selector, environment badge, and global search
class AdminAppBar extends ConsumerStatefulWidget implements PreferredSizeWidget {
  final String title;

  const AdminAppBar({super.key, required this.title});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  ConsumerState<AdminAppBar> createState() => _AdminAppBarState();
}

class _AdminAppBarState extends ConsumerState<AdminAppBar> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  bool _isSearchExpanded = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchSubmit(String query) {
    if (query.trim().isEmpty) return;
    ref.read(searchQueryProvider.notifier).state = query.trim();
    // Show search results dialog
    _showSearchResults(context, query.trim());
  }

  void _showSearchResults(BuildContext context, String query) {
    showDialog(
      context: context,
      builder: (ctx) => _SearchResultsDialog(query: query),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentApp = ref.watch(currentAppProvider);
    final currentEnv = ref.watch(currentEnvironmentProvider);

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
              widget.title,
              style: const TextStyle(
                color: AdminColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Global Search
          _GlobalSearchField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            isExpanded: _isSearchExpanded,
            onToggle: () => setState(() => _isSearchExpanded = !_isSearchExpanded),
            onSubmit: _onSearchSubmit,
          ),
          const SizedBox(width: 16),
          // Environment Badge
          _EnvironmentBadge(
            environment: currentEnv,
            onChanged: (env) {
              ref.read(currentEnvironmentProvider.notifier).setEnvironment(env);
            },
          ),
          const SizedBox(width: 16),
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

/// Global search field with expandable UI
class _GlobalSearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Function(String) onSubmit;

  const _GlobalSearchField({
    required this.controller,
    required this.focusNode,
    required this.isExpanded,
    required this.onToggle,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isExpanded ? 280 : 40,
      height: 40,
      decoration: BoxDecoration(
        color: isExpanded ? AdminColors.slateMedium : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isExpanded ? Border.all(color: AdminColors.borderDefault) : null,
      ),
      child: isExpanded
          ? Row(
              children: [
                const SizedBox(width: 12),
                const Icon(Icons.search, color: AdminColors.textMuted, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    style: const TextStyle(color: AdminColors.textPrimary, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Search Order ID, Agent ID...',
                      hintStyle: TextStyle(color: AdminColors.textMuted, fontSize: 14),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: onSubmit,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: AdminColors.textMuted,
                  onPressed: () {
                    controller.clear();
                    onToggle();
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            )
          : IconButton(
              icon: const Icon(Icons.search),
              color: AdminColors.textSecondary,
              onPressed: () {
                onToggle();
                focusNode.requestFocus();
              },
              tooltip: 'Global Search',
            ),
    );
  }
}

/// Environment badge with dropdown
class _EnvironmentBadge extends StatelessWidget {
  final AppEnvironment environment;
  final Function(AppEnvironment) onChanged;

  const _EnvironmentBadge({
    required this.environment,
    required this.onChanged,
  });

  Color get badgeColor {
    switch (environment) {
      case AppEnvironment.prod:
        return AdminColors.emeraldGreen;
      case AppEnvironment.staging:
        return AdminColors.statusWarning;
      case AppEnvironment.dev:
        return AdminColors.statusInfo;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AppEnvironment>(
      initialValue: environment,
      onSelected: onChanged,
      tooltip: 'Environment',
      offset: const Offset(0, 48),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              environment.label,
              style: TextStyle(
                color: badgeColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, color: badgeColor, size: 16),
          ],
        ),
      ),
      itemBuilder: (context) => AppEnvironment.values.map((env) {
        final isSelected = env == environment;
        final color = switch (env) {
          AppEnvironment.prod => AdminColors.emeraldGreen,
          AppEnvironment.staging => AdminColors.statusWarning,
          AppEnvironment.dev => AdminColors.statusInfo,
        };
        return PopupMenuItem<AppEnvironment>(
          value: env,
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                env.displayName,
                style: TextStyle(
                  color: isSelected ? color : AdminColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              const Spacer(),
              if (isSelected) Icon(Icons.check, color: color, size: 18),
            ],
          ),
        );
      }).toList(),
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

/// Search results dialog
class _SearchResultsDialog extends StatelessWidget {
  final String query;

  const _SearchResultsDialog({required this.query});

  @override
  Widget build(BuildContext context) {
    // Mock search results
    final results = <Map<String, dynamic>>[
      if (query.toUpperCase().contains('ORD') || query.contains('99'))
        {'type': 'Order', 'id': 'ORD_9912', 'status': 'Pending Verification'},
      if (query.toUpperCase().contains('TXN') || query.contains('78'))
        {'type': 'Transaction', 'id': 'TXN_78234', 'status': 'Awaiting Approval'},
      if (query.toUpperCase().contains('ORCH') || query.toLowerCase().contains('finance'))
        {'type': 'Agent', 'id': 'orch_finance', 'status': 'Online'},
    ];

    return Dialog(
      backgroundColor: AdminColors.slateMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AdminColors.borderDefault),
      ),
      child: Container(
        width: 480,
        constraints: const BoxConstraints(maxHeight: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.search, color: AdminColors.emeraldGreen),
                const SizedBox(width: 12),
                Text(
                  'Search Results for "$query"',
                  style: const TextStyle(
                    color: AdminColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: AdminColors.textMuted,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: AdminColors.borderDefault),
            const SizedBox(height: 16),
            if (results.isEmpty)
              const Center(
                child: Column(
                  children: [
                    Icon(Icons.search_off, color: AdminColors.textMuted, size: 48),
                    SizedBox(height: 12),
                    Text(
                      'No results found',
                      style: TextStyle(color: AdminColors.textMuted),
                    ),
                  ],
                ),
              )
            else
              ...results.map((result) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AdminColors.slateDark,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AdminColors.borderDefault),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AdminColors.emeraldGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            result['type'] as String,
                            style: const TextStyle(
                              color: AdminColors.emeraldGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                result['id'] as String,
                                style: const TextStyle(
                                  color: AdminColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                result['status'] as String,
                                style: const TextStyle(
                                  color: AdminColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          color: AdminColors.textMuted,
                          size: 14,
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
