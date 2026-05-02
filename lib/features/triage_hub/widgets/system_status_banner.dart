import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local2local/features/triage_hub/theme/admin_theme.dart';
import 'package:local2local/features/triage_hub/providers/superadmin_providers.dart';

class SystemStatusBanner extends ConsumerWidget {
  const SystemStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(systemStatusStreamProvider);
    final versionAsync = ref.watch(currentVersionStreamProvider);

    return statusAsync.when(
      data: (status) {
        final Color color = _getStatusColor(status);
        final IconData icon = _getStatusIcon(status);

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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TELEMETRY HEALTH: $status',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: 1.2,
                    ),
                  ),
                  versionAsync.when(
                    data: (v) => Text(
                      'CORE VERSION: $v',
                      style: TextStyle(
                        color: color.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                status == 'RED' ? 'DEPLOYMENTS LOCKED' : 'Code modifications permitted',
                style: TextStyle(
                  color: color.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              )
            ],
          ),
        );
      },
      loading: () => const LinearProgressIndicator(color: AdminColors.emeraldGreen),
      error: (e, _) => Text('Telemetry Offline: $e', style: const TextStyle(color: AdminColors.rubyRed)),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'GREEN':
        return AdminColors.emeraldGreen;
      case 'YELLOW':
        return Colors.orangeAccent;
      case 'RED':
        return AdminColors.rubyRed;
      default:
        return AdminColors.textSecondary;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'GREEN':
        return Icons.check_circle_rounded;
      case 'YELLOW':
        return Icons.warning_rounded;
      case 'RED':
        return Icons.dangerous_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }
}