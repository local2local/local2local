/// Evolution Event Types for the system diary
enum EvolutionEventType {
  agentDeployed('Agent Deployed', 'New orchestrator version deployed'),
  ruleAdded('Rule Added', 'New HBR rule created'),
  ruleModified('Rule Modified', 'Existing rule updated'),
  thresholdChanged('Threshold Changed', 'Business threshold adjusted'),
  rollback('Rollback', 'System rolled back to previous state'),
  humanOverride('Human Override', 'Admin intervention recorded'),
  patternLearned('Pattern Learned', 'New pattern recognized by AI'),
  systemEvolved('System Evolved', 'Autonomous improvement applied');

  const EvolutionEventType(this.label, this.description);
  final String label;
  final String description;
}

/// Evolution Timeline Event Model
/// Path: artifacts/{appId}/public/data/evolution_timeline
class EvolutionEventModel {
  final String id;
  final EvolutionEventType type;
  final String title;
  final String description;
  final String agentId;
  final String agentName;
  final DateTime timestamp;
  final Map<String, dynamic>? beforeState;
  final Map<String, dynamic>? afterState;
  final String? triggeredBy;
  final bool isAutonomous;

  const EvolutionEventModel({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.agentId,
    required this.agentName,
    required this.timestamp,
    this.beforeState,
    this.afterState,
    this.triggeredBy,
    this.isAutonomous = false,
  });

  String get timeDisplay {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    
    return '${timestamp.month}/${timestamp.day}/${timestamp.year}';
  }
}
