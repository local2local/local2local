import 'dart:convert';

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
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AdminColors.slateDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
          child: _AgentBusInjectionModal(ref: ref),
        ),
      ),
    );
  }
}

class _AgentBusInjectionModal extends StatefulWidget {
  final WidgetRef ref;
  
  const _AgentBusInjectionModal({required this.ref});

  @override
  State<_AgentBusInjectionModal> createState() => _AgentBusInjectionModalState();
}

class _AgentBusInjectionModalState extends State<_AgentBusInjectionModal> {
  String _tenant = 'kaskflow';
  bool _shadow = false;
  int _selectedTab = 0;
  bool _isInjecting = false;

  // Structured form controllers
  late TextEditingController _correlationIdController;
  late TextEditingController _senderIdController;
  late TextEditingController _receiverIdController;
  late TextEditingController _hbrIdController;
  late TextEditingController _targetPathController;
  late TextEditingController _detailsController;
  late TextEditingController _rawJsonController;

  // Structured form state
  String _status = 'dispatched';
  String _messageType = 'REQUEST';
  String _priority = 'normal';
  String _intent = 'PROPOSE_LOGIC_CHANGE';

  static const _tenantOptions = [
    ('SYSTEM', 'system_status'),
    ('KASKFLOW', 'kaskflow'),
    ('MOONLITELY', 'moonlitely'),
  ];

  static const _busTypeOptions = [
    ('AGENT BUS', false),
    ('SHADOW BUS', true),
  ];

  static const _tabs = ['RAW JSON', 'STRUCTURED', 'TEMPLATES'];

  static const _statusOptions = ['dispatched', 'pending', 'intercepted'];
  
  static const _intentOptions = [
    'PROPOSE_LOGIC_CHANGE',
    'AUTONOMOUS_REMEDIATION',
    'LOG_RUNTIME_ERROR',
    'LOG_SAFETY_VIOLATION',
    'GET_FLEET_STATE',
    'GENERATE_PROFIT_REPORT',
    'PROCESS_FEEDBACK',
    'INITIATE_PAYOUT',
    'RECONCILE_LEDGER',
    'FOLD_CONTEXT',
  ];

  static const _receiverChips = [
    'EVOLUTION_WORKER',
    'SAFETY_WORKER',
    'ANALYTICS_WORKER',
    'INFRASTRUCTURE_WORKER',
    'TREASURY_WORKER',
  ];

  @override
  void initState() {
    super.initState();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _correlationIdController = TextEditingController(text: 'INJECT-$timestamp');
    _senderIdController = TextEditingController(text: 'SUPERADMIN_UI');
    _receiverIdController = TextEditingController(text: 'EVOLUTION_WORKER');
    _hbrIdController = TextEditingController(text: 'HBR-TEST-001');
    _targetPathController = TextEditingController();
    _detailsController = TextEditingController();
    _rawJsonController = TextEditingController();
  }

  @override
  void dispose() {
    _correlationIdController.dispose();
    _senderIdController.dispose();
    _receiverIdController.dispose();
    _hbrIdController.dispose();
    _targetPathController.dispose();
    _detailsController.dispose();
    _rawJsonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resolvedPath = widget.ref
        .read(superadminRepositoryProvider)
        .resolveCollectionPath(_tenant, shadow: _shadow);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Agent Bus Injection',
                style: TextStyle(
                  color: AdminColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: AdminColors.textSecondary),
                splashRadius: 20,
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Target selector row
          Row(
            children: [
              // Tenant dropdown
              Expanded(child: _buildTenantDropdown()),
              const SizedBox(width: 16),
              // Bus type dropdown
              Expanded(child: _buildBusTypeDropdown()),
            ],
          ),
          const SizedBox(height: 12),
          
          // Resolved path display
          Text(
            resolvedPath,
            style: const TextStyle(
              color: AdminColors.textMuted,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 20),
          
          // Tab bar
          _buildTabBar(),
          const SizedBox(height: 16),
          
          // Tab content
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AdminColors.slateDarkest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: _buildTabContent(),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Footer row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'CANCEL',
                  style: TextStyle(color: AdminColors.textSecondary),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isInjecting ? null : _handleInject,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminColors.emeraldGreen,
                  foregroundColor: AdminColors.slateDarkest,
                  disabledBackgroundColor: AdminColors.emeraldGreen.withValues(alpha: 0.3),
                  disabledForegroundColor: AdminColors.textMuted,
                ),
                child: _isInjecting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AdminColors.textMuted,
                        ),
                      )
                    : const Text('INJECT'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTenantDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AdminColors.slateDarkest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AdminColors.borderDefault),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _tenant,
          isExpanded: true,
          dropdownColor: AdminColors.slateDark,
          icon: const Icon(Icons.arrow_drop_down, color: AdminColors.textSecondary),
          style: const TextStyle(color: AdminColors.textPrimary, fontSize: 14),
          items: _tenantOptions.map((option) {
            return DropdownMenuItem<String>(
              value: option.$2,
              child: Text(option.$1),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) setState(() => _tenant = value);
          },
        ),
      ),
    );
  }

  Widget _buildBusTypeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AdminColors.slateDarkest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AdminColors.borderDefault),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<bool>(
          value: _shadow,
          isExpanded: true,
          dropdownColor: AdminColors.slateDark,
          icon: const Icon(Icons.arrow_drop_down, color: AdminColors.textSecondary),
          style: const TextStyle(color: AdminColors.textPrimary, fontSize: 14),
          items: _busTypeOptions.map((option) {
            return DropdownMenuItem<bool>(
              value: option.$2,
              child: Text(option.$1),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) setState(() => _shadow = value);
          },
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Row(
      children: List.generate(_tabs.length, (index) {
        final isSelected = _selectedTab == index;
        return GestureDetector(
          onTap: () => setState(() => _selectedTab = index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isSelected ? AdminColors.emeraldGreen : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Text(
              _tabs[index],
              style: TextStyle(
                color: isSelected ? AdminColors.textPrimary : AdminColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildRawJsonTab();
      case 1:
        return _buildStructuredTab();
      case 2:
        return _buildTemplatesTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildRawJsonTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _rawJsonController,
        maxLines: null,
        expands: true,
        style: const TextStyle(
          color: AdminColors.textPrimary,
          fontSize: 13,
          fontFamily: 'monospace',
        ),
        decoration: InputDecoration(
          hintText: '{\n  "status": "dispatched",\n  "payload": { ... }\n}',
          hintStyle: TextStyle(color: AdminColors.textMuted.withValues(alpha: 0.5)),
          filled: true,
          fillColor: AdminColors.slateDark,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AdminColors.borderDefault),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AdminColors.borderDefault),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AdminColors.emeraldGreen, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildStructuredTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Correlation ID
          _buildFormLabel('Correlation ID'),
          const SizedBox(height: 6),
          _buildTextField(_correlationIdController),
          const SizedBox(height: 16),

          // Status dropdown
          _buildFormLabel('Status'),
          const SizedBox(height: 6),
          _buildDropdown(
            value: _status,
            items: _statusOptions,
            onChanged: (v) => setState(() => _status = v!),
          ),
          const SizedBox(height: 16),

          // Sender ID
          _buildFormLabel('Sender ID'),
          const SizedBox(height: 6),
          _buildTextField(_senderIdController),
          const SizedBox(height: 16),

          // Receiver ID with quick-select chips
          _buildFormLabel('Receiver ID'),
          const SizedBox(height: 6),
          _buildTextField(_receiverIdController),
          const SizedBox(height: 8),
          _buildReceiverChips(),
          const SizedBox(height: 16),

          // Type segmented button
          _buildFormLabel('Type'),
          const SizedBox(height: 6),
          _buildSegmentedButton(
            value: _messageType,
            options: const ['REQUEST', 'RESPONSE', 'ERROR'],
            onChanged: (v) => setState(() => _messageType = v),
          ),
          const SizedBox(height: 16),

          // Priority segmented button
          _buildFormLabel('Priority'),
          const SizedBox(height: 6),
          _buildSegmentedButton(
            value: _priority,
            options: const ['normal', 'urgent', 'high', 'critical'],
            onChanged: (v) => setState(() => _priority = v),
          ),
          const SizedBox(height: 16),

          // Intent dropdown
          _buildFormLabel('Intent'),
          const SizedBox(height: 6),
          _buildDropdown(
            value: _intent,
            items: _intentOptions,
            onChanged: (v) => setState(() => _intent = v!),
          ),
          const SizedBox(height: 16),

          // HBR ID (conditional)
          if (_intent == 'PROPOSE_LOGIC_CHANGE') ...[
            _buildFormLabel('HBR ID'),
            const SizedBox(height: 6),
            _buildTextField(_hbrIdController),
            const SizedBox(height: 16),

            // Target Path (conditional)
            _buildFormLabel('Target Path'),
            const SizedBox(height: 6),
            _buildTextField(_targetPathController),
            const SizedBox(height: 16),
          ],

          // Details / Instructions
          _buildFormLabel('Details / Instructions'),
          const SizedBox(height: 6),
          _buildTextField(_detailsController, maxLines: 3),
        ],
      ),
    );
  }

  Widget _buildTemplatesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: _templates.map((template) => _buildTemplateCard(template)).toList(),
      ),
    );
  }

  Widget _buildTemplateCard(_InjectionTemplate template) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminColors.slateDarkest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AdminColors.borderDefault),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  template.name,
                  style: const TextStyle(
                    color: AdminColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  template.description,
                  style: const TextStyle(
                    color: AdminColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: () => _useTemplate(template),
            style: OutlinedButton.styleFrom(
              foregroundColor: AdminColors.emeraldGreen,
              side: const BorderSide(color: AdminColors.emeraldGreen),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text(
              'USE TEMPLATE',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  void _useTemplate(_InjectionTemplate template) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final json = template.jsonTemplate.replaceAll('<timestamp>', timestamp.toString());
    
    setState(() {
      _rawJsonController.text = json;
      _selectedTab = 0; // Switch to RAW JSON tab
    });
  }

  static final List<_InjectionTemplate> _templates = [
    _InjectionTemplate(
      name: 'Propose Logic Change',
      description: 'Submit an autonomous code change proposal to the Evolution Worker',
      jsonTemplate: '''{
  "correlation_id": "INJECT-<timestamp>",
  "status": "dispatched",
  "provenance": { "sender_id": "SUPERADMIN_UI", "receiver_id": "EVOLUTION_WORKER" },
  "control": { "type": "REQUEST", "priority": "normal" },
  "payload": { "manifest": { "intent": "PROPOSE_LOGIC_CHANGE", "agentId": "SUPERADMIN_UI", "hbrId": "HBR-TEST-001", "targetPath": "functions/src/logic/evolution.ts", "proposedLogic": "// proposed changes here" } }
}''',
    ),
    _InjectionTemplate(
      name: 'Autonomous Remediation',
      description: 'Trigger self-healing protocol for a detected runtime error',
      jsonTemplate: '''{
  "correlation_id": "INJECT-<timestamp>",
  "status": "dispatched",
  "provenance": { "sender_id": "SUPERADMIN_UI", "receiver_id": "EVOLUTION_WORKER" },
  "control": { "type": "REQUEST", "priority": "urgent" },
  "payload": { "manifest": { "intent": "AUTONOMOUS_REMEDIATION", "error": "Describe the error here", "stackTrace": "", "platform": "web" } }
}''',
    ),
    _InjectionTemplate(
      name: 'Log Safety Violation',
      description: 'Report a critical safety event to the Safety Worker',
      jsonTemplate: '''{
  "correlation_id": "INJECT-<timestamp>",
  "status": "dispatched",
  "provenance": { "sender_id": "SUPERADMIN_UI", "receiver_id": "SAFETY_WORKER" },
  "control": { "type": "REQUEST", "priority": "urgent" },
  "payload": { "manifest": { "intent": "LOG_SAFETY_VIOLATION", "severity": "critical", "details": "Describe the violation here" } }
}''',
    ),
    _InjectionTemplate(
      name: 'Generate Profit Report',
      description: 'Request a profit summary from the Analytics Worker',
      jsonTemplate: '''{
  "correlation_id": "INJECT-<timestamp>",
  "status": "dispatched",
  "provenance": { "sender_id": "SUPERADMIN_UI", "receiver_id": "ANALYTICS_WORKER" },
  "control": { "type": "REQUEST", "priority": "normal" },
  "payload": { "manifest": { "intent": "GENERATE_PROFIT_REPORT" } }
}''',
    ),
    _InjectionTemplate(
      name: 'Get Fleet State',
      description: 'Request current fleet status from the Dispatch Worker',
      jsonTemplate: '''{
  "correlation_id": "INJECT-<timestamp>",
  "status": "dispatched",
  "provenance": { "sender_id": "SUPERADMIN_UI", "receiver_id": "DISPATCH_WORKER" },
  "control": { "type": "REQUEST", "priority": "normal" },
  "payload": { "manifest": { "intent": "GET_FLEET_STATE", "filterJurisdiction": "AB" } }
}''',
    ),
    _InjectionTemplate(
      name: 'Fold Context',
      description: 'Trigger context folding for an underperforming agent',
      jsonTemplate: '''{
  "correlation_id": "INJECT-<timestamp>",
  "status": "dispatched",
  "provenance": { "sender_id": "SUPERADMIN_UI", "receiver_id": "INFRASTRUCTURE_WORKER" },
  "control": { "type": "REQUEST", "priority": "normal" },
  "payload": { "manifest": { "intent": "FOLD_CONTEXT", "targetAgentId": "AGENT_ID_HERE", "correlationId": "" } }
}''',
    ),
  ];

  Widget _buildFormLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: AdminColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: AdminColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        filled: true,
        fillColor: AdminColors.slateDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AdminColors.borderDefault),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AdminColors.borderDefault),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AdminColors.emeraldGreen, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AdminColors.slateDark,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AdminColors.borderDefault),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: AdminColors.slateDark,
          icon: const Icon(Icons.arrow_drop_down, color: AdminColors.textSecondary),
          style: const TextStyle(color: AdminColors.textPrimary, fontSize: 14),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSegmentedButton({
    required String value,
    required List<String> options,
    required void Function(String) onChanged,
  }) {
    return Row(
      children: options.map((option) {
        final isSelected = value == option;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(option),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AdminColors.emeraldGreen.withValues(alpha: 0.15)
                    : AdminColors.slateDark,
                border: Border.all(
                  color: isSelected
                      ? AdminColors.emeraldGreen.withValues(alpha: 0.5)
                      : AdminColors.borderDefault,
                ),
                borderRadius: BorderRadius.horizontal(
                  left: option == options.first ? const Radius.circular(6) : Radius.zero,
                  right: option == options.last ? const Radius.circular(6) : Radius.zero,
                ),
              ),
              child: Center(
                child: Text(
                  option.toUpperCase(),
                  style: TextStyle(
                    color: isSelected ? AdminColors.emeraldGreen : AdminColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildReceiverChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _receiverChips.map((receiver) {
        final isActive = _receiverIdController.text == receiver;
        return GestureDetector(
          onTap: () => setState(() => _receiverIdController.text = receiver),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isActive
                  ? AdminColors.emeraldGreen.withValues(alpha: 0.15)
                  : AdminColors.slateMedium,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              receiver,
              style: TextStyle(
                color: isActive ? AdminColors.emeraldGreen : AdminColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _handleInject() async {
    setState(() => _isInjecting = true);

    try {
      Map<String, dynamic> payload;

      if (_selectedTab == 0) {
        // RAW JSON tab
        final jsonText = _rawJsonController.text.trim();
        if (jsonText.isEmpty) {
          _showSnackbar('Please enter JSON payload', isError: true);
          return;
        }
        try {
          payload = _parseJson(jsonText);
        } catch (e) {
          _showSnackbar('Invalid JSON: $e', isError: true);
          return;
        }
      } else if (_selectedTab == 1) {
        // STRUCTURED tab
        payload = _buildStructuredPayload();
      } else {
        // TEMPLATES tab - not implemented yet
        _showSnackbar('Templates not yet implemented', isError: true);
        return;
      }

      await widget.ref.read(superadminRepositoryProvider).injectPayload(
        tenant: _tenant,
        shadow: _shadow,
        payload: payload,
      );

      if (mounted) {
        _showSnackbar('Payload injected successfully');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('Injection failed: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isInjecting = false);
      }
    }
  }

  Map<String, dynamic> _parseJson(String jsonText) {
    final decoded = jsonDecode(jsonText);
    if (decoded is! Map) {
      throw const FormatException('JSON must be an object');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Map<String, dynamic> _buildStructuredPayload() {
    final manifest = <String, dynamic>{
      'intent': _intent,
      'agentId': _senderIdController.text,
    };

    // Add conditional fields for PROPOSE_LOGIC_CHANGE
    if (_intent == 'PROPOSE_LOGIC_CHANGE') {
      manifest['hbrId'] = _hbrIdController.text;
      if (_targetPathController.text.isNotEmpty) {
        manifest['targetPath'] = _targetPathController.text;
      }
    }

    // Add details if provided
    if (_detailsController.text.isNotEmpty) {
      manifest['details'] = _detailsController.text;
    }

    return {
      'correlation_id': _correlationIdController.text,
      'status': _status,
      'sender_id': _senderIdController.text,
      'receiver_id': _receiverIdController.text,
      'type': _messageType,
      'priority': _priority,
      'payload': {
        'manifest': manifest,
      },
    };
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: isError ? AdminColors.rubyRed : AdminColors.emeraldGreen,
          ),
        ),
        backgroundColor: AdminColors.slateMedium,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isError ? 4 : 2),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _InjectionTemplate {
  final String name;
  final String description;
  final String jsonTemplate;

  const _InjectionTemplate({
    required this.name,
    required this.description,
    required this.jsonTemplate,
  });
}