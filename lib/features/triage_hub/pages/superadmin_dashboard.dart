import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local2local/features/triage_hub/theme/admin_theme.dart';
import 'package:local2local/features/triage_hub/widgets/system_status_banner.dart';

class SuperadminDashboard extends ConsumerWidget {
  const SuperadminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AdminColors.slateDarkest,
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Superadmin Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Implement Phase 42 Manual Payload Injection
                  },
                  icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                  label: const Text('Test Inject'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminColors.slateDark,
                    foregroundColor: AdminColors.emeraldGreen,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    side: BorderSide(
                      color: AdminColors.emeraldGreen.withValues(alpha: 0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            // Phase 42: Telemetry Banner
            const SystemStatusBanner(),
            const SizedBox(height: 40),
            
            // Agent Bus Section Title
            const Text(
              'AGENT BUS (ACTIVE PROPOSALS)',
              style: TextStyle(
                color: AdminColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: AdminColors.borderDefault, height: 1),
            const SizedBox(height: 16),
            
            // Placeholder List - To be connected to agent_bus stream
            Expanded(
              child: ListView.builder(
                itemCount: 2, 
                itemBuilder: (context, index) {
                  return _buildProposalCard(index);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProposalCard(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminColors.slateDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.borderDefault),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Proposal ID: EVOLVE-${1042 + index}',
                style: const TextStyle(
                  color: Colors.white, 
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Status: Pending Orchestration',
                style: TextStyle(
                  color: AdminColors.textSecondary.withValues(alpha: 0.9), 
                  fontSize: 14,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded, color: AdminColors.textSecondary, size: 20),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}