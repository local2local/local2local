import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

final _systemStatusProvider = StreamProvider.autoDispose<String>((ref) {
  return FirebaseFirestore.instance
      .collection('artifacts')
      .doc('system_status')
      .collection('public')
      .doc('data')
      .collection('telemetry')
      .doc('current')
      .snapshots()
      .map((snap) => snap.data()?['status'] as String? ?? 'GREEN');
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
                  final doc = FirebaseFirestore.instance
                      .collection('artifacts')
                      .doc(env.projectId)
                      .collection('public')
                      .doc('data')
                      .collection('agent_bus')
                      .doc();
                  
                  await doc.set({
                    "status": "dispatched",
                    "correlation_id": "TEST-DASHBOARD-${DateTime.now().millisecondsSinceEpoch}",
                    "payload": {
                      "manifest": {
                        "intent": "PROPOSE_LOGIC_CHANGE",
                        "hbrId": "HBR-DASHBOARD-TEST",
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
                        backgroundColor: Colors.greenAccent,
                        behavior: SnackBarBehavior.floating,
                      )
                    );
                  }
                },
                icon: const Icon(Icons.rocket_launch_rounded, size: 16),
                label: const Text('Test Inject'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E1E2C),
                  foregroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  side: BorderSide(
                    color: Colors.blueAccent.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const _SystemStatusBanner(),
          const SizedBox(height: 40),
          const Text(
            'AGENT BUS (ACTIVE PROPOSALS)',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
          const SizedBox(height: 16),
          Expanded(
            child: busAsync.when(
              data: (docs) {
                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "No active proposals in the Agent Bus.", 
                      style: TextStyle(color: Colors.white38, fontSize: 14)
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
                    final accentColor = isPromoted ? Colors.greenAccent : Colors.blueAccent;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E2C),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isPromoted ? accentColor.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.1),
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
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
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
                          Text(reason, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F0F1E),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("ID: $correlationId", style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace')),
                                const SizedBox(height: 4),
                                Text("TARGET: $targetPath", style: const TextStyle(color: Colors.white54, fontSize: 11, fontFamily: 'monospace')),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
              error: (e, s) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.redAccent))),
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemStatusBanner extends ConsumerWidget {
  const _SystemStatusBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(_systemStatusProvider);

    return statusAsync.when(
      data: (status) {
        Color color = Colors.greenAccent;
        IconData icon = Icons.check_circle_rounded;
        String text = 'TELEMETRY HEALTH: STABLE';
        String subtext = 'Code modifications permitted';

        if (status == 'YELLOW') {
          color = Colors.orangeAccent;
          icon = Icons.warning_amber_rounded;
          text = 'TELEMETRY HEALTH: WARNING';
          subtext = 'Feature deployments delayed by 60s';
        } else if (status == 'RED') {
          color = Colors.redAccent;
          icon = Icons.error_outline_rounded;
          text = 'TELEMETRY HEALTH: CRITICAL';
          subtext = 'Feature deployments completely blocked';
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            border: Border.all(color: color.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 16),
              Text(
                text,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                subtext,
                style: TextStyle(
                  color: color.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              )
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        color: const Color(0xFF1E1E2C),
        child: const Text("TELEMETRY DISCONNECTED", style: TextStyle(color: Colors.white54)),
      ),
    );
  }
}