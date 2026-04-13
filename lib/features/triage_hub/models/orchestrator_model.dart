import 'package:cloud_firestore/cloud_firestore.dart';

enum OrchestratorStatus { online, degraded, paused, offline, rollback }

enum OrchestratorType {
  compliance('Compliance'),
  finance('Finance'),
  logistics('Logistics'),
  talent('Talent'),
  customer('Customer'),
  inventory('Inventory'),
  analytics('Analytics');

  const OrchestratorType(this.label);
  final String label;
}

class OrchestratorModel {
  final String id, version, domain; // Added domain
  final OrchestratorType type;
  final OrchestratorStatus status;
  final double efficacyScore;
  final int latencyMs;

  const OrchestratorModel({
    required this.id,
    required this.type,
    required this.status,
    required this.efficacyScore,
    required this.latencyMs,
    required this.version,
    required this.domain, // Added to constructor
  });

  factory OrchestratorModel.fromFirestore(DocumentSnapshot doc) {
    final dynamic data = doc.data();
    final dynamic statusData = data['status'] ?? {};
    final dynamic deployData = data['deployment'] ?? {};

    final String rawDomain =
        (data['domain'] ?? 'GENERAL').toString().toUpperCase();
    final String health =
        (statusData['health'] ?? 'green').toString().toLowerCase();

    return OrchestratorModel(
      id: doc.id,
      domain: rawDomain,
      version: (deployData['version'] ?? 'v2.0').toString(),
      efficacyScore: (statusData['current_efficacy'] is num)
          ? (statusData['current_efficacy'] as num).toDouble()
          : 100.0,
      latencyMs: (statusData['latency_ms'] is num)
          ? (statusData['latency_ms'] as num).toInt()
          : 0,
      type: rawDomain.contains('FINANCE')
          ? OrchestratorType.finance
          : rawDomain.contains('OPS')
              ? OrchestratorType.logistics
              : OrchestratorType.compliance,
      status: statusData['mode'] == 'paused'
          ? OrchestratorStatus.paused
          : health == 'red'
              ? OrchestratorStatus.offline
              : OrchestratorStatus.online,
    );
  }

  bool get isHealthy =>
      status == OrchestratorStatus.online && efficacyScore >= 80;
  String get efficacyDisplay => '${efficacyScore.toStringAsFixed(1)}%';
  String get latencyDisplay => '${latencyMs}ms';
  bool get isWarning => efficacyScore >= 60 && efficacyScore < 80;
  bool get isCritical =>
      efficacyScore < 60 || status == OrchestratorStatus.offline;
}
