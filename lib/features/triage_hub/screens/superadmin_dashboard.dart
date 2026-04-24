import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/system_status_banner.dart';

final agentBusProvider = StreamProvider.autoDispose<List<QueryDocumentSnapshot>>((ref) {
  return FirebaseFirestore.instance
      .collection('artifacts/local2local-kaskflow/public/data/agent_bus')
      .snapshots()
      .map((snapshot) => snapshot.docs);
});

class SuperadminDashboard extends ConsumerWidget {
  const SuperadminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busAsync = ref.watch(agentBusProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          'L2LAAF Control Tower', 
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 1.2)
        ),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 4,
        shadowColor: Colors.black45,
      ),
      body: Column(
        children: [
          const SystemStatusBanner(),
          Expanded(
            child: busAsync.when(
              data: (docs) {
                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "No active proposals in the Agent Bus.", 
                      style: TextStyle(color: Colors.white54, fontSize: 16)
                    )
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
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

                    return Card(
                      color: const Color(0xFF1E293B),
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isPromoted ? Colors.green.withValues(alpha: 0.3) : Colors.blueAccent.withValues(alpha: 0.3),
                          width: 1,
                        )
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
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
                                      color: isPromoted ? Colors.greenAccent : Colors.blueAccent,
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
                                    color: isPromoted ? Colors.green.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isPromoted ? Colors.green : Colors.orange,
                                      width: 1,
                                    )
                                  ),
                                  child: Text(
                                    status.toString().toUpperCase(),
                                    style: TextStyle(
                                      color: isPromoted ? Colors.greenAccent : Colors.orangeAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(reason, style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.4)),
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("ID: $correlationId", style: const TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'monospace')),
                                  const SizedBox(height: 4),
                                  Text("TARGET: $targetPath", style: const TextStyle(color: Colors.white54, fontSize: 12, fontFamily: 'monospace')),
                                ],
                              ),
                            ),
                          ],
                        ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final doc = FirebaseFirestore.instance.collection('artifacts/local2local-kaskflow/public/data/agent_bus').doc();
          await doc.set({
            "status": "dispatched",
            "correlation_id": "TEST-DASHBOARD-${DateTime.now().millisecondsSinceEpoch}",
            "payload": {
              "manifest": {
                "intent": "PROPOSE_LOGIC_CHANGE",
                "hbrId": "HBR-DASHBOARD-TEST",
                "agentId": "TEST_BOT_ORCHESTRATOR",
                "reason": "Test E: Dashboard manual trigger verified.",
                "proposedLogic": "// UI manual trigger executed successfully.",
                "targetPath": "functions/src/logic/does_not_exist.ts"
              }
            }
          });
          
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Test Payload injected into Agent Bus! Check Google Chat.'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              )
            );
          }
        },
        label: const Text("Inject Test Payload", style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.rocket_launch),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
    );
  }
}