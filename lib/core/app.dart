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
      home: const CockpitShell(),
    );
  }
}