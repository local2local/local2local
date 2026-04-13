import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local2local/features/triage_hub/models/orchestrator_model.dart';
import 'package:local2local/features/triage_hub/providers/app_providers.dart';
import 'package:local2local/features/triage_hub/theme/admin_theme.dart';

class HealthGridPage extends ConsumerWidget {
  const HealthGridPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orchestratorsAsync = ref.watch(orchestratorsProvider);

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
              spacing: 20,
              runSpacing: 16,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Infrastructure Health',
                      style: TextStyle(
                        color: AdminColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Real-time status of L2LAAF service nodes.',
                      style: TextStyle(
                          color: AdminColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                _SystemStatusBadge(orchestratorsAsync: orchestratorsAsync),
              ],
            ),
          ),
          const Divider(height: 1, color: AdminColors.borderDefault),

          // Content Section
          Expanded(
            child: orchestratorsAsync.when(
              data: (orchestrators) => _buildGrid(context, orchestrators),
              loading: () => const Center(
                  child: CircularProgressIndicator(
                      color: AdminColors.emeraldGreen)),
              error: (e, _) => Center(
                  child: Text('Registry Error: $e',
                      style: const TextStyle(color: AdminColors.rubyRed))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(
      BuildContext context, List<OrchestratorModel> orchestrators) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          double cardWidth;
          if (constraints.maxWidth > 1200) {
            cardWidth = (constraints.maxWidth - (16 * 3)) / 4;
          } else if (constraints.maxWidth > 800) {
            cardWidth = (constraints.maxWidth - (16 * 2)) / 3;
          } else if (constraints.maxWidth > 500) {
            cardWidth = (constraints.maxWidth - 16) / 2;
          } else {
            cardWidth = constraints.maxWidth;
          }

          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: orchestrators
                .map((orch) => SizedBox(
                      width: cardWidth,
                      child: _HealthCard(orchestrator: orch),
                    ))
                .toList(),
          );
        },
      ),
    );
  }
}

class _SystemStatusBadge extends StatelessWidget {
  final AsyncValue<List<OrchestratorModel>> orchestratorsAsync;
  const _SystemStatusBadge({required this.orchestratorsAsync});

  @override
  Widget build(BuildContext context) {
    return orchestratorsAsync.when(
      data: (list) {
        final anyCritical = list.any((o) => o.isCritical);
        final color =
            anyCritical ? AdminColors.rubyRed : AdminColors.emeraldGreen;
        final label =
            anyCritical ? 'SYSTEM DEGRADED' : 'ALL SYSTEMS OPERATIONAL';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                  anyCritical
                      ? Icons.warning_rounded
                      : Icons.check_circle_rounded,
                  color: color,
                  size: 14),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _HealthCard extends ConsumerWidget {
  final OrchestratorModel orchestrator;
  const _HealthCard({required this.orchestrator});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = orchestrator.status == OrchestratorStatus.paused
        ? AdminColors.statusWarning
        : (orchestrator.isHealthy
            ? AdminColors.emeraldGreen
            : AdminColors.rubyRed);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminColors.slateDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: orchestrator.status == OrchestratorStatus.paused
              ? AdminColors.statusWarning.withValues(alpha: 0.3)
              : AdminColors.borderDefault,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_getIcon(orchestrator.domain),
                    color: statusColor, size: 20),
              ),
              const Spacer(),
              _ControlMenu(orchestrator: orchestrator),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            orchestrator.id
                .replaceAll('_ORCHESTRATOR', '')
                .replaceAll('_', ' '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: AdminColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            orchestrator.status == OrchestratorStatus.paused
                ? 'PAUSED'
                : 'OPERATIONAL',
            style: TextStyle(
                color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Metric(label: 'EFFICACY', value: orchestrator.efficacyDisplay),
              _Metric(label: 'LATENCY', value: orchestrator.latencyDisplay),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getIcon(String domain) {
    switch (domain) {
      case 'COMPLIANCE':
        return Icons.gavel_rounded;
      case 'FINANCE':
        return Icons.account_balance_wallet_rounded;
      case 'OPS':
        return Icons.settings_input_component_rounded;
      // FIX: Changed from shield_lock_rounded to security_rounded for better version compatibility
      case 'SECURITY':
        return Icons.security_rounded;
      default:
        return Icons.hub_rounded;
    }
  }
}

class _ControlMenu extends ConsumerWidget {
  final OrchestratorModel orchestrator;
  const _ControlMenu({required this.orchestrator});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appId = ref.watch(currentAppProvider).id;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: AdminColors.textMuted, size: 20),
      tooltip: 'Agent Controls',
      onSelected: (value) async {
        switch (value) {
          case 'pause':
            await OrchestratorService.pauseOrchestrator(appId, orchestrator.id);
            break;
          case 'resume':
            await OrchestratorService.resumeOrchestrator(
                appId, orchestrator.id);
            break;
          case 'rollback':
            await OrchestratorService.rollbackOrchestrator(
                appId, orchestrator.id);
            break;
        }
      },
      itemBuilder: (context) => [
        if (orchestrator.status != OrchestratorStatus.paused)
          const PopupMenuItem(value: 'pause', child: Text('Pause Operations')),
        if (orchestrator.status == OrchestratorStatus.paused)
          const PopupMenuItem(
              value: 'resume', child: Text('Resume Operations')),
        const PopupMenuItem(
          value: 'rollback',
          child: Text('One-Click Rollback',
              style: TextStyle(color: AdminColors.rubyRed)),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(
                color: AdminColors.textSecondary,
                fontSize: 9,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                color: AdminColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}
