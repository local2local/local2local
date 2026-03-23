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

/// Orchestrator Agent Model matching Firestore structure
/// Path: artifacts/{appId}/public/data/agent_registry
class OrchestratorModel {
  final String id;
  final OrchestratorType type;
  final OrchestratorStatus status;
  final double efficacyScore; // E score (0-100)
  final int latencyMs; // P score - latency in milliseconds
  final int currentBacklog; // Queue depth
  final int processedToday;
  final int errorsToday;
  final String version;
  final DateTime lastHeartbeat;
  final DateTime? lastRollback;
  final Map<String, dynamic>? config;

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
    this.lastRollback,
    this.config,
  });

  bool get isHealthy => status == OrchestratorStatus.online && efficacyScore >= 80;
  bool get isWarning => efficacyScore >= 60 && efficacyScore < 80;
  bool get isCritical => efficacyScore < 60 || status == OrchestratorStatus.offline;

  String get efficacyDisplay => '${efficacyScore.toStringAsFixed(1)}%';
  String get latencyDisplay => '${latencyMs}ms';

  OrchestratorModel copyWith({
    String? id,
    OrchestratorType? type,
    OrchestratorStatus? status,
    double? efficacyScore,
    int? latencyMs,
    int? currentBacklog,
    int? processedToday,
    int? errorsToday,
    String? version,
    DateTime? lastHeartbeat,
    DateTime? lastRollback,
    Map<String, dynamic>? config,
  }) {
    return OrchestratorModel(
      id: id ?? this.id,
      type: type ?? this.type,
      status: status ?? this.status,
      efficacyScore: efficacyScore ?? this.efficacyScore,
      latencyMs: latencyMs ?? this.latencyMs,
      currentBacklog: currentBacklog ?? this.currentBacklog,
      processedToday: processedToday ?? this.processedToday,
      errorsToday: errorsToday ?? this.errorsToday,
      version: version ?? this.version,
      lastHeartbeat: lastHeartbeat ?? this.lastHeartbeat,
      lastRollback: lastRollback ?? this.lastRollback,
      config: config ?? this.config,
    );
  }
}
