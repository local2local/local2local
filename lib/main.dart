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
    debugPrint("L2LAAF_BOOT: Starting Handshake v11.76.36...");
    
    // DREAMFLOW HARDENING: Ensure we don't call init if JS side already did
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    
    // MICROTASK DELAY: Finalizing Bridge Attachment
    await Future.delayed(const Duration(milliseconds: 100));
    
    try {
      await FirebaseAuth.instance.signInAnonymously();
      
      // SYSTEM HEARTBEAT: Write to independent system subcollection
      await FirebaseFirestore.instance
          .collection('artifacts')
          .doc('system_status')
          .collection('public')
          .doc('data')
          .collection('telemetry')
          .doc('last_heartbeat')
          .set({
            'version': 'v11.76.36',
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'OPERATIONAL',
            'tenant_default': 'local2local-kaskflow'
          }, SetOptions(merge: true));
          
      debugPrint("L2LAAF_BOOT: Heartbeat established.");
    } catch (serviceError) {
      debugPrint("L2LAAF_BOOT_WARNING: Post-init sync delayed: $serviceError");
    }

    initialized = true;
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