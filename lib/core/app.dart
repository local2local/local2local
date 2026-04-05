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
      home: const Scaffold(
        body: Column(
          children: [
            CockpitHeader(),
            Expanded(
              child: Center(
                child: Text('L2LAAF PIPELINE DIAGNOSTICS: STACK STABILIZED'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}