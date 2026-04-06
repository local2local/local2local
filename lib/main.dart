import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local2local/core/app.dart';
import 'package:local2local/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  bool initialized = false;
  String? errorMsg;

  try {
    debugPrint("L2LAAF_BOOT: Handshaking v11.87.36...");
    
    // Auth-init via authoritative compiled options
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    try {
      debugPrint("L2LAAF_BOOT: Signing in anonymously...");
      await FirebaseAuth.instance.signInAnonymously();
      
      // HEARTBEAT: Only written if Auth succeeds
      await FirebaseFirestore.instance
          .collection('artifacts')
          .doc('system_status')
          .collection('public')
          .doc('data')
          .collection('telemetry')
          .doc('last_heartbeat')
          .set({
            'version': 'v11.87.36',
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'OPERATIONAL',
            'bridge': 'MODULAR_V10_STABLE'
          }, SetOptions(merge: true));
      
      debugPrint("L2LAAF_BOOT: System Ready.");
      initialized = true;
    } on FirebaseAuthException catch (authE) {
      // Handle 'admin-restricted-operation' gracefully
      if (authE.code == 'admin-restricted-operation') {
        errorMsg = "AUTH ERROR: Anonymous Sign-in is disabled in Firebase Console.";
      } else {
        errorMsg = "AUTH ERROR: ${authE.message}";
      }
      debugPrint("L2LAAF_BOOT_AUTH_FAIL: ${authE.code} - ${authE.message}");
      // We set initialized to true anyway so the UI loads in 'degraded' mode
      initialized = true; 
    }
  } catch (e) {
    errorMsg = "BOOT FATAL: $e";
    debugPrint("L2LAAF_BOOT_FATAL: $e");
  }

  runApp(
    ProviderScope(
      overrides: [
        firebaseReadyProvider.overrideWith((ref) => initialized),
        initErrorProvider.overrideWith((ref) => errorMsg),
      ],
      child: const L2LAAFApp(),
    ),
  );
}

final firebaseReadyProvider = Provider<bool>((ref) => false);
final initErrorProvider = Provider<String?>((ref) => null);