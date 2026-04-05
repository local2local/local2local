import 'package:flutter/material.dart';
import 'package:local2local/features/triage_hub/presentation/widgets/cockpit_header.dart';

class CockpitShell extends StatefulWidget {
  const CockpitShell({super.key});

  @override
  State<CockpitShell> createState() => _CockpitShellState();
}

class _CockpitShellState extends State<CockpitShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1E),
      body: Row(
        children: [
          // SIDE NAVIGATION BAR (Restored from Original Layout)
          Container(
            width: 72,
            color: const Color(0xFF16162A),
            child: Column(
              children: [
                const SizedBox(height: 24),
                // Logo/Home Icon Placeholder (FIX: greenAccent)
                const Icon(Icons.blur_on, color: Colors.greenAccent, size: 32),
                const SizedBox(height: 48),
                _buildNavItem(0, Icons.list_alt, 'Triage'),
                _buildNavItem(1, Icons.grid_view, 'Health'),
                _buildNavItem(2, Icons.directions_car, 'Fleet'),
                _buildNavItem(3, Icons.psychology, 'Evolution'),
                const Spacer(),
                // Bottom Logout Icon
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: IconButton(
                    icon: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),
          // MAIN CONTENT AREA
          Expanded(
            child: Column(
              children: [
                const CockpitHeader(),
                Expanded(
                  child: _buildBody(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        width: double.infinity,
        height: 64,
        decoration: BoxDecoration(
          border: isSelected ? const Border(left: BorderSide(color: Colors.blueAccent, width: 4)) : null,
          color: isSelected ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.blueAccent : Colors.white24,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.blueAccent : Colors.white24,
                fontSize: 8,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildGenericPage('Active Exceptions', Icons.list_alt);
      case 1:
        return _buildGenericPage('System Health', Icons.grid_view);
      case 2:
        return _buildGenericPage('Fleet Logistics', Icons.directions_car);
      case 3:
        return _buildEvolutionTimeline();
      default:
        return const Center(child: Text('L2LAAF Module Selection Required'));
    }
  }

  Widget _buildGenericPage(String title, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Colors.white10),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(color: Colors.white24, fontSize: 18, letterSpacing: 2),
          ),
          const SizedBox(height: 8),
          const Text(
            'NO ACTIVE ITEMS IN QUEUE',
            style: TextStyle(color: Colors.white10, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildEvolutionTimeline() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Evolution Timeline',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Autonomous logic optimization logs and rule enforcement audit.',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: ListView(
              children: [
                _buildTimelineCard(
                  'LOGIC COMMIT SUCCESS',
                  'Phase 36 Stabilization: Successfully committed optimized logic for Unit HBR_EVO_LOOP_36. Business Rule Enforcement: (1) Rule [MUTEX_LOCK] verified... (2) Rule [OMBUDSMAN_AUDIT] verified logic integrity.',
                  'EVOLUTION_WORKER',
                  'Just Now',
                  true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineCard(String title, String desc, String agent, String time, bool isAuto) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
              Text(time, style: const TextStyle(color: Colors.white24, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 12),
          Text(desc, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
                child: Text(agent, style: const TextStyle(color: Colors.white54, fontSize: 9)),
              ),
              if (isAuto) ...[
                const SizedBox(width: 8),
                const Icon(Icons.bolt, color: Colors.greenAccent, size: 12), // FIX: greenAccent
                const SizedBox(width: 4),
                const Text('AUTONOMOUS', style: TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold)), // FIX: greenAccent
              ],
            ],
          ),
        ],
      ),
    );
  }
}