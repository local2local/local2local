import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local2local/features/triage_hub/models/evolution_event_model.dart';
import 'package:local2local/features/triage_hub/providers/app_providers.dart';
import 'package:local2local/features/triage_hub/theme/admin_theme.dart';

class EvolutionTimelinePage extends ConsumerWidget {
  const EvolutionTimelinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(evolutionTimelineProvider);

    return eventsAsync.when(
      data: (events) => _TimelineContent(events: events),
      loading: () => const Center(
        child: CircularProgressIndicator(color: AdminColors.emeraldGreen),
      ),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: AdminColors.rubyRed, size: 48),
            const SizedBox(height: 16),
            Text('Error loading timeline',
                style: TextStyle(color: AdminColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _TimelineContent extends StatelessWidget {
  final List<EvolutionEventModel> events;

  const _TimelineContent({required this.events});

  @override
  Widget build(BuildContext context) {
    final sortedEvents = List<EvolutionEventModel>.from(events)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final Map<String, List<EvolutionEventModel>> groupedEvents = {};
    for (final event in sortedEvents) {
      final dateKey = _formatDateKey(event.timestamp);
      groupedEvents.putIfAbsent(dateKey, () => []).add(event);
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _TimelineHeader(
              totalEvents: events.length,
              autonomousCount: events.where((e) => e.isAutonomous).length,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final entries = groupedEvents.entries.toList();
                if (index >= entries.length) return null;

                final entry = entries[index];
                return _DateSection(
                  dateLabel: entry.key,
                  events: entry.value,
                  isFirst: index == 0,
                );
              },
              childCount: groupedEvents.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  String _formatDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDate = DateTime(date.year, date.month, date.day);

    if (eventDate == today) {
      return 'Today';
    } else if (eventDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}

class _TimelineHeader extends StatelessWidget {
  final int totalEvents;
  final int autonomousCount;

  const _TimelineHeader({
    required this.totalEvents,
    required this.autonomousCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AdminColors.slateMedium,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.borderDefault),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AdminColors.emeraldGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.auto_graph_rounded,
              color: AdminColors.emeraldGreen,
              size: 28,
            ),
          ),
          const SizedBox(width: 20),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Evolution Timeline',
                  style: TextStyle(
                    color: AdminColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'The chronological diary of system growth and human interventions',
                  style:
                      TextStyle(color: AdminColors.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DateSection extends StatelessWidget {
  final String dateLabel;
  final List<EvolutionEventModel> events;
  final bool isFirst;

  const _DateSection({
    required this.dateLabel,
    required this.events,
    required this.isFirst,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isFirst) const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AdminColors.slateLight,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            dateLabel,
            style: const TextStyle(
              color: AdminColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...events.asMap().entries.map((entry) {
          return _TimelineEventCard(
            event: entry.value,
            isLast: entry.key == events.length - 1,
          );
        }),
      ],
    );
  }
}

class _TimelineEventCard extends StatelessWidget {
  final EvolutionEventModel event;
  final bool isLast;

  const _TimelineEventCard({
    required this.event,
    required this.isLast,
  });

  IconData get typeIcon {
    switch (event.type) {
      case EvolutionEventType.agentDeployed:
        return Icons.rocket_launch_rounded;
      case EvolutionEventType.ruleAdded:
        return Icons.add_circle_rounded;
      case EvolutionEventType.ruleModified:
        return Icons.edit_rounded;
      case EvolutionEventType.thresholdChanged:
        return Icons.tune_rounded;
      case EvolutionEventType.rollback:
        return Icons.history_rounded;
      case EvolutionEventType.humanOverride:
        return Icons.person_rounded;
      case EvolutionEventType.patternLearned:
        return Icons.lightbulb_rounded;
      case EvolutionEventType.systemEvolved:
        return Icons.auto_awesome_rounded;
      case EvolutionEventType.criticalIntervention:
        return Icons.warning_amber_rounded; // FIX: Added missing case
    }
  }

  Color get typeColor {
    switch (event.type) {
      case EvolutionEventType.agentDeployed:
        return AdminColors.statusInfo;
      case EvolutionEventType.ruleAdded:
        return AdminColors.emeraldGreen;
      case EvolutionEventType.ruleModified:
      case EvolutionEventType.thresholdChanged:
      case EvolutionEventType.humanOverride:
        return AdminColors.statusWarning;
      case EvolutionEventType.rollback:
      case EvolutionEventType.criticalIntervention: // FIX: Added missing case
        return AdminColors.rubyRed;
      case EvolutionEventType.patternLearned:
      case EvolutionEventType.systemEvolved:
        return AdminColors.emeraldGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 16),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AdminColors.borderDefault,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AdminColors.slateMedium,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AdminColors.borderDefault),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          event.type.label,
                          style: TextStyle(
                              color: typeColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (event.isAutonomous)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AdminColors.emeraldGreen
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.smart_toy_outlined,
                                  size: 12, color: AdminColors.emeraldGreen),
                              SizedBox(width: 4),
                              Text('AUTONOMOUS',
                                  style: TextStyle(
                                      color: AdminColors.emeraldGreen,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      const Spacer(),
                      Text(event.timeDisplay,
                          style: const TextStyle(
                              color: AdminColors.textMuted, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(event.title,
                      style: const TextStyle(
                          color: AdminColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(event.description,
                      style: const TextStyle(
                          color: AdminColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.smart_toy_outlined,
                          size: 14, color: AdminColors.textMuted),
                      const SizedBox(width: 6),
                      Text(event.agentName,
                          style: const TextStyle(
                              color: AdminColors.textMuted, fontSize: 11)),
                      if (event.triggeredBy != null) ...[
                        const SizedBox(width: 16),
                        const Icon(Icons.person_outline,
                            size: 14, color: AdminColors.textMuted),
                        const SizedBox(width: 6),
                        Text(event.triggeredBy!,
                            style: const TextStyle(
                                color: AdminColors.textMuted, fontSize: 11)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
