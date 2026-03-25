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
          child: CircularProgressIndicator(color: AdminColors.emeraldGreen)),
      error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: AdminColors.textSecondary))),
    );
  }
}

class _HealthGridContent extends StatelessWidget {
  final List<OrchestratorModel> orchestrators;
  const _HealthGridContent({required this.orchestrators});

  @override
  Widget build(BuildContext context) {
    if (orchestrators.isEmpty) {
      return const Center(
        child: Text(
            "Agent Registry is empty.\nWaiting for workers to report in...",
            textAlign: TextAlign.center,
            style: TextStyle(color: AdminColors.textMuted)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 400,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.15,
      ),
      itemCount: orchestrators.length,
      itemBuilder: (context, index) =>
          OrchestratorCard(orchestrator: orchestrators[index]),
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
  bool _isProcessing = false;

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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminColors.slateMedium,
        borderRadius: BorderRadius.circular(16),
        // FIX: withValues instead of withOpacity
        border: Border.all(
            color: orch.isCritical
                ? AdminColors.rubyRed.withValues(alpha: 0.3)
                : AdminColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _PulsingLight(color: color, isPaused: isPaused),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(orch.id.replaceAll('_', ' '),
                        style: const TextStyle(
                            color: AdminColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AdminColors.slateDarkest,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AdminColors.borderDefault),
                      ),
                      child: Text(orch.domain,
                          style: const TextStyle(
                              color: AdminColors.statusInfo,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1)),
                    ),
                  ],
                ),
              ),
              Text(orch.version,
                  style: const TextStyle(
                      color: AdminColors.textMuted,
                      fontSize: 10,
                      fontFamily: 'monospace')),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Metric(
                  label: 'EFFICACY', value: orch.efficacyDisplay, color: color),
              _Metric(
                  label: 'LATENCY',
                  value: orch.latencyDisplay,
                  color: AdminColors.textPrimary),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isProcessing ? null : () => _toggleMode(isPaused),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AdminColors.textPrimary,
                    side: const BorderSide(color: AdminColors.borderDefault),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text(isPaused ? 'RESUME' : 'PAUSE',
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.history_rounded, size: 20),
                onPressed: () => _showRollback(),
                tooltip: 'Rollback to Stable',
              ),
            ],
          )
        ],
      ),
    );
  }

  Future<void> _toggleMode(bool isPaused) async {
    setState(() => _isProcessing = true);
    try {
      final appId = ref.read(currentAppProvider).id;
      if (isPaused) {
        await OrchestratorService.resumeOrchestrator(
            appId, widget.orchestrator.id);
      } else {
        await OrchestratorService.pauseOrchestrator(
            appId, widget.orchestrator.id);
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showRollback() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Rollback request sent to Evolution Engine')));
  }
}

class _Metric extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Metric(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AdminColors.textMuted,
                fontSize: 8,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5)),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _PulsingLight extends StatefulWidget {
  final Color color;
  final bool isPaused;
  const _PulsingLight({required this.color, required this.isPaused});

  @override
  State<_PulsingLight> createState() => _PulsingLightState();
}

class _PulsingLightState extends State<_PulsingLight>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _pulse = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    if (!widget.isPaused) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_PulsingLight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPaused != oldWidget.isPaused) {
      if (widget.isPaused) {
        _controller.stop();
      } else {
        _controller.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.isPaused ? AdminColors.textMuted : widget.color;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // FIX: withValues instead of withOpacity
          color:
              baseColor.withValues(alpha: widget.isPaused ? 1.0 : _pulse.value),
          boxShadow: widget.isPaused
              ? null
              : [
                  BoxShadow(
                      color: baseColor.withValues(alpha: 0.5 * _pulse.value),
                      blurRadius: 10,
                      spreadRadius: 3 * _pulse.value)
                ],
        ),
      ),
    );
  }
}
