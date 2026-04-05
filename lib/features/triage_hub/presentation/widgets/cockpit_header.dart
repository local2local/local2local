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
    
    // NUCLEAR CYAN: Impossible to miss. If you see Blue, the cache is still active.
    const nuclearCyan = Color(0xFF00E5FF); 

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: nuclearCyan, 
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 2),
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
                    style: TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(20)),
                    child: const Text(
                      'PIPELINE LIVE',
                      style: TextStyle(color: Colors.black87, fontSize: 8, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              Text(
                'System Build: ${envState.version}',
                style: TextStyle(color: Colors.black54, fontSize: 10, letterSpacing: 0.5),
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
                  color: Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<L2LEnvironment>(
                    value: envState.environment,
                    dropdownColor: AdminColors.slateDarkest,
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black87),
                    onChanged: (val) => ref.read(environmentProvider.notifier).setEnvironment(val!, context),
                    items: L2LEnvironment.values.map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(
                        e.name.toUpperCase(),
                        style: TextStyle(
                          color: e == L2LEnvironment.prod ? Colors.red : Colors.white,
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
                style: const TextStyle(color: Colors.black45, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(width: 24),
          const Icon(Icons.notifications_none, color: Colors.black87, size: 22),
          const SizedBox(width: 12),
          // LARGE DARK BOLT FOR STRESS TEST
          const Icon(Icons.bolt, color: Colors.black87, size: 32),
        ],
      ),
    );
  }
}