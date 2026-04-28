import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local2local/features/triage_hub/theme/admin_theme.dart';

class SystemStatusBanner extends ConsumerWidget {
  const SystemStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: Connect to your actual StreamProvider for telemetry status
    // For now, mocked to Green/Stable as requested in Phase 42 UI setup
    const String status = 'AWAITING TELEMETRY'; 
    const Color color = AdminColors.statusWarning;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1), // Flutter 3.27 compliant
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_rounded, color: color, size: 28),
          const SizedBox(width: 16),
          Text(
            'TELEMETRY HEALTH: $status',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          Text(
            'Code modifications permitted',
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          )
        ],
      ),
    );
  }
}