import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Repository for Phase 44 SuperAdmin capabilities.
/// Handles multi-tenant telemetry, versioning, and agent bus streams.
class SuperadminRepository {
  final FirebaseFirestore _firestore;

  SuperadminRepository(this._firestore);

  /// Streams the current system telemetry status from the system root.
  Stream<String> watchSystemStatus() {
    return _firestore
        .doc('artifacts/system_status/public/data/telemetry/current')
        .snapshots()
        .map((doc) => doc.data()?['status'] as String? ?? 'UNKNOWN');
  }

  /// Streams the current app version from Firestore.
  Stream<String> watchCurrentVersion() {
    return _firestore
        .doc('artifacts/system_status/public/data/version/current')
        .snapshots()
        .map((doc) => doc.data()?['version'] as String? ?? '0.0.0');
  }

  /// Streams agent bus entries from a specific tenant.
  Stream<List<Map<String, dynamic>>> watchAgentBus(String tenant) {
    return _firestore
        .collection('artifacts/$tenant/public/data/agent_bus')
        .orderBy('created_at', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = Map<String, dynamic>.from(doc.data());
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  /// Streams phase history (promoted or abandoned).
  Stream<List<Map<String, dynamic>>> watchPhaseHistory(String collection) {
    return _firestore
        .collection('artifacts/system_status/public/data/$collection')
        .orderBy('timestamp', descending: true)
        .limit(10)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Map<String, dynamic>.from(doc.data()))
            .toList());
  }

  /// Manual Payload Injection for Test Sequence A.
  Future<void> injectTestPayload({
    required String targetPath,
    required String instructions,
  }) async {
    final timestamp = DateTime.now().toIso8601String();
    await _firestore.collection('artifacts/local2local-dev/public/data/agent_bus').add({
      'status': 'dispatched',
      'correlation_id': 'TEST-DASHBOARD-${DateTime.now().millisecondsSinceEpoch}',
      'created_at': FieldValue.serverTimestamp(),
      'payload': {
        'manifest': {
          'intent': 'PROPOSE_LOGIC_CHANGE',
          'hbrId': 'HBR-DASHBOARD-TEST',
          'agentId': 'SUPERADMIN_UI',
          'reason': instructions,
          'targetPath': targetPath,
          'proposedLogic': '// Manual trigger from dashboard at $timestamp',
        }
      }
    });
  }
}

final superadminRepositoryProvider = Provider<SuperadminRepository>((ref) {
  return SuperadminRepository(FirebaseFirestore.instance);
});