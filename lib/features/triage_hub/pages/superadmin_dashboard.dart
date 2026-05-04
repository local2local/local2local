import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// ignore: depend_on_referenced_packages
import 'package:intl/intl.dart';
import 'package:local2local/features/triage_hub/theme/admin_theme.dart';
import 'package:local2local/features/triage_hub/widgets/system_status_banner.dart';
import 'package:local2local/features/triage_hub/widgets/agent_bus_viewer.dart';
import 'package:local2local/features/triage_hub/providers/superadmin_providers.dart';
import 'package:local2local/features/triage_hub/data/superadmin_repository.dart';

class SuperadminDashboard extends ConsumerStatefulWidget {
  const SuperadminDashboard({super.key});

  @override
  ConsumerState<SuperadminDashboard> createState() => _SuperadminDashboardState();
}

class _SuperadminDashboardState extends ConsumerState<SuperadminDashboard>
    with SingleTickerProviderStateMixin {
  int _selectedPhaseHistoryIndex = 0;
  final TextEditingController _phaseSearchController = TextEditingController();
  String _phaseSearchQuery = '';

  // Phase History streaming/static mode state (per-tab: 0=PROMOTED, 1=ABANDONED)
  final Map<int, bool> _phaseStreamingByTab = {0: true, 1: true};
  final Map<int, List<Map<String, dynamic>>> _phaseSnapshotByTab = {0: [], 1: []};
  final Map<int, int> _newPhasesByTab = {0: 0, 1: 0};

  // Animation controller for pulsing LIVE indicator
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
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Superadmin Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showTestInjectModal(context),
                  icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                  label: const Text('Test Inject'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminColors.slateDark,
                    foregroundColor: AdminColors.emeraldGreen,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    side: BorderSide(
                      color: AdminColors.emeraldGreen.withValues(alpha: 0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            const SystemStatusBanner(),
            const SizedBox(height: 24),
            
            // Side-by-side panels
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left Panel: Agent Bus Viewer
                  const Expanded(child: AgentBusViewer()),
                  
                  const SizedBox(width: 24),
                  
                  // Right Panel: Phase History
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
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
                          // Phase History Search Bar
                          _buildPhaseSearchBar(),
                          const SizedBox(height: 16),
                          // Phase History Tabs
                          Row(
                            children: [
                              _buildPhaseHistoryTab('PROMOTED', 0),
                              _buildPhaseHistoryTab('ABANDONED', 1),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(color: AdminColors.borderDefault, height: 1),
                          const SizedBox(height: 16),
                          // Phase History List with independent scrolling
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

    // Track new phases when in static mode
    if (!isStreaming && snapshot.isNotEmpty) {
      promotedAsync.whenData((liveItems) {
        int newCount = 0;
        if (liveItems.length > snapshot.length) {
          newCount = liveItems.length - snapshot.length;
        }
        if (newCount != (_newPhasesByTab[tabIndex] ?? 0)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _newPhasesByTab[tabIndex] = newCount);
          });
        }
      });
    }

    // Determine which data to use
    final effectiveAsync = isStreaming
        ? promotedAsync
        : AsyncValue.data(snapshot);

    return effectiveAsync.when(
      data: (phases) {
        if (phases.isEmpty) {
          return const Center(
            child: Text('No history yet.', style: TextStyle(color: AdminColors.textSecondary)),
          );
        }
        final filteredPhases = _filterPhases(phases);
        if (filteredPhases.isEmpty && _phaseSearchQuery.isNotEmpty) {
          return Center(
            child: Text(
              'No results for "$_phaseSearchQuery"',
              style: const TextStyle(color: AdminColors.textSecondary),
            ),
          );
        }
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

    // Track new phases when in static mode
    if (!isStreaming && snapshot.isNotEmpty) {
      abandonedAsync.whenData((liveItems) {
        int newCount = 0;
        if (liveItems.length > snapshot.length) {
          newCount = liveItems.length - snapshot.length;
        }
        if (newCount != (_newPhasesByTab[tabIndex] ?? 0)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _newPhasesByTab[tabIndex] = newCount);
          });
        }
      });
    }

    // Determine which data to use
    final effectiveAsync = isStreaming
        ? abandonedAsync
        : AsyncValue.data(snapshot);

    return effectiveAsync.when(
      data: (phases) {
        if (phases.isEmpty) {
          return const Center(
            child: Text('No history yet.', style: TextStyle(color: AdminColors.textSecondary)),
          );
        }
        final filteredPhases = _filterPhases(phases);
        if (filteredPhases.isEmpty && _phaseSearchQuery.isNotEmpty) {
          return Center(
            child: Text(
              'No results for "$_phaseSearchQuery"',
              style: const TextStyle(color: AdminColors.textSecondary),
            ),
          );
        }
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
              Text(
                'Phase $phase',
                style: const TextStyle(
                  color: AdminColors.emeraldGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (commitSha.isNotEmpty) ...[
                const SizedBox(width: 12),
                _buildCommitShaBadge(commitSha),
              ],
              const SizedBox(width: 12),
              _buildOriginatorBadge(originator),
              const Spacer(),
              _buildStatusChip(status, isPromoted: true),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            summary,
            style: const TextStyle(color: AdminColors.textMuted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          Text(
            'Promoted at: ${_formatTimestamp(promotedAt)}',
            style: TextStyle(color: AdminColors.textSecondary.withValues(alpha: 0.7), fontSize: 11),
          ),
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
              Text(
                'Phase $phase',
                style: const TextStyle(
                  color: AdminColors.statusWarning,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (commitSha.isNotEmpty) ...[
                const SizedBox(width: 12),
                _buildCommitShaBadge(commitSha),
              ],
              const SizedBox(width: 12),
              _buildOriginatorBadge(originator),
              const Spacer(),
              _buildReasonChip(reason),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            summary,
            style: const TextStyle(color: AdminColors.textMuted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          Text(
            'Abandoned at: ${_formatTimestamp(abandonedAt)}',
            style: TextStyle(color: AdminColors.textSecondary.withValues(alpha: 0.7), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildOriginatorBadge(String originator) {
    Color badgeColor;
    switch (originator.toUpperCase()) {
      case 'MANUAL':
        badgeColor = AdminColors.statusInfo;
        break;
      case 'ASSISTED':
        badgeColor = AdminColors.emeraldGreen;
        break;
      case 'AUTO':
        badgeColor = AdminColors.statusWarning;
        break;
      case 'DREAM':
        badgeColor = const Color(0xFFA855F7); // Purple for dream
        break;
      default:
        badgeColor = AdminColors.textSecondary;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
      ),
      child: Text(
        originator.toUpperCase(),
        style: TextStyle(
          color: badgeColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCommitShaBadge(String fullSha) {
    final shortSha = fullSha.length >= 7 ? fullSha.substring(0, 7) : fullSha;
    
    return Tooltip(
      message: 'Click to copy SHA hash: $fullSha',
      child: InkWell(
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: fullSha));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Copied!', style: TextStyle(color: AdminColors.emeraldGreen)),
                backgroundColor: AdminColors.slateMedium,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 1),
                margin: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: AdminColors.slateDarkest,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AdminColors.borderDefault),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'SHA ',
                style: TextStyle(
                  color: AdminColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                shortSha,
                style: const TextStyle(
                  color: AdminColors.textSecondary,
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.copy, size: 12, color: AdminColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status, {required bool isPromoted}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AdminColors.emeraldGreen.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.emeraldGreen.withValues(alpha: 0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        style: const TextStyle(
          color: AdminColors.emeraldGreen,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildReasonChip(String reason) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AdminColors.textMuted.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.textMuted.withValues(alpha: 0.5)),
      ),
      child: Text(
        reason.toUpperCase(),
        style: const TextStyle(
          color: AdminColors.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      DateTime dt;
      if (timestamp is DateTime) {
        dt = timestamp.toUtc();
      } else if (timestamp is Timestamp) {
        // Handle Firestore Timestamp - convert to UTC first
        dt = timestamp.toDate().toUtc();
      } else {
        return timestamp.toString();
      }
      // Convert to Mountain Daylight Time (UTC-6 for MDT)
      // Alberta permanent MDT
      final mountainTime = dt.subtract(const Duration(hours: 6));
      return '${DateFormat('yyyy-MM-dd HH:mm').format(mountainTime)} MT';
    } catch (e) {
      return timestamp.toString();
    }
  }

  Widget _buildPhaseHistoryHeader() {
    final isStreaming = _phaseStreamingByTab[_selectedPhaseHistoryIndex] ?? true;
    final newCount = _newPhasesByTab[_selectedPhaseHistoryIndex] ?? 0;

    return Row(
      children: [
        const Text(
          'Phase History',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        _buildPhaseHistoryStreamingToggle(),
        if (!isStreaming && newCount > 0) ...[
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AdminColors.statusWarning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AdminColors.statusWarning.withValues(alpha: 0.3)),
            ),
            child: Text(
              '$newCount new since snapshot',
              style: const TextStyle(
                color: AdminColors.statusWarning,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPhaseHistoryStreamingToggle() {
    final isStreaming = _phaseStreamingByTab[_selectedPhaseHistoryIndex] ?? true;

    return GestureDetector(
      onTap: _togglePhaseHistoryStreamingMode,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isStreaming
              ? AdminColors.emeraldGreen.withValues(alpha: 0.15)
              : AdminColors.statusWarning.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isStreaming
                ? AdminColors.emeraldGreen.withValues(alpha: 0.5)
                : AdminColors.statusWarning.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isStreaming)
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) => Opacity(
                  opacity: _pulseAnimation.value,
                  child: const Text(
                    '●',
                    style: TextStyle(
                      color: AdminColors.emeraldGreen,
                      fontSize: 14,
                    ),
                  ),
                ),
              )
            else
              const Text(
                '⏸',
                style: TextStyle(
                  color: AdminColors.statusWarning,
                  fontSize: 14,
                ),
              ),
            const SizedBox(width: 6),
            Text(
              isStreaming ? 'LIVE' : 'PAUSED',
              style: TextStyle(
                color: isStreaming ? AdminColors.emeraldGreen : AdminColors.statusWarning,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _togglePhaseHistoryStreamingMode() {
    final tabIndex = _selectedPhaseHistoryIndex;
    final isCurrentlyStreaming = _phaseStreamingByTab[tabIndex] ?? true;

    setState(() {
      if (isCurrentlyStreaming) {
        // Switching from LIVE to PAUSED for this tab
        _phaseStreamingByTab[tabIndex] = false;
        // Copy current live list into snapshot for this tab
        final provider = tabIndex == 0 ? promotedPhasesProvider : abandonedPhasesProvider;
        final asyncValue = ref.read(provider);
        asyncValue.whenData((items) {
          _phaseSnapshotByTab[tabIndex] = List<Map<String, dynamic>>.from(items);
        });
        _newPhasesByTab[tabIndex] = 0;
      } else {
        // Switching from PAUSED to LIVE for this tab
        _phaseStreamingByTab[tabIndex] = true;
        _phaseSnapshotByTab[tabIndex] = [];
        _newPhasesByTab[tabIndex] = 0;
      }
    });
  }

  void _showTestInjectModal(BuildContext context) {
    final TextEditingController pathController = TextEditingController(text: 'lib/features/triage_hub/widgets/system_status_banner.dart');
    final TextEditingController reasonController = TextEditingController(text: "Update status string to 'AWAITING TELEMETRY' and color to orangeAccent.");

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AdminColors.slateDark,
        title: const Text('Manual Logic Injection', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pathController,
              decoration: const InputDecoration(labelText: 'Target Path', labelStyle: TextStyle(color: AdminColors.textSecondary)),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Instructions', labelStyle: TextStyle(color: AdminColors.textSecondary)),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(superadminRepositoryProvider).injectTestPayload(
                targetPath: pathController.text,
                instructions: reasonController.text,
              );
              if (mounted) {
                // ignore: use_build_context_synchronously
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('INJECT'),
          ),
        ],
      ),
    );
  }
}