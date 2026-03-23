import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local2local/features/triage_hub/providers/app_providers.dart';
import 'package:local2local/features/triage_hub/theme/admin_theme.dart';

/// Evolution Timeline Page - Historical view of system changes
class EvolutionTimelinePage extends ConsumerWidget {
  const EvolutionTimelinePage({super.key});

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
                      Icons.history_rounded,
                      color: AdminColors.emeraldGreen,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Evolution Timeline',
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
                  'Track system evolution, deployments, and configuration changes over time.',
                  style: TextStyle(
                    color: AdminColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Timeline
          _TimelineView(),
        ],
      ),
    );
  }
}

class _TimelineView extends StatelessWidget {
  final events = const [
    {
      'date': 'Today',
      'time': '14:32',
      'title': 'Configuration Update',
      'description': 'Updated rate limiting rules for API gateway',
      'type': 'config',
    },
    {
      'date': 'Today',
      'time': '09:15',
      'title': 'Deployment v2.4.1',
      'description': 'Rolled out performance improvements to all regions',
      'type': 'deploy',
    },
    {
      'date': 'Yesterday',
      'time': '18:45',
      'title': 'Incident Resolved',
      'description': 'High latency issue in EU region resolved',
      'type': 'incident',
    },
    {
      'date': 'Yesterday',
      'time': '16:20',
      'title': 'Scaling Event',
      'description': 'Auto-scaled to 12 nodes in US-East',
      'type': 'scale',
    },
    {
      'date': '3 days ago',
      'time': '11:00',
      'title': 'Deployment v2.4.0',
      'description': 'Major feature release: Real-time analytics dashboard',
      'type': 'deploy',
    },
  ];

  Color _getTypeColor(String type) {
    switch (type) {
      case 'deploy':
        return AdminColors.emeraldGreen;
      case 'incident':
        return AdminColors.rubyRed;
      case 'config':
        return AdminColors.statusInfo;
      case 'scale':
        return AdminColors.statusWarning;
      default:
        return AdminColors.textMuted;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'deploy':
        return Icons.rocket_launch_rounded;
      case 'incident':
        return Icons.warning_rounded;
      case 'config':
        return Icons.settings_rounded;
      case 'scale':
        return Icons.trending_up_rounded;
      default:
        return Icons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: events.asMap().entries.map((entry) {
        final index = entry.key;
        final event = entry.value;
        final isLast = index == events.length - 1;
        final color = _getTypeColor(event['type'] as String);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline rail
            SizedBox(
              width: 60,
              child: Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getTypeIcon(event['type'] as String),
                      size: 16,
                      color: color,
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 80,
                      color: AdminColors.borderDefault,
                    ),
                ],
              ),
            ),
            // Event content
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
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
                        Text(
                          event['title'] as String,
                          style: const TextStyle(
                            color: AdminColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${event['date']} • ${event['time']}',
                          style: const TextStyle(
                            color: AdminColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      event['description'] as String,
                      style: const TextStyle(
                        color: AdminColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
