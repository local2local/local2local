import 'package:flutter/material.dart';
import 'package:local2local/features/triage_hub/theme/admin_theme.dart';

class EvolutionTimelinePage extends StatelessWidget {
  const EvolutionTimelinePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AdminColors.slateDarkest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section - Refactored for Responsiveness
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                // Title Section - Constrained to prevent overflow
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'System Evolution',
                        style: TextStyle(
                          color: AdminColors.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Chronological trace of Agent protocols and L2LAAF milestones.',
                        style: TextStyle(
                            color: AdminColors.textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                // Filter Chips Section
                const Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FilterChip(label: 'All Events', isSelected: true),
                    _FilterChip(label: 'Protocol Updates', isSelected: false),
                    _FilterChip(label: 'Agent Versions', isSelected: false),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AdminColors.borderDefault),

          // Timeline List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              children: [
                const _TimelineEvent(
                  date: 'MAR 29, 2026',
                  title: 'Security Hardening: Double-Guard Implemented',
                  description:
                      'Cryptographic Custom Claims verification fused with GoRouter navigation guards to eliminate sensitive data leakage on Flutter Web.',
                  icon: Icons.security_rounded,
                  color: AdminColors.emeraldGreen,
                  isLast: false,
                ),
                const _TimelineEvent(
                  date: 'MAR 24, 2026',
                  title: 'Agent Protocol v4.2 Deployment',
                  description:
                      'Enhanced Treasury Worker reasoning trace. Added support for multi-tenant Xero reconciliation exceptions.',
                  icon: Icons.precision_manufacturing_rounded,
                  color: AdminColors.statusInfo,
                  isLast: false,
                ),
                const _TimelineEvent(
                  date: 'MAR 15, 2026',
                  title: 'Fleet Map Integration',
                  description:
                      'Real-time geospatial tracking of local service agents enabled via Firestore geo-queries.',
                  icon: Icons.map_rounded,
                  color: AdminColors.statusWarning,
                  isLast: false,
                ),
                const _TimelineEvent(
                  date: 'FEB 28, 2026',
                  title: 'L2LAAF Infrastructure Genesis',
                  description:
                      'Initial project setup. Github Actions CI/CD pipelines established with Flutter 3.38.5 pinning.',
                  icon: Icons.auto_awesome_mosaic_rounded,
                  color: AdminColors.textSecondary,
                  isLast: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineEvent extends StatelessWidget {
  final String date;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isLast;

  const _TimelineEvent({
    required this.date,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column: The "Strand"
          Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: color.withValues(alpha: 0.3), width: 2),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: AdminColors.borderDefault,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 24),
          // Right Column: The Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    date,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      color: AdminColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity, // Ensure card fills available space
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AdminColors.slateDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AdminColors.borderDefault),
                    ),
                    child: Text(
                      description,
                      style: const TextStyle(
                        color: AdminColors.textSecondary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;

  const _FilterChip({required this.label, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? AdminColors.emeraldGreen.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              isSelected ? AdminColors.emeraldGreen : AdminColors.borderDefault,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color:
              isSelected ? AdminColors.emeraldGreen : AdminColors.textSecondary,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
