import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local2local/features/triage_hub/theme/admin_theme.dart';
import 'package:local2local/features/triage_hub/widgets/system_status_banner.dart';
import 'package:local2local/features/triage_hub/providers/environment_provider.dart';

final _agentBusProvider = StreamProvider.autoDispose.family<List<QueryDocumentSnapshot>, String>((ref, appId) {
  return FirebaseFirestore.instance
      .collection('artifacts')
      .doc(appId)
      .collection('public')
      .doc('data')
      .collection('agent_bus')
      .snapshots()
      .map((snapshot) => snapshot.docs);
});

class SuperadminDashboard extends ConsumerWidget {
  const SuperadminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final env = ref.watch(environmentProvider);
    final busAsync = ref.watch(_agentBusProvider(env.projectId));

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Superadmin Command Center',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
                  final doc = FirebaseFirestore.instance
                      .collection('artifacts')
                      .doc(env.projectId)
                      .collection('public')
                      .doc('data')
                      .collection('agent_bus')
                      .doc();
                  
                  await doc.set({
                    "status": "dispatched",
                    "correlation_id": "TEST-DASHBOARD-$timestamp",
                    "payload": {
                      "manifest": {
                        "intent": "PROPOSE_LOGIC_CHANGE",
                        "hbrId": "HBR-TEST-$timestamp",
                        "agentId": "TEST_BOT_ORCHESTRATOR",
                        "reason": "Test Injection: Dashboard manual trigger verified.",
                        "proposedLogic": "// UI manual trigger executed successfully.",
                        "targetPath": "functions/src/logic/does_not_exist.ts"
                      }
                    }
                  });
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Test Payload injected into Agent Bus!'),
                        backgroundColor: AdminColors.emeraldGreen,
                        behavior: SnackBarBehavior.floating,
                      )
                    );
                  }
                },
                icon: const Icon(Icons.rocket_launch_rounded, size: 16),
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
          const SystemStatusBanner(),
          const SizedBox(height: 40),
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
          Expanded(
            child: busAsync.when(
              data: (docs) {
                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "No active proposals in the Agent Bus.", 
                      style: TextStyle(color: AdminColors.textSecondary, fontSize: 16)
                    )
                  );
                }
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final correlationId = data['correlation_id'] ?? 'Unknown ID';
                    final status = data['status'] ?? 'pending';
                    final payload = data['payload'] as Map<String, dynamic>? ?? {};
                    final manifest = payload['manifest'] as Map<String, dynamic>? ?? {};
                    
                    final intent = manifest['intent'] ?? 'UNKNOWN_INTENT';
                    final reason = manifest['reason'] ?? 'No reason provided.';
                    final targetPath = manifest['targetPath'] ?? 'N/A';

                    final isPromoted = status.toString().toUpperCase() == 'PROMOTED';
                    final accentColor = isPromoted ? AdminColors.emeraldGreen : AdminColors.statusInfo;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AdminColors.slateDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isPromoted ? accentColor.withValues(alpha: 0.3) : AdminColors.borderDefault,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isPromoted ? Icons.check_circle : Icons.memory, 
                                    color: accentColor,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    intent,
                                    style: const TextStyle(color: AdminColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: accentColor.withValues(alpha: 0.5),
                                    width: 1,
                                  )
                                ),
                                child: Text(
                                  status.toString().toUpperCase(),
                                  style: TextStyle(
                                    color: accentColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(reason, style: const TextStyle(color: AdminColors.textSecondary, fontSize: 15, height: 1.4)),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AdminColors.slateDarkest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("ID: $correlationId", style: TextStyle(color: AdminColors.textSecondary.withValues(alpha: 0.7), fontSize: 11, fontFamily: 'monospace')),
                                const SizedBox(height: 4),
                                Text("TARGET: $targetPath", style: const TextStyle(color: AdminColors.textSecondary, fontSize: 12, fontFamily: 'monospace')),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AdminColors.emeraldGreen)),
              error: (e, s) => Center(child: Text('Error: $e', style: const TextStyle(color: AdminColors.rubyRed))),
            ),
          ),
        ],
      ),
    );
  }
}