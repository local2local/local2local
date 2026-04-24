import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local2local/features/triage_hub/theme/admin_theme.dart';

class AdminAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  const AdminAppBar({super.key, required this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      backgroundColor: AdminColors.slateDarkest,
      elevation: 1,
      shadowColor: Colors.black,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          const Text('Build: v42.1.28', style: TextStyle(color: AdminColors.textSecondary, fontSize: 11)),
        ],
      ),
      actions: [
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AdminColors.slateDark,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AdminColors.borderDefault),
            ),
            child: const Row(
              children: [
                Text('DEV', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 16),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        const Center(
          child: Text('PROJECT: local2local-dev', style: TextStyle(color: AdminColors.emeraldGreen, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 16),
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
          onPressed: () {},
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}