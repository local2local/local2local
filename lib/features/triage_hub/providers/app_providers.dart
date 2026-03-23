import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Available app tenants
enum AppTenant {
  kaskflow('kaskflow', 'Kaskflow'),
  moonlitely('moonlitely', 'Moonlitely');

  const AppTenant(this.id, this.displayName);
  final String id;
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

/// Mock intervention data for demonstration
/// In production, this would connect to Firebase Firestore
class InterventionService {
  static final Map<String, List<Map<String, dynamic>>> _mockInterventions = {
    'kaskflow': [
      {'id': '1', 'status': 'active', 'title': 'High CPU Usage Alert'},
      {'id': '2', 'status': 'active', 'title': 'Memory Leak Detected'},
      {'id': '3', 'status': 'resolved', 'title': 'Network Timeout'},
      {'id': '4', 'status': 'active', 'title': 'Database Connection Pool'},
    ],
    'moonlitely': [
      {'id': '1', 'status': 'active', 'title': 'API Rate Limit'},
      {'id': '2', 'status': 'resolved', 'title': 'SSL Certificate Expiry'},
    ],
  };

  /// Stream of active intervention counts for a given app
  static Stream<int> getActiveInterventionCount(String appId) {
    return Stream.periodic(const Duration(seconds: 1), (_) {
      final interventions = _mockInterventions[appId] ?? [];
      return interventions.where((i) => i['status'] == 'active').length;
    });
  }

  /// Add a mock intervention (for testing)
  static void addMockIntervention(String appId) {
    final list = _mockInterventions[appId] ?? [];
    list.add({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'status': 'active',
      'title': 'New Intervention ${list.length + 1}',
    });
    _mockInterventions[appId] = list;
  }
}

/// StreamProvider for active intervention count
/// Automatically updates when currentAppProvider changes
final activeInterventionCountProvider = StreamProvider<int>((ref) {
  final currentApp = ref.watch(currentAppProvider);
  return InterventionService.getActiveInterventionCount(currentApp.id);
});
