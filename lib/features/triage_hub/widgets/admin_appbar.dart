import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local2local/features/triage_hub/providers/app_providers.dart';
import 'package:local2local/features/triage_hub/theme/admin_theme.dart';

class AdminAppBar extends ConsumerStatefulWidget
    implements PreferredSizeWidget {
  final String title;
  const AdminAppBar({super.key, required this.title});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  ConsumerState<AdminAppBar> createState() => _AdminAppBarState();
}

class _AdminAppBarState extends ConsumerState<AdminAppBar> {
  @override
  Widget build(BuildContext context) {
    final currentApp = ref.watch(currentAppProvider);
    final currentEnv = ref.watch(currentEnvironmentProvider);

    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: AdminColors.slateDark,
        border: Border(
            bottom: BorderSide(color: AdminColors.borderDefault, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16), // Reduced padding
      child: Row(
        children: [
          // Use Flexible to prevent the title from pushing everything off screen
          Flexible(
            child: Text(
              widget.title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AdminColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          _EnvironmentBadge(
            environment: currentEnv,
            onChanged: (env) => ref
                .read(currentEnvironmentProvider.notifier)
                .setEnvironment(env),
          ),
          const SizedBox(width: 8),
          // Wrapped in Flexible so the toggle shrinks on smaller windows
          Flexible(
            child: _TenantSelector(
              currentApp: currentApp,
              onChanged: (tenant) =>
                  ref.read(currentAppProvider.notifier).setApp(tenant),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, size: 20),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

class _EnvironmentBadge extends StatelessWidget {
  final AppEnvironment environment;
  final Function(AppEnvironment) onChanged;
  const _EnvironmentBadge({required this.environment, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final Color badgeColor = switch (environment) {
      AppEnvironment.prod => AdminColors.emeraldGreen,
      AppEnvironment.staging => AdminColors.statusWarning,
      AppEnvironment.dev => AdminColors.statusInfo,
    };

    return PopupMenuButton<AppEnvironment>(
      initialValue: environment,
      onSelected: onChanged,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: badgeColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: badgeColor.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(environment.label,
                style: TextStyle(
                    color: badgeColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
            const Icon(Icons.arrow_drop_down, size: 14),
          ],
        ),
      ),
      itemBuilder: (context) => AppEnvironment.values
          .map((env) => PopupMenuItem(value: env, child: Text(env.displayName)))
          .toList(),
    );
  }
}

class _TenantSelector extends StatelessWidget {
  final AppTenant currentApp;
  final Function(AppTenant) onChanged;
  const _TenantSelector({required this.currentApp, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<AppTenant>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        textStyle: const TextStyle(fontSize: 11),
      ),
      segments: AppTenant.values
          .map((t) => ButtonSegment(
                value: t,
                label: Text(t.displayName.substring(0, 4)), // Compact labels
              ))
          .toList(),
      selected: {currentApp},
      onSelectionChanged: (set) => onChanged(set.first),
    );
  }
}
