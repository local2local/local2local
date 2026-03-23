import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:local2local/features/triage_hub/models/intervention_model.dart';
import 'package:local2local/features/triage_hub/models/orchestrator_model.dart';
import 'package:local2local/features/triage_hub/models/evolution_event_model.dart';

/// Available app tenants
enum AppTenant {
  kaskflow('local2local-kaskflow', 'Kaskflow'),
  moonlitely('local2local-moonlitely', 'Moonlitely');

  const AppTenant(this.id, this.displayName);
  final String id;
  final String displayName;
}

/// Environment types
enum AppEnvironment {
  prod('PROD', 'Production'),
  staging('STAGING', 'Staging'),
  dev('DEV', 'Development');

  const AppEnvironment(this.label, this.displayName);
  final String label;
  final String displayName;
}

/// Notifier for the currently selected app tenant
class CurrentAppNotifier extends Notifier<AppTenant> {
  @override
  AppTenant build() => AppTenant.kaskflow;

  void setApp(AppTenant tenant) => state = tenant;
}

/// Provider for the currently selected app tenant
final currentAppProvider = NotifierProvider<CurrentAppNotifier, AppTenant>(
  CurrentAppNotifier.new,
);

/// Notifier for the current environment
class CurrentEnvironmentNotifier extends Notifier<AppEnvironment> {
  @override
  AppEnvironment build() => AppEnvironment.prod;

  void setEnvironment(AppEnvironment env) => state = env;
}

/// Provider for the current environment
final currentEnvironmentProvider = NotifierProvider<CurrentEnvironmentNotifier, AppEnvironment>(
  CurrentEnvironmentNotifier.new,
);

/// Search query provider for global search
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Mock intervention data service
/// In production, connects to: artifacts/{appId}/public/data/interventions
class InterventionService {
  static final Map<String, List<InterventionModel>> _mockInterventions = {
    'local2local-kaskflow': [
      InterventionModel(
        id: 'int_001',
        category: InterventionCategory.finance,
        severity: InterventionSeverity.red,
        summary: 'High-Value Payout Approval Required (\$1,500)',
        reasoningTrace: '''
[Step 1] Transaction TXN_78234 received for payout processing.
[Step 2] Amount \$1,500.00 exceeds threshold of \$1,000.00 defined in HBR-FIN-003.
[Step 3] Vendor "Premium Logistics Inc" has positive history (45 successful payouts).
[Step 4] DECISION: Amount triggers mandatory human review per HBR-FIN-003.
[Step 5] Escalating to Triage Hub for human sign-off.
''',
        hbrRuleId: 'HBR-FIN-003',
        hbrRuleLink: 'https://rules.local2local.app/hbr/finance/003',
        agentId: 'orch_finance',
        agentName: 'Finance Orchestrator',
        transactionId: 'TXN_78234',
        amountUsd: 1500.00,
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      InterventionModel(
        id: 'int_002',
        category: InterventionCategory.compliance,
        severity: InterventionSeverity.red,
        summary: 'AGLC Age Verification Failed - Order #ORD_9912',
        reasoningTrace: '''
[Step 1] Order ORD_9912 contains age-restricted items (category: alcohol).
[Step 2] Customer profile age: 19 years.
[Step 3] Delivery address in Alberta (legal age: 18) - PASS
[Step 4] ID verification scan returned: INCONCLUSIVE
[Step 5] HBR-COMP-001 requires positive ID match for alcohol delivery.
[Step 6] DECISION: Block delivery pending human verification.
''',
        hbrRuleId: 'HBR-COMP-001',
        hbrRuleLink: 'https://rules.local2local.app/hbr/compliance/001',
        agentId: 'orch_compliance',
        agentName: 'Compliance Orchestrator',
        transactionId: 'ORD_9912',
        createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
      ),
      InterventionModel(
        id: 'int_003',
        category: InterventionCategory.safety,
        severity: InterventionSeverity.yellow,
        summary: 'Weather Alert - Route Risk Elevated',
        reasoningTrace: '''
[Step 1] Active delivery route RT_445 from Edmonton to Calgary.
[Step 2] Weather API reports: Heavy snowfall warning.
[Step 3] Road conditions: "Slippery sections" per 511 Alberta.
[Step 4] Current carrier has winter tire certification.
[Step 5] HBR-SAFE-007 recommends human review for severe weather.
[Step 6] DECISION: Flagging for optional reroute consideration.
''',
        hbrRuleId: 'HBR-SAFE-007',
        hbrRuleLink: 'https://rules.local2local.app/hbr/safety/007',
        agentId: 'orch_logistics',
        agentName: 'Logistics Orchestrator',
        transactionId: 'RT_445',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      InterventionModel(
        id: 'int_004',
        category: InterventionCategory.talent,
        severity: InterventionSeverity.yellow,
        summary: 'Worker Overtime Threshold Reached',
        reasoningTrace: '''
[Step 1] Worker WRK_2234 (John D.) scheduled for shift.
[Step 2] Current week hours: 44 of 44 max per HBR-TAL-002.
[Step 3] New assignment would add 6 hours = 50 total.
[Step 4] Worker has opted-in to overtime availability.
[Step 5] DECISION: Requires manager approval for overtime exception.
''',
        hbrRuleId: 'HBR-TAL-002',
        hbrRuleLink: 'https://rules.local2local.app/hbr/talent/002',
        agentId: 'orch_talent',
        agentName: 'Talent Orchestrator',
        transactionId: 'WRK_2234',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
    ],
    'local2local-moonlitely': [
      InterventionModel(
        id: 'int_101',
        category: InterventionCategory.finance,
        severity: InterventionSeverity.red,
        summary: 'Suspicious Transaction Pattern Detected',
        reasoningTrace: '''
[Step 1] Transaction TXN_M_4421 flagged by fraud detection.
[Step 2] Pattern match: Multiple small orders from same IP.
[Step 3] Total value in 1hr: \$847.00 across 12 transactions.
[Step 4] Customer account age: 2 days.
[Step 5] HBR-FIN-009 fraud threshold exceeded.
[Step 6] DECISION: Blocking pending human review.
''',
        hbrRuleId: 'HBR-FIN-009',
        hbrRuleLink: 'https://rules.local2local.app/hbr/finance/009',
        agentId: 'orch_finance',
        agentName: 'Finance Orchestrator',
        transactionId: 'TXN_M_4421',
        amountUsd: 847.00,
        createdAt: DateTime.now().subtract(const Duration(minutes: 8)),
      ),
      InterventionModel(
        id: 'int_102',
        category: InterventionCategory.logistics,
        severity: InterventionSeverity.yellow,
        summary: 'Carrier Assignment Conflict',
        reasoningTrace: '''
[Step 1] Order ORD_M_8823 requires refrigerated transport.
[Step 2] Assigned carrier CAR_445 has refrigerated unit.
[Step 3] Carrier reports equipment malfunction.
[Step 4] Alternative carriers: 2 available, 15km further.
[Step 5] Customer paid for priority delivery.
[Step 6] DECISION: Requires human decision on reassignment vs delay.
''',
        hbrRuleId: 'HBR-LOG-004',
        hbrRuleLink: 'https://rules.local2local.app/hbr/logistics/004',
        agentId: 'orch_logistics',
        agentName: 'Logistics Orchestrator',
        transactionId: 'ORD_M_8823',
        createdAt: DateTime.now().subtract(const Duration(minutes: 25)),
      ),
    ],
  };

  /// Get all interventions for an app
  static List<InterventionModel> getInterventions(String appId) {
    return _mockInterventions[appId] ?? [];
  }

  /// Get active (unresolved) interventions
  static List<InterventionModel> getActiveInterventions(String appId) {
    return getInterventions(appId).where((i) => i.isActive).toList();
  }

  /// Stream of active intervention counts for a given app
  static Stream<int> getActiveInterventionCount(String appId) {
    return Stream.periodic(const Duration(seconds: 1), (_) {
      return getActiveInterventions(appId).length;
    });
  }

  /// Stream of interventions for real-time updates
  static Stream<List<InterventionModel>> getInterventionsStream(String appId) {
    return Stream.periodic(const Duration(seconds: 2), (_) {
      return getActiveInterventions(appId);
    });
  }

  /// Resolve an intervention with a macro response
  static Future<void> resolveIntervention(String appId, String interventionId, String macroId) async {
    // In production, this would update Firestore and publish to the bus
    await Future.delayed(const Duration(milliseconds: 500));
    final interventions = _mockInterventions[appId];
    if (interventions != null) {
      final index = interventions.indexWhere((i) => i.id == interventionId);
      if (index >= 0) {
        interventions[index] = interventions[index].copyWith(
          resolvedAt: DateTime.now(),
          resolvedBy: 'admin@local2local.app',
          resolution: macroId,
        );
      }
    }
  }
}

/// Mock orchestrator agent registry service
/// In production, connects to: artifacts/{appId}/public/data/agent_registry
class OrchestratorService {
  static final Map<String, List<OrchestratorModel>> _mockOrchestrators = {
    'local2local-kaskflow': [
      OrchestratorModel(
        id: 'orch_compliance',
        type: OrchestratorType.compliance,
        status: OrchestratorStatus.online,
        efficacyScore: 98.5,
        latencyMs: 45,
        currentBacklog: 2,
        processedToday: 1247,
        errorsToday: 3,
        version: 'v2.4.1',
        lastHeartbeat: DateTime.now().subtract(const Duration(seconds: 5)),
      ),
      OrchestratorModel(
        id: 'orch_finance',
        type: OrchestratorType.finance,
        status: OrchestratorStatus.online,
        efficacyScore: 94.2,
        latencyMs: 78,
        currentBacklog: 5,
        processedToday: 3892,
        errorsToday: 12,
        version: 'v2.4.0',
        lastHeartbeat: DateTime.now().subtract(const Duration(seconds: 3)),
      ),
      OrchestratorModel(
        id: 'orch_logistics',
        type: OrchestratorType.logistics,
        status: OrchestratorStatus.degraded,
        efficacyScore: 76.8,
        latencyMs: 234,
        currentBacklog: 18,
        processedToday: 892,
        errorsToday: 45,
        version: 'v2.3.8',
        lastHeartbeat: DateTime.now().subtract(const Duration(seconds: 12)),
      ),
      OrchestratorModel(
        id: 'orch_talent',
        type: OrchestratorType.talent,
        status: OrchestratorStatus.online,
        efficacyScore: 91.3,
        latencyMs: 56,
        currentBacklog: 3,
        processedToday: 567,
        errorsToday: 8,
        version: 'v2.4.1',
        lastHeartbeat: DateTime.now().subtract(const Duration(seconds: 2)),
      ),
      OrchestratorModel(
        id: 'orch_customer',
        type: OrchestratorType.customer,
        status: OrchestratorStatus.online,
        efficacyScore: 96.7,
        latencyMs: 34,
        currentBacklog: 1,
        processedToday: 2341,
        errorsToday: 5,
        version: 'v2.4.1',
        lastHeartbeat: DateTime.now().subtract(const Duration(seconds: 1)),
      ),
      OrchestratorModel(
        id: 'orch_inventory',
        type: OrchestratorType.inventory,
        status: OrchestratorStatus.online,
        efficacyScore: 99.1,
        latencyMs: 23,
        currentBacklog: 0,
        processedToday: 4521,
        errorsToday: 2,
        version: 'v2.4.1',
        lastHeartbeat: DateTime.now().subtract(const Duration(seconds: 4)),
      ),
      OrchestratorModel(
        id: 'orch_analytics',
        type: OrchestratorType.analytics,
        status: OrchestratorStatus.online,
        efficacyScore: 88.4,
        latencyMs: 156,
        currentBacklog: 7,
        processedToday: 234,
        errorsToday: 1,
        version: 'v2.4.0',
        lastHeartbeat: DateTime.now().subtract(const Duration(seconds: 8)),
      ),
    ],
    'local2local-moonlitely': [
      OrchestratorModel(
        id: 'orch_compliance',
        type: OrchestratorType.compliance,
        status: OrchestratorStatus.online,
        efficacyScore: 97.2,
        latencyMs: 52,
        currentBacklog: 1,
        processedToday: 892,
        errorsToday: 2,
        version: 'v2.4.1',
        lastHeartbeat: DateTime.now().subtract(const Duration(seconds: 3)),
      ),
      OrchestratorModel(
        id: 'orch_finance',
        type: OrchestratorType.finance,
        status: OrchestratorStatus.online,
        efficacyScore: 95.8,
        latencyMs: 67,
        currentBacklog: 3,
        processedToday: 2134,
        errorsToday: 7,
        version: 'v2.4.1',
        lastHeartbeat: DateTime.now().subtract(const Duration(seconds: 2)),
      ),
      OrchestratorModel(
        id: 'orch_logistics',
        type: OrchestratorType.logistics,
        status: OrchestratorStatus.online,
        efficacyScore: 92.4,
        latencyMs: 89,
        currentBacklog: 4,
        processedToday: 654,
        errorsToday: 11,
        version: 'v2.4.0',
        lastHeartbeat: DateTime.now().subtract(const Duration(seconds: 5)),
      ),
      OrchestratorModel(
        id: 'orch_talent',
        type: OrchestratorType.talent,
        status: OrchestratorStatus.paused,
        efficacyScore: 85.1,
        latencyMs: 0,
        currentBacklog: 12,
        processedToday: 234,
        errorsToday: 0,
        version: 'v2.3.9',
        lastHeartbeat: DateTime.now().subtract(const Duration(minutes: 15)),
      ),
      OrchestratorModel(
        id: 'orch_customer',
        type: OrchestratorType.customer,
        status: OrchestratorStatus.online,
        efficacyScore: 94.3,
        latencyMs: 41,
        currentBacklog: 2,
        processedToday: 1567,
        errorsToday: 4,
        version: 'v2.4.1',
        lastHeartbeat: DateTime.now().subtract(const Duration(seconds: 1)),
      ),
      OrchestratorModel(
        id: 'orch_inventory',
        type: OrchestratorType.inventory,
        status: OrchestratorStatus.online,
        efficacyScore: 98.7,
        latencyMs: 28,
        currentBacklog: 0,
        processedToday: 3245,
        errorsToday: 1,
        version: 'v2.4.1',
        lastHeartbeat: DateTime.now().subtract(const Duration(seconds: 2)),
      ),
      OrchestratorModel(
        id: 'orch_analytics',
        type: OrchestratorType.analytics,
        status: OrchestratorStatus.online,
        efficacyScore: 91.2,
        latencyMs: 134,
        currentBacklog: 5,
        processedToday: 189,
        errorsToday: 0,
        version: 'v2.4.1',
        lastHeartbeat: DateTime.now().subtract(const Duration(seconds: 6)),
      ),
    ],
  };

  /// Get all orchestrators for an app
  static List<OrchestratorModel> getOrchestrators(String appId) {
    return _mockOrchestrators[appId] ?? [];
  }

  /// Stream of orchestrators for real-time updates
  static Stream<List<OrchestratorModel>> getOrchestratorsStream(String appId) {
    return Stream.periodic(const Duration(seconds: 3), (_) {
      return getOrchestrators(appId);
    });
  }

  /// Pause an orchestrator
  static Future<void> pauseOrchestrator(String appId, String orchestratorId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final orchestrators = _mockOrchestrators[appId];
    if (orchestrators != null) {
      final index = orchestrators.indexWhere((o) => o.id == orchestratorId);
      if (index >= 0) {
        orchestrators[index] = orchestrators[index].copyWith(
          status: OrchestratorStatus.paused,
        );
      }
    }
  }

  /// Resume an orchestrator
  static Future<void> resumeOrchestrator(String appId, String orchestratorId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final orchestrators = _mockOrchestrators[appId];
    if (orchestrators != null) {
      final index = orchestrators.indexWhere((o) => o.id == orchestratorId);
      if (index >= 0) {
        orchestrators[index] = orchestrators[index].copyWith(
          status: OrchestratorStatus.online,
        );
      }
    }
  }

  /// Rollback an orchestrator to previous version
  static Future<void> rollbackOrchestrator(String appId, String orchestratorId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final orchestrators = _mockOrchestrators[appId];
    if (orchestrators != null) {
      final index = orchestrators.indexWhere((o) => o.id == orchestratorId);
      if (index >= 0) {
        orchestrators[index] = orchestrators[index].copyWith(
          status: OrchestratorStatus.rollback,
          lastRollback: DateTime.now(),
        );
      }
    }
  }
}

/// Mock evolution timeline service
/// In production, connects to: artifacts/{appId}/public/data/evolution_timeline
class EvolutionTimelineService {
  static final Map<String, List<EvolutionEventModel>> _mockEvents = {
    'local2local-kaskflow': [
      EvolutionEventModel(
        id: 'evt_001',
        type: EvolutionEventType.agentDeployed,
        title: 'Finance Orchestrator v2.4.0 Deployed',
        description: 'New fraud detection patterns and improved payout processing.',
        agentId: 'orch_finance',
        agentName: 'Finance Orchestrator',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        isAutonomous: false,
        triggeredBy: 'admin@local2local.app',
      ),
      EvolutionEventModel(
        id: 'evt_002',
        type: EvolutionEventType.patternLearned,
        title: 'New Delivery Route Pattern Identified',
        description: 'AI recognized optimal route for Edmonton-Calgary corridor during peak hours.',
        agentId: 'orch_logistics',
        agentName: 'Logistics Orchestrator',
        timestamp: DateTime.now().subtract(const Duration(hours: 5)),
        isAutonomous: true,
      ),
      EvolutionEventModel(
        id: 'evt_003',
        type: EvolutionEventType.thresholdChanged,
        title: 'Payout Threshold Adjusted',
        description: 'Auto-approval threshold increased from \$500 to \$1,000 based on risk analysis.',
        agentId: 'orch_finance',
        agentName: 'Finance Orchestrator',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        isAutonomous: true,
      ),
      EvolutionEventModel(
        id: 'evt_004',
        type: EvolutionEventType.humanOverride,
        title: 'Manual AGLC Override Applied',
        description: 'Admin approved age-restricted delivery for verified customer.',
        agentId: 'orch_compliance',
        agentName: 'Compliance Orchestrator',
        timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
        isAutonomous: false,
        triggeredBy: 'admin@local2local.app',
      ),
      EvolutionEventModel(
        id: 'evt_005',
        type: EvolutionEventType.ruleAdded,
        title: 'New Weather Safety Rule HBR-SAFE-007',
        description: 'Added automatic weather-based route risk assessment.',
        agentId: 'orch_logistics',
        agentName: 'Logistics Orchestrator',
        timestamp: DateTime.now().subtract(const Duration(days: 3)),
        isAutonomous: false,
        triggeredBy: 'admin@local2local.app',
      ),
    ],
    'local2local-moonlitely': [
      EvolutionEventModel(
        id: 'evt_101',
        type: EvolutionEventType.rollback,
        title: 'Talent Orchestrator Rolled Back',
        description: 'Reverted to v2.3.9 due to scheduling conflicts.',
        agentId: 'orch_talent',
        agentName: 'Talent Orchestrator',
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        isAutonomous: false,
        triggeredBy: 'admin@local2local.app',
      ),
      EvolutionEventModel(
        id: 'evt_102',
        type: EvolutionEventType.systemEvolved,
        title: 'Customer Support Escalation Logic Improved',
        description: 'AI optimized escalation paths reducing average resolution time by 15%.',
        agentId: 'orch_customer',
        agentName: 'Customer Orchestrator',
        timestamp: DateTime.now().subtract(const Duration(hours: 8)),
        isAutonomous: true,
      ),
      EvolutionEventModel(
        id: 'evt_103',
        type: EvolutionEventType.ruleModified,
        title: 'Fraud Detection Rule Updated',
        description: 'Adjusted transaction velocity thresholds based on holiday patterns.',
        agentId: 'orch_finance',
        agentName: 'Finance Orchestrator',
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        isAutonomous: true,
      ),
    ],
  };

  /// Get evolution events for an app
  static List<EvolutionEventModel> getEvents(String appId) {
    return _mockEvents[appId] ?? [];
  }

  /// Stream of evolution events
  static Stream<List<EvolutionEventModel>> getEventsStream(String appId) {
    return Stream.periodic(const Duration(seconds: 5), (_) {
      return getEvents(appId);
    });
  }
}

// ============= RIVERPOD PROVIDERS =============

/// StreamProvider for active intervention count
final activeInterventionCountProvider = StreamProvider<int>((ref) {
  final currentApp = ref.watch(currentAppProvider);
  return InterventionService.getActiveInterventionCount(currentApp.id);
});

/// StreamProvider for interventions list
final interventionsProvider = StreamProvider<List<InterventionModel>>((ref) {
  final currentApp = ref.watch(currentAppProvider);
  return InterventionService.getInterventionsStream(currentApp.id);
});

/// StreamProvider for orchestrators list
final orchestratorsProvider = StreamProvider<List<OrchestratorModel>>((ref) {
  final currentApp = ref.watch(currentAppProvider);
  return OrchestratorService.getOrchestratorsStream(currentApp.id);
});

/// StreamProvider for evolution timeline
final evolutionTimelineProvider = StreamProvider<List<EvolutionEventModel>>((ref) {
  final currentApp = ref.watch(currentAppProvider);
  return EvolutionTimelineService.getEventsStream(currentApp.id);
});

/// Provider for selected intervention (for detail panel)
final selectedInterventionProvider = StateProvider<InterventionModel?>((ref) => null);
