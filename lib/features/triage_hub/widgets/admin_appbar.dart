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
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: Text(widget.title,
                style: const TextStyle(
                    color: AdminColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 16),
          _EnvironmentBadge(
            environment: currentEnv,
            onChanged: (env) => ref
                .read(currentEnvironmentProvider.notifier)
                .setEnvironment(env),
          ),
          const SizedBox(width: 16),
          _TenantSelector(
            currentApp: currentApp,
            onChanged: (tenant) =>
                ref.read(currentAppProvider.notifier).setApp(tenant),
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
    // FIX: Exhaustive switch ensures a Color is always returned
    final Color badgeColor = switch (environment) {
      AppEnvironment.prod => AdminColors.emeraldGreen,
      AppEnvironment.staging => AdminColors.statusWarning,
      AppEnvironment.dev => AdminColors.statusInfo,
    };

    return PopupMenuButton<AppEnvironment>(
      initialValue: environment,
      onSelected: onChanged,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: badgeColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: badgeColor.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: badgeColor, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(environment.label,
                style: TextStyle(
                    color: badgeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, color: badgeColor, size: 16),
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
      segments: AppTenant.values
          .map((t) => ButtonSegment(value: t, label: Text(t.displayName)))
          .toList(),
      selected: {currentApp},
      onSelectionChanged: (set) => onChanged(set.first),
    );
  }
}
