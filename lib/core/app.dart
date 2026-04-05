import 'package:flutter/material.dart';
import 'package:local2local/features/triage_hub/presentation/widgets/cockpit_header.dart';

class L2LAAFApp extends StatelessWidget {
  const L2LAAFApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'L2LAAF Cockpit',
      theme: ThemeData.dark(),
      home: Scaffold(
        backgroundColor: const Color(0xFF0F0F1E),
        body: Column(
          children: [
            const CockpitHeader(),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.verified, size: 64, color: Color(0xFF2979FF)),
                    const SizedBox(height: 16),
                    const Text(
                      'PIPELINE BRIDGE ESTABLISHED',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Stack Stabilized: Version v11.47',
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