import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local2local/features/triage_hub/models/intervention_model.dart';
import 'package:local2local/features/triage_hub/models/orchestrator_model.dart';
import 'package:local2local/features/triage_hub/models/logistics_job_model.dart';
import 'package:local2local/features/triage_hub/models/evolution_event_model.dart';

// --- TENANT STATE ---

enum AppTenant {
  kaskflow('local2local-kaskflow', 'Kaskflow'),
  moonlitely('local2local-moonlitely', 'Moonlitely');

  const AppTenant(this.id, this.displayName);
  final String id, displayName;
}

enum AppEnvironment {
  dev('Development'),
  staging('Staging'),
  prod('Production');

  const AppEnvironment(this.displayName);
  final String displayName;
  String get label => name.toUpperCase();
}

class CurrentAppNotifier extends Notifier<AppTenant> {
  @override
  AppTenant build() => AppTenant.kaskflow;
  void setApp(AppTenant app) => state = app;
}

class CurrentEnvNotifier extends Notifier<AppEnvironment> {
  @override
  AppEnvironment build() => AppEnvironment.dev;
  void setEnvironment(AppEnvironment env) => state = env;
}

final currentAppProvider =
    NotifierProvider<CurrentAppNotifier, AppTenant>(CurrentAppNotifier.new);
final currentEnvironmentProvider =
    NotifierProvider<CurrentEnvNotifier, AppEnvironment>(
        CurrentEnvNotifier.new);

// --- NAVIGATION STATE ---

class NavIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void setIndex(int index) => state = index;
}

final selectedNavIndexProvider =
    NotifierProvider<NavIndexNotifier, int>(NavIndexNotifier.new);

// --- DATA STREAMS ---

final interventionsProvider = StreamProvider<List<InterventionModel>>((ref) {
  final app = ref.watch(currentAppProvider);
  return FirebaseFirestore.instance
      .collection('artifacts/${app.id}/public/data/interventions')
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => InterventionModel.fromFirestore(doc))
          .toList());
});

final orchestratorsProvider = StreamProvider<List<OrchestratorModel>>((ref) {
  final app = ref.watch(currentAppProvider);
  return FirebaseFirestore.instance
      .collection('artifacts/${app.id}/public/data/agent_registry')
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => OrchestratorModel.fromFirestore(doc))
          .toList());
});

final fleetProvider = StreamProvider<List<LogisticsJobModel>>((ref) {
  final app = ref.watch(currentAppProvider);
  return FirebaseFirestore.instance
      .collection('artifacts/${app.id}/public/data/logistics_jobs')
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => LogisticsJobModel.fromFirestore(doc))
          .toList());
});

final evolutionTimelineProvider =
    StreamProvider<List<EvolutionEventModel>>((ref) {
  final app = ref.watch(currentAppProvider);
  return FirebaseFirestore.instance
      .collection('artifacts/${app.id}/public/data/evolution_timeline')
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => EvolutionEventModel.fromFirestore(doc))
          .toList());
});

final activeInterventionCountProvider = Provider<AsyncValue<int>>((ref) {
  return ref
      .watch(interventionsProvider)
      .whenData((list) => list.where((i) => i.isActive).length);
});

// --- UI SELECTION STATE ---

class SelectedInterventionNotifier extends Notifier<InterventionModel?> {
  @override
  InterventionModel? build() => null;
  void setSelected(InterventionModel? item) => state = item;
}

final selectedInterventionProvider =
    NotifierProvider<SelectedInterventionNotifier, InterventionModel?>(
        SelectedInterventionNotifier.new);

// --- SERVICE LAYER (RESOLUTION LOGIC) ---

class InterventionService {
  static Future<void> resolveIntervention(
      String appId, String interventionId, String macroId) async {
    final batch = FirebaseFirestore.instance.batch();

    // 1. Mark Intervention as Resolved
    final interventionRef = FirebaseFirestore.instance
        .doc('artifacts/$appId/public/data/interventions/$interventionId');
    batch.update(interventionRef, {
      'status': 'resolved',
      'resolvedAt': FieldValue.serverTimestamp(),
      'resolution': macroId,
    });

    // 2. Write Human Response to Agent Bus
    final busRef = FirebaseFirestore.instance
        .collection('artifacts/$appId/public/data/agent_bus')
        .doc();
    batch.set(busRef, {
      'correlation_id': 'resolution-$interventionId',
      'status': 'pending',
      'control': {'type': 'RESPONSE', 'priority': 'high'},
      'provenance': {
        'sender_id': 'SUPER_ADMIN_HUB',
        'receiver_id': 'EVOLUTION_WORKER',
      },
      'payload': {
        'result': {
          'action': 'HUMAN_COMMIT',
          'intervention_id': interventionId,
          'macro_applied': macroId,
          'timestamp': DateTime.now().toIso8601String(),
        }
      }
    });

    await batch.commit();
  }
}

class OrchestratorService {
  static Future<void> pauseOrchestrator(String appId, String agentId) async {
    await FirebaseFirestore.instance
        .doc('artifacts/$appId/public/data/agent_registry/$agentId')
        .update({'status.mode': 'paused'});
  }

  static Future<void> resumeOrchestrator(String appId, String agentId) async {
    await FirebaseFirestore.instance
        .doc('artifacts/$appId/public/data/agent_registry/$agentId')
        .update({'status.mode': 'live'});
  }

  static Future<void> rollbackOrchestrator(String appId, String agentId) async {
    await FirebaseFirestore.instance
        .collection('artifacts/$appId/public/data/agent_bus')
        .add({
      'status': 'pending',
      'control': {'type': 'REQUEST', 'priority': 'urgent'},
      'provenance': {
        'sender_id': 'SUPER_ADMIN_HUB',
        'receiver_id': 'EVOLUTION_WORKER'
      },
      'payload': {
        'manifest': {
          'intent': 'ROLLBACK_AGENT',
          'targetAgentId': agentId,
        }
      }
    });
  }
}
