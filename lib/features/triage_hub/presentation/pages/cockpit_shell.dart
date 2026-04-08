import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local2local/features/triage_hub/presentation/widgets/cockpit_header.dart';
import 'package:local2local/features/triage_hub/presentation/widgets/hbr_lock_indicator.dart';
import 'package:local2local/features/triage_hub/providers/environment_provider.dart';
import 'package:local2local/features/triage_hub/models/evolution_event_model.dart';
import 'package:local2local/main.dart';

class CockpitShell extends ConsumerStatefulWidget {
  const CockpitShell({super.key});
  @override
  ConsumerState<CockpitShell> createState() => _CockpitShellState();
}

class _CockpitShellState extends ConsumerState<CockpitShell> {
  int _selectedIndex = 3;
  
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1E),
      body: authState.when(
        data: (user) => _buildMainLayout(user),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('AUTH ERROR: $err', style: const TextStyle(color: Colors.redAccent))),
      ),
    );
  }

  Widget _buildMainLayout(User? user) {
    if (user == null) return const Center(child: Text("ACCESS DENIED", style: TextStyle(color: Colors.white)));
    return Row(
      children: [
        _buildSidebar(),
        Expanded(
          child: Column(
            children: [
              const CockpitHeader(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 72,
      color: const Color(0xFF16162A),
      child: Column(
        children: [
          const SizedBox(height: 24),
          const Icon(Icons.blur_on, color: Colors.greenAccent, size: 32),
          const SizedBox(height: 48),
          _buildNavItem(0, Icons.list_alt, 'Triage'),
          _buildNavItem(3, Icons.psychology, 'Evolution'),
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
    if (_selectedIndex == 3) return _buildEvolutionTimeline(env.projectId);
    return _buildFirestoreList(env.projectId, 'agent_bus', 'Active Exceptions');
  }

  Widget _buildFirestoreList(String appId, String coll, String title) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('artifacts').doc(appId)
          .collection('public').doc('data')
          .collection(coll).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final isLocked = data['lock_status'] == 'LOCKED';
            
            return Card(
              color: const Color(0xFF1E1E2C),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Row(
                  children: [
                    Text(data['title'] ?? 'Record', style: const TextStyle(color: Colors.white)),
                    const SizedBox(width: 8),
                    HbrLockIndicator(isLocked: isLocked, lockedBy: data['locked_by']),
                  ],
                ),
                subtitle: Text(data['details'] ?? 'Active Trace', style: const TextStyle(color: Colors.white54)),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEvolutionTimeline(String appId) {
    return const Center(child: Text("Evolution Engine Online", style: TextStyle(color: Colors.white24)));
  }
}