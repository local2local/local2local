import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local2local/features/triage_hub/presentation/widgets/cockpit_header.dart';
import 'package:local2local/features/triage_hub/providers/environment_provider.dart';
import 'package:local2local/features/triage_hub/models/evolution_event_model.dart';
import 'package:local2local/main.dart';

class CockpitShell extends ConsumerStatefulWidget {
  const CockpitShell({super.key});

  @override
  ConsumerState<CockpitShell> createState() => _CockpitShellState();
}

class _CockpitShellState extends ConsumerState<CockpitShell> {
  int _selectedIndex = 3; // Default to Evolution for P36 verification

  @override
  Widget build(BuildContext context) {
    final isReady = ref.watch(firebaseStatusProvider);
    final bootMsg = ref.watch(bootMessageProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1E),
      body: Row(
        children: [
          // SIDE NAVIGATION
          Container(
            width: 72,
            color: const Color(0xFF16162A),
            child: Column(
              children: [
                const SizedBox(height: 24),
                const Icon(Icons.blur_on, color: Colors.greenAccent, size: 32),
                const SizedBox(height: 48),
                _buildNavItem(0, Icons.list_alt, 'Triage'),
                _buildNavItem(1, Icons.grid_view, 'Health'),
                _buildNavItem(2, Icons.directions_car, 'Fleet'),
                _buildNavItem(3, Icons.psychology, 'Evolution'),
                const Spacer(),
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
          // MAIN CONTENT
          Expanded(
            child: Column(
              children: [
                const CockpitHeader(),
                if (bootMsg != null)
                  Container(
                    width: double.infinity,
                    color: Colors.orangeAccent.withValues(alpha: 0.1),
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                    child: Text(bootMsg, style: const TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                Expanded(
                  child: !isReady 
                    ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                    : _buildBody(),
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
            Icon(icon, color: isSelected ? Colors.blueAccent : Colors.white24, size: 24),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: isSelected ? Colors.blueAccent : Colors.white24, fontSize: 8)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final env = ref.watch(environmentProvider);
    final projectId = env.projectId;

    switch (_selectedIndex) {
      case 0: return _buildFirestoreList(projectId, 'agent_bus', 'Active Exceptions', Icons.list_alt);
      case 1: return _buildFirestoreList(projectId, 'system_health', 'System Health', Icons.grid_view);
      case 2: return _buildFirestoreList(projectId, 'fleet_status', 'Fleet Logistics', Icons.directions_car);
      case 3: return _buildEvolutionTimeline(projectId);
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildFirestoreList(String appId, String coll, String title, IconData icon) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('artifacts')
          .doc(appId)
          .collection('public')
          .doc('data')
          .collection(coll)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox.shrink();
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return _buildEmptyState(title, icon);
        
        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            return Card(
              color: const Color(0xFF1E1E2C),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(data['title'] ?? data['correlation_id'] ?? 'Log Record', style: const TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: Text(data['details'] ?? data['status'] ?? 'Tracing active', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEvolutionTimeline(String appId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('artifacts')
          .doc(appId)
          .collection('public')
          .doc('data')
          .collection('evolution_timeline')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox.shrink();
        final docs = snapshot.data?.docs ?? [];
        final events = docs.map((d) => EvolutionEventModel.fromFirestore(d)).toList();
        events.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        return Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Evolution Timeline', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Autonomous logic optimization logs and rule enforcement audit.', style: TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 32),
              Expanded(
                child: events.isEmpty 
                  ? const Center(child: Text('Waiting for evolution cycles...', style: TextStyle(color: Colors.white10)))
                  : ListView.builder(
                      itemCount: events.length,
                      itemBuilder: (ctx, i) => _buildTimelineCard(events[i]),
                    ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimelineCard(EvolutionEventModel event) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: const Color(0xFF1E1E2C), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(event.title, style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
              Text(event.timeDisplay, style: const TextStyle(color: Colors.white24, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 12),
          Text(event.description, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
                child: Text(event.agentName, style: const TextStyle(color: Colors.white54, fontSize: 9)),
              ),
              if (event.isAutonomous) ...[
                const SizedBox(width: 8),
                const Icon(Icons.bolt, color: Colors.greenAccent, size: 12),
                const SizedBox(width: 4),
                const Text('AUTONOMOUS', style: TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Colors.white10),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: Colors.white24, fontSize: 18)),
        ],
      ),
    );
  }
}