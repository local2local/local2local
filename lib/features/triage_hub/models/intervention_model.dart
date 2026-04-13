import 'package:cloud_firestore/cloud_firestore.dart';

enum InterventionCategory { compliance, finance, safety, logistics, talent }

enum InterventionSeverity { red, yellow, green }

extension CategoryLabel on InterventionCategory {
  String get label => switch (this) {
        InterventionCategory.compliance => 'Compliance',
        InterventionCategory.finance => 'Finance',
        InterventionCategory.safety => 'Safety',
        InterventionCategory.logistics => 'Logistics',
        InterventionCategory.talent => 'Talent',
      };
}

class MacroResponse {
  final String id, label, description;
  const MacroResponse(
      {required this.id, required this.label, required this.description});
}

class InterventionModel {
  final String id,
      summary,
      reasoningTrace,
      hbrRuleId,
      hbrRuleLink,
      agentId,
      agentName,
      transactionId;
  final InterventionCategory category;
  final InterventionSeverity severity;
  final DateTime createdAt;
  final double? amountUsd;
  final DateTime? resolvedAt;
  final String? resolution;
  final String
      rawType; // Added to store the original type for the 'title' getter

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
    required this.rawType,
    this.amountUsd,
    this.resolvedAt,
    this.resolution,
  });

  // --- MISSING UI GETTERS (Fixes Phase 26 Compilation Errors) ---

  /// UI Alias for the 'type' field
  String get title => rawType.replaceAll('_', ' ');

  /// UI Alias for the 'summary' field
  String get description => summary;

  /// UI Alias for mapping enum severity to the string expected by _PriorityIndicator
  String get priority {
    if (severity == InterventionSeverity.red) return 'high';
    if (severity == InterventionSeverity.yellow) return 'medium';
    return 'low';
  }

  /// Maps the internal availableMacros to the List<Map> structure expected by the UI
  List<Map<String, String>> get macros => availableMacros
      .map((m) => {
            'id': m.id,
            'label': m.label,
          })
      .toList();

  // -------------------------------------------------------------

  factory InterventionModel.fromFirestore(DocumentSnapshot doc) {
    final dynamic data = doc.data();

    final String severityStr =
        (data['severity'] ?? 'green').toString().toLowerCase();
    final String typeStr =
        (data['type'] ?? 'EXCEPTION').toString().toUpperCase();

    DateTime parsedDate = DateTime.now();
    final createdValue = data['createdAt'];
    if (createdValue is Timestamp) {
      parsedDate = createdValue.toDate();
    } else if (createdValue is String) {
      parsedDate = DateTime.tryParse(createdValue) ?? DateTime.now();
    }

    double? calculatedAmount;
    final amountVal = data['amountCents'];
    if (amountVal is num) {
      calculatedAmount = amountVal.toDouble() / 100;
    }

    return InterventionModel(
      id: doc.id,
      rawType: typeStr,
      summary: data['details']?.toString() ?? 'No Details',
      reasoningTrace: data['reasoning_trace']?.toString() ?? 'No trace.',
      hbrRuleId: data['hbr_id']?.toString() ?? 'HBR-GEN-001',
      hbrRuleLink:
          'https://rules.local2local.app/hbr/${data['hbr_id'] ?? 'GEN-001'}',
      agentId: data['agent_id']?.toString() ?? 'unknown',
      agentName: data['agent_name']?.toString() ?? 'System Agent',
      transactionId:
          (data['orderId'] ?? data['correlation_id'] ?? 'N/A').toString(),
      category: typeStr.contains('PAYOUT') || typeStr.contains('FINANCE')
          ? InterventionCategory.finance
          : typeStr.contains('SAFETY')
              ? InterventionCategory.safety
              : InterventionCategory.compliance,
      severity: (severityStr == 'high' ||
              severityStr == 'critical' ||
              severityStr == 'red')
          ? InterventionSeverity.red
          : (severityStr == 'medium' || severityStr == 'yellow')
              ? InterventionSeverity.yellow
              : InterventionSeverity.green,
      createdAt: parsedDate,
      amountUsd: calculatedAmount,
      resolvedAt: data['resolvedAt'] is Timestamp
          ? (data['resolvedAt'] as Timestamp).toDate()
          : null,
      resolution: data['resolution']?.toString(),
    );
  }

  bool get isActive => resolvedAt == null;
  String get ageDisplay =>
      '${DateTime.now().difference(createdAt).inMinutes}m ago';

  List<MacroResponse> get availableMacros => const [
        MacroResponse(
            id: 'approve',
            label: 'Approve',
            description: 'Proceed with action'),
        MacroResponse(
            id: 'reject', label: 'Reject', description: 'Deny and notify user'),
      ];
}
