import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  int _selectedIndex = 3;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoggingIn = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isReady = ref.watch(firebaseReadyProvider);
    final error = ref.watch(initErrorProvider);
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1E),
      body: authState.when(
        data: (user) {
          if (user == null) return _buildLoginGate();
          
          return Row(
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
                        tooltip: 'Sign Out',
                        onPressed: () => FirebaseAuth.instance.signOut(),
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
                    Expanded(
                      child: error != null 
                        ? Center(child: Text('BOOT ERROR: $error', style: const TextStyle(color: Colors.redAccent, fontSize: 10)))
                        : !isReady 
                            ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                            : _buildBody(),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('AUTH ERROR: $err', style: const TextStyle(color: Colors.redAccent))),
      ),
    );
  }

  Widget _buildLoginGate() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shield_outlined, color: Colors.blueAccent, size: 64),
            const SizedBox(height: 24),
            const Text('L2LAAF COCKPIT', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 12),
            const Text('CREDENTIAL ACCESS REQUIRED', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 48),
            
            TextField(
              controller: _emailController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Email address',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.email_outlined, color: Colors.white24, size: 18),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Password',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.lock_outline, color: Colors.white24, size: 18),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _isLoggingIn ? null : _handleLogin,
                child: _isLoggingIn 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('AUTHORIZE ACCESS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError('Email and Password are required.');
      return;
    }

    setState(() => _isLoggingIn = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Authentication failed.');
    } finally {
      if (mounted) setState(() => _isLoggingIn = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent)
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
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text("Connection failed. Check permissions.", style: const TextStyle(color: Colors.white24, fontSize: 10)));
        
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return _buildEmptyState(title, icon);
        
        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            
            // DYNAMIC MAPPING: capturing fields common to Health, Fleet, and Triage
            final displayTitle = data['title'] ?? data['metric_name'] ?? data['event_type'] ?? data['agent_id'] ?? data['correlation_id'] ?? 'Record';
            final displaySub = data['details'] ?? data['status'] ?? data['value']?.toString() ?? data['message'] ?? 'Active Trace';
            final statusColor = _getColorForStatus(data['status'] ?? data['severity']);

            return Card(
              color: const Color(0xFF1E1E2C),
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: ListTile(
                leading: Icon(Icons.circle, color: statusColor, size: 10),
                title: Text(displayTitle, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text(displaySub, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                trailing: data['timestamp'] != null ? Text(_formatTs(data['timestamp']), style: const TextStyle(color: Colors.white10, fontSize: 10)) : null,
              ),
            );
          },
        );
      },
    );
  }

  Color _getColorForStatus(dynamic status) {
    final s = status.toString().toLowerCase();
    if (s.contains('error') || s.contains('failed') || s.contains('critical')) return Colors.redAccent;
    if (s.contains('warn')) return Colors.orangeAccent;
    if (s.contains('healthy') || s.contains('ok') || s.contains('success')) return Colors.greenAccent;
    return Colors.blueAccent;
  }

  String _formatTs(dynamic ts) {
    if (ts is Timestamp) return "${ts.toDate().hour}:${ts.toDate().minute.toString().padLeft(2, '0')}";
    return "";
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
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data?.docs ?? [];
        final events = docs.map((d) => EvolutionEventModel.fromFirestore(d)).toList();
        events.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        return Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Evolution Timeline', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  _buildAdminBadge(),
                ],
              ),
              const SizedBox(height: 32),
              Expanded(
                child: events.isEmpty 
                  ? const Center(child: Text('No evolution cycles detected.', style: TextStyle(color: Colors.white10)))
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

  Widget _buildAdminBadge() {
    return Consumer(builder: (context, ref, child) {
      final isAdmin = ref.watch(isAdminProvider).value ?? false;
      if (!isAdmin) return const SizedBox.shrink();
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: Colors.blueAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3))),
        child: const Text('ADMIN ACCESS', style: TextStyle(color: Colors.blueAccent, fontSize: 9, fontWeight: FontWeight.bold)),
      );
    });
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
          const SizedBox(height: 8),
          const Text('Waiting for data feed...', style: TextStyle(color: Colors.white10, fontSize: 10)),
        ],
      ),
    );
  }
}