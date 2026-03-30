import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local2local/features/triage_hub/models/evolution_event_model.dart';
import 'package:local2local/features/triage_hub/providers/app_providers.dart';
import 'package:local2local/features/triage_hub/theme/admin_theme.dart';

class EvolutionTimelinePage extends ConsumerWidget {
  const EvolutionTimelinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timelineAsync = ref.watch(evolutionTimelineProvider);

    return Container(
      color: AdminColors.slateDarkest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'System Evolution',
                        style: TextStyle(
                          color: AdminColors.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Chronological trace of Agent protocols and L2LAAF milestones.',
                        style: TextStyle(
                            color: AdminColors.textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AdminColors.borderDefault),

          // Timeline List - Now Live
          Expanded(
            child: timelineAsync.when(
              data: (events) {
                if (events.isEmpty) {
                  return const Center(
                    child: Text('No evolution events recorded yet.',
                        style: TextStyle(color: AdminColors.textMuted)),
                  );
                }

                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];
                    return _TimelineEvent(
                      event: event,
                      isLast: index == events.length - 1,
                    );
                  },
                );
              },
              loading: () => const Center(
                  child: CircularProgressIndicator(
                      color: AdminColors.emeraldGreen)),
              error: (e, _) => Center(
                  child: Text('Timeline Link Error: $e',
                      style: const TextStyle(color: AdminColors.rubyRed))),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineEvent extends StatelessWidget {
  final EvolutionEventModel event;
  final bool isLast;

  const _TimelineEvent({
    required this.event,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getEventColor(event.type);
    final icon = _getEventIcon(event.type);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column: The "Strand"
          Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: color.withValues(alpha: 0.3), width: 2),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: AdminColors.borderDefault,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 24),
          // Right Column: The Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        event.timeDisplay.toUpperCase(),
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (event.isAutonomous)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                AdminColors.emeraldGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('AUTONOMOUS',
                              style: TextStyle(
                                  color: AdminColors.emeraldGreen,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    event.title,
                    style: const TextStyle(
                      color: AdminColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AdminColors.slateDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AdminColors.borderDefault),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.description,
                          style: const TextStyle(
                            color: AdminColors.textSecondary,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.token_rounded,
                                size: 12, color: AdminColors.textMuted),
                            const SizedBox(width: 6),
                            Text('Source: ${event.agentName}',
                                style: const TextStyle(
                                    color: AdminColors.textMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getEventColor(EvolutionEventType type) {
    switch (type) {
      case EvolutionEventType.criticalIntervention:
        return AdminColors.rubyRed;
      case EvolutionEventType.rollback:
        return AdminColors.statusWarning;
      case EvolutionEventType.humanOverride:
        return AdminColors.statusInfo;
      default:
        return AdminColors.emeraldGreen;
    }
  }

  IconData _getEventIcon(EvolutionEventType type) {
    switch (type) {
      case EvolutionEventType.criticalIntervention:
        return Icons.warning_rounded;
      case EvolutionEventType.rollback:
        return Icons.settings_backup_restore_rounded;
      case EvolutionEventType.humanOverride:
        return Icons.person_search_rounded;
      case EvolutionEventType.agentDeployed:
        return Icons.cloud_done_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }
}
