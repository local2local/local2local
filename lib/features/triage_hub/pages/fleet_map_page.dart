import 'package:flutter/material.dart';
import 'package:local2local/features/triage_hub/theme/admin_theme.dart';

class FleetMapPage extends StatelessWidget {
  const FleetMapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AdminColors.slateDarkest,
      child: Row(
        children: [
          // 1. Primary Map Area
          Expanded(
            child: Stack(
              children: [
                // Abstract Map Grid / Background
                Positioned.fill(
                  child: CustomPaint(
                    painter: _MapGridPainter(),
                  ),
                ),
                // Map Header Overlay
                Positioned(
                  top: 24,
                  left: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Fleet Geo-Intelligence',
                        style: TextStyle(
                          color: AdminColors.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AdminColors.emeraldGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '12 ACTIVE NODES IN RANGE',
                            style: TextStyle(
                              color: AdminColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Pulse Markers (Simulated Agent Locations)
                // FIX: These now use Align internally to avoid the ParentDataWidget error
                const _AgentMarker(
                    top: 0.3, left: 0.4, label: 'Node-Alpha', status: 'Online'),
                const _AgentMarker(
                    top: 0.5, left: 0.7, label: 'Node-Beta', status: 'Transit'),
                const _AgentMarker(
                    top: 0.2, left: 0.8, label: 'Node-Gamma', status: 'Online'),
                const _AgentMarker(
                    top: 0.7,
                    left: 0.3,
                    label: 'Node-Delta',
                    status: 'Offline',
                    isAlert: true),
              ],
            ),
          ),

          // 2. Telemetry Sidebar (Right-hand side)
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
                  child: Text(
                    'TELEMETRY STREAM',
                    style: TextStyle(
                      color: AdminColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const Divider(height: 1, color: AdminColors.borderDefault),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: const [
                      _TelemetryCard(
                        title: 'Node-Alpha',
                        detail: 'Position: 51.5074° N, 0.1278° W',
                        metrics: 'Ping: 14ms | Load: 12%',
                        isActive: true,
                      ),
                      _TelemetryCard(
                        title: 'Node-Beta',
                        detail: 'Moving: East toward Sector 7',
                        metrics: 'Ping: 42ms | Velocity: 45km/h',
                        isActive: true,
                      ),
                      _TelemetryCard(
                        title: 'Node-Delta',
                        detail: 'Connection lost in Sector 4',
                        metrics: 'Last Seen: 4 mins ago',
                        isAlert: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
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

    // Draw Vertical Lines
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }

    // Draw Horizontal Lines
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }

    // Draw some "Map Contours"
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
  final double top;
  final double left;
  final String label;
  final String status;
  final bool isAlert;

  const _AgentMarker({
    required this.top,
    required this.left,
    required this.label,
    required this.status,
    this.isAlert = false,
  });

  @override
  State<_AgentMarker> createState() => _AgentMarkerState();
}

class _AgentMarkerState extends State<_AgentMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
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

    // FIX: Switched from Positioned + LayoutBuilder to Align + FractionalOffset.
    // This resolves the "Incorrect use of ParentDataWidget" error because Align
    // works correctly as a direct child of Stack and manages its own layout offset.
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
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AdminColors.slateDark.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AdminColors.borderDefault),
            ),
            child: Text(
              widget.label,
              style: const TextStyle(
                  color: AdminColors.textPrimary,
                  fontSize: 9,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _TelemetryCard extends StatelessWidget {
  final String title;
  final String detail;
  final String metrics;
  final bool isActive;
  final bool isAlert;

  const _TelemetryCard({
    required this.title,
    required this.detail,
    required this.metrics,
    this.isActive = false,
    this.isAlert = false,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = isAlert
        ? AdminColors.rubyRed
        : (isActive ? AdminColors.emeraldGreen : AdminColors.textSecondary);

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
                title,
                style: const TextStyle(
                    color: AdminColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                width: 6,
                height: 6,
                decoration:
                    BoxDecoration(color: statusColor, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style:
                const TextStyle(color: AdminColors.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 8),
          Text(
            metrics,
            style: TextStyle(
                color: statusColor.withValues(alpha: 0.8),
                fontSize: 10,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
