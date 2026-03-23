/// Intervention Categories
enum InterventionCategory {
  compliance('Compliance', 'AGLC/Regulatory violations'),
  finance('Finance', 'High-value transactions requiring approval'),
  safety('Safety', 'Safety protocol violations'),
  logistics('Logistics', 'Delivery/routing issues'),
  talent('Talent', 'Worker-related issues');

  const InterventionCategory(this.label, this.description);
  final String label;
  final String description;
}

/// Intervention Severity Levels
enum InterventionSeverity {
  red('Critical', 'Immediate action required'),
  yellow('Warning', 'Action needed soon'),
  green('Info', 'Informational only');

  const InterventionSeverity(this.label, this.description);
  final String label;
  final String description;
}

/// Macro Response Options for intervention resolution
class MacroResponse {
  final String id;
  final String label;
  final String description;

  const MacroResponse({
    required this.id,
    required this.label,
    required this.description,
  });
}

/// Intervention data model matching Firestore structure
/// Path: artifacts/{appId}/public/data/interventions
class InterventionModel {
  final String id;
  final InterventionCategory category;
  final InterventionSeverity severity;
  final String summary;
  final String reasoningTrace;
  final String hbrRuleId;
  final String hbrRuleLink;
  final String agentId;
  final String agentName;
  final String transactionId;
  final double? amountUsd;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final String? resolution;
  final Map<String, dynamic>? metadata;

  const InterventionModel({
    required this.id,
    required this.category,
    required this.severity,
    required this.summary,
    required this.reasoningTrace,
    required this.hbrRuleId,
    required this.hbrRuleLink,
    required this.agentId,
    required this.agentName,
    required this.transactionId,
    required this.createdAt,
    this.amountUsd,
    this.resolvedAt,
    this.resolvedBy,
    this.resolution,
    this.metadata,
  });

  bool get isActive => resolvedAt == null;

  Duration get age => DateTime.now().difference(createdAt);

  String get ageDisplay {
    final mins = age.inMinutes;
    if (mins < 1) return 'Just now';
    if (mins < 60) return '$mins min ago';
    final hours = age.inHours;
    if (hours < 24) return '$hours hr ago';
    final days = age.inDays;
    return '$days day${days > 1 ? 's' : ''} ago';
  }

  /// Available macro responses based on category
  List<MacroResponse> get availableMacros {
    switch (category) {
      case InterventionCategory.compliance:
        return const [
          MacroResponse(id: 'aglc_override', label: 'Manual AGLC Override', description: 'Approve with regulatory exemption'),
          MacroResponse(id: 'aglc_reject', label: 'Reject - AGLC Violation', description: 'Deny transaction'),
          MacroResponse(id: 'escalate_legal', label: 'Escalate to Legal', description: 'Send to legal team'),
        ];
      case InterventionCategory.finance:
        return const [
          MacroResponse(id: 'approve_payout', label: 'Approve Payout', description: 'Release funds'),
          MacroResponse(id: 'hold_review', label: 'Hold for Review', description: 'Flag for finance review'),
          MacroResponse(id: 'reject_fraud', label: 'Reject - Suspected Fraud', description: 'Block transaction'),
        ];
      case InterventionCategory.safety:
        return const [
          MacroResponse(id: 'safety_override', label: 'Safety Override', description: 'Acknowledge risk, proceed'),
          MacroResponse(id: 'safety_halt', label: 'Halt Operations', description: 'Stop all related activities'),
          MacroResponse(id: 'safety_review', label: 'Schedule Safety Review', description: 'Flag for review'),
        ];
      case InterventionCategory.logistics:
        return const [
          MacroResponse(id: 'reroute', label: 'Approve Reroute', description: 'Allow alternate route'),
          MacroResponse(id: 'cancel_delivery', label: 'Cancel Delivery', description: 'Abort delivery'),
          MacroResponse(id: 'reassign', label: 'Reassign Carrier', description: 'Assign new carrier'),
        ];
      case InterventionCategory.talent:
        return const [
          MacroResponse(id: 'approve_assignment', label: 'Approve Assignment', description: 'Confirm talent assignment'),
          MacroResponse(id: 'flag_performance', label: 'Flag Performance Issue', description: 'Add to review queue'),
          MacroResponse(id: 'suspend', label: 'Suspend Worker', description: 'Temporarily disable'),
        ];
    }
  }

  InterventionModel copyWith({
    String? id,
    InterventionCategory? category,
    InterventionSeverity? severity,
    String? summary,
    String? reasoningTrace,
    String? hbrRuleId,
    String? hbrRuleLink,
    String? agentId,
    String? agentName,
    String? transactionId,
    double? amountUsd,
    DateTime? createdAt,
    DateTime? resolvedAt,
    String? resolvedBy,
    String? resolution,
    Map<String, dynamic>? metadata,
  }) {
    return InterventionModel(
      id: id ?? this.id,
      category: category ?? this.category,
      severity: severity ?? this.severity,
      summary: summary ?? this.summary,
      reasoningTrace: reasoningTrace ?? this.reasoningTrace,
      hbrRuleId: hbrRuleId ?? this.hbrRuleId,
      hbrRuleLink: hbrRuleLink ?? this.hbrRuleLink,
      agentId: agentId ?? this.agentId,
      agentName: agentName ?? this.agentName,
      transactionId: transactionId ?? this.transactionId,
      amountUsd: amountUsd ?? this.amountUsd,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      resolution: resolution ?? this.resolution,
      metadata: metadata ?? this.metadata,
    );
  }
}
