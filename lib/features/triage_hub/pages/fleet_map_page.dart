import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local2local/features/triage_hub/providers/app_providers.dart';
import 'package:local2local/features/triage_hub/theme/admin_theme.dart';

/// Fleet Map Page - Geographic distribution of services
class FleetMapPage extends ConsumerWidget {
  const FleetMapPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentApp = ref.watch(currentAppProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AdminColors.slateMedium,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AdminColors.borderDefault),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.map_rounded,
                      color: AdminColors.emeraldGreen,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Fleet Map',
                      style: TextStyle(
                        color: AdminColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AdminColors.emeraldGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        currentApp.displayName,
                        style: const TextStyle(
                          color: AdminColors.emeraldGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Geographic distribution of your fleet nodes and edge locations.',
                  style: TextStyle(
                    color: AdminColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Map placeholder
          Container(
            height: 400,
            decoration: BoxDecoration(
              color: AdminColors.slateMedium,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AdminColors.borderDefault),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.map_outlined,
                    size: 64,
                    color: AdminColors.textMuted.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Fleet Map Visualization',
                    style: TextStyle(
                      color: AdminColors.textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Interactive map coming soon',
                    style: TextStyle(
                      color: AdminColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Region list
          const Text(
            'Active Regions',
            style: TextStyle(
              color: AdminColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _RegionList(),
        ],
      ),
    );
  }
}

class _RegionList extends StatelessWidget {
  final regions = const [
    {'name': 'US East (N. Virginia)', 'nodes': 8, 'latency': '12ms'},
    {'name': 'US West (Oregon)', 'nodes': 6, 'latency': '18ms'},
    {'name': 'Europe (Frankfurt)', 'nodes': 5, 'latency': '45ms'},
    {'name': 'Asia Pacific (Tokyo)', 'nodes': 4, 'latency': '89ms'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.slateMedium,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.borderDefault),
      ),
      child: Column(
        children: regions.map((region) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AdminColors.borderDefault),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  color: AdminColors.emeraldGreen,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    region['name'] as String,
                    style: const TextStyle(
                      color: AdminColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  '${region['nodes']} nodes',
                  style: const TextStyle(
                    color: AdminColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 24),
                Text(
                  region['latency'] as String,
                  style: const TextStyle(
                    color: AdminColors.emeraldGreen,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
