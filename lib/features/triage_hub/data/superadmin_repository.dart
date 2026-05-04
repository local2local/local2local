import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Repository for Phase 44 SuperAdmin capabilities.
/// Handles multi-tenant telemetry, versioning, and agent bus streams.
///
/// Firestore structure (local2local-dev):
///   artifacts/system_status/public/data/telemetry/last_heartbeat
///     - status: "GREEN" | "YELLOW" | "RED"
///     - version: "vX.X.X"
///     - bridge: string
///     - timestamp: Timestamp
///   artifacts/system_status/public/data/abandoned_phases/{auto-id}
///   artifacts/system_status/public/data/promoted_phases/{auto-id}
class SuperadminRepository {
  final FirebaseFirestore _firestore;

  SuperadminRepository(this._firestore);

  /// Streams the current system telemetry status (GREEN | YELLOW | RED).
  Stream<String> watchSystemStatus() {
    return _firestore
        .doc('artifacts/system_status/public/data/telemetry/last_heartbeat')
        .snapshots()
        .map((doc) => doc.data()?['status'] as String? ?? 'UNKNOWN');
  }

  /// Streams the current version from the telemetry heartbeat document.
  Stream<String> watchCurrentVersion() {
    return _firestore
        .doc('artifacts/system_status/public/data/telemetry/last_heartbeat')
        .snapshots()
        .map((doc) => doc.data()?['version'] as String? ?? '–');
  }

  /// Streams agent bus entries from a specific tenant.
  /// Tenant values: 'system_status' | 'kaskflow' | 'moonlitely'
  Stream<List<Map<String, dynamic>>> watchAgentBus(String tenant) {

    final artifactId = switch (tenant) {
      'kaskflow' => 'local2local-kaskflow',
      'moonlitely' => 'local2local-moonlitely',
      _ => tenant,
    };
    final path = 'artifacts/$artifactId/public/data/agent_bus';
    debugPrint('[AgentBus] Watching: $path');
    return _firestore
        .collection(path)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          debugPrint('[AgentBus] $tenant: ${snapshot.docs.length} docs');
          for (final doc in snapshot.docs) {
            debugPrint('[AgentBus] Doc ${doc.id}: ${doc.data().keys.toList()}');
          }
          return snapshot.docs.map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            data['id'] = doc.id;
            return data;
          }).toList();
        });
  }

  /// Streams phase history (promoted or abandoned).
  /// promoted_phases sorts by promoted_at, abandoned_phases by abandoned_at.
  Stream<List<Map<String, dynamic>>> watchPhaseHistory(String collection) {
    final sortField =
        collection == 'promoted_phases' ? 'promoted_at' : 'abandoned_at';
    return _firestore
        .collection('artifacts/system_status/public/data/$collection')
        .orderBy(sortField, descending: true)
        .limit(10)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Map<String, dynamic>.from(doc.data()))
            .toList());
  }

  /// Manual Payload Injection for test sequences.
  /// Writes created_at, last_updated, and telemetry.processed_at on every write.
  Future<void> injectTestPayload({
    required String targetPath,
    required String instructions,
  }) async {
    final timestamp = DateTime.now().toIso8601String();
    final now = FieldValue.serverTimestamp();
    await _firestore
        .collection('artifacts/local2local-dev/public/data/agent_bus')
        .add({
      'status': 'dispatched',
      'correlation_id':
          'TEST-DASHBOARD-${DateTime.now().millisecondsSinceEpoch}',
      'created_at': now,
      'last_updated': now,
      'telemetry': {
        'processed_at': now,
      },
      'payload': {
        'manifest': {
          'intent': 'PROPOSE_LOGIC_CHANGE',
          'hbrId': 'HBR-DASHBOARD-TEST',
          'agentId': 'SUPERADMIN_UI',
          'reason': instructions,
          'targetPath': targetPath,
          'proposedLogic':
              '// Manual trigger from dashboard at $timestamp',
        }
      }
    });
  }
}

final superadminRepositoryProvider = Provider<SuperadminRepository>((ref) {
  return SuperadminRepository(FirebaseFirestore.instance);
});