import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local2local/features/triage_hub/providers/app_providers.dart';
import 'package:local2local/features/triage_hub/theme/admin_theme.dart';

/// Health Grid Page - System monitoring dashboard
class HealthGridPage extends ConsumerWidget {
  const HealthGridPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentApp = ref.watch(currentAppProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AdminColors.slateMedium,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AdminColors.borderDefault),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.monitor_heart_rounded,
                      color: AdminColors.emeraldGreen,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Health Grid',
                      style: TextStyle(
                        color: AdminColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AdminColors.emeraldGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        currentApp.displayName,
                        style: const TextStyle(
                          color: AdminColors.emeraldGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Real-time system health monitoring across all nodes and services.',
                  style: TextStyle(
                    color: AdminColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Placeholder grid
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: const [
              _HealthTile(name: 'API Gateway', status: 'healthy', uptime: '99.9%'),
              _HealthTile(name: 'Database', status: 'healthy', uptime: '99.8%'),
              _HealthTile(name: 'Cache Layer', status: 'warning', uptime: '98.5%'),
              _HealthTile(name: 'Auth Service', status: 'healthy', uptime: '100%'),
              _HealthTile(name: 'Storage', status: 'healthy', uptime: '99.7%'),
              _HealthTile(name: 'CDN', status: 'degraded', uptime: '95.2%'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HealthTile extends StatelessWidget {
  final String name;
  final String status;
  final String uptime;

  const _HealthTile({
    required this.name,
    required this.status,
    required this.uptime,
  });

  Color get statusColor {
    switch (status) {
      case 'healthy':
        return AdminColors.emeraldGreen;
      case 'warning':
        return AdminColors.statusWarning;
      case 'degraded':
        return AdminColors.rubyRed;
      default:
        return AdminColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.slateMedium,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                name,
                style: const TextStyle(
                  color: AdminColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                uptime,
                style: const TextStyle(
                  color: AdminColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                status.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
