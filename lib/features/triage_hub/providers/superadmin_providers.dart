import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local2local/features/triage_hub/data/superadmin_repository.dart';

/// Live stream of system telemetry (GREEN/YELLOW/RED)
final systemStatusStreamProvider = StreamProvider<String>((ref) {
  return ref.watch(superadminRepositoryProvider).watchSystemStatus();
});

/// Live stream of the official app version
final currentVersionStreamProvider = StreamProvider<String>((ref) {
  return ref.watch(superadminRepositoryProvider).watchCurrentVersion();
});

/// Unified stream for the System-wide Agent Bus
final systemAgentBusProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(superadminRepositoryProvider).watchAgentBus('system_status');
});

/// Unified stream for the Kaskflow Agent Bus
final kaskflowAgentBusProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(superadminRepositoryProvider).watchAgentBus('kaskflow');
});

/// Unified stream for the Moonlitely Agent Bus
final moonlitelyAgentBusProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(superadminRepositoryProvider).watchAgentBus('moonlitely');
});

/// Shadow Bus Providers
final systemShadowBusProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(superadminRepositoryProvider).watchAgentBus('system_status', shadow: true);
});

final kaskflowShadowBusProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(superadminRepositoryProvider).watchAgentBus('kaskflow', shadow: true);
});

final moonlitelyShadowBusProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(superadminRepositoryProvider).watchAgentBus('moonlitely', shadow: true);
});

/// Phase History Providers
final promotedPhasesProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(superadminRepositoryProvider).watchPhaseHistory('promoted_phases');
});

final abandonedPhasesProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(superadminRepositoryProvider).watchPhaseHistory('abandoned_phases');
});