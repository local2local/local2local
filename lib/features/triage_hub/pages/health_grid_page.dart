import 'package:flutter/material.dart';
import 'package:local2local/features/triage_hub/theme/admin_theme.dart';

class HealthGridPage extends StatelessWidget {
  const HealthGridPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AdminColors.slateDarkest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section - Fully flexible Wrap
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
                // Status Badge - Ensuring min size to avoid inner row overflow
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AdminColors.emeraldGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AdminColors.emeraldGreen.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: AdminColors.emeraldGreen, size: 14),
                      SizedBox(width: 8),
                      Text(
                        'ALL SYSTEMS OPERATIONAL',
                        style: TextStyle(
                          color: AdminColors.emeraldGreen,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AdminColors.borderDefault),

          // Content Section - Replaced GridView with Wrap in a ScrollView
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Calculate dynamic card width based on available space
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
                    children: _healthData
                        .map((data) => SizedBox(
                              width: cardWidth,
                              child: _HealthCard(
                                service: data['service'],
                                status: data['status'],
                                uptime: data['uptime'],
                                latency: data['latency'],
                                icon: data['icon'],
                                color: data['color'],
                              ),
                            ))
                        .toList(),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final List<Map<String, dynamic>> _healthData = [
  {
    'service': 'Firebase Auth',
    'status': 'Operational',
    'uptime': '99.99%',
    'latency': '42ms',
    'icon': Icons.lock_person_rounded,
    'color': AdminColors.emeraldGreen,
  },
  {
    'service': 'Xero API Gateway',
    'status': 'Operational',
    'uptime': '98.5%',
    'latency': '156ms',
    'icon': Icons.account_balance_rounded,
    'color': AdminColors.emeraldGreen,
  },
  {
    'service': 'Stripe Webhooks',
    'status': 'Operational',
    'uptime': '100%',
    'latency': '12ms',
    'icon': Icons.payments_rounded,
    'color': AdminColors.emeraldGreen,
  },
  {
    'service': 'Agent Cluster Alpha',
    'status': 'Degraded',
    'uptime': '94.2%',
    'latency': '890ms',
    'icon': Icons.hub_rounded,
    'color': AdminColors.statusWarning,
  },
  {
    'service': 'Firestore Core',
    'status': 'Operational',
    'uptime': '99.9%',
    'latency': '24ms',
    'icon': Icons.storage_rounded,
    'color': AdminColors.emeraldGreen,
  },
  {
    'service': 'Search Engine',
    'status': 'Operational',
    'uptime': '99.7%',
    'latency': '68ms',
    'icon': Icons.search_rounded,
    'color': AdminColors.emeraldGreen,
  },
];

class _HealthCard extends StatelessWidget {
  final String service;
  final String status;
  final String uptime;
  final String latency;
  final IconData icon;
  final Color color;

  const _HealthCard({
    required this.service,
    required this.status,
    required this.uptime,
    required this.latency,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // Removed fixed height constraints (natural height)
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminColors.slateDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.borderDefault),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Shrink wrap height
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 4,
                        spreadRadius: 1),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            service,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AdminColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            status,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          // Metrics Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Metric(label: 'UPTIME', value: uptime),
              _Metric(label: 'LATENCY', value: latency),
            ],
          ),
        ],
      ),
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
        Text(
          label,
          style: const TextStyle(
              color: AdminColors.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
              color: AdminColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
