import 'package:flutter/material.dart';
import 'package:local2local/features/triage_hub/presentation/pages/cockpit_shell.dart';

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
      // Dreamflow Pattern: Standard error boundary
      builder: (context, child) {
        ErrorWidget.builder = (details) => Container(
          alignment: Alignment.center,
          color: const Color(0xFF0F0F1E),
          child: Text(
            'L2LAAF RUNTIME ERROR: ${details.exception}',
            style: const TextStyle(color: Colors.redAccent, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        );
        return child!;
      },
      home: const CockpitShell(),
    );
  }
}