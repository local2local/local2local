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

    return timelineAsync.when(
      data: (events) {
        if (events.isEmpty) {
          return const Center(
            child: Text(
                "No evolution events recorded yet.\nSystem is in baseline state.",
                textAlign: TextAlign.center,
                style: TextStyle(color: AdminColors.textMuted)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: events.length,
          itemBuilder: (context, index) => _TimelineItem(
              event: events[index],
              isFirst: index == 0,
              isLast: index == events.length - 1),
        );
      },
      loading: () => const Center(
          child: CircularProgressIndicator(color: AdminColors.emeraldGreen)),
      error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: AdminColors.textSecondary))),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final EvolutionEventModel event;
  final bool isFirst;
  final bool isLast;
  const _TimelineItem(
      {required this.event, required this.isFirst, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final bool isCritical =
        event.type == EvolutionEventType.criticalIntervention;
    final Color accentColor =
        isCritical ? AdminColors.rubyRed : AdminColors.emeraldGreen;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline Line & Dot
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: isCritical ? accentColor : AdminColors.slateDarkest,
                  shape: BoxShape.circle,
                  border: Border.all(color: accentColor, width: 2),
                  boxShadow: isCritical
                      ? [
                          BoxShadow(
                              color: accentColor.withOpacity(0.3),
                              blurRadius: 8)
                        ]
                      : null,
                ),
              ),
              if (!isLast)
                Expanded(
                    child:
                        Container(width: 2, color: AdminColors.borderDefault)),
            ],
          ),
          const SizedBox(width: 20),
          // Content Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(event.title.toUpperCase(),
                          style: TextStyle(
                              color: isCritical
                                  ? AdminColors.rubyRed
                                  : AdminColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 1)),
                      Text(event.timeDisplay,
                          style: const TextStyle(
                              color: AdminColors.textMuted, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(event.description,
                      style: const TextStyle(
                          color: AdminColors.textSecondary,
                          fontSize: 13,
                          height: 1.4)),
                  const SizedBox(height: 12),
                  // Provenance Metadata
                  Row(
                    children: [
                      _MetaBadge(
                          label: "AGENT: ${event.agentName}",
                          color: AdminColors.slateLight),
                      const SizedBox(width: 8),
                      if (event.isAutonomous)
                        _MetaBadge(
                            label: "AUTONOMOUS",
                            color: AdminColors.emeraldGreen.withOpacity(0.1),
                            textColor: AdminColors.emeraldGreen),
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

class _MetaBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color? textColor;
  const _MetaBadge({required this.label, required this.color, this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      child: Text(label,
          style: TextStyle(
              color: textColor ?? AdminColors.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5)),
    );
  }
}
