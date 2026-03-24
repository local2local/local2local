import 'package:cloud_firestore/cloud_firestore.dart';

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
  });

  /// Factory to create an InterventionModel from a Firestore document
  factory InterventionModel.fromFirestore(DocumentSnapshot doc) {
    // FIX: Using Map.from to handle minified types on Web
    final rawData = doc.data() as Map?;
    final data = rawData != null
        ? Map<String, dynamic>.from(rawData)
        : <String, dynamic>{};

    // Severity Mapping
    final severityStr = data['severity']?.toString().toLowerCase() ?? 'green';
    final severity = (severityStr == 'high' || severityStr == 'critical')
        ? InterventionSeverity.red
        : (severityStr == 'medium' || severityStr == 'yellow')
            ? InterventionSeverity.yellow
            : InterventionSeverity.green;

    // Category Mapping (Based on document 'type' or fallback)
    final type = data['type']?.toString().toUpperCase() ?? '';
    InterventionCategory category = InterventionCategory.compliance;
    if (type.contains('PAYOUT') || type.contains('FINANCE')) {
      category = InterventionCategory.finance;
    } else if (type.contains('SAFETY')) {
      category = InterventionCategory.safety;
    } else if (type.contains('LOGISTICS')) {
      category = InterventionCategory.logistics;
    }

    // FIX: Handle both Firestore Timestamp and ISO String from manual JSON injection
    DateTime parsedDate = DateTime.now();
    final rawCreated = data['createdAt'];
    if (rawCreated is Timestamp) {
      parsedDate = rawCreated.toDate();
    } else if (rawCreated is String) {
      parsedDate = DateTime.tryParse(rawCreated) ?? DateTime.now();
    }

    return InterventionModel(
      id: doc.id,
      category: category,
      severity: severity,
      summary: data['details'] ?? 'No description provided',
      reasoningTrace:
          data['reasoning_trace'] ?? 'Trace unavailable for this event.',
      hbrRuleId: data['hbr_id'] ?? 'HBR-GEN-001',
      hbrRuleLink:
          'https://rules.local2local.app/hbr/${data['hbr_id'] ?? 'GEN-001'}',
      agentId: data['agent_id'] ?? 'unknown_agent',
      agentName: data['agent_name'] ?? 'System Agent',
      transactionId: data['orderId'] ?? data['correlation_id'] ?? 'N/A',
      createdAt: parsedDate,
      amountUsd: data['amountCents'] != null
          ? (data['amountCents'] / 100).toDouble()
          : null,
      resolvedAt: data['resolvedAt'] is Timestamp
          ? (data['resolvedAt'] as Timestamp).toDate()
          : null,
      resolvedBy: data['resolvedBy'],
      resolution: data['resolution'],
    );
  }

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

  List<MacroResponse> get availableMacros {
    switch (category) {
      case InterventionCategory.compliance:
        return const [
          MacroResponse(
              id: 'aglc_override',
              label: 'Manual AGLC Override',
              description: 'Approve with regulatory exemption'),
          MacroResponse(
              id: 'aglc_reject',
              label: 'Reject - AGLC Violation',
              description: 'Deny transaction'),
        ];
      case InterventionCategory.finance:
        return const [
          MacroResponse(
              id: 'approve_payout',
              label: 'Approve Payout',
              description: 'Release funds'),
          MacroResponse(
              id: 'reject_fraud',
              label: 'Reject - Suspected Fraud',
              description: 'Block transaction'),
        ];
      default:
        return const [
          MacroResponse(
              id: 'manual_resolve',
              label: 'Mark Resolved',
              description: 'Close task'),
        ];
    }
  }
}
