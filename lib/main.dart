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

  // DREAMFLOW STABILIZER: Async Retry Loop for JS SDK binding
  int attempts = 0;
  while (attempts < 5 && !initialized) {
    try {
      debugPrint("L2LAAF_BOOT: Handshake Attempt ${attempts + 1} (v11.73.36)...");
      await Firebase.initializeApp();
      await FirebaseAuth.instance.signInAnonymously();
      
      // Heartbeat: Write current version to Firestore for tracking
      await FirebaseFirestore.instance
          .collection('artifacts')
          .doc('local2local-dev')
          .collection('public')
          .doc('data')
          .collection('system_status')
          .doc('heartbeat')
          .set({
            'active_version': 'v11.73.36',
            'last_boot': FieldValue.serverTimestamp(),
            'status': 'HEALTHY'
          }, SetOptions(merge: true));

      initialized = true;
      debugPrint("L2LAAF_BOOT: Handshake SUCCESS.");
    } catch (e) {
      attempts++;
      errorMsg = e.toString();
      debugPrint("L2LAAF_BOOT_RETRY: $e");
      if (attempts < 5) await Future.delayed(const Duration(milliseconds: 500));
    }
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