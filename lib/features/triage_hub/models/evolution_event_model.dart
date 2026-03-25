import 'package:cloud_firestore/cloud_firestore.dart';

enum EvolutionEventType {
  agentDeployed('Agent Deployed'),
  ruleAdded('Rule Added'),
  ruleModified('Rule Modified'),
  thresholdChanged('Threshold Changed'),
  rollback('Rollback'),
  humanOverride('Human Override'),
  patternLearned('Pattern Learned'),
  systemEvolved('System Evolved'),
  criticalIntervention('Intervention Required');

  const EvolutionEventType(this.label);
  final String label;
}

class EvolutionEventModel {
  final String id;
  final EvolutionEventType type;
  final String title;
  final String description;
  final String agentName;
  final DateTime timestamp;
  final bool isAutonomous;
  final String? triggeredBy;

  const EvolutionEventModel({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.agentName,
    required this.timestamp,
    required this.isAutonomous,
    this.triggeredBy,
  });

  factory EvolutionEventModel.fromFirestore(DocumentSnapshot doc) {
    final dynamic data = doc.data();

    final typeStr = data['type']?.toString() ?? 'SYSTEM_EVOLVED';
    EvolutionEventType type = EvolutionEventType.systemEvolved;

    // FIX: Statements in an if are now enclosed in blocks
    if (typeStr.contains('INTERVENTION')) {
      type = EvolutionEventType.criticalIntervention;
    }
    if (typeStr.contains('VALIDATION_SUCCESS')) {
      type = EvolutionEventType.systemEvolved;
    }
    if (typeStr.contains('VALIDATION_FAILURE')) {
      type = EvolutionEventType.rollback;
    }
    if (typeStr.contains('HUMAN_OVERRIDE')) {
      type = EvolutionEventType.humanOverride;
    }

    DateTime parsedDate = DateTime.now();
    final rawTs = data['timestamp'];
    if (rawTs is Timestamp) {
      parsedDate = rawTs.toDate();
    } else if (rawTs is String) {
      parsedDate = DateTime.tryParse(rawTs) ?? DateTime.now();
    }

    return EvolutionEventModel(
      id: doc.id,
      type: type,
      title: typeStr.replaceAll('_', ' '),
      description: data['details'] ?? 'System event recorded.',
      agentName: data['agentId'] ?? data['source'] ?? 'Core Engine',
      timestamp: parsedDate,
      isAutonomous: data['isAutonomous'] ?? true,
      triggeredBy: data['triggeredBy'],
    );
  }

  String get timeDisplay {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inMinutes < 1) {
      return 'Just now';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }
    return '${timestamp.month}/${timestamp.day}';
  }
}
