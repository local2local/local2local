import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local2local/features/triage_hub/models/intervention_model.dart';
import 'package:local2local/features/triage_hub/models/orchestrator_model.dart';
import 'package:local2local/features/triage_hub/models/evolution_event_model.dart';

/// Available app tenants (App IDs)
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

final currentAppProvider =
    NotifierProvider<CurrentAppNotifier, AppTenant>(CurrentAppNotifier.new);

/// Notifier for the current environment
class CurrentEnvironmentNotifier extends Notifier<AppEnvironment> {
  @override
  AppEnvironment build() => AppEnvironment.dev;
  void setEnvironment(AppEnvironment env) => state = env;
}

final currentEnvironmentProvider =
    NotifierProvider<CurrentEnvironmentNotifier, AppEnvironment>(
  CurrentEnvironmentNotifier.new,
);

/// Consolidated Navigation Index Provider
class SelectedNavIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void setIndex(int index) => state = index;
}

final selectedNavIndexProvider =
    NotifierProvider<SelectedNavIndexNotifier, int>(
  SelectedNavIndexNotifier.new,
);

/// Notifier for Selected Intervention
class SelectedInterventionNotifier extends Notifier<InterventionModel?> {
  @override
  InterventionModel? build() => null;
  void setSelected(InterventionModel? val) => state = val;
}

final selectedInterventionProvider =
    NotifierProvider<SelectedInterventionNotifier, InterventionModel?>(
  SelectedInterventionNotifier.new,
);

/// Notifier for Search Query
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void setQuery(String query) => state = query;
}

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(
  SearchQueryNotifier.new,
);

// ============= LIVE FIRESTORE PROVIDERS =============

final activeInterventionCountProvider = StreamProvider<int>((ref) {
  final currentApp = ref.watch(currentAppProvider);
  return FirebaseFirestore.instance
      .collection('artifacts')
      .doc(currentApp.id)
      .collection('public')
      .doc('data')
      .collection('interventions')
      .where('status', isEqualTo: 'active')
      .snapshots()
      .map((snapshot) => snapshot.docs.length);
});

final interventionsProvider = StreamProvider<List<InterventionModel>>((ref) {
  final currentApp = ref.watch(currentAppProvider);
  return FirebaseFirestore.instance
      .collection('artifacts')
      .doc(currentApp.id)
      .collection('public')
      .doc('data')
      .collection('interventions')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => InterventionModel.fromFirestore(doc))
          .toList());
});

final orchestratorsProvider = StreamProvider<List<OrchestratorModel>>((ref) {
  final currentApp = ref.watch(currentAppProvider);
  return FirebaseFirestore.instance
      .collection('artifacts')
      .doc(currentApp.id)
      .collection('public')
      .doc('data')
      .collection('agent_registry')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => OrchestratorModel.fromFirestore(doc))
          .toList());
});

final evolutionTimelineProvider =
    StreamProvider<List<EvolutionEventModel>>((ref) {
  final currentApp = ref.watch(currentAppProvider);
  return FirebaseFirestore.instance
      .collection('artifacts')
      .doc(currentApp.id)
      .collection('public')
      .doc('data')
      .collection('evolution_timeline')
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => EvolutionEventModel.fromFirestore(doc))
          .toList());
});

// ============= LIVE SERVICES =============

/// Service to handle manual agent overrides from the UI
class OrchestratorService {
  static final _db = FirebaseFirestore.instance;

  static Future<void> pauseOrchestrator(String appId, String agentId) async {
    await _db
        .collection('artifacts')
        .doc(appId)
        .collection('public')
        .doc('data')
        .collection('agent_registry')
        .doc(agentId)
        .update({'status.mode': 'paused'});
  }

  static Future<void> resumeOrchestrator(String appId, String agentId) async {
    await _db
        .collection('artifacts')
        .doc(appId)
        .collection('public')
        .doc('data')
        .collection('agent_registry')
        .doc(agentId)
        .update({'status.mode': 'live'});
  }

  static Future<void> rollbackOrchestrator(String appId, String agentId) async {
    await _db
        .collection('artifacts')
        .doc(appId)
        .collection('public')
        .doc('data')
        .collection('agent_bus')
        .add({
      'correlation_id': 'rollback-${DateTime.now().millisecondsSinceEpoch}',
      'status': 'pending',
      'control': {'type': 'REQUEST', 'priority': 'high'},
      'provenance': {
        'sender_id': 'DASHBOARD_UI',
        'receiver_id': 'EVOLUTION_WORKER'
      },
      'payload': {
        'manifest': {'intent': 'ROLLBACK_AGENT', 'targetAgentId': agentId}
      },
      'telemetry': {'created_at': DateTime.now().toIso8601String()},
    });
  }
}

/// Service to handle human intervention resolutions
class InterventionService {
  static final _db = FirebaseFirestore.instance;

  /// Resolves an intervention and notifies the agent bus
  static Future<void> resolveIntervention(
      String appId, String interventionId, String macroId) async {
    final batch = _db.batch();

    // 1. Mark the intervention as resolved
    final interventionRef = _db
        .collection('artifacts')
        .doc(appId)
        .collection('public')
        .doc('data')
        .collection('interventions')
        .doc(interventionId);
    batch.update(interventionRef, {
      'status': 'resolved',
      'resolution': macroId,
      'resolvedAt': FieldValue.serverTimestamp(),
      'resolvedBy': 'SUPER_ADMIN'
    });

    // 2. Post the Human Decision to the bus to unblock the agent
    final busRef = _db
        .collection('artifacts')
        .doc(appId)
        .collection('public')
        .doc('data')
        .collection('agent_bus')
        .doc();
    batch.set(busRef, {
      'correlation_id': 'resolve-$interventionId',
      'status': 'pending',
      'control': {'type': 'RESPONSE', 'priority': 'high'},
      'provenance': {
        'sender_id': 'DASHBOARD_UI',
        'receiver_id': 'SAFETY_WORKER'
      },
      'payload': {
        'result': {
          'interventionId': interventionId,
          'action': macroId,
          'source': 'HUMAN_COMMIT'
        }
      },
      'telemetry': {'created_at': DateTime.now().toIso8601String()},
    });

    await batch.commit();
  }
}
