import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local2local/features/triage_hub/models/intervention_model.dart';
import 'package:local2local/features/triage_hub/providers/app_providers.dart';
import 'package:local2local/features/triage_hub/theme/admin_theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// Triage Queue Page - Primary workspace for human interventions
/// Listens to: artifacts/{appId}/public/data/interventions
class TriageQueuePage extends ConsumerWidget {
  const TriageQueuePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interventionsAsync = ref.watch(interventionsProvider);
    final selectedIntervention = ref.watch(selectedInterventionProvider);

    return Row(
      children: [
        // Main intervention list
        Expanded(
          flex: selectedIntervention != null ? 5 : 1,
          child: interventionsAsync.when(
            data: (interventions) => _InterventionListView(interventions: interventions),
            loading: () => const Center(
              child: CircularProgressIndicator(color: AdminColors.emeraldGreen),
            ),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: AdminColors.rubyRed, size: 48),
                  const SizedBox(height: 16),
                  Text('Error loading interventions', style: TextStyle(color: AdminColors.textSecondary)),
                  const SizedBox(height: 8),
                  Text(e.toString(), style: const TextStyle(color: AdminColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
        // Context panel (slide-out)
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

/// List view of intervention cards
class _InterventionListView extends ConsumerWidget {
  final List<InterventionModel> interventions;

  const _InterventionListView({required this.interventions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeInterventions = interventions.where((i) => i.isActive).toList();
    final resolvedInterventions = interventions.where((i) => !i.isActive).toList();

    // Sort by severity (red first), then by age
    activeInterventions.sort((a, b) {
      final severityCompare = a.severity.index.compareTo(b.severity.index);
      if (severityCompare != 0) return severityCompare;
      return a.createdAt.compareTo(b.createdAt);
    });

    if (activeInterventions.isEmpty) {
      return _EmptyStateView();
    }

    return CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AdminColors.rubyRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: AdminColors.rubyRed, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Active Interventions',
                        style: TextStyle(
                          color: AdminColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${activeInterventions.length} items requiring human sign-off',
                        style: const TextStyle(color: AdminColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                _FilterChip(label: 'All', isSelected: true),
                const SizedBox(width: 8),
                _FilterChip(label: 'Critical', isSelected: false),
                const SizedBox(width: 8),
                _FilterChip(label: 'Warning', isSelected: false),
              ],
            ),
          ),
        ),
        // Intervention cards
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final intervention = activeInterventions[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InterventionCard(intervention: intervention),
                );
              },
              childCount: activeInterventions.length,
            ),
          ),
        ),
        // Resolved section (collapsed)
        if (resolvedInterventions.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  'Recently Resolved (${resolvedInterventions.length})',
                  style: const TextStyle(color: AdminColors.textSecondary, fontSize: 14),
                ),
                leading: const Icon(Icons.check_circle_outline, color: AdminColors.emeraldGreen, size: 20),
                children: resolvedInterventions
                    .map((i) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InterventionCard(intervention: i, isCompact: true),
                        ))
                    .toList(),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

/// Filter chip widget
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;

  const _FilterChip({required this.label, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? AdminColors.emeraldGreen.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AdminColors.emeraldGreen : AdminColors.borderDefault,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? AdminColors.emeraldGreen : AdminColors.textSecondary,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}

/// Empty state when all interventions are green
class _EmptyStateView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AdminColors.emeraldGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: AdminColors.emeraldGreen,
              size: 64,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'All Clear',
            style: TextStyle(
              color: AdminColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No interventions requiring attention.\nThe business is running itself.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AdminColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// Individual intervention card
class InterventionCard extends ConsumerWidget {
  final InterventionModel intervention;
  final bool isCompact;

  const InterventionCard({
    super.key,
    required this.intervention,
    this.isCompact = false,
  });

  Color get severityColor {
    switch (intervention.severity) {
      case InterventionSeverity.red:
        return AdminColors.rubyRed;
      case InterventionSeverity.yellow:
        return AdminColors.statusWarning;
      case InterventionSeverity.green:
        return AdminColors.emeraldGreen;
    }
  }

  IconData get categoryIcon {
    switch (intervention.category) {
      case InterventionCategory.compliance:
        return Icons.gavel_rounded;
      case InterventionCategory.finance:
        return Icons.account_balance_rounded;
      case InterventionCategory.safety:
        return Icons.shield_rounded;
      case InterventionCategory.logistics:
        return Icons.local_shipping_rounded;
      case InterventionCategory.talent:
        return Icons.person_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = ref.watch(selectedInterventionProvider)?.id == intervention.id;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (intervention.isActive) {
            ref.read(selectedInterventionProvider.notifier).state =
                isSelected ? null : intervention;
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.all(isCompact ? 12 : 16),
          decoration: BoxDecoration(
            color: isSelected
                ? AdminColors.emeraldGreen.withValues(alpha: 0.08)
                : AdminColors.slateMedium,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AdminColors.emeraldGreen : AdminColors.borderDefault,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: Category, Severity, Age
              Row(
                children: [
                  // Severity indicator
                  Container(
                    width: 4,
                    height: isCompact ? 32 : 40,
                    decoration: BoxDecoration(
                      color: severityColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Category badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AdminColors.slateLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(categoryIcon, size: 14, color: AdminColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          intervention.category.label,
                          style: const TextStyle(
                            color: AdminColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Severity badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: severityColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      intervention.severity.label.toUpperCase(),
                      style: TextStyle(
                        color: severityColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Age
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 14, color: AdminColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        intervention.ageDisplay,
                        style: const TextStyle(color: AdminColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              if (!isCompact) ...[
                const SizedBox(height: 12),
                // Summary
                Text(
                  intervention.summary,
                  style: const TextStyle(
                    color: AdminColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                // Agent info
                Row(
                  children: [
                    const Icon(Icons.smart_toy_outlined, size: 14, color: AdminColors.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      intervention.agentName,
                      style: const TextStyle(color: AdminColors.textMuted, fontSize: 12),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.tag, size: 14, color: AdminColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      intervention.transactionId,
                      style: const TextStyle(
                        color: AdminColors.textMuted,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ],
              if (!intervention.isActive) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AdminColors.emeraldGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check, size: 14, color: AdminColors.emeraldGreen),
                      const SizedBox(width: 4),
                      Text(
                        'Resolved: ${intervention.resolution ?? "Unknown"}',
                        style: const TextStyle(
                          color: AdminColors.emeraldGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Slide-out context panel for intervention details
class InterventionContextPanel extends ConsumerStatefulWidget {
  final InterventionModel intervention;

  const InterventionContextPanel({super.key, required this.intervention});

  @override
  ConsumerState<InterventionContextPanel> createState() => _InterventionContextPanelState();
}

class _InterventionContextPanelState extends ConsumerState<InterventionContextPanel> {
  String? _selectedMacroId;
  bool _isCommitting = false;

  @override
  Widget build(BuildContext context) {
    final intervention = widget.intervention;

    return Container(
      color: AdminColors.slateDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AdminColors.borderDefault)),
            ),
            child: Row(
              children: [
                const Icon(Icons.description_outlined, color: AdminColors.emeraldGreen),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Context Bundle',
                    style: TextStyle(
                      color: AdminColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: AdminColors.textMuted,
                  onPressed: () {
                    ref.read(selectedInterventionProvider.notifier).state = null;
                  },
                ),
              ],
            ),
          ),
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Transaction summary
                  _SectionHeader(title: 'Summary'),
                  const SizedBox(height: 8),
                  Text(
                    intervention.summary,
                    style: const TextStyle(
                      color: AdminColors.textPrimary,
                      fontSize: 15,
                    ),
                  ),
                  if (intervention.amountUsd != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AdminColors.statusWarning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AdminColors.statusWarning.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.attach_money, color: AdminColors.statusWarning, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Amount: \$${intervention.amountUsd!.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: AdminColors.statusWarning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // Reasoning Trace
                  _SectionHeader(title: 'Reasoning Trace'),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AdminColors.slateDarkest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AdminColors.borderDefault),
                    ),
                    child: SelectableText(
                      intervention.reasoningTrace,
                      style: const TextStyle(
                        color: AdminColors.textSecondary,
                        fontSize: 13,
                        height: 1.6,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // HBR Link
                  _SectionHeader(title: 'Rule Reference'),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _launchUrl(intervention.hbrRuleLink),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AdminColors.slateMedium,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AdminColors.borderDefault),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.rule, color: AdminColors.statusInfo, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  intervention.hbrRuleId,
                                  style: const TextStyle(
                                    color: AdminColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  intervention.hbrRuleLink,
                                  style: const TextStyle(
                                    color: AdminColors.statusInfo,
                                    fontSize: 12,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.content_copy, size: 18),
                            color: AdminColors.textMuted,
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: intervention.hbrRuleLink));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Link copied to clipboard')),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Macro Selector
                  _SectionHeader(title: 'Response Macros'),
                  const SizedBox(height: 8),
                  ...intervention.availableMacros.map((macro) => _MacroOption(
                        macro: macro,
                        isSelected: _selectedMacroId == macro.id,
                        onTap: () => setState(() => _selectedMacroId = macro.id),
                      )),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          // Commit button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AdminColors.slateMedium,
              border: Border(top: BorderSide(color: AdminColors.borderDefault)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedMacroId != null
                        ? 'Ready to commit: ${intervention.availableMacros.firstWhere((m) => m.id == _selectedMacroId).label}'
                        : 'Select a response macro above',
                    style: TextStyle(
                      color: _selectedMacroId != null
                          ? AdminColors.textPrimary
                          : AdminColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _selectedMacroId != null && !_isCommitting
                      ? () => _commitResponse(context)
                      : null,
                  icon: _isCommitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AdminColors.slateDarkest,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(_isCommitting ? 'Committing...' : 'Commit Response'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminColors.emeraldGreen,
                    foregroundColor: AdminColors.slateDarkest,
                    disabledBackgroundColor: AdminColors.slateLight,
                    disabledForegroundColor: AdminColors.textMuted,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _commitResponse(BuildContext context) async {
    if (_selectedMacroId == null) return;

    setState(() => _isCommitting = true);

    try {
      final currentApp = ref.read(currentAppProvider);
      await InterventionService.resolveIntervention(
        currentApp.id,
        widget.intervention.id,
        _selectedMacroId!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Response committed successfully'),
            backgroundColor: AdminColors.emeraldGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.read(selectedInterventionProvider.notifier).state = null;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AdminColors.rubyRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
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

/// Section header widget
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AdminColors.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
      ),
    );
  }
}

/// Macro option tile
class _MacroOption extends StatelessWidget {
  final MacroResponse macro;
  final bool isSelected;
  final VoidCallback onTap;

  const _MacroOption({
    required this.macro,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? AdminColors.emeraldGreen.withValues(alpha: 0.1)
                : AdminColors.slateMedium,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AdminColors.emeraldGreen : AdminColors.borderDefault,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AdminColors.emeraldGreen : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? AdminColors.emeraldGreen : AdminColors.textMuted,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 14, color: AdminColors.slateDarkest)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      macro.label,
                      style: TextStyle(
                        color: isSelected ? AdminColors.emeraldGreen : AdminColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      macro.description,
                      style: const TextStyle(color: AdminColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
