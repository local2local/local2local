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
        final statusColor = _getStatusColor(status);
        final statusIcon = _getStatusIcon(status);
        final backgroundColor = _getBackgroundColor(status);
        final borderColor = _getBorderColor(status);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border(
              left: BorderSide(color: borderColor, width: 4),
            ),
          ),
          child: Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 28),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TELEMETRY HEALTH: $status',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: 1.2,
                    ),
                  ),
                  versionAsync.when(
                    data: (v) => Text(
                      'CORE VERSION: $v',
                      style: const TextStyle(
                        color: AdminColors.textSecondary,
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
                _getStatusMessage(status),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                ),
              ),
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
        return AdminColors.statusWarning;
      case 'RED':
        return AdminColors.rubyRed;
      default:
        return AdminColors.slateLight;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'GREEN':
        return Icons.check_circle;
      case 'YELLOW':
        return Icons.warning;
      case 'RED':
        return Icons.error;
      default:
        return Icons.help_outline;
    }
  }

  Color _getBackgroundColor(String status) {
    if (status == 'RED') {
      return AdminColors.rubyRed.withValues(alpha: 0.08);
    }
    return AdminColors.slateDark;
  }

  Color _getBorderColor(String status) {
    switch (status) {
      case 'GREEN':
        return AdminColors.emeraldGreen;
      case 'YELLOW':
        return AdminColors.statusWarning;
      case 'RED':
        return AdminColors.rubyRed;
      default:
        return AdminColors.slateLight;
    }
  }

  String _getStatusMessage(String status) {
    switch (status) {
      case 'GREEN':
        return 'Code modifications permitted';
      case 'YELLOW':
        return 'System operating below standard — limit deployment change rate';
      case 'RED':
        return 'Code blocked by orchestrator — chat override required to bypass';
      default:
        return 'Status unknown';
    }
  }
}
