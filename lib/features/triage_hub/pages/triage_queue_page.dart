import 'package:flutter/material.dart';
// REMOVED: unnecessary services.dart import
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
            error: (e, _) => Center(
                child: Text('Error: $e',
                    style: const TextStyle(color: AdminColors.textSecondary))),
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
    final active = interventions.where((i) => i.isActive).toList();

    if (active.isEmpty) {
      return const Center(
          child: Text("No active interventions",
              style: TextStyle(color: AdminColors.textMuted)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: active.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InterventionCard(intervention: active[index]),
      ),
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
    final color = intervention.severity == InterventionSeverity.red
        ? AdminColors.rubyRed
        : AdminColors.statusWarning;

    return InkWell(
      onTap: () => ref
          .read(selectedInterventionProvider.notifier)
          .setSelected(isSelected ? null : intervention),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          // FIX: withValues instead of withOpacity
          color: isSelected
              ? AdminColors.emeraldGreen.withValues(alpha: 0.08)
              : AdminColors.slateMedium,
          border: Border.all(
              color: isSelected
                  ? AdminColors.emeraldGreen
                  : AdminColors.borderDefault,
              width: isSelected ? 2 : 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(intervention.category.label.toUpperCase(),
                      style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Text(intervention.summary,
                      style: const TextStyle(
                          color: AdminColors.textPrimary,
                          fontWeight: FontWeight.w500,
                          fontSize: 14)),
                ],
              ),
            ),
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
      color: AdminColors.slateDark,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: AdminColors.borderDefault))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Context Bundle',
                    style: TextStyle(
                        color: AdminColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => ref
                        .read(selectedInterventionProvider.notifier)
                        .setSelected(null)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildSectionHeader('SUMMARY'),
                const SizedBox(height: 8),
                Text(widget.intervention.summary,
                    style: const TextStyle(
                        color: AdminColors.textPrimary, fontSize: 15)),
                if (widget.intervention.amountUsd != null) ...[
                  const SizedBox(height: 8),
                  Text(
                      'Amount: \$${widget.intervention.amountUsd!.toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: AdminColors.statusWarning,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ],
                const SizedBox(height: 24),
                _buildSectionHeader('REASONING TRACE'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: AdminColors.slateDarkest,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(widget.intervention.reasoningTrace,
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: AdminColors.textSecondary,
                          height: 1.5)),
                ),
                const SizedBox(height: 24),
                _buildSectionHeader('RULE REFERENCE'),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      const Icon(Icons.rule, color: AdminColors.statusInfo),
                  title: Text(widget.intervention.hbrRuleId,
                      style: const TextStyle(
                          color: AdminColors.statusInfo,
                          fontWeight: FontWeight.bold)),
                  subtitle: const Text('View logic in Policy Registry',
                      style: TextStyle(fontSize: 11)),
                  onTap: () => _launchUrl(widget.intervention.hbrRuleLink),
                  trailing: const Icon(Icons.open_in_new,
                      size: 16, color: AdminColors.textMuted),
                ),
                const SizedBox(height: 24),
                _buildSectionHeader('RESPONSE MACROS'),
                const SizedBox(height: 8),
                ...widget.intervention.availableMacros
                    .map((m) => RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          title: Text(m.label,
                              style: const TextStyle(
                                  color: AdminColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(m.description,
                              style: const TextStyle(
                                  color: AdminColors.textMuted, fontSize: 12)),
                          value: m.id,
                          activeColor: AdminColors.emeraldGreen,
                          groupValue: _selectedMacroId,
                          onChanged: (val) =>
                              setState(() => _selectedMacroId = val),
                        )),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
                border:
                    Border(top: BorderSide(color: AdminColors.borderDefault)),
                color: AdminColors.slateMedium),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _selectedMacroId == null || _isCommitting
                    ? null
                    : () => _commit(context),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AdminColors.emeraldGreen,
                    disabledBackgroundColor: AdminColors.slateLight),
                child: _isCommitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AdminColors.slateDarkest))
                    : const Text('Commit Decision',
                        style: TextStyle(
                            color: AdminColors.slateDarkest,
                            fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title,
        style: const TextStyle(
            color: AdminColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1));
  }

  Future<void> _commit(BuildContext context) async {
    setState(() => _isCommitting = true);
    try {
      final appId = ref.read(currentAppProvider).id;
      await InterventionService.resolveIntervention(
          appId, widget.intervention.id, _selectedMacroId!);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Intervention Resolved & Agent Notified'),
            backgroundColor: AdminColors.emeraldGreen));
        ref.read(selectedInterventionProvider.notifier).setSelected(null);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: AdminColors.rubyRed));
      }
    } finally {
      if (mounted) {
        setState(() => _isCommitting = false);
      }
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
