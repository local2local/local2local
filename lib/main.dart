import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:local2local/features/triage_hub/screens/superadmin_dashboard.dart';
import 'package:local2local/firebase_options.dart';

const String telemetryEndpoint = 'https://us-central1-local2local-dev.cloudfunctions.net/ingestWebError';

Future<void> sendErrorToAgentBus(String error, String stackTrace, bool isFatal) async {
  try {
    await http.post(
      Uri.parse(telemetryEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'error': error,
        'stackTrace': stackTrace,
        'isFatal': isFatal,
        'timestamp': DateTime.now().toIso8601String(),
        'platform': kIsWeb ? 'web' : 'native',
        'appId': 'local2local-kaskflow' 
      }),
    );
  } catch (e) {
    debugPrint('L2LAAF_TELEMETRY_FAIL: Failed to send error to bus: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    sendErrorToAgentBus(details.exceptionAsString(), details.stack.toString(), true);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    sendErrorToAgentBus(error.toString(), stack.toString(), true);
    return true;
  };
  
  bool coreReady = false;
  String? bootError;

  try {
    debugPrint("L2LAAF_BOOT: Initializing Credential Engine...");
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    coreReady = true;
  } catch (e, stack) {
    bootError = e.toString();
    sendErrorToAgentBus("Firebase Init Failed: ${e.toString()}", stack.toString(), true);
  }

  runApp(
    ProviderScope(
      overrides: [
        firebaseReadyProvider.overrideWith((ref) => coreReady),
        initErrorProvider.overrideWith((ref) => bootError),
      ],
      child: const MaterialApp(
        title: 'L2LAAF Orchestrator',
        debugShowCheckedModeBanner: false,
        home: SuperadminDashboard(),
      ),
    ),
  );
}

final firebaseReadyProvider = Provider<bool>((ref) => false);
final initErrorProvider = Provider<String?>((ref) => null);
final authStateProvider = StreamProvider<User?>((ref) => FirebaseAuth.instance.authStateChanges());
final isAdminProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return false;
  final idToken = await user.getIdTokenResult(true); 
  return idToken.claims?['admin'] == true || idToken.claims?['operator'] == true;
});