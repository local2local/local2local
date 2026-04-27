import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local2local/features/triage_hub/theme/admin_theme.dart';

class SystemStatusBanner extends ConsumerWidget {
  const SystemStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: Connect to your actual StreamProvider for telemetry status
    // For now, mocked to Green/Stable as requested in Phase 42 UI setup
    const String status = 'STABLE'; 
    const Color color = AdminColors.emeraldGreen;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1), // Corrected to use withOpacity
        border: Border.all(color: color.withOpacity(0.3)), // Corrected to use withOpacity
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: color, size: 28),
          const SizedBox(width: 16),
          Text( // Changed to Text widget without const for string interpolation
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
              color: color.withOpacity(0.8), // Corrected to use withOpacity
              fontSize: 12,
            ),
          )
        ],
      ),
    );
  }
}