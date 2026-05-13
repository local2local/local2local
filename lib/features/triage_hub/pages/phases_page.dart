import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// ignore: depend_on_referenced_packages
import 'package:intl/intl.dart';
import 'package:local2local/features/triage_hub/theme/admin_theme.dart';
import 'package:local2local/features/triage_hub/providers/superadmin_providers.dart';

/// Page displaying Phase History with PROMOTED and ABANDONED tabs.
/// Part of the Phase 44 Evolution Timeline.
class PhasesPage extends ConsumerStatefulWidget {
  const PhasesPage({super.key});

  @override
  ConsumerState<PhasesPage> createState() => _PhasesPageState();
}

class _PhasesPageState extends ConsumerState<PhasesPage>
    with SingleTickerProviderStateMixin {
  int _selectedPhaseHistoryIndex = 0;
  final TextEditingController _phaseSearchController = TextEditingController();
  String _phaseSearchQuery = '';

  final Map<int, bool> _phaseStreamingByTab = {0: true, 1: true};
  final Map<int, List<Map<String, dynamic>>> _phaseSnapshotByTab = {0: [], 1: []};
  final Map<int, int> _newPhasesByTab = {0: 0, 1: 0};
  final Map<int, Set<String>> _phaseSnapshotIdsByTab = {0: {}, 1: {}};

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(_pulseController);
  }

  @override
  void dispose() {
    _phaseSearchController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.slateDarkest,
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Phase History',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Track promoted and abandoned phases across the evolution pipeline.',
              style: TextStyle(
                color: AdminColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AdminColors.slateDark.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AdminColors.borderDefault),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPhaseHistoryHeader(),
                    const SizedBox(height: 16),
                    _buildPhaseSearchBar(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildPhaseHistoryTab('PROMOTED', 0),
                        _buildPhaseHistoryTab('ABANDONED', 1),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: AdminColors.borderDefault, height: 1),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _selectedPhaseHistoryIndex == 0
                          ? _buildPromotedPhasesList()
                          : _buildAbandonedPhasesList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseSearchBar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AdminColors.slateDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AdminColors.borderDefault),
      ),
      child: TextField(
        controller: _phaseSearchController,
        style: const TextStyle(color: AdminColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search by summary...',
          hintStyle: const TextStyle(color: AdminColors.textMuted, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: AdminColors.textMuted, size: 20),
          suffixIcon: _phaseSearchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, color: AdminColors.textMuted, size: 18),
                  onPressed: () {
                    _phaseSearchController.clear();
                    setState(() => _phaseSearchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (value) => setState(() => _phaseSearchQuery = value),
      ),
    );
  }

  Widget _buildPhaseHistoryTab(String label, int index) {
    final isSelected = _selectedPhaseHistoryIndex == index;
    final isPromoted = index == 0;
    return GestureDetector(
      onTap: () => setState(() => _selectedPhaseHistoryIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected 
                  ? (isPromoted ? AdminColors.emeraldGreen : AdminColors.statusWarning) 
                  : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AdminColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildPromotedPhasesList() {
    const tabIndex = 0;
    final promotedAsync = ref.watch(promotedPhasesProvider);
    final isStreaming = _phaseStreamingByTab[tabIndex] ?? true;
    final snapshot = _phaseSnapshotByTab[tabIndex] ?? [];
    final snapshotIds = _phaseSnapshotIdsByTab[tabIndex] ?? {};

    if (!isStreaming && snapshotIds.isNotEmpty) {
      promotedAsync.whenData((liveItems) {
        final newCount = liveItems.where((item) {
          final phaseId = item['phase'] as String? ?? '';
          return phaseId.isNotEmpty && !snapshotIds.contains(phaseId);
        }).length;
        if (newCount != (_newPhasesByTab[tabIndex] ?? 0)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _newPhasesByTab[tabIndex] = newCount);
          });
        }
      });
    }

    final effectiveAsync = isStreaming ? promotedAsync : AsyncValue.data(snapshot);

    return effectiveAsync.when(
      data: (phases) {
        if (phases.isEmpty) {
          return const Center(
            child: Text('No history yet.', style: TextStyle(color: AdminColors.textSecondary)),
          );
        }
        final filteredPhases = _filterPhases(phases);
        return ListView.builder(
          itemCount: filteredPhases.length,
          itemBuilder: (context, index) => _buildPromotedPhaseCard(filteredPhases[index]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AdminColors.emeraldGreen)),
      error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AdminColors.rubyRed))),
    );
  }

  Widget _buildAbandonedPhasesList() {
    const tabIndex = 1;
    final abandonedAsync = ref.watch(abandonedPhasesProvider);
    final isStreaming = _phaseStreamingByTab[tabIndex] ?? true;
    final snapshot = _phaseSnapshotByTab[tabIndex] ?? [];
    final snapshotIds = _phaseSnapshotIdsByTab[tabIndex] ?? {};

    if (!isStreaming && snapshotIds.isNotEmpty) {
      abandonedAsync.whenData((liveItems) {
        final newCount = liveItems.where((item) {
          final phaseId = item['phase'] as String? ?? '';
          return phaseId.isNotEmpty && !snapshotIds.contains(phaseId);
        }).length;
        if (newCount != (_newPhasesByTab[tabIndex] ?? 0)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _newPhasesByTab[tabIndex] = newCount);
          });
        }
      });
    }

    final effectiveAsync = isStreaming ? abandonedAsync : AsyncValue.data(snapshot);

    return effectiveAsync.when(
      data: (phases) {
        if (phases.isEmpty) {
          return const Center(
            child: Text('No history yet.', style: TextStyle(color: AdminColors.textSecondary)),
          );
        }
        final filteredPhases = _filterPhases(phases);
        return ListView.builder(
          itemCount: filteredPhases.length,
          itemBuilder: (context, index) => _buildAbandonedPhaseCard(filteredPhases[index]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AdminColors.statusWarning)),
      error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AdminColors.rubyRed))),
    );
  }

  List<Map<String, dynamic>> _filterPhases(List<Map<String, dynamic>> phases) {
    if (_phaseSearchQuery.isEmpty) return phases;
    final query = _phaseSearchQuery.toLowerCase();
    return phases.where((phase) {
      final summary = (phase['summary']?.toString() ?? '').toLowerCase();
      return summary.contains(query);
    }).toList();
  }

  Widget _buildPromotedPhaseCard(Map<String, dynamic> data) {
    final phase = data['phase']?.toString() ?? 'Unknown';
    final originator = data['originator']?.toString() ?? 'UNKNOWN';
    final summary = data['summary']?.toString() ?? 'No summary provided.';
    final promotedAt = data['promoted_at'];
    final status = data['status']?.toString() ?? 'ACTIVE';
    final commitSha = data['commit_sha']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.slateDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AdminColors.emeraldGreen.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Phase $phase', style: const TextStyle(color: AdminColors.emeraldGreen, fontSize: 18, fontWeight: FontWeight.bold)),
              if (commitSha.isNotEmpty) ...[const SizedBox(width: 12), _buildCommitShaBadge(commitSha)],
              const SizedBox(width: 12),
              _buildOriginatorBadge(originator),
              const Spacer(),
              _buildStatusChip(status, isPromoted: true),
            ],
          ),
          const SizedBox(height: 12),
          Text(summary, style: const TextStyle(color: AdminColors.textMuted, fontSize: 13, height: 1.4)),
          const SizedBox(height: 12),
          Text('Promoted: ${_formatTimestamp(promotedAt)}', style: TextStyle(color: AdminColors.textSecondary.withValues(alpha: 0.7), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildAbandonedPhaseCard(Map<String, dynamic> data) {
    final phase = data['phase']?.toString() ?? 'Unknown';
    final originator = data['originator']?.toString() ?? 'UNKNOWN';
    final summary = data['summary']?.toString() ?? 'No summary provided.';
    final abandonedAt = data['abandoned_at'];
    final reason = data['reason']?.toString() ?? 'KEEP_IN_DEV';
    final commitSha = data['commit_sha']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.slateDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AdminColors.statusWarning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Phase $phase', style: const TextStyle(color: AdminColors.statusWarning, fontSize: 18, fontWeight: FontWeight.bold)),
              if (commitSha.isNotEmpty) ...[const SizedBox(width: 12), _buildCommitShaBadge(commitSha)],
              const SizedBox(width: 12),
              _buildOriginatorBadge(originator),
              const Spacer(),
              _buildReasonChip(reason),
            ],
          ),
          const SizedBox(height: 12),
          Text(summary, style: const TextStyle(color: AdminColors.textMuted, fontSize: 13, height: 1.4)),
          const SizedBox(height: 12),
          Text('Abandoned: ${_formatTimestamp(abandonedAt)}', style: TextStyle(color: AdminColors.textSecondary.withValues(alpha: 0.7), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildOriginatorBadge(String originator) {
    Color badgeColor = AdminColors.textSecondary;
    switch (originator.toUpperCase()) {
      case 'MANUAL': badgeColor = AdminColors.statusInfo; break;
      case 'ASSISTED': badgeColor = AdminColors.emeraldGreen; break;
      case 'AUTO': badgeColor = AdminColors.statusWarning; break;
      case 'DREAM': badgeColor = const Color(0xFFA855F7); break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4), border: Border.all(color: badgeColor.withValues(alpha: 0.5))),
      child: Text(originator.toUpperCase(), style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
    );
  }

  Widget _buildCommitShaBadge(String fullSha) {
    final shortSha = fullSha.length >= 7 ? fullSha.substring(0, 7) : fullSha;
    return InkWell(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: fullSha));
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied SHA')));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(color: AdminColors.slateDarkest, borderRadius: BorderRadius.circular(4), border: Border.all(color: AdminColors.borderDefault)),
        child: Text('SHA $shortSha', style: const TextStyle(color: AdminColors.textSecondary, fontSize: 11, fontFamily: 'monospace')),
      ),
    );
  }

  Widget _buildStatusChip(String status, {required bool isPromoted}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: AdminColors.emeraldGreen.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: AdminColors.emeraldGreen.withValues(alpha: 0.5))),
      child: Text(status.toUpperCase(), style: const TextStyle(color: AdminColors.emeraldGreen, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildReasonChip(String reason) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: AdminColors.textMuted.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: AdminColors.textMuted.withValues(alpha: 0.5))),
      child: Text(reason.toUpperCase(), style: const TextStyle(color: AdminColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      DateTime dt = (timestamp is Timestamp) ? timestamp.toDate() : (timestamp as DateTime);
      return DateFormat('yyyy-MM-dd HH:mm').format(dt.subtract(const Duration(hours: 6)));
    } catch (e) { return 'Invalid'; }
  }

  Widget _buildPhaseHistoryHeader() {
    final isStreaming = _phaseStreamingByTab[_selectedPhaseHistoryIndex] ?? true;
    return Row(
      children: [
        const Icon(Icons.timeline_rounded, color: AdminColors.emeraldGreen, size: 24),
        const SizedBox(width: 12),
        const Text('Evolution Phases', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const Spacer(),
        _buildPhaseHistoryStreamingToggle(isStreaming),
      ],
    );
  }

  Widget _buildPhaseHistoryStreamingToggle(bool isStreaming) {
    return GestureDetector(
      onTap: _togglePhaseHistoryStreamingMode,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isStreaming ? AdminColors.emeraldGreen.withValues(alpha: 0.15) : AdminColors.statusWarning.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isStreaming ? AdminColors.emeraldGreen.withValues(alpha: 0.5) : AdminColors.statusWarning.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isStreaming) AnimatedBuilder(animation: _pulseAnimation, builder: (c, _) => Opacity(opacity: _pulseAnimation.value, child: const Text('●', style: TextStyle(color: AdminColors.emeraldGreen, fontSize: 14)))),
            const SizedBox(width: 6),
            Text(isStreaming ? 'LIVE' : 'PAUSED', style: TextStyle(color: isStreaming ? AdminColors.emeraldGreen : AdminColors.statusWarning, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  void _togglePhaseHistoryStreamingMode() {
    final tabIndex = _selectedPhaseHistoryIndex;
    final isStreaming = _phaseStreamingByTab[tabIndex] ?? true;
    setState(() {
      _phaseStreamingByTab[tabIndex] = !isStreaming;
      if (isStreaming) {
        final provider = tabIndex == 0 ? promotedPhasesProvider : abandonedPhasesProvider;
        ref.read(provider).whenData((items) {
          _phaseSnapshotByTab[tabIndex] = List<Map<String, dynamic>>.from(items);
          _phaseSnapshotIdsByTab[tabIndex] = items.map((e) => e['phase'] as String? ?? '').toSet();
        });
      }
    });
  }
}