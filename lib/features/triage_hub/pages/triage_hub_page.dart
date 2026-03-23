import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local2local/features/triage_hub/providers/app_providers.dart';
import 'package:local2local/features/triage_hub/theme/admin_theme.dart';

/// Triage Hub Dashboard Page
class TriageHubPage extends ConsumerWidget {
  const TriageHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentApp = ref.watch(currentAppProvider);
    final interventionCount = ref.watch(activeInterventionCountProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Row
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Active Interventions',
                  value: interventionCount.when(
                    data: (count) => count.toString(),
                    loading: () => '...',
                    error: (_, __) => '-',
                  ),
                  icon: Icons.warning_amber_rounded,
                  color: AdminColors.rubyRed,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: _StatCard(
                  title: 'System Health',
                  value: '98%',
                  icon: Icons.favorite_rounded,
                  color: AdminColors.emeraldGreen,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: _StatCard(
                  title: 'Active Nodes',
                  value: '24',
                  icon: Icons.hub_rounded,
                  color: AdminColors.statusInfo,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: _StatCard(
                  title: 'Pending Tasks',
                  value: '7',
                  icon: Icons.pending_actions_rounded,
                  color: AdminColors.statusWarning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Current App Info
          Container(
            padding: const EdgeInsets.all(20),
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AdminColors.emeraldGreen.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            currentApp == AppTenant.kaskflow
                                ? Icons.water_drop_rounded
                                : Icons.nightlight_round,
                            size: 16,
                            color: AdminColors.emeraldGreen,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            currentApp.displayName,
                            style: const TextStyle(
                              color: AdminColors.emeraldGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'App ID: ${currentApp.id}',
                      style: const TextStyle(
                        color: AdminColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Triage Hub Dashboard',
                  style: TextStyle(
                    color: AdminColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Monitor and manage active interventions across your application fleet. '
                  'Switch between tenants using the selector in the top bar.',
                  style: TextStyle(
                    color: AdminColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Placeholder for Intervention List
          const Text(
            'Recent Interventions',
            style: TextStyle(
              color: AdminColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _InterventionList(appId: currentApp.id),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Icon(
                Icons.trending_up_rounded,
                color: AdminColors.textMuted,
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              color: AdminColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: AdminColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _InterventionList extends StatelessWidget {
  final String appId;

  const _InterventionList({required this.appId});

  @override
  Widget build(BuildContext context) {
    // Mock data - in production would come from Firestore
    final interventions = appId == 'kaskflow'
        ? [
            _InterventionItem(
              title: 'High CPU Usage Alert',
              status: 'active',
              time: '2 min ago',
            ),
            _InterventionItem(
              title: 'Memory Leak Detected',
              status: 'active',
              time: '5 min ago',
            ),
            _InterventionItem(
              title: 'Network Timeout',
              status: 'resolved',
              time: '1 hour ago',
            ),
            _InterventionItem(
              title: 'Database Connection Pool',
              status: 'active',
              time: '3 hours ago',
            ),
          ]
        : [
            _InterventionItem(
              title: 'API Rate Limit',
              status: 'active',
              time: '10 min ago',
            ),
            _InterventionItem(
              title: 'SSL Certificate Expiry',
              status: 'resolved',
              time: '2 days ago',
            ),
          ];

    return Container(
      decoration: BoxDecoration(
        color: AdminColors.slateMedium,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.borderDefault),
      ),
      child: Column(
        children: interventions
            .map((item) => _InterventionTile(intervention: item))
            .toList(),
      ),
    );
  }
}

class _InterventionItem {
  final String title;
  final String status;
  final String time;

  const _InterventionItem({
    required this.title,
    required this.status,
    required this.time,
  });
}

class _InterventionTile extends StatelessWidget {
  final _InterventionItem intervention;

  const _InterventionTile({required this.intervention});

  @override
  Widget build(BuildContext context) {
    final isActive = intervention.status == 'active';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AdminColors.borderDefault, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive ? AdminColors.rubyRed : AdminColors.emeraldGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  intervention.title,
                  style: const TextStyle(
                    color: AdminColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  intervention.time,
                  style: const TextStyle(
                    color: AdminColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isActive
                  ? AdminColors.rubyRed.withValues(alpha: 0.15)
                  : AdminColors.emeraldGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              intervention.status.toUpperCase(),
              style: TextStyle(
                color: isActive ? AdminColors.rubyRed : AdminColors.emeraldGreen,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
