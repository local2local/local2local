import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local2local/features/triage_hub/models/intervention_model.dart';
import 'package:local2local/features/triage_hub/providers/app_providers.dart';
import 'package:local2local/features/triage_hub/theme/admin_theme.dart';

/// Main page for managing active exceptions and performing reasoning audits.
class TriageQueuePage extends ConsumerWidget {
  const TriageQueuePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interventionsAsync = ref.watch(interventionsProvider);
    final selectedItem = ref.watch(selectedInterventionProvider);

    return Container(
      color: AdminColors.slateDarkest,
      child: Row(
        children: [
          // 1. The Queue (Left List)
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    'Active Exceptions',
                    style: TextStyle(
                      color: AdminColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(height: 1, color: AdminColors.borderDefault),
                Expanded(
                  child: interventionsAsync.when(
                    data: (items) {
                      final active = items.where((i) => i.isActive).toList();
                      if (active.isEmpty) {
                        return const _EmptyState(
                            message: 'No active interventions.');
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(24),
                        itemCount: active.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) => _InterventionCard(
                          item: active[index],
                          isSelected: selectedItem?.id == active[index].id,
                        ),
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                          color: AdminColors.emeraldGreen),
                    ),
                    error: (e, _) => Center(
                      child: Text('Stream Error: $e',
                          style: const TextStyle(color: AdminColors.rubyRed)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. The Detail Pane (Right Reasoning Audit)
          const VerticalDivider(width: 1, color: AdminColors.borderDefault),
          Expanded(
            flex: 2,
            child: _buildDetailContent(selectedItem),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailContent(InterventionModel? selectedItem) {
    if (selectedItem == null) {
      return const _EmptyState(
          message: 'Select an exception to view reasoning trace.');
    }
    return _InterventionDetailPane(item: selectedItem);
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
        child: Text(message,
            style: const TextStyle(color: AdminColors.textMuted)));
  }
}

class _InterventionCard extends ConsumerWidget {
  final InterventionModel item;
  final bool isSelected;
  const _InterventionCard({required this.item, required this.isSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () =>
          ref.read(selectedInterventionProvider.notifier).setSelected(item),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AdminColors.slateDark : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isSelected
                  ? AdminColors.emeraldGreen
                  : AdminColors.borderDefault),
        ),
        child: Row(
          children: [
            _PriorityIndicator(priority: item.priority),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      style: const TextStyle(
                          color: AdminColors.textPrimary,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AdminColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AdminColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _PriorityIndicator extends StatelessWidget {
  final String priority;
  const _PriorityIndicator({required this.priority});

  @override
  Widget build(BuildContext context) {
    Color color = AdminColors.statusInfo;
    if (priority == 'high') {
      color = AdminColors.rubyRed;
    } else if (priority == 'medium') {
      color = AdminColors.statusWarning;
    }

    return Container(
      width: 4,
      height: 40,
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
    );
  }
}

class _InterventionDetailPane extends ConsumerWidget {
  final InterventionModel item;
  const _InterventionDetailPane({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Detail Header
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'EXCEPTION DETAIL',
                style: TextStyle(
                  color: AdminColors.emeraldGreen,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(item.title,
                  style: const TextStyle(
                      color: AdminColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(item.description,
                  style: const TextStyle(
                      color: AdminColors.textSecondary,
                      fontSize: 14,
                      height: 1.5)),
            ],
          ),
        ),
        const Divider(height: 1, color: AdminColors.borderDefault),

        // REASONING TRACE
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const _SectionHeader(
                  title: 'AGENT REASONING TRACE',
                  icon: Icons.psychology_rounded),
              const SizedBox(height: 16),
              const _ReasoningStep(
                step: '1',
                label: 'Ingestion of Xero Reconciliation Event',
                description:
                    'Detected discrepancy in Bank Account ending in *9902.',
                status: 'COMPLETED',
              ),
              const _ReasoningStep(
                step: '2',
                label: 'Cross-Reference with Stripe Webhook',
                description:
                    'Found matching payload ID st_45612. Amount: \$250.00.',
                status: 'COMPLETED',
              ),
              const _ReasoningStep(
                step: '3',
                label: 'Constraint Violation Detected',
                description:
                    'Metadata mismatch. Tenant "Kaskflow" expected, but payload contained "Kaskflow-Test-A".',
                status: 'HALTED',
                isCritical: true,
              ),
              const SizedBox(height: 24),
              const _ConfidenceMeter(score: 0.42),
              const SizedBox(height: 32),
              const _SectionHeader(
                  title: 'RESOLUTION MACROS', icon: Icons.bolt_rounded),
              const SizedBox(height: 16),
              ...item.macros.map((m) {
                return _MacroButton(
                  label: m['label'] ?? 'Unknown',
                  macroId: m['id'] ?? 'none',
                  onTap: () async {
                    final appId = ref.read(currentAppProvider).id;
                    final mid = m['id'];
                    if (mid != null) {
                      await InterventionService.resolveIntervention(
                          appId, item.id, mid);
                      ref
                          .read(selectedInterventionProvider.notifier)
                          .setSelected(null);
                    }
                  },
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AdminColors.textSecondary, size: 14),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                color: AdminColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1)),
      ],
    );
  }
}

class _ReasoningStep extends StatelessWidget {
  final String step, label, description, status;
  final bool isCritical;
  const _ReasoningStep(
      {required this.step,
      required this.label,
      required this.description,
      required this.status,
      this.isCritical = false});

  @override
  Widget build(BuildContext context) {
    final color = isCritical ? AdminColors.rubyRed : AdminColors.emeraldGreen;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Center(
                child: Text(step,
                    style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(label,
                        style: const TextStyle(
                            color: AdminColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text(status,
                        style: TextStyle(
                            color: color,
                            fontSize: 9,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(description,
                    style: const TextStyle(
                        color: AdminColors.textSecondary,
                        fontSize: 12,
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfidenceMeter extends StatelessWidget {
  final double score;
  const _ConfidenceMeter({required this.score});

  @override
  Widget build(BuildContext context) {
    final barColor =
        score < 0.5 ? AdminColors.rubyRed : AdminColors.emeraldGreen;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.slateDarkest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('AGENT CONFIDENCE SCORE',
              style: TextStyle(
                  color: AdminColors.textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: score,
            backgroundColor: AdminColors.borderDefault,
            color: barColor,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          Text(
            '${(score * 100).toInt()}% Confidence - Logic Halted due to Namespace Ambiguity',
            style: const TextStyle(color: AdminColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _MacroButton extends StatelessWidget {
  final String label, macroId;
  final VoidCallback onTap;
  const _MacroButton(
      {required this.label, required this.macroId, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AdminColors.slateDarkest,
          foregroundColor: AdminColors.textPrimary,
          minimumSize: const Size(double.infinity, 50),
          side: const BorderSide(color: AdminColors.borderDefault),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            const Icon(Icons.arrow_forward_rounded, size: 16),
          ],
        ),
      ),
    );
  }
}
