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
    debugPrint("L2LAAF_BOOT: Handshaking v11.82.36...");
    
    // Auth-init via compiled options (Secure + Race-Condition Proof)
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    await FirebaseAuth.instance.signInAnonymously();
    
    // HEARTBEAT: Telemetry verify
    await FirebaseFirestore.instance
        .collection('artifacts')
        .doc('system_status')
        .collection('public')
        .doc('data')
        .collection('telemetry')
        .doc('last_heartbeat')
        .set({
          'version': 'v11.82.36',
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'OPERATIONAL',
          'bridge': 'MODULAR_V10'
        }, SetOptions(merge: true));

    initialized = true;
    debugPrint("L2LAAF_BOOT: System Ready.");
  } catch (e) {
    errorMsg = e.toString();
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