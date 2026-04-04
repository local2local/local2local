import 'package:cloud_firestore/cloud_firestore.dart';

enum EvolutionEventType {
  criticalIntervention,
  rollback,
  humanOverride,
  agentDeployed,
  logicCommitSuccess,
  unknown
}

class EvolutionEventModel {
  final String id;
  final EvolutionEventType type;
  final String title;
  final String description;
  final String agentName;
  final bool isAutonomous;
  final DateTime timestamp;

  EvolutionEventModel({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.agentName,
    required this.isAutonomous,
    required this.timestamp,
  });

  factory EvolutionEventModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return EvolutionEventModel(
      id: doc.id,
      type: _parseType(data['type'] as String?),
      title: data['title'] as String? ?? 'System Evolution Event',
      // Fixed: Explicitly look for 'description' field written by backend
      description: data['description'] as String? ?? 'Autonomous logic update committed.',
      // Fixed: Explicitly look for 'agent_name' snake_case key
      agentName: data['agent_name'] as String? ?? 'EVOLUTION_WORKER',
      // Fixed: Explicitly look for 'is_autonomous' snake_case key
      isAutonomous: data['is_autonomous'] as bool? ?? true,
      timestamp: _parseTimestamp(data['timestamp']),
    );
  }

  String get timeDisplay {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) return 'Just Now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${timestamp.month}/${timestamp.day}';
  }

  static EvolutionEventType _parseType(String? type) {
    switch (type) {
      case 'CRITICAL_INTERVENTION_REQUIRED':
        return EvolutionEventType.criticalIntervention;
      case 'LOGIC_ROLLBACK':
        return EvolutionEventType.rollback;
      case 'HUMAN_OVERRIDE_COMMITTED':
        return EvolutionEventType.humanOverride;
      case 'AGENT_DEPLOYED':
        return EvolutionEventType.agentDeployed;
      case 'LOGIC_COMMIT_SUCCESS':
        return EvolutionEventType.logicCommitSuccess;
      default:
        return EvolutionEventType.unknown;
    }
  }

  static DateTime _parseTimestamp(dynamic ts) {
    if (ts is Timestamp) return ts.toDate();
    if (ts is String) return DateTime.tryParse(ts) ?? DateTime.now();
    return DateTime.now();
  }
}