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
    debugPrint("L2LAAF_BOOT: Initializing core v11.74.36...");
    await Firebase.initializeApp();
    
    // MICROTASK DELAY: Prevent Null check crash on immediate service access
    Future.delayed(Duration.zero, () async {
      try {
        await FirebaseAuth.instance.signInAnonymously();
        
        // HEARTBEAT: Using system-level independent subcollection
        await FirebaseFirestore.instance
            .collection('artifacts')
            .doc('system_status')
            .collection('public')
            .doc('data')
            .collection('telemetry')
            .doc('last_heartbeat')
            .set({
              'active_version': 'v11.74.36',
              'timestamp': FieldValue.serverTimestamp(),
              'status': 'OPERATIONAL'
            }, SetOptions(merge: true));
            
        debugPrint("L2LAAF_BOOT: Background Handshake Success.");
      } catch (e) {
        debugPrint("L2LAAF_BOOT_WARNING: Service Handshake Delayed: $e");
      }
    });

    initialized = true;
    debugPrint("L2LAAF_BOOT: Initialization Triggered.");
  } catch (e) {
    errorMsg = e.toString();
    debugPrint("L2LAAF_BOOT_ERROR: $e");
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