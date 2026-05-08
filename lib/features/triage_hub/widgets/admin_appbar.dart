import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local2local/features/triage_hub/theme/admin_theme.dart';
import 'package:local2local/features/triage_hub/providers/environment_provider.dart';
import 'package:local2local/features/triage_hub/providers/superadmin_providers.dart';

class AdminAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  const AdminAppBar({super.key, required this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionAsync = ref.watch(currentVersionStreamProvider);
    final envState = ref.watch(environmentProvider);
    final isProd = envState.environment == L2LEnvironment.prod;

    return AppBar(
      backgroundColor: AdminColors.slateDarkest,
      elevation: 1,
      shadowColor: Colors.black,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AdminColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
          Text(
            versionAsync.when(
              data: (version) => 'Build: $version',
              loading: () => 'Build: ...',
              error: (_, __) => 'Build: –',
            ),
            style: const TextStyle(color: AdminColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
      actions: [
        Center(
          child: PopupMenuButton<L2LEnvironment>(
            offset: const Offset(0, 40),
            color: AdminColors.slateDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: AdminColors.borderDefault),
            ),
            onSelected: (env) => ref.read(environmentProvider.notifier).setEnvironment(env, context),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: L2LEnvironment.dev,
                child: Text('DEV', style: TextStyle(color: AdminColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              PopupMenuItem(
                value: L2LEnvironment.prod,
                child: Text('PROD', style: TextStyle(color: AdminColors.rubyRed, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AdminColors.slateDark,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: isProd ? AdminColors.rubyRed : AdminColors.borderDefault),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isProd ? 'PROD' : 'DEV',
                    style: TextStyle(color: isProd ? AdminColors.rubyRed : AdminColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down_rounded, color: isProd ? AdminColors.rubyRed : AdminColors.textPrimary, size: 16),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Center(
          child: Text(
            'PROJECT: ${envState.projectId}',
            style: const TextStyle(color: AdminColors.emeraldGreen, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 16),
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded, color: AdminColors.textPrimary),
          onPressed: () {},
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
