import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local2local/features/triage_hub/models/orchestrator_model.dart';
import 'package:local2local/features/triage_hub/providers/app_providers.dart';
import 'package:local2local/features/triage_hub/theme/admin_theme.dart';

/// Orchestrator Health Grid Page - The "Brain" Map
/// Displays the 7 orchestrator agents with real-time health metrics
/// Listens to: artifacts/{appId}/public/data/agent_registry
class HealthGridPage extends ConsumerWidget {
  const HealthGridPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orchestratorsAsync = ref.watch(orchestratorsProvider);
    final currentApp = ref.watch(currentAppProvider);

    return orchestratorsAsync.when(
      data: (orchestrators) => _HealthGridContent(orchestrators: orchestrators),
      loading: () => const Center(
        child: CircularProgressIndicator(color: AdminColors.emeraldGreen),
      ),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AdminColors.rubyRed, size: 48),
            const SizedBox(height: 16),
            Text('Error loading orchestrators', style: TextStyle(color: AdminColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _HealthGridContent extends StatelessWidget {
  final List<OrchestratorModel> orchestrators;

  const _HealthGridContent({required this.orchestrators});

  @override
  Widget build(BuildContext context) {
    // Calculate overall health
    final healthyCount = orchestrators.where((o) => o.isHealthy).length;
    final totalCount = orchestrators.length;
    final overallHealth = totalCount > 0 ? (healthyCount / totalCount * 100) : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with overall status
          _OverallHealthHeader(
            healthyCount: healthyCount,
            totalCount: totalCount,
            overallHealth: overallHealth,
          ),
          const SizedBox(height: 24),
          // Grid of orchestrator cards
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 1200
                  ? 4
                  : constraints.maxWidth > 800
                      ? 3
                      : 2;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                ),
                itemCount: orchestrators.length,
                itemBuilder: (context, index) {
                  return OrchestratorCard(orchestrator: orchestrators[index]);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Overall health header with summary stats
class _OverallHealthHeader extends StatelessWidget {
  final int healthyCount;
  final int totalCount;
  final double overallHealth;

  const _OverallHealthHeader({
    required this.healthyCount,
    required this.totalCount,
    required this.overallHealth,
  });

  @override
  Widget build(BuildContext context) {
    final isHealthy = overallHealth >= 80;
    final isWarning = overallHealth >= 60 && overallHealth < 80;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AdminColors.slateMedium,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.borderDefault),
      ),
      child: Row(
        children: [
          // Brain icon with pulsing effect
          _PulsingStatusIndicator(
            isHealthy: isHealthy,
            isWarning: isWarning,
            size: 56,
            child: Icon(
              Icons.psychology_rounded,
              size: 32,
              color: isHealthy
                  ? AdminColors.emeraldGreen
                  : isWarning
                      ? AdminColors.statusWarning
                      : AdminColors.rubyRed,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Orchestrator Health Grid',
                  style: TextStyle(
                    color: AdminColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'The "Brain" Map - $healthyCount of $totalCount agents operating normally',
                  style: const TextStyle(color: AdminColors.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
          // Overall health score
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: (isHealthy
                      ? AdminColors.emeraldGreen
                      : isWarning
                          ? AdminColors.statusWarning
                          : AdminColors.rubyRed)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  '${overallHealth.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: isHealthy
                        ? AdminColors.emeraldGreen
                        : isWarning
                            ? AdminColors.statusWarning
                            : AdminColors.rubyRed,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Text(
                  'Overall Health',
                  style: TextStyle(color: AdminColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual orchestrator card with metrics and controls
class OrchestratorCard extends ConsumerStatefulWidget {
  final OrchestratorModel orchestrator;

  const OrchestratorCard({super.key, required this.orchestrator});

  @override
  ConsumerState<OrchestratorCard> createState() => _OrchestratorCardState();
}

class _OrchestratorCardState extends ConsumerState<OrchestratorCard> {
  bool _isLoading = false;

  IconData get typeIcon {
    switch (widget.orchestrator.type) {
      case OrchestratorType.compliance:
        return Icons.gavel_rounded;
      case OrchestratorType.finance:
        return Icons.account_balance_rounded;
      case OrchestratorType.logistics:
        return Icons.local_shipping_rounded;
      case OrchestratorType.talent:
        return Icons.people_rounded;
      case OrchestratorType.customer:
        return Icons.support_agent_rounded;
      case OrchestratorType.inventory:
        return Icons.inventory_2_rounded;
      case OrchestratorType.analytics:
        return Icons.analytics_rounded;
    }
  }

  Color get statusColor {
    if (widget.orchestrator.isCritical) return AdminColors.rubyRed;
    if (widget.orchestrator.isWarning) return AdminColors.statusWarning;
    return AdminColors.emeraldGreen;
  }

  @override
  Widget build(BuildContext context) {
    final orch = widget.orchestrator;
    final isPaused = orch.status == OrchestratorStatus.paused;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.slateMedium,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: orch.isCritical ? AdminColors.rubyRed.withValues(alpha: 0.5) : AdminColors.borderDefault,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with status light
          Row(
            children: [
              _PulsingStatusIndicator(
                isHealthy: orch.isHealthy,
                isWarning: orch.isWarning,
                isPaused: isPaused,
                size: 12,
              ),
              const SizedBox(width: 10),
              Icon(typeIcon, size: 18, color: AdminColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  orch.type.label,
                  style: const TextStyle(
                    color: AdminColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Version badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AdminColors.slateLight,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  orch.version,
                  style: const TextStyle(
                    color: AdminColors.textMuted,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Status text
          Text(
            orch.status.label,
            style: TextStyle(
              color: statusColor,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          // Metrics
          Row(
            children: [
              _MetricTile(
                label: 'Efficacy',
                value: orch.efficacyDisplay,
                icon: Icons.speed_rounded,
                color: statusColor,
              ),
              const SizedBox(width: 12),
              _MetricTile(
                label: 'Latency',
                value: orch.latencyDisplay,
                icon: Icons.timer_outlined,
                color: orch.latencyMs > 200
                    ? AdminColors.statusWarning
                    : AdminColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MetricTile(
                label: 'Backlog',
                value: orch.currentBacklog.toString(),
                icon: Icons.pending_actions_rounded,
                color: orch.currentBacklog > 10
                    ? AdminColors.statusWarning
                    : AdminColors.textSecondary,
              ),
              const SizedBox(width: 12),
              _MetricTile(
                label: 'Processed',
                value: _formatNumber(orch.processedToday),
                icon: Icons.check_circle_outline,
                color: AdminColors.textSecondary,
              ),
            ],
          ),
          const Spacer(),
          // Controls
          Row(
            children: [
              Expanded(
                child: _ControlButton(
                  label: isPaused ? 'Resume' : 'Pause',
                  icon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  isLoading: _isLoading,
                  onPressed: () => _togglePause(isPaused),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ControlButton(
                  label: 'Rollback',
                  icon: Icons.history_rounded,
                  isLoading: _isLoading,
                  isDangerous: true,
                  onPressed: _showRollbackDialog,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatNumber(int num) {
    if (num >= 1000) {
      return '${(num / 1000).toStringAsFixed(1)}k';
    }
    return num.toString();
  }

  Future<void> _togglePause(bool isPaused) async {
    setState(() => _isLoading = true);
    try {
      final currentApp = ref.read(currentAppProvider);
      if (isPaused) {
        await OrchestratorService.resumeOrchestrator(currentApp.id, widget.orchestrator.id);
      } else {
        await OrchestratorService.pauseOrchestrator(currentApp.id, widget.orchestrator.id);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showRollbackDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminColors.slateMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AdminColors.borderDefault),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AdminColors.statusWarning),
            const SizedBox(width: 12),
            const Text('Confirm Rollback', style: TextStyle(color: AdminColors.textPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to rollback ${widget.orchestrator.type.label}?',
              style: const TextStyle(color: AdminColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AdminColors.slateDark,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AdminColors.statusInfo, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'This will revert to the previous stable version and may affect ongoing transactions.',
                      style: TextStyle(color: AdminColors.textMuted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AdminColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              setState(() => _isLoading = true);
              try {
                final currentApp = ref.read(currentAppProvider);
                await OrchestratorService.rollbackOrchestrator(currentApp.id, widget.orchestrator.id);
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.statusWarning,
              foregroundColor: AdminColors.slateDarkest,
            ),
            child: const Text('Rollback'),
          ),
        ],
      ),
    );
  }
}

/// Metric tile widget
class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: AdminColors.slateDark,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: color == AdminColors.textSecondary ? AdminColors.textPrimary : color,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(color: AdminColors.textMuted, fontSize: 9),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Control button for pause/rollback
class _ControlButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isLoading;
  final bool isDangerous;
  final VoidCallback onPressed;

  const _ControlButton({
    required this.label,
    required this.icon,
    required this.isLoading,
    this.isDangerous = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: isDangerous ? AdminColors.statusWarning : AdminColors.textSecondary,
        side: BorderSide(
          color: isDangerous
              ? AdminColors.statusWarning.withValues(alpha: 0.5)
              : AdminColors.borderDefault,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      child: isLoading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14),
                const SizedBox(width: 4),
                Text(label, style: const TextStyle(fontSize: 11)),
              ],
            ),
    );
  }
}

/// Pulsing status indicator with animation
class _PulsingStatusIndicator extends StatefulWidget {
  final bool isHealthy;
  final bool isWarning;
  final bool isPaused;
  final double size;
  final Widget? child;

  const _PulsingStatusIndicator({
    required this.isHealthy,
    this.isWarning = false,
    this.isPaused = false,
    required this.size,
    this.child,
  });

  @override
  State<_PulsingStatusIndicator> createState() => _PulsingStatusIndicatorState();
}

class _PulsingStatusIndicatorState extends State<_PulsingStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (!widget.isPaused) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_PulsingStatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPaused && _controller.isAnimating) {
      _controller.stop();
    } else if (!widget.isPaused && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get statusColor {
    if (widget.isPaused) return AdminColors.textMuted;
    if (!widget.isHealthy && !widget.isWarning) return AdminColors.rubyRed;
    if (widget.isWarning) return AdminColors.statusWarning;
    return AdminColors.emeraldGreen;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.child != null) {
      return AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: _animation.value * 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(child: widget.child),
          );
        },
      );
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: statusColor,
            shape: BoxShape.circle,
            boxShadow: widget.isPaused
                ? null
                : [
                    BoxShadow(
                      color: statusColor.withValues(alpha: _animation.value * 0.5),
                      blurRadius: widget.size * 0.5,
                      spreadRadius: widget.size * 0.1,
                    ),
                  ],
          ),
        );
      },
    );
  }
}
