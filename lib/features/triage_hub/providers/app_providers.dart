import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/intervention_model.dart';
import '../models/orchestrator_model.dart';
import '../models/evolution_event_model.dart';
import '../models/logistics_job_model.dart';

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

/// Notifier for Navigation Index
class NavIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void setIndex(int index) => state = index;
}

final selectedNavIndexProvider =
    NotifierProvider<NavIndexNotifier, int>(NavIndexNotifier.new);

/// Notifier for Selected Intervention
class SelectedInterventionNotifier extends Notifier<InterventionModel?> {
  @override
  InterventionModel? build() => null;
  void setSelected(InterventionModel? model) => state = model;
}

final selectedInterventionProvider =
    NotifierProvider<SelectedInterventionNotifier, InterventionModel?>(
  SelectedInterventionNotifier.new,
);

/// Notifier for Environment Selection
class CurrentEnvironmentNotifier extends Notifier<AppEnvironment> {
  @override
  AppEnvironment build() => AppEnvironment.dev;
  void setEnvironment(AppEnvironment env) => state = env;
}

final currentEnvironmentProvider =
    NotifierProvider<CurrentEnvironmentNotifier, AppEnvironment>(
  CurrentEnvironmentNotifier.new,
);

/// Notifier for Search Query
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void setQuery(String query) => state = query;
}

final searchQueryProvider =
    NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);

// ============= LIVE FIRESTORE PROVIDERS (Hardened with Converters) =============

final interventionsProvider = StreamProvider<List<InterventionModel>>((ref) {
  final currentApp = ref.watch(currentAppProvider);
  return FirebaseFirestore.instance
      .collection('artifacts')
      .doc(currentApp.id)
      .collection('public')
      .doc('data')
      .collection('interventions')
      .withConverter<InterventionModel>(
        fromFirestore: (snapshot, _) =>
            InterventionModel.fromFirestore(snapshot),
        toFirestore: (model, _) => {},
      )
      .snapshots()
      .map((snapshot) =>
          List<InterventionModel>.from(snapshot.docs.map((doc) => doc.data())));
});

final orchestratorsProvider = StreamProvider<List<OrchestratorModel>>((ref) {
  final currentApp = ref.watch(currentAppProvider);
  return FirebaseFirestore.instance
      .collection('artifacts')
      .doc(currentApp.id)
      .collection('public')
      .doc('data')
      .collection('agent_registry')
      .withConverter<OrchestratorModel>(
        fromFirestore: (snapshot, _) =>
            OrchestratorModel.fromFirestore(snapshot),
        toFirestore: (model, _) => {},
      )
      .snapshots()
      .map((snapshot) =>
          List<OrchestratorModel>.from(snapshot.docs.map((doc) => doc.data())));
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
      .withConverter<EvolutionEventModel>(
        fromFirestore: (snapshot, _) =>
            EvolutionEventModel.fromFirestore(snapshot),
        toFirestore: (model, _) => {},
      )
      .snapshots()
      .map((snapshot) => List<EvolutionEventModel>.from(
          snapshot.docs.map((doc) => doc.data())));
});

final fleetProvider = StreamProvider<List<LogisticsJobModel>>((ref) {
  final currentApp = ref.watch(currentAppProvider);
  return FirebaseFirestore.instance
      .collection('artifacts')
      .doc(currentApp.id)
      .collection('public')
      .doc('data')
      .collection('logistics_jobs')
      .withConverter<LogisticsJobModel>(
        fromFirestore: (snapshot, _) =>
            LogisticsJobModel.fromFirestore(snapshot),
        toFirestore: (model, _) => {},
      )
      .snapshots()
      .map((snapshot) =>
          List<LogisticsJobModel>.from(snapshot.docs.map((doc) => doc.data())));
});

/// Optimized provider for active intervention count badge
final activeInterventionCountProvider = Provider<AsyncValue<int>>((ref) {
  final interventionsAsync = ref.watch(interventionsProvider);
  return interventionsAsync
      .whenData((list) => list.where((i) => i.isActive).length);
});

// ============= LIVE SERVICES (The "Hands") =============

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

  /// Resolves an intervention and notifies the agent bus to unblock the backend task
  static Future<void> resolveIntervention(
      String appId, String interventionId, String macroId) async {
    final batch = _db.batch();

    // 1. Mark status as resolved
    final intRef = _db
        .collection('artifacts')
        .doc(appId)
        .collection('public')
        .doc('data')
        .collection('interventions')
        .doc(interventionId);

    batch.update(intRef, {
      'status': 'resolved',
      'resolution': macroId,
      'resolvedAt': FieldValue.serverTimestamp(),
      'resolvedBy': 'SUPER_ADMIN'
    });

    // 2. Post a RESPONSE message to the agent bus to notify the waiting Orchestrator
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
