import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local2local/features/triage_hub/providers/environment_provider.dart';
import 'package:local2local/features/triage_hub/theme/admin_theme.dart';

class CockpitHeader extends ConsumerWidget {
  const CockpitHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final envState = ref.watch(environmentProvider);
    final isProd = envState.environment == L2LEnvironment.prod;
    
    // NUCLEAR TEST COLOR: Impossible to miss if the pipeline works
    const testColor = Color(0xFFE91E63); 

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: testColor, 
        boxShadow: isProd ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            spreadRadius: 5,
          )
        ] : null,
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
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                    child: const Text(
                      'PIPELINE VERIFIED',
                      style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              Text(
                'System Build: ${envState.version}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10, letterSpacing: 0.5),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<L2LEnvironment>(
                    value: envState.environment,
                    dropdownColor: AdminColors.slateDarkest,
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                    onChanged: (val) => ref.read(environmentProvider.notifier).setEnvironment(val!, context),
                    items: L2LEnvironment.values.map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(
                        e.name.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'TARGET: ${envState.projectId}',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(width: 24),
          const Icon(Icons.notifications_none, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          // LARGE YELLOW ICON FOR STRESS TEST
          const Icon(Icons.bolt, color: Colors.yellowAccent, size: 32),
        ],
      ),
    );
  }
}