import 'package:flutter/material.dart';
import 'package:local2local/features/triage_hub/presentation/widgets/cockpit_header.dart';

class L2LAAFApp extends StatelessWidget {
  const L2LAAFApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'L2LAAF Cockpit',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F0F1E),
      ),
      home: Scaffold(
        body: Column(
          children: [
            const CockpitHeader(),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // FIX: 'emeraldAccent' does not exist. Using 'greenAccent'.
                    const Icon(Icons.verified_user, size: 64, color: Colors.greenAccent),
                    const SizedBox(height: 16),
                    const Text(
                      'L2LAAF COCKPIT: SYSTEM SECURE',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Phase 36 Stabilization Finalized',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}