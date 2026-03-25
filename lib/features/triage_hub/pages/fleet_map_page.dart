import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/logistics_job_model.dart';
import '../providers/app_providers.dart';
import '../theme/admin_theme.dart';

class FleetMapPage extends ConsumerWidget {
  const FleetMapPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fleetAsync = ref.watch(fleetProvider);

    return Container(
      color: AdminColors.slateDarkest,
      child: fleetAsync.when(
        data: (jobs) => _FleetMapContent(jobs: jobs),
        loading: () => const Center(
            child: CircularProgressIndicator(color: AdminColors.emeraldGreen)),
        error: (e, _) => Center(
            child: Text('Map Error: $e',
                style: const TextStyle(color: AdminColors.rubyRed))),
      ),
    );
  }
}

class _FleetMapContent extends StatelessWidget {
  final List<LogisticsJobModel> jobs;
  const _FleetMapContent({required this.jobs});

  @override
  Widget build(BuildContext context) {
    final activeJobs =
        jobs.where((j) => j.lat != null && j.lng != null).toList();

    return Stack(
      children: [
        // 1. Map Background (Custom Grid)
        Positioned.fill(
          child: CustomPaint(
            painter: _MapGridPainter(),
          ),
        ),

        // 2. Active Job Markers
        ...activeJobs.map((job) => _FleetMarker(job: job)),

        // 3. Status Overlay
        Positioned(
          top: 24,
          left: 24,
          child: _MapStatsHeader(activeCount: activeJobs.length),
        ),
      ],
    );
  }
}

class _FleetMarker extends StatelessWidget {
  final LogisticsJobModel job;
  const _FleetMarker({required this.job});

  @override
  Widget build(BuildContext context) {
    // Coordinate projection (Simplified for demonstration)
    // In a production app, we would use a library like flutter_map
    // Here we map Lat/Lng to relative % of the screen for the "Fleet Grid"
    final double top = _projectLat(job.lat!);
    final double left = _projectLng(job.lng!);

    return AnimatedPositioned(
      duration: const Duration(seconds: 1),
      top: top,
      left: left,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Tooltip(
          message: 'Order: ${job.orderId}\nCarrier: ${job.carrierId}',
          child: Column(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: AdminColors.emeraldGreen,
                  shape: BoxShape.circle,
                  border: Border.all(color: AdminColors.textPrimary, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AdminColors.emeraldGreen.withValues(alpha: 0.5),
                      blurRadius: 10,
                      spreadRadius: 4,
                    )
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AdminColors.slateDark.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  job.carrierId.substring(0, 5),
                  style: const TextStyle(
                      color: AdminColors.textPrimary,
                      fontSize: 8,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Simplified projections for the "Handshake" test
  double _projectLat(double lat) =>
      (53.6 - lat) * 5000 + 100; // Relative to Edmonton base
  double _projectLng(double lng) => (lng + 113.6) * 4000 + 100;
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AdminColors.borderDefault.withValues(alpha: 0.3)
      ..strokeWidth = 1;

    const double spacing = 50;
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class _MapStatsHeader extends StatelessWidget {
  final int activeCount;
  const _MapStatsHeader({required this.activeCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AdminColors.slateDark.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AdminColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('FLEET STATUS',
              style: TextStyle(
                  color: AdminColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.local_shipping,
                  color: AdminColors.emeraldGreen, size: 18),
              const SizedBox(width: 8),
              Text('$activeCount Active Units',
                  style: const TextStyle(
                      color: AdminColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
