import 'package:cloud_firestore/cloud_firestore.dart';

/// Orchestrator Agent Status
enum OrchestratorStatus {
  online('Online', 'Operating normally'),
  degraded('Degraded', 'Performance issues detected'),
  paused('Paused', 'Manually paused by admin'),
  offline('Offline', 'Not responding'),
  rollback('Rollback', 'Rolling back to previous version');

  const OrchestratorStatus(this.label, this.description);
  final String label;
  final String description;
}

/// The 7 "Brain" Orchestrator Agents
enum OrchestratorType {
  compliance('Compliance', 'AGLC & regulatory enforcement'),
  finance('Finance', 'Payouts, invoicing, fraud detection'),
  logistics('Logistics', 'Route optimization, carrier dispatch'),
  talent('Talent', 'Worker matching & scheduling'),
  customer('Customer', 'Support, escalation handling'),
  inventory('Inventory', 'Stock management & forecasting'),
  analytics('Analytics', 'Reporting & insights generation');

  const OrchestratorType(this.label, this.description);
  final String label;
  final String description;
}

class OrchestratorModel {
  final String id;
  final OrchestratorType type;
  final OrchestratorStatus status;
  final double efficacyScore;
  final int latencyMs;
  final int currentBacklog;
  final int processedToday;
  final int errorsToday;
  final String version;
  final DateTime lastHeartbeat;

  const OrchestratorModel({
    required this.id,
    required this.type,
    required this.status,
    required this.efficacyScore,
    required this.latencyMs,
    required this.currentBacklog,
    required this.processedToday,
    required this.errorsToday,
    required this.version,
    required this.lastHeartbeat,
  });

  /// Factory to map Firestore 'agent_registry' documents to UI model
  factory OrchestratorModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final statusData = data['status'] as Map<String, dynamic>? ?? {};
    final deployData = data['deployment'] as Map<String, dynamic>? ?? {};

    // Map Domain/Type
    final domain = data['domain']?.toString().toUpperCase() ?? '';
    OrchestratorType type = OrchestratorType.compliance;
    if (domain.contains('FINANCE')) type = OrchestratorType.finance;
    if (domain.contains('OPS')) type = OrchestratorType.logistics;
    if (domain.contains('INSIGHTS')) type = OrchestratorType.analytics;

    // Map Health to Status
    final health = statusData['health']?.toString().toLowerCase() ?? 'green';
    OrchestratorStatus status = (statusData['mode'] == 'paused')
        ? OrchestratorStatus.paused
        : (health == 'red')
            ? OrchestratorStatus.offline
            : OrchestratorStatus.online;

    return OrchestratorModel(
      id: doc.id,
      type: type,
      status: status,
      efficacyScore: (statusData['current_efficacy'] ?? 100).toDouble(),
      latencyMs: (statusData['latency_ms'] ?? 0).toInt(),
      currentBacklog: (statusData['backlog_count'] ?? 0).toInt(),
      processedToday: (statusData['processed_today'] ?? 0).toInt(),
      errorsToday: (statusData['errors_today'] ?? 0).toInt(),
      version: deployData['version'] ?? 'v2.0.0',
      lastHeartbeat: (statusData['last_heartbeat'] is Timestamp)
          ? (statusData['last_heartbeat'] as Timestamp).toDate()
          : DateTime.tryParse(statusData['last_heartbeat'] ?? '') ??
              DateTime.now(),
    );
  }

  bool get isHealthy =>
      status == OrchestratorStatus.online && efficacyScore >= 80;
  bool get isWarning => efficacyScore >= 60 && efficacyScore < 80;
  bool get isCritical =>
      efficacyScore < 60 || status == OrchestratorStatus.offline;

  String get efficacyDisplay => '${efficacyScore.toStringAsFixed(1)}%';
  String get latencyDisplay => '${latencyMs}ms';
}
