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

    return orchestratorsAsync.when(
      data: (orchestrators) => _HealthGridContent(orchestrators: orchestrators),
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
            Text('Error loading orchestrators',
                style: TextStyle(color: AdminColors.textSecondary)),
            const SizedBox(height: 8),
            Text(e.toString(),
                style: const TextStyle(
                    color: AdminColors.textMuted, fontSize: 12)),
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
    final healthyCount = orchestrators.where((o) => o.isHealthy).length;
    final totalCount = orchestrators.length;
    final overallHealth =
        totalCount > 0 ? (healthyCount / totalCount * 100) : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OverallHealthHeader(
            healthyCount: healthyCount,
            totalCount: totalCount,
            overallHealth: overallHealth,
          ),
          const SizedBox(height: 24),
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
                itemBuilder: (context, index) =>
                    OrchestratorCard(orchestrator: orchestrators[index]),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OverallHealthHeader extends StatelessWidget {
  final int healthyCount;
  final int totalCount;
  final double overallHealth;

  const _OverallHealthHeader(
      {required this.healthyCount,
      required this.totalCount,
      required this.overallHealth});

  @override
  Widget build(BuildContext context) {
    final isHealthy = overallHealth >= 80;
    final isWarning = overallHealth >= 60 && overallHealth < 80;
    final color = isHealthy
        ? AdminColors.emeraldGreen
        : isWarning
            ? AdminColors.statusWarning
            : AdminColors.rubyRed;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AdminColors.slateMedium,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.borderDefault),
      ),
      child: Row(
        children: [
          _PulsingStatusIndicator(
            isHealthy: isHealthy,
            isWarning: isWarning,
            size: 56,
            child: Icon(Icons.psychology_rounded, size: 32, color: color),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Orchestrator Health Grid',
                    style: TextStyle(
                        color: AdminColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                    'The "Brain" Map - $healthyCount of $totalCount agents operating normally',
                    style: const TextStyle(
                        color: AdminColors.textSecondary, fontSize: 14)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text('${overallHealth.toStringAsFixed(0)}%',
                    style: TextStyle(
                        color: color,
                        fontSize: 28,
                        fontWeight: FontWeight.w700)),
                const Text('Overall Health',
                    style:
                        TextStyle(color: AdminColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OrchestratorCard extends ConsumerStatefulWidget {
  final OrchestratorModel orchestrator;
  const OrchestratorCard({super.key, required this.orchestrator});

  @override
  ConsumerState<OrchestratorCard> createState() => _OrchestratorCardState();
}

class _OrchestratorCardState extends ConsumerState<OrchestratorCard> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final orch = widget.orchestrator;
    final isPaused = orch.status == OrchestratorStatus.paused;
    final color = orch.isCritical
        ? AdminColors.rubyRed
        : orch.isWarning
            ? AdminColors.statusWarning
            : AdminColors.emeraldGreen;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.slateMedium,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: orch.isCritical
                ? AdminColors.rubyRed.withOpacity(0.5)
                : AdminColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _PulsingStatusIndicator(
                  isHealthy: orch.isHealthy,
                  isWarning: orch.isWarning,
                  isPaused: isPaused,
                  size: 12),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(orch.type.label,
                      style: const TextStyle(
                          color: AdminColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600))),
              Text(orch.version,
                  style: const TextStyle(
                      color: AdminColors.textMuted,
                      fontSize: 10,
                      fontFamily: 'monospace')),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _MetricTile(
                  label: 'Efficacy',
                  value: orch.efficacyDisplay,
                  icon: Icons.speed_rounded,
                  color: color),
              const SizedBox(width: 12),
              _MetricTile(
                  label: 'Latency',
                  value: orch.latencyDisplay,
                  icon: Icons.timer_outlined,
                  color: AdminColors.textSecondary),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: _ControlButton(
                  label: isPaused ? 'Resume' : 'Pause',
                  icon:
                      isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
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

  Future<void> _togglePause(bool isPaused) async {
    setState(() => _isLoading = true);
    final currentApp = ref.read(currentAppProvider);
    if (isPaused) {
      await OrchestratorService.resumeOrchestrator(
          currentApp.id, widget.orchestrator.id);
    } else {
      await OrchestratorService.pauseOrchestrator(
          currentApp.id, widget.orchestrator.id);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _showRollbackDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminColors.slateMedium,
        title: const Text('Confirm Rollback'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              setState(() => _isLoading = true);
              await OrchestratorService.rollbackOrchestrator(
                  ref.read(currentAppProvider).id, widget.orchestrator.id);
              if (mounted) setState(() => _isLoading = false);
            },
            child: const Text('Rollback'),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _MetricTile(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: AdminColors.slateDark,
            borderRadius: BorderRadius.circular(6)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 13, fontWeight: FontWeight.w600)),
            Text(label,
                style:
                    const TextStyle(color: AdminColors.textMuted, fontSize: 9)),
          ],
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isLoading, isDangerous;
  final VoidCallback onPressed;
  const _ControlButton(
      {required this.label,
      required this.icon,
      required this.isLoading,
      this.isDangerous = false,
      required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2))
          : Text(label),
    );
  }
}

class _PulsingStatusIndicator extends StatefulWidget {
  final bool isHealthy, isWarning, isPaused;
  final double size;
  final Widget? child;
  const _PulsingStatusIndicator(
      {required this.isHealthy,
      this.isWarning = false,
      this.isPaused = false,
      required this.size,
      this.child});

  @override
  State<_PulsingStatusIndicator> createState() =>
      _PulsingStatusIndicatorState();
}

class _PulsingStatusIndicatorState extends State<_PulsingStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        duration: const Duration(milliseconds: 1500), vsync: this);
    _animation = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    if (!widget.isPaused) _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isPaused
        ? AdminColors.textMuted
        : widget.isHealthy
            ? AdminColors.emeraldGreen
            : widget.isWarning
                ? AdminColors.statusWarning
                : AdminColors.rubyRed;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
            color:
                color.withOpacity(widget.isPaused ? 1 : _animation.value * 0.5),
            shape: BoxShape.circle),
        child: widget.child,
      ),
    );
  }
}
