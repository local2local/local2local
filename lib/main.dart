import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'dart:convert';
import 'package:local2local/core/app.dart';
import 'package:local2local/firebase_options.dart';

// --- L2LAAF TELEMETRY CONFIGURATION ---
// Cloud Function endpoint for local2local-dev
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
// --------------------------------------

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize date formatting for intl package
  await initializeDateFormatting();

  // --- L2LAAF GLOBAL ERROR CATCHERS ---
  // Catch synchronous Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    sendErrorToAgentBus(details.exceptionAsString(), details.stack.toString(), true);
  };

  // Catch asynchronous Dart errors
  PlatformDispatcher.instance.onError = (error, stack) {
    sendErrorToAgentBus(error.toString(), stack.toString(), true);
    return true;
  };
  // ------------------------------------
  
  bool coreReady = false;
  String? bootError;

  try {
    debugPrint("L2LAAF_BOOT: Initializing Credential Engine v11.92.36...");
    
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    coreReady = true;
    debugPrint("L2LAAF_BOOT: Firebase Core Ready.");
  } catch (e, stack) {
    bootError = e.toString();
    debugPrint("L2LAAF_BOOT_FATAL: $e");
    
    // Explicitly catch boot failures and send to the Autonomous Orchestrator
    sendErrorToAgentBus("Firebase Init Failed: ${e.toString()}", stack.toString(), true);
  }

  runApp(
    ProviderScope(
      overrides: [
        firebaseReadyProvider.overrideWith((ref) => coreReady),
        initErrorProvider.overrideWith((ref) => bootError),
      ],
      child: const L2LAAFApp(),
    ),
  );
}

final firebaseReadyProvider = Provider<bool>((ref) => false);
final initErrorProvider = Provider<String?>((ref) => null);

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final isAdminProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return false;
  final idToken = await user.getIdTokenResult(true); 
  return idToken.claims?['admin'] == true || idToken.claims?['operator'] == true;
});