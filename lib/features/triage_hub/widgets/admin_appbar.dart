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
      padding: const EdgeInsets.only(
          left: 16,
          right: 8), // Adjusted padding for better right-justification
      child: Row(
        children: [
          // 1. App Title
          Text(
            widget.title,
            style: const TextStyle(
                color: AdminColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 20),

          // 2. Environment Selector
          _EnvironmentBadge(
            environment: currentEnv,
            onChanged: (env) => ref
                .read(currentEnvironmentProvider.notifier)
                .setEnvironment(env),
          ),
          const SizedBox(width: 12),

          // 3. Tenant Selector
          _TenantSelector(
            currentApp: currentApp,
            onChanged: (tenant) =>
                ref.read(currentAppProvider.notifier).setApp(tenant),
          ),

          // 4. Elastic Space to push content to the right
          const Spacer(),

          // 5. Right-Justified Notifications
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_outlined,
                size: 22, color: AdminColors.textSecondary),
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
      AppEnvironment.prod => AdminColors.rubyRed,
      AppEnvironment.dev => AdminColors.statusInfo,
    };

    return PopupMenuButton<AppEnvironment>(
      initialValue: environment,
      onSelected: onChanged,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: badgeColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(environment.label,
                style: TextStyle(
                    color: badgeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 16, color: badgeColor),
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
        padding: const EdgeInsets.symmetric(horizontal: 4),
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
      segments: AppTenant.values
          .map((t) => ButtonSegment(
                value: t,
                label: Text(t.displayName.toUpperCase()),
              ))
          .toList(),
      selected: {currentApp},
      onSelectionChanged: (set) => onChanged(set.first),
    );
  }
}