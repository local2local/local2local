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
    final isStressTest = envState.version == 'v11.38.36';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        // PIPELINE STRESS TEST: Background turns Amber/Orange if updated
        color: isStressTest ? Colors.amber.shade900 : envState.headerColor,
        boxShadow: isProd ? [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.5),
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
                  if (isStressTest) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
                      child: const Text(
                        'STRESS TEST ACTIVE',
                        style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
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
                          color: e == L2LEnvironment.prod ? Colors.redAccent : Colors.white,
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
                'PROJECT: ${envState.projectId}',
                style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(width: 24),
          const Icon(Icons.notifications_none, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          // PIPELINE STRESS TEST: Bright Yellow Info Icon
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.info_outline, color: Colors.yellowAccent, size: 24),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}