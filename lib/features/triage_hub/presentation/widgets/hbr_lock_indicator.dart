import 'package:flutter/material.dart';

class HbrLockIndicator extends StatelessWidget {
  final bool isLocked;
  final String? lockedBy;

  const HbrLockIndicator({
    super.key, 
    required this.isLocked, 
    this.lockedBy
  });

  @override
  Widget build(BuildContext context) {
    if (!isLocked) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_clock_outlined, color: Colors.amber, size: 12),
          const SizedBox(width: 4),
          Text(
            'LOCKED: ${lockedBy ?? "EVOLUTION"}',
            style: const TextStyle(
              color: Colors.amber, 
              fontSize: 9, 
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5
            ),
          ),
        ],
      ),
    );
  }
}