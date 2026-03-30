import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local2local/features/triage_hub/models/logistics_job_model.dart';
import 'package:local2local/features/triage_hub/providers/app_providers.dart';
import 'package:local2local/features/triage_hub/theme/admin_theme.dart';

class FleetMapPage extends ConsumerWidget {
  const FleetMapPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fleetAsync = ref.watch(fleetProvider);

    return Container(
      color: AdminColors.slateDarkest,
      child: Row(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: _MapGridPainter())),

                Positioned(
                  top: 24,
                  left: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Fleet Geo-Intelligence',
                          style: TextStyle(
                              color: AdminColors.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      _FleetStatusCounter(fleetAsync: fleetAsync),
                    ],
                  ),
                ),

                // LIVE DATA MARKERS
                fleetAsync.when(
                  data: (jobs) {
                    final activeJobs = jobs
                        .where((j) => j.status != LogisticsStatus.completed)
                        .toList();
                    if (activeJobs.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return Stack(
                      children: List.generate(activeJobs.length, (index) {
                        final job = activeJobs[index];

                        // 1. Projection
                        double top = _projectLatitude(job.lat ?? 53.5);
                        double left = _projectLongitude(job.lng ?? -113.5);

                        // 2. JITTER ENGINE
                        final jitterOffset = 0.015 * index;

                        // 3. DYNAMIC LABEL
                        final String label = job.carrierId == 'Unassigned'
                            ? 'Job: ${job.id.substring(0, 4)}'
                            : job.carrierId;

                        return _AgentMarker(
                          key: ValueKey(job.id),
                          top: top + jitterOffset,
                          left: left + jitterOffset,
                          label: label,
                          status: job.status.name.toUpperCase(),
                          isAlert: job.status == LogisticsStatus.open,
                        );
                      }),
                    );
                  },
                  loading: () => const Center(
                      child: CircularProgressIndicator(
                          color: AdminColors.emeraldGreen)),
                  error: (e, _) => Center(
                      child: Text('Map Link Error: $e',
                          style: const TextStyle(color: AdminColors.rubyRed))),
                ),
              ],
            ),
          ),

          // Telemetry Sidebar
          Container(
            width: 300,
            decoration: const BoxDecoration(
              color: AdminColors.slateDark,
              border:
                  Border(left: BorderSide(color: AdminColors.borderDefault)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('TELEMETRY STREAM',
                      style: TextStyle(
                          color: AdminColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2)),
                ),
                const Divider(height: 1, color: AdminColors.borderDefault),
                Expanded(
                  child: fleetAsync.when(
                    data: (jobs) => _TelemetryListView(jobs: jobs),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _projectLatitude(double lat) =>
      1.0 - ((lat - 49.0) / 11.0).clamp(0.1, 0.9);
  double _projectLongitude(double lng) =>
      ((lng + 120.0) / 10.0).clamp(0.1, 0.9);
}

class _FleetStatusCounter extends StatelessWidget {
  final AsyncValue<List<LogisticsJobModel>> fleetAsync;
  const _FleetStatusCounter({required this.fleetAsync});

  @override
  Widget build(BuildContext context) {
    return fleetAsync.when(
      data: (jobs) {
        final count =
            jobs.where((j) => j.status != LogisticsStatus.completed).length;
        return Row(
          children: [
            Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    color: count > 0
                        ? AdminColors.emeraldGreen
                        : AdminColors.textMuted,
                    shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text('$count ACTIVE NODES IN RANGE',
                style: const TextStyle(
                    color: AdminColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1)),
          ],
        );
      },
      loading: () => const Text('CONNECTING...',
          style: TextStyle(color: AdminColors.textMuted, fontSize: 11)),
      error: (_, __) => const Text('OFFLINE',
          style: TextStyle(color: AdminColors.rubyRed, fontSize: 11)),
    );
  }
}

class _TelemetryListView extends StatelessWidget {
  final List<LogisticsJobModel> jobs;
  const _TelemetryListView({required this.jobs});

  @override
  Widget build(BuildContext context) {
    final activeJobs =
        jobs.where((j) => j.status != LogisticsStatus.completed).toList();
    if (activeJobs.isEmpty) {
      return const Center(
          child: Text("No active logistics jobs",
              style: TextStyle(color: AdminColors.textMuted, fontSize: 12)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: activeJobs.length,
      itemBuilder: (context, index) => _TelemetryCard(job: activeJobs[index]),
    );
  }
}

class _TelemetryCard extends StatelessWidget {
  final LogisticsJobModel job;
  const _TelemetryCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final isAlert = job.status == LogisticsStatus.open;
    final statusColor =
        isAlert ? AdminColors.rubyRed : AdminColors.emeraldGreen;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminColors.slateDarkest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: isAlert
                ? AdminColors.rubyRed.withValues(alpha: 0.3)
                : AdminColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                  'Job: ${job.id.length > 6 ? job.id.substring(0, 6) : job.id}',
                  style: const TextStyle(
                      color: AdminColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                      color: statusColor, shape: BoxShape.circle)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Order: ${job.orderId}',
              style: const TextStyle(
                  color: AdminColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(job.status.name.toUpperCase(),
                  style: TextStyle(
                      color: statusColor.withValues(alpha: 0.8),
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
              Text('${(job.distanceMeters / 1000).toStringAsFixed(1)}km out',
                  style: const TextStyle(
                      color: AdminColors.textMuted, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AdminColors.borderDefault.withValues(alpha: 0.2)
      ..strokeWidth = 1.0;
    const double spacing = 40.0;
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
    final pathPaint = Paint()
      ..color = AdminColors.emeraldGreen.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width * 0.2, size.height * 0.3)
      ..quadraticBezierTo(size.width * 0.4, size.height * 0.1, size.width * 0.6,
          size.height * 0.4)
      ..quadraticBezierTo(size.width * 0.8, size.height * 0.6, size.width * 0.5,
          size.height * 0.8)
      ..close();
    canvas.drawPath(path, pathPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AgentMarker extends StatefulWidget {
  final double top, left;
  final String label, status;
  final bool isAlert;
  const _AgentMarker(
      {super.key,
      required this.top,
      required this.left,
      required this.label,
      required this.status,
      this.isAlert = false});
  @override
  State<_AgentMarker> createState() => _AgentMarkerState();
}

class _AgentMarkerState extends State<_AgentMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color =
        widget.isAlert ? AdminColors.rubyRed : AdminColors.emeraldGreen;
    return Align(
      alignment: FractionalOffset(widget.left, widget.top),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              FadeTransition(
                opacity: Tween(begin: 0.5, end: 0.0).animate(_controller),
                child: ScaleTransition(
                  scale: Tween(begin: 1.0, end: 3.0).animate(_controller),
                  child: Container(
                      width: 12,
                      height: 12,
                      decoration:
                          BoxDecoration(color: color, shape: BoxShape.circle)),
                ),
              ),
              Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1))),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: AdminColors.slateDark.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AdminColors.borderDefault)),
            child: Text(widget.label,
                style: const TextStyle(
                    color: AdminColors.textPrimary,
                    fontSize: 9,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
