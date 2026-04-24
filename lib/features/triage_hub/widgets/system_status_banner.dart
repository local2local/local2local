import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local2local/features/triage_hub/theme/admin_theme.dart';

final systemStatusProvider = StreamProvider<String>((ref) {
  return FirebaseFirestore.instance
      .doc('artifacts/system_status/public/data/telemetry/current')
      .snapshots()
      .map((snap) => snap.data()?['status'] as String? ?? 'GREEN');
});

class SystemStatusBanner extends ConsumerWidget {
  const SystemStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(systemStatusProvider);

    return statusAsync.when(
      data: (status) {
        Color color = AdminColors.emeraldGreen;
        IconData icon = Icons.check_circle_rounded;
        String text = 'TELEMETRY HEALTH: STABLE';
        String subtext = 'Code modifications permitted';

        if (status == 'YELLOW') {
          color = Colors.orange.shade400;
          icon = Icons.warning_amber_rounded;
          text = 'TELEMETRY HEALTH: WARNING';
          subtext = 'Feature deployments delayed by 60s';
        } else if (status == 'RED') {
          color = AdminColors.rubyRed;
          icon = Icons.error_outline_rounded;
          text = 'TELEMETRY HEALTH: CRITICAL';
          subtext = 'Feature deployments completely blocked';
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            border: Border.all(color: color.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 16),
              Text(
                text,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                subtext,
                style: TextStyle(
                  color: color.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              )
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        color: AdminColors.slateDark,
        child: const Text("TELEMETRY DISCONNECTED", style: TextStyle(color: AdminColors.textSecondary)),
      ),
    );
  }
}