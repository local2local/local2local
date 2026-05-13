import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local2local/features/triage_hub/theme/admin_theme.dart';
import 'package:local2local/features/triage_hub/widgets/system_status_banner.dart';
import 'package:local2local/features/triage_hub/providers/superadmin_providers.dart';
import 'package:local2local/features/triage_hub/data/superadmin_repository.dart';

/// Main Cockpit Dashboard for Phase 44/45 SuperAdmin operations.
/// Features multi-tenant agent bus monitoring and live telemetry.
class SuperadminDashboard extends ConsumerStatefulWidget {
  const SuperadminDashboard({super.key});

  @override
  ConsumerState<SuperadminDashboard> createState() => _SuperadminDashboardState();
}

class _SuperadminDashboardState extends ConsumerState<SuperadminDashboard> {
  int _selectedTenantIndex = 0;

  @override
  Widget build(BuildContext context) {
    final systemBus = ref.watch(systemAgentBusProvider);
    final kaskflowBus = ref.watch(kaskflowAgentBusProvider);
    final moonlitelyBus = ref.watch(moonlitelyAgentBusProvider);

    return Scaffold(
      backgroundColor: AdminColors.slateDarkest,
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Superadmin Dashboard',
                  style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showTestInjectModal(context),
                  icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                  label: const Text('Test Inject'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminColors.slateDark,
                    foregroundColor: AdminColors.emeraldGreen,
                    side: BorderSide(color: AdminColors.emeraldGreen.withValues(alpha: 0.5)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const SystemStatusBanner(),
            const SizedBox(height: 40),
            Row(
              children: [
                _buildTab('SYSTEM', 0),
                _buildTab('KASKFLOW', 1),
                _buildTab('MOONLITELY', 2),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: AdminColors.borderDefault, height: 1),
            const SizedBox(height: 16),
            Expanded(
              child: _buildBusList(_selectedTenantIndex == 0 
                  ? systemBus 
                  : _selectedTenantIndex == 1 ? kaskflowBus : moonlitelyBus),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedTenantIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTenantIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: isSelected ? AdminColors.emeraldGreen : Colors.transparent, width: 2)),
        ),
        child: Text(
          label,
          style: TextStyle(color: isSelected ? Colors.white : AdminColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildBusList(AsyncValue<List<Map<String, dynamic>>> busAsync) {
    return busAsync.when(
      data: (items) {
        if (items.isEmpty) return const Center(child: Text('No active bus traffic.', style: TextStyle(color: AdminColors.textSecondary)));
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) => _buildProposalCard(items[index]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AdminColors.emeraldGreen)),
      error: (e, _) => Center(child: Text('Bus Error: $e', style: const TextStyle(color: AdminColors.rubyRed))),
    );
  }

  Widget _buildProposalCard(Map<String, dynamic> data) {
    final Map<String, dynamic> manifest = data['payload']?['manifest'] != null 
        ? Map<String, dynamic>.from(data['payload']['manifest'])
        : {};
    final status = data['status'] ?? 'unknown';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.slateDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AdminColors.borderDefault),
      ),
      child: Row(
        children: [
          const Icon(Icons.hub_rounded, color: AdminColors.emeraldGreen, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(manifest['reason']?.toString() ?? 'Autonomous Proposal', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text('Target: ${manifest['targetPath']?.toString() ?? 'Unknown'}', style: const TextStyle(color: AdminColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Text(status.toString().toUpperCase(), style: const TextStyle(color: AdminColors.emeraldGreen, fontSize: 10, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  void _showTestInjectModal(BuildContext context) {
    final TextEditingController pathController = TextEditingController(text: 'lib/features/triage_hub/widgets/system_status_banner.dart');
    final TextEditingController reasonController = TextEditingController(text: "Update status string to 'AWAITING TELEMETRY'.");

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AdminColors.slateDark,
        title: const Text('Manual Logic Injection', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: pathController, decoration: const InputDecoration(labelText: 'Target Path', labelStyle: TextStyle(color: AdminColors.textSecondary)), style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 16),
            TextField(controller: reasonController, maxLines: 3, decoration: const InputDecoration(labelText: 'Instructions', labelStyle: TextStyle(color: AdminColors.textSecondary)), style: const TextStyle(color: Colors.white)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(superadminRepositoryProvider).injectTestPayload(targetPath: pathController.text, instructions: reasonController.text);
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('INJECT'),
          ),
        ],
      ),
    );
  }
}