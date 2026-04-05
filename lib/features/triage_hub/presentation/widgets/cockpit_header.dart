import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local2local/features/triage_hub/providers/environment_provider.dart';
import 'package:local2local/features/triage_hub/theme/admin_theme.dart';

class CockpitHeader extends ConsumerWidget {
  const CockpitHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final envState = ref.watch(environmentProvider);
    
    // NUCLEAR COLOR: Bright Neon Green for v11.42
    const nuclearColor = Color(0xFF00FF00);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: nuclearColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
          )
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'L2LAAF Cockpit',
                    style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(4)),
                    child: const Text(
                      'DIAGNOSTICS ACTIVE',
                      style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              Text(
                'Build: ${envState.version} | TS: ${envState.buildTimestamp}',
                style: const TextStyle(color: Colors.black54, fontSize: 10, letterSpacing: 0.5),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<L2LEnvironment>(
                    value: envState.environment,
                    dropdownColor: AdminColors.slateDarkest,
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black),
                    onChanged: (val) => ref.read(environmentProvider.notifier).setEnvironment(val!, context),
                    items: L2LEnvironment.values.map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(
                        e.name.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    )).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'TARGET: ${envState.projectId}',
                style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(width: 24),
          const Icon(Icons.bug_report, color: Colors.black, size: 28),
        ],
      ),
    );
  }
}