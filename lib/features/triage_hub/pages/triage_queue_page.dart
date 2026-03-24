import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local2local/features/triage_hub/models/intervention_model.dart';
import 'package:local2local/features/triage_hub/providers/app_providers.dart';
import 'package:local2local/features/triage_hub/theme/admin_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class TriageQueuePage extends ConsumerWidget {
  const TriageQueuePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interventionsAsync = ref.watch(interventionsProvider);
    final selectedIntervention = ref.watch(selectedInterventionProvider);

    return Row(
      children: [
        Expanded(
          flex: selectedIntervention != null ? 5 : 1,
          child: interventionsAsync.when(
            data: (interventions) =>
                _InterventionListView(interventions: interventions),
            loading: () => const Center(
                child:
                    CircularProgressIndicator(color: AdminColors.emeraldGreen)),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
        if (selectedIntervention != null) ...[
          const VerticalDivider(width: 1, color: AdminColors.borderDefault),
          Expanded(
            flex: 4,
            child: InterventionContextPanel(intervention: selectedIntervention),
          ),
        ],
      ],
    );
  }
}

class _InterventionListView extends ConsumerWidget {
  final List<InterventionModel> interventions;
  const _InterventionListView({required this.interventions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeInterventions = interventions.where((i) => i.isActive).toList();
    final resolvedInterventions =
        interventions.where((i) => !i.isActive).toList();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AdminColors.rubyRed, size: 24),
                const SizedBox(width: 16),
                const Expanded(
                    child: Text('Active Interventions',
                        style: TextStyle(
                            color: AdminColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w600))),
                Text('${activeInterventions.length} items',
                    style: const TextStyle(color: AdminColors.textSecondary)),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child:
                    InterventionCard(intervention: activeInterventions[index]),
              ),
              childCount: activeInterventions.length,
            ),
          ),
        ),
        if (resolvedInterventions.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ExpansionTile(
                title: Text('Resolved (${resolvedInterventions.length})'),
                children: resolvedInterventions
                    .map((i) =>
                        InterventionCard(intervention: i, isCompact: true))
                    .toList(),
              ),
            ),
          ),
      ],
    );
  }
}

class InterventionCard extends ConsumerWidget {
  final InterventionModel intervention;
  final bool isCompact;

  const InterventionCard(
      {super.key, required this.intervention, this.isCompact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected =
        ref.watch(selectedInterventionProvider)?.id == intervention.id;
    final severityColor = intervention.severity == InterventionSeverity.red
        ? AdminColors.rubyRed
        : AdminColors.statusWarning;

    return InkWell(
      onTap: () {
        if (intervention.isActive) {
          ref
              .read(selectedInterventionProvider.notifier)
              .setSelected(isSelected ? null : intervention);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AdminColors.emeraldGreen.withOpacity(0.1)
              : AdminColors.slateMedium,
          border: Border.all(
              color: isSelected
                  ? AdminColors.emeraldGreen
                  : AdminColors.borderDefault),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                    color: severityColor,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(intervention.category.label.toUpperCase(),
                      style: TextStyle(
                          color: severityColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                  Text(intervention.summary,
                      style: const TextStyle(
                          color: AdminColors.textPrimary,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Text(intervention.ageDisplay,
                style: const TextStyle(
                    color: AdminColors.textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class InterventionContextPanel extends ConsumerStatefulWidget {
  final InterventionModel intervention;
  const InterventionContextPanel({super.key, required this.intervention});

  @override
  ConsumerState<InterventionContextPanel> createState() =>
      _InterventionContextPanelState();
}

class _InterventionContextPanelState
    extends ConsumerState<InterventionContextPanel> {
  String? _selectedMacroId;
  bool _isCommitting = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: AdminColors.slateDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Context Bundle',
                  style: TextStyle(
                      color: AdminColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => ref
                      .read(selectedInterventionProvider.notifier)
                      .setSelected(null)),
            ],
          ),
          const Divider(),
          Expanded(
            child: ListView(
              children: [
                const Text('REASONING TRACE',
                    style:
                        TextStyle(color: AdminColors.textMuted, fontSize: 10)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  color: AdminColors.slateDarkest,
                  child: Text(widget.intervention.reasoningTrace,
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: AdminColors.textSecondary)),
                ),
                const SizedBox(height: 20),
                const Text('RESPONSE MACROS',
                    style:
                        TextStyle(color: AdminColors.textMuted, fontSize: 10)),
                ...widget.intervention.availableMacros
                    .map((m) => RadioListTile<String>(
                          title: Text(m.label,
                              style: const TextStyle(
                                  color: AdminColors.textPrimary,
                                  fontSize: 14)),
                          subtitle: Text(m.description,
                              style: const TextStyle(
                                  color: AdminColors.textMuted, fontSize: 12)),
                          value: m.id,
                          groupValue: _selectedMacroId,
                          onChanged: (val) =>
                              setState(() => _selectedMacroId = val),
                        )),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedMacroId == null || _isCommitting
                  ? null
                  : () => _commit(context),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AdminColors.emeraldGreen),
              child: _isCommitting
                  ? const CircularProgressIndicator()
                  : const Text('Commit Decision',
                      style: TextStyle(color: AdminColors.slateDarkest)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _commit(BuildContext context) async {
    setState(() => _isCommitting = true);
    try {
      final appId = ref.read(currentAppProvider).id;
      await InterventionService.resolveIntervention(
          appId, widget.intervention.id, _selectedMacroId!);

      // FIX: Use context.mounted check for async gaps
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Intervention Resolved'),
            backgroundColor: AdminColors.emeraldGreen));
        ref.read(selectedInterventionProvider.notifier).setSelected(null);
      }
    } finally {
      if (mounted) setState(() => _isCommitting = false);
    }
  }
}
