import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local2local/core/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  bool initialized = false;
  String? errorMsg;

  try {
    debugPrint("L2LAAF_BOOT: Starting core v11.75.36...");
    
    // DREAMFLOW COMPLIANCE: Check if already initialized by JS before calling Plugin
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    
    // MICROTASK ESCAPE: Run service access in next tick to clear null checks
    Future.delayed(const Duration(milliseconds: 50), () async {
      try {
        await FirebaseAuth.instance.signInAnonymously();
        
        // SYSTEM HEARTBEAT: Global tracking independent of project ID
        await FirebaseFirestore.instance
            .collection('artifacts')
            .doc('system_status')
            .collection('public')
            .doc('data')
            .collection('telemetry')
            .doc('last_heartbeat')
            .set({
              'active_version': 'v11.75.36',
              'timestamp': FieldValue.serverTimestamp(),
              'status': 'HEALTHY'
            }, SetOptions(merge: true));
            
        debugPrint("L2LAAF_BOOT: Heartbeat established.");
      } catch (e) {
        debugPrint("L2LAAF_BOOT_WARNING: Service sync delayed: $e");
      }
    });

    initialized = true;
    debugPrint("L2LAAF_BOOT: Plugin Handshake complete.");
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