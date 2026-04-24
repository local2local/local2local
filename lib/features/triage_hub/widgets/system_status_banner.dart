import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final systemStatusProvider = StreamProvider<String>((ref) {
  return FirebaseFirestore.instance
      .doc('artifacts/system_status/public/data/telemetry/current')
      .snapshots()
      .map((snap) => snap.data()?['status'] as String? ?? 'GREEN');
});

class SystemStatusBanner extends ConsumerWidget {
  const SystemStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(systemStatusProvider);

    return statusAsync.when(
      data: (status) {
        Color bgColor = Colors.green.shade800;
        IconData icon = Icons.check_circle;
        String text = "SYSTEM NORMAL - ALL DEPLOYMENTS PERMITTED";

        if (status == 'YELLOW') {
          bgColor = Colors.orange.shade800;
          icon = Icons.warning_amber_rounded;
          text = "WARNING STATE - FEATURE DEPLOYMENTS DELAYED BY 60s";
        } else if (status == 'RED') {
          bgColor = Colors.red.shade900;
          icon = Icons.error_outline;
          text = "CRITICAL STATE - FEATURE DEPLOYMENTS BLOCKED";
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: bgColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white, 
                  fontWeight: FontWeight.bold, 
                  letterSpacing: 1.1,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const LinearProgressIndicator(minHeight: 36),
      error: (e, s) => Container(
        width: double.infinity,
        color: Colors.grey.shade800,
        height: 36,
        alignment: Alignment.center,
        child: const Text("TELEMETRY DISCONNECTED", style: TextStyle(color: Colors.white)),
      ),
    );
  }
}