import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local2local/core/app.dart';
import 'package:local2local/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  bool coreReady = false;
  String? bootError;

  try {
    debugPrint("L2LAAF_BOOT: Initializing Credential Engine v11.91.36...");
    
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    coreReady = true;
    debugPrint("L2LAAF_BOOT: Firebase Core Ready.");
  } catch (e) {
    bootError = e.toString();
    debugPrint("L2LAAF_BOOT_FATAL: $e");
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

// Auth state stream
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// Admin/Operator claim check - stays valid for email users
final isAdminProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return false;
  final idToken = await user.getIdTokenResult(true); 
  return idToken.claims?['admin'] == true || idToken.claims?['operator'] == true;
});