import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:local2local/features/triage_hub/theme/admin_theme.dart';
import 'package:local2local/features/triage_hub/providers/superadmin_providers.dart';

enum AgentBusSortField { documentId, correlationId, sender, receiver, processedAt }

enum AgentBusStatusFilter { all, pending, dispatched, intercepted }

class AgentBusViewer extends ConsumerStatefulWidget {
  const AgentBusViewer({super.key});

  @override
  ConsumerState<AgentBusViewer> createState() => _AgentBusViewerState();
}

class _AgentBusViewerState extends ConsumerState<AgentBusViewer>
    with SingleTickerProviderStateMixin {
  int _selectedTenantIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  AgentBusSortField _sortField = AgentBusSortField.documentId;
  bool _sortAscending = true;
  AgentBusStatusFilter _statusFilter = AgentBusStatusFilter.all;
  bool _matchCorrelationId = false;
  String? _activeCorrelationId;
  final Set<String> _expandedCards = {};

  // Streaming/Static mode state (per-tab)
  final Map<int, bool> _isStreamingByTab = {0: true, 1: true, 2: true};
  final Map<int, List<Map<String, dynamic>>> _snapshotByTab = {0: [], 1: [], 2: []};
  final Map<int, int> _newDocsByTab = {0: 0, 1: 0, 2: 0};
  final Map<int, int> _currentPageByTab = {0: 0, 1: 0, 2: 0};
  static const int _pageSize = 50;

  // Timestamp range filter (per-tab, only active in static mode)
  final Map<int, DateTime?> _filterFromByTab = {0: null, 1: null, 2: null};
  final Map<int, DateTime?> _filterToByTab = {0: null, 1: null, 2: null};
  final Map<int, String?> _activeTimePresetByTab = {0: null, 1: null, 2: null};

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
    _searchController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  AsyncValue<List<Map<String, dynamic>>> _getCurrentBusProvider() {
    switch (_selectedTenantIndex) {
      case 0:
        return ref.watch(systemAgentBusProvider);
      case 1:
        return ref.watch(kaskflowAgentBusProvider);
      case 2:
        return ref.watch(moonlitelyAgentBusProvider);
      default:
        return ref.watch(systemAgentBusProvider);
    }
  }

  List<Map<String, dynamic>> _filterAndSortItems(List<Map<String, dynamic>> items) {
    var filtered = items.where((item) {
      // Status filter
      if (_statusFilter != AgentBusStatusFilter.all) {
        final status = (item['status']?.toString() ?? '').toLowerCase();
        if (status != _statusFilter.name) return false;
      }

      // Correlation ID match filter
      if (_matchCorrelationId && _activeCorrelationId != null) {
        final correlationId = item['correlation_id']?.toString() ?? '';
        if (correlationId != _activeCorrelationId) return false;
      }

      // Timestamp range filter (only in static mode)
      final isStreaming = _isStreamingByTab[_selectedTenantIndex] ?? true;
      final filterFrom = _filterFromByTab[_selectedTenantIndex];
      final filterTo = _filterToByTab[_selectedTenantIndex];
      if (!isStreaming && (filterFrom != null || filterTo != null)) {
        final itemTimestamp = _extractItemTimestamp(item);
        if (itemTimestamp == null) return false;
        
        if (filterFrom != null && itemTimestamp.isBefore(filterFrom)) {
          return false;
        }
        if (filterTo != null && itemTimestamp.isAfter(filterTo)) {
          return false;
        }
      }

      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final documentId = (item['id']?.toString() ?? '').toLowerCase();
        final correlationId = (item['correlation_id']?.toString() ?? '').toLowerCase();
        final provenance = item['provenance'] as Map<String, dynamic>? ?? {};
        final senderId = (provenance['sender_id']?.toString() ?? '').toLowerCase();
        final receiverId = (provenance['receiver_id']?.toString() ?? '').toLowerCase();
        final control = item['control'] as Map<String, dynamic>? ?? {};
        final controlType = (control['type']?.toString() ?? '').toLowerCase();
        final priority = (control['priority']?.toString() ?? '').toLowerCase();
        final status = (item['status']?.toString() ?? '').toLowerCase();
        final telemetry = item['telemetry'] as Map<String, dynamic>? ?? {};
        final processedAt = telemetry['processed_at'];
        String timestamp = '';
        if (processedAt != null) {
          if (processedAt is Timestamp) {
            timestamp = DateFormat('yyyy-MM-dd HH:mm').format(processedAt.toDate()).toLowerCase();
          } else if (processedAt is String) {
            timestamp = processedAt.toLowerCase();
          }
        }

        if (!documentId.contains(query) &&
            !correlationId.contains(query) &&
            !senderId.contains(query) &&
            !receiverId.contains(query) &&
            !controlType.contains(query) &&
            !priority.contains(query) &&
            !status.contains(query) &&
            !timestamp.contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();

    // Sort
    filtered.sort((a, b) {
      int comparison;
      switch (_sortField) {
        case AgentBusSortField.documentId:
          comparison = (a['id']?.toString() ?? '').compareTo(b['id']?.toString() ?? '');
        case AgentBusSortField.correlationId:
          comparison = (a['correlation_id']?.toString() ?? '').compareTo(b['correlation_id']?.toString() ?? '');
        case AgentBusSortField.sender:
          final aProvenance = a['provenance'] as Map<String, dynamic>? ?? {};
          final bProvenance = b['provenance'] as Map<String, dynamic>? ?? {};
          comparison = (aProvenance['sender_id']?.toString() ?? '').compareTo(bProvenance['sender_id']?.toString() ?? '');
        case AgentBusSortField.receiver:
          final aProvenance = a['provenance'] as Map<String, dynamic>? ?? {};
          final bProvenance = b['provenance'] as Map<String, dynamic>? ?? {};
          comparison = (aProvenance['receiver_id']?.toString() ?? '').compareTo(bProvenance['receiver_id']?.toString() ?? '');
        case AgentBusSortField.processedAt:
          final aTime = a['processed_at'];
          final bTime = b['processed_at'];
          if (aTime == null && bTime == null) {
            comparison = 0;
          } else if (aTime == null) {
            comparison = 1;
          } else if (bTime == null) {
            comparison = -1;
          } else {
            comparison = aTime.toString().compareTo(bTime.toString());
          }
      }
      return _sortAscending ? comparison : -comparison;
    });

    return filtered;
  }

  /// Extracts the timestamp from an item for filtering.
  /// Uses telemetry.processed_at if present, otherwise created_at.
  DateTime? _extractItemTimestamp(Map<String, dynamic> item) {
    final telemetry = item['telemetry'] as Map<String, dynamic>? ?? {};
    final processedAt = telemetry['processed_at'];
    final createdAt = item['created_at'];

    // Try processed_at first
    if (processedAt != null) {
      final dt = _parseTimestampValue(processedAt);
      if (dt != null) return dt;
    }

    // Fall back to created_at
    if (createdAt != null) {
      return _parseTimestampValue(createdAt);
    }

    return null;
  }

  /// Parses a timestamp value to DateTime.
  /// Handles Firestore Timestamp and ISO 8601 strings.
  DateTime? _parseTimestampValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    } else if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  String _getTenantCollectionPath() {
    switch (_selectedTenantIndex) {
      case 0:
        return 'artifacts/system_status/public/data/agent_bus';
      case 1:
        return 'artifacts/local2local_kaskflow/public/data/agent_bus';
      case 2:
        return 'artifacts/local2local_moonlitely/public/data/agent_bus';
      default:
        return 'artifacts/system_status/public/data/agent_bus';
    }
  }

  void _onDeleteCorrelationId() {
    final correlationIdController = TextEditingController(
      text: _activeCorrelationId ?? '',
    );

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AdminColors.slateDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delete by Correlation ID',
                  style: TextStyle(
                    color: AdminColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Enter the correlation ID to delete all matching items:',
                  style: TextStyle(
                    color: AdminColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: correlationIdController,
                  style: const TextStyle(color: AdminColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Correlation ID',
                    filled: true,
                    fillColor: AdminColors.slateDarkest,
                    hintStyle: const TextStyle(color: AdminColors.textMuted, fontSize: 14),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: AdminColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        final correlationId = correlationIdController.text.trim();
                        if (correlationId.isEmpty) {
                          Navigator.of(dialogContext).pop();
                          return;
                        }
                        Navigator.of(dialogContext).pop();
                        await _executeDeleteByCorrelationId(correlationId);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminColors.rubyRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Delete All Matching',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) => correlationIdController.dispose());
  }

  Future<void> _executeDeleteByCorrelationId(String correlationId) async {
    try {
      final collectionPath = _getTenantCollectionPath();
      final firestore = FirebaseFirestore.instance;
      
      final querySnapshot = await firestore
          .collection(collectionPath)
          .where('correlation_id', isEqualTo: correlationId)
          .get();

      if (querySnapshot.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No items found with correlation ID: $correlationId', style: const TextStyle(color: AdminColors.statusWarning)),
              backgroundColor: AdminColors.statusWarning,
            ),
          );
        }
        return;
      }

      final batch = firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted all items with correlation ID: $correlationId', style: const TextStyle(color: AdminColors.emeraldGreen)),
            backgroundColor: AdminColors.emeraldGreen,
          ),
        );

        // Clear the active correlation ID if it was the one deleted
        if (_activeCorrelationId == correlationId) {
          setState(() {
            _activeCorrelationId = null;
            _matchCorrelationId = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e', style: const TextStyle(color: AdminColors.rubyRed)),
            backgroundColor: AdminColors.rubyRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final busAsync = _getCurrentBusProvider();
    final isStreaming = _isStreamingByTab[_selectedTenantIndex] ?? true;
    final staticSnapshot = _snapshotByTab[_selectedTenantIndex] ?? [];
    final newDocsSinceSnapshot = _newDocsByTab[_selectedTenantIndex] ?? 0;

    // Track new docs when in static mode (compare by list length)
    if (!isStreaming && staticSnapshot.isNotEmpty) {
      busAsync.whenData((liveItems) {
        final newCount = liveItems.length > staticSnapshot.length
            ? liveItems.length - staticSnapshot.length
            : 0;
        if (newCount != newDocsSinceSnapshot) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _newDocsByTab[_selectedTenantIndex] = newCount);
          });
        }
      });
    }

    // Determine which data to use
    final effectiveBusAsync = isStreaming
        ? busAsync
        : AsyncValue.data(staticSnapshot);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.slateDark.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tenant Selector Tabs
          Row(
            children: [
              _buildTenantTab('SYSTEM', 0),
              _buildTenantTab('KASKFLOW', 1),
              _buildTenantTab('MOONLITELY', 2),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AdminColors.borderDefault, height: 1),
          const SizedBox(height: 16),
          
          // Toolbar
          _buildToolbar(),
          const SizedBox(height: 16),
          
          // Content Area
          Expanded(
            child: _buildContent(effectiveBusAsync),
          ),
        ],
      ),
    );
  }

  Widget _buildTenantTab(String label, int index) {
    final isSelected = _selectedTenantIndex == index;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedTenantIndex = index;
        // Per-tab state is preserved; no need to reset _currentPage
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AdminColors.emeraldGreen : Colors.transparent,
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

  Widget _buildToolbar() {
    final isStreaming = _isStreamingByTab[_selectedTenantIndex] ?? true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mode Control Row (above search bar)
        _buildModeControlRow(),
        const SizedBox(height: 12),
        
        // Timestamp Filter Row (only in static mode)
        if (!isStreaming) ...[
          _buildTimestampFilterRow(),
          const SizedBox(height: 12),
        ],
        
        // Search Bar with Delete button
        Row(
          children: [
            Expanded(child: _buildSearchBar()),
            const SizedBox(width: 12),
            _buildDeleteCorrelationIdButton(),
          ],
        ),
        const SizedBox(height: 12),
        
        // Filter Row
        _buildFilterRow(),
      ],
    );
  }

  Widget _buildModeControlRow() {
    final isStreaming = _isStreamingByTab[_selectedTenantIndex] ?? true;
    final newDocsSinceSnapshot = _newDocsByTab[_selectedTenantIndex] ?? 0;
    return Row(
      children: [
        // LIVE/PAUSED toggle button
        _buildStreamingToggleButton(),
        const SizedBox(width: 12),
        // New docs badge and Refresh button (only visible when paused)
        if (!isStreaming) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AdminColors.statusWarning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AdminColors.statusWarning.withValues(alpha: 0.3)),
            ),
            child: Text(
              '$newDocsSinceSnapshot new since snapshot',
              style: const TextStyle(
                color: AdminColors.statusWarning,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _refreshSnapshot,
            icon: const Icon(Icons.refresh, size: 18),
            color: AdminColors.statusWarning,
            style: IconButton.styleFrom(
              backgroundColor: AdminColors.statusWarning.withValues(alpha: 0.15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: BorderSide(color: AdminColors.statusWarning.withValues(alpha: 0.3)),
              ),
              minimumSize: const Size(36, 36),
              padding: EdgeInsets.zero,
            ),
            tooltip: 'Refresh snapshot',
          ),
        ],
      ],
    );
  }

  Widget _buildTimestampFilterRow() {
    final filterFrom = _filterFromByTab[_selectedTenantIndex];
    final filterTo = _filterToByTab[_selectedTenantIndex];
    final hasActiveFilter = filterFrom != null || filterTo != null;
    
    return Row(
      children: [
        // Quick preset chips in horizontal scroll
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTimePresetChip('Last 15 min', 'last15min', const Duration(minutes: 15)),
                const SizedBox(width: 8),
                _buildTimePresetChip('Last hour', 'lastHour', const Duration(hours: 1)),
                const SizedBox(width: 8),
                _buildTimePresetChip('Last 24h', 'last24h', const Duration(hours: 24)),
                const SizedBox(width: 8),
                _buildCustomTimeChip(),
              ],
            ),
          ),
        ),
        // Clear button (only visible when filter is active)
        if (hasActiveFilter) ...[
          const SizedBox(width: 8),
          IconButton(
            onPressed: _clearTimestampFilter,
            icon: const Icon(Icons.close, size: 18),
            color: AdminColors.textMuted,
            style: IconButton.styleFrom(
              minimumSize: const Size(32, 32),
              padding: EdgeInsets.zero,
            ),
            tooltip: 'Clear filter',
          ),
        ],
      ],
    );
  }

  Widget _buildTimePresetChip(String label, String presetKey, Duration duration) {
    final activeTimePreset = _activeTimePresetByTab[_selectedTenantIndex];
    final isActive = activeTimePreset == presetKey;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filterFromByTab[_selectedTenantIndex] = DateTime.now().subtract(duration);
          _filterToByTab[_selectedTenantIndex] = null;
          _activeTimePresetByTab[_selectedTenantIndex] = presetKey;
          _currentPageByTab[_selectedTenantIndex] = 0;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AdminColors.emeraldGreen.withValues(alpha: 0.15)
              : AdminColors.slateDark,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive
                ? AdminColors.emeraldGreen.withValues(alpha: 0.5)
                : AdminColors.borderDefault,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? AdminColors.emeraldGreen : AdminColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomTimeChip() {
    final activeTimePreset = _activeTimePresetByTab[_selectedTenantIndex];
    final filterFrom = _filterFromByTab[_selectedTenantIndex];
    final filterTo = _filterToByTab[_selectedTenantIndex];
    final isActive = activeTimePreset == null && (filterFrom != null || filterTo != null);
    return GestureDetector(
      onTap: _showCustomTimeRangeDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AdminColors.emeraldGreen.withValues(alpha: 0.15)
              : AdminColors.slateDark,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive
                ? AdminColors.emeraldGreen.withValues(alpha: 0.5)
                : AdminColors.borderDefault,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.date_range,
              size: 14,
              color: isActive ? AdminColors.emeraldGreen : AdminColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              isActive ? _formatCustomRange() : 'Custom',
              style: TextStyle(
                color: isActive ? AdminColors.emeraldGreen : AdminColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCustomRange() {
    final dateFormat = DateFormat('MM/dd HH:mm');
    final filterFrom = _filterFromByTab[_selectedTenantIndex];
    final filterTo = _filterToByTab[_selectedTenantIndex];
    final fromStr = filterFrom != null ? dateFormat.format(filterFrom) : '—';
    final toStr = filterTo != null ? dateFormat.format(filterTo) : 'now';
    return '$fromStr - $toStr';
  }

  void _clearTimestampFilter() {
    setState(() {
      _filterFromByTab[_selectedTenantIndex] = null;
      _filterToByTab[_selectedTenantIndex] = null;
      _activeTimePresetByTab[_selectedTenantIndex] = null;
      _currentPageByTab[_selectedTenantIndex] = 0;
    });
  }

  void _showCustomTimeRangeDialog() {
    DateTime? tempFrom = _filterFromByTab[_selectedTenantIndex];
    DateTime? tempTo = _filterToByTab[_selectedTenantIndex];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: AdminColors.slateDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Custom Time Range',
                    style: TextStyle(
                      color: AdminColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // From DateTime Picker
                  _buildDateTimePickerField(
                    label: 'From',
                    value: tempFrom,
                    onChanged: (dt) => setDialogState(() => tempFrom = dt),
                  ),
                  const SizedBox(height: 16),
                  // To DateTime Picker
                  _buildDateTimePickerField(
                    label: 'To',
                    value: tempTo,
                    onChanged: (dt) => setDialogState(() => tempTo = dt),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: AdminColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          setState(() {
                            _filterFromByTab[_selectedTenantIndex] = tempFrom;
                            _filterToByTab[_selectedTenantIndex] = tempTo;
                            _activeTimePresetByTab[_selectedTenantIndex] = null; // Clear preset when using custom
                            _currentPageByTab[_selectedTenantIndex] = 0;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminColors.emeraldGreen,
                          foregroundColor: AdminColors.slateDarkest,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Apply',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimePickerField({
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime?> onChanged,
  }) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final timeFormat = DateFormat('HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AdminColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Date picker button
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: value ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                    builder: (context, child) => Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.dark(
                          primary: AdminColors.emeraldGreen,
                          onPrimary: AdminColors.slateDarkest,
                          surface: AdminColors.slateDark,
                          onSurface: AdminColors.textPrimary,
                        ),
                        dialogTheme: DialogThemeData(
                          backgroundColor: AdminColors.slateDark,
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  if (date != null) {
                    final existingTime = value ?? DateTime.now();
                    onChanged(DateTime(
                      date.year,
                      date.month,
                      date.day,
                      existingTime.hour,
                      existingTime.minute,
                    ));
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: AdminColors.slateDarkest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AdminColors.borderDefault),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: AdminColors.textMuted),
                      const SizedBox(width: 8),
                      Text(
                        value != null ? dateFormat.format(value) : 'Select date',
                        style: TextStyle(
                          color: value != null ? AdminColors.textPrimary : AdminColors.textMuted,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Time picker button
            GestureDetector(
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: value != null
                      ? TimeOfDay.fromDateTime(value)
                      : TimeOfDay.now(),
                  builder: (context, child) => Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: AdminColors.emeraldGreen,
                        onPrimary: AdminColors.slateDarkest,
                        surface: AdminColors.slateDark,
                        onSurface: AdminColors.textPrimary,
                      ),
                      dialogTheme: DialogThemeData(
                        backgroundColor: AdminColors.slateDark,
                      ),
                    ),
                    child: child!,
                  ),
                );
                if (time != null) {
                  final existingDate = value ?? DateTime.now();
                  onChanged(DateTime(
                    existingDate.year,
                    existingDate.month,
                    existingDate.day,
                    time.hour,
                    time.minute,
                  ));
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: AdminColors.slateDarkest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AdminColors.borderDefault),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, size: 16, color: AdminColors.textMuted),
                    const SizedBox(width: 8),
                    Text(
                      value != null ? timeFormat.format(value) : '00:00',
                      style: TextStyle(
                        color: value != null ? AdminColors.textPrimary : AdminColors.textMuted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Clear button for this field
            if (value != null) ...[
              const SizedBox(width: 4),
              IconButton(
                onPressed: () => onChanged(null),
                icon: const Icon(Icons.close, size: 16),
                color: AdminColors.textMuted,
                style: IconButton.styleFrom(
                  minimumSize: const Size(32, 32),
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildStreamingToggleButton() {
    final isStreaming = _isStreamingByTab[_selectedTenantIndex] ?? true;
    return GestureDetector(
      onTap: _toggleStreamingMode,
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

  void _toggleStreamingMode() {
    final busAsync = _getCurrentBusProvider();
    final isStreaming = _isStreamingByTab[_selectedTenantIndex] ?? true;
    setState(() {
      if (isStreaming) {
        // Switching from LIVE to PAUSED
        _isStreamingByTab[_selectedTenantIndex] = false;
        // Copy current live list into static snapshot
        busAsync.whenData((items) {
          _snapshotByTab[_selectedTenantIndex] = List<Map<String, dynamic>>.from(items);
        });
        _newDocsByTab[_selectedTenantIndex] = 0;
        _currentPageByTab[_selectedTenantIndex] = 0;
      } else {
        // Switching from PAUSED to LIVE
        _isStreamingByTab[_selectedTenantIndex] = true;
        _snapshotByTab[_selectedTenantIndex] = [];
        _newDocsByTab[_selectedTenantIndex] = 0;
        _currentPageByTab[_selectedTenantIndex] = 0;
        // Reset timestamp filter when switching to streaming mode
        _filterFromByTab[_selectedTenantIndex] = null;
        _filterToByTab[_selectedTenantIndex] = null;
        _activeTimePresetByTab[_selectedTenantIndex] = null;
      }
    });
  }

  void _refreshSnapshot() {
    final busAsync = _getCurrentBusProvider();
    setState(() {
      busAsync.whenData((items) {
        _snapshotByTab[_selectedTenantIndex] = List<Map<String, dynamic>>.from(items);
      });
      _newDocsByTab[_selectedTenantIndex] = 0;
      _currentPageByTab[_selectedTenantIndex] = 0;
    });
  }

  Widget _buildSearchBar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AdminColors.slateDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AdminColors.borderDefault),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: AdminColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search by ID, priority, timestamp...',
          hintStyle: const TextStyle(color: AdminColors.textMuted, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: AdminColors.textMuted, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, color: AdminColors.textMuted, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _currentPageByTab[_selectedTenantIndex] = 0;
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (value) => setState(() {
          _searchQuery = value;
          _currentPageByTab[_selectedTenantIndex] = 0;
        }),
      ),
    );
  }

  Widget _buildFilterRow() {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Sort Dropdown with Ascending/Descending Toggle
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSortDropdown(),
            const SizedBox(width: 4),
            _buildSortDirectionButton(),
          ],
        ),
        
        // Status Filter Buttons
        _buildStatusFilterButtons(),
        
        // Match Correlation ID Toggle
        _buildCorrelationIdToggle(),
        
        // Correlation ID Chip (if active)
        if (_matchCorrelationId && _activeCorrelationId != null)
          _buildCorrelationIdChip(),
      ],
    );
  }

  Widget _buildSortDropdown() {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AdminColors.slateDark,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AdminColors.borderDefault),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AgentBusSortField>(
          value: _sortField,
          dropdownColor: AdminColors.slateDark,
          style: const TextStyle(color: AdminColors.textPrimary, fontSize: 13),
          icon: const Icon(Icons.arrow_drop_down, color: AdminColors.textSecondary, size: 20),
          items: const [
            DropdownMenuItem(value: AgentBusSortField.documentId, child: Text('Document ID')),
            DropdownMenuItem(value: AgentBusSortField.correlationId, child: Text('Correlation ID')),
            DropdownMenuItem(value: AgentBusSortField.sender, child: Text('Sender')),
            DropdownMenuItem(value: AgentBusSortField.receiver, child: Text('Receiver')),
            DropdownMenuItem(value: AgentBusSortField.processedAt, child: Text('Processed At')),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _sortField = value;
                _currentPageByTab[_selectedTenantIndex] = 0;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildSortDirectionButton() {
    return IconButton(
      onPressed: () => setState(() => _sortAscending = !_sortAscending),
      icon: Icon(
        _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
        color: AdminColors.textSecondary,
        size: 18,
      ),
      style: IconButton.styleFrom(
        backgroundColor: AdminColors.slateDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: AdminColors.borderDefault),
        ),
        minimumSize: const Size(36, 36),
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildStatusFilterButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStatusButton('All', AgentBusStatusFilter.all),
        const SizedBox(width: 4),
        _buildStatusButton('pending', AgentBusStatusFilter.pending),
        const SizedBox(width: 4),
        _buildStatusButton('dispatched', AgentBusStatusFilter.dispatched),
        const SizedBox(width: 4),
        _buildStatusButton('intercepted', AgentBusStatusFilter.intercepted),
      ],
    );
  }

  Widget _buildStatusButton(String label, AgentBusStatusFilter filter) {
    final isActive = _statusFilter == filter;
    return GestureDetector(
      onTap: () => setState(() {
        _statusFilter = filter;
        _currentPageByTab[_selectedTenantIndex] = 0;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive 
              ? AdminColors.emeraldGreen.withValues(alpha: 0.15)
              : AdminColors.slateDark,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? AdminColors.emeraldGreen.withValues(alpha: 0.5) : AdminColors.borderDefault,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? AdminColors.emeraldGreen : AdminColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildCorrelationIdToggle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Match Correlation ID',
          style: TextStyle(color: AdminColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 24,
          child: Switch(
            value: _matchCorrelationId,
            onChanged: (value) {
              setState(() {
                _matchCorrelationId = value;
                if (!value) {
                  _activeCorrelationId = null;
                }
              });
            },
            activeColor: AdminColors.emeraldGreen,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }

  Widget _buildCorrelationIdChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AdminColors.statusInfo.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.statusInfo.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _activeCorrelationId ?? '',
            style: const TextStyle(
              color: AdminColors.statusInfo,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () {
              setState(() {
                _activeCorrelationId = null;
                _matchCorrelationId = false;
              });
            },
            child: const Icon(
              Icons.close,
              color: AdminColors.statusInfo,
              size: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteCorrelationIdButton() {
    return OutlinedButton(
      onPressed: _onDeleteCorrelationId,
      style: OutlinedButton.styleFrom(
        foregroundColor: AdminColors.rubyRed,
        side: const BorderSide(color: AdminColors.slateMedium),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      child: const Text(
        'Delete Correlation ID',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildContent(AsyncValue<List<Map<String, dynamic>>> busAsync) {
    final isStreaming = _isStreamingByTab[_selectedTenantIndex] ?? true;
    final currentPage = _currentPageByTab[_selectedTenantIndex] ?? 0;
    return busAsync.when(
      data: (items) {
        final filteredItems = _filterAndSortItems(items);
        if (filteredItems.isEmpty) {
          return const Center(
            child: Text(
              'No active bus traffic.',
              style: TextStyle(color: AdminColors.textSecondary),
            ),
          );
        }

        // In streaming mode, show all items without pagination
        if (isStreaming) {
          return ListView.builder(
            itemCount: filteredItems.length,
            itemBuilder: (context, index) {
              final item = filteredItems[index];
              return _buildBusCard(item);
            },
          );
        }

        // In static mode, apply pagination
        final totalItems = filteredItems.length;
        final totalPages = (totalItems / _pageSize).ceil();
        final startIndex = currentPage * _pageSize;
        final endIndex = (startIndex + _pageSize).clamp(0, totalItems);
        final paginatedItems = filteredItems.sublist(startIndex, endIndex);

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: paginatedItems.length,
                itemBuilder: (context, index) {
                  final item = paginatedItems[index];
                  return _buildBusCard(item);
                },
              ),
            ),
            _buildPaginationRow(
              currentPage: currentPage,
              totalPages: totalPages,
              startIndex: startIndex,
              endIndex: endIndex,
              totalItems: totalItems,
            ),
          ],
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AdminColors.emeraldGreen),
      ),
      error: (e, _) => Center(
        child: Text(
          'Bus Error: $e',
          style: const TextStyle(color: AdminColors.rubyRed),
        ),
      ),
    );
  }

  Widget _buildPaginationRow({
    required int currentPage,
    required int totalPages,
    required int startIndex,
    required int endIndex,
    required int totalItems,
  }) {
    final isFirstPage = currentPage == 0;
    final isLastPage = currentPage >= totalPages - 1;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AdminColors.borderDefault),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Previous button
          IconButton(
            onPressed: isFirstPage
                ? null
                : () => setState(() => _currentPageByTab[_selectedTenantIndex] = currentPage - 1),
            icon: const Icon(Icons.chevron_left, size: 20),
            color: AdminColors.textSecondary,
            disabledColor: AdminColors.textMuted.withValues(alpha: 0.4),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'Previous page',
          ),
          const SizedBox(width: 12),
          // Page N of M
          Text(
            'Page ${currentPage + 1} of $totalPages',
            style: const TextStyle(
              color: AdminColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 12),
          // Next button
          IconButton(
            onPressed: isLastPage
                ? null
                : () => setState(() => _currentPageByTab[_selectedTenantIndex] = currentPage + 1),
            icon: const Icon(Icons.chevron_right, size: 20),
            color: AdminColors.textSecondary,
            disabledColor: AdminColors.textMuted.withValues(alpha: 0.4),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'Next page',
          ),
          const SizedBox(width: 24),
          // Showing X-Y of Z results
          Text(
            'Showing ${startIndex + 1}–$endIndex of $totalItems results',
            style: const TextStyle(
              color: AdminColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusCard(Map<String, dynamic> item) {
    final docId = item['id']?.toString() ?? '';
    final correlationId = item['correlation_id']?.toString() ?? '';
    final status = (item['status']?.toString() ?? 'pending').toLowerCase();
    final provenance = item['provenance'] as Map<String, dynamic>? ?? {};
    final senderId = provenance['sender_id']?.toString();
    final receiverId = provenance['receiver_id']?.toString();
    final control = item['control'] as Map<String, dynamic>? ?? {};
    final controlType = control['type']?.toString() ?? '';
    final priority = (control['priority']?.toString() ?? 'normal').toLowerCase();
    final telemetry = item['telemetry'] as Map<String, dynamic>? ?? {};
    final processedAt = telemetry['processed_at'];

    final isExpanded = _expandedCards.contains(docId);
    final isHighlighted = _activeCorrelationId != null && 
        correlationId == _activeCorrelationId;

    return GestureDetector(
      onTap: () {
        setState(() {
          _activeCorrelationId = correlationId.isNotEmpty ? correlationId : null;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AdminColors.slateDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isHighlighted ? AdminColors.statusInfo : AdminColors.borderDefault,
            width: isHighlighted ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: correlation_id, status badge, expand/collapse, copy JSON
            _buildCardRow1(correlationId, status, docId, isExpanded, item),
            const SizedBox(height: 8),
            
            // Row 2: From: sender_id ➜ To: receiver_id
            _buildCardRow2(senderId, receiverId),
            const SizedBox(height: 8),
            
            // Row 3: document id, Type badge, Priority badge
            _buildCardRow3(docId, controlType, priority),
            const SizedBox(height: 8),
            
            // Row 4: Processed timestamp
            _buildCardRow4(processedAt),
            
            // Expanded content
            if (isExpanded) ...[
              const SizedBox(height: 12),
              const Divider(color: AdminColors.borderDefault, height: 1),
              const SizedBox(height: 12),
              _buildExpandedContent(item),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCardRow1(
    String correlationId,
    String status,
    String docId,
    bool isExpanded,
    Map<String, dynamic> item,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildHighlightedText(
            correlationId.isNotEmpty ? correlationId : '—',
            baseStyle: const TextStyle(
              color: AdminColors.emeraldGreen,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _buildStatusBadge(status),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => _showFullJsonModal(item),
          icon: const Icon(Icons.data_object, size: 16),
          color: AdminColors.textMuted,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          tooltip: 'View Full JSON',
        ),
        IconButton(
          onPressed: () {
            setState(() {
              if (isExpanded) {
                _expandedCards.remove(docId);
              } else {
                _expandedCards.add(docId);
              }
            });
          },
          icon: Icon(
            isExpanded ? Icons.expand_less : Icons.expand_more,
            size: 20,
          ),
          color: AdminColors.textSecondary,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          tooltip: isExpanded ? 'Collapse' : 'Expand',
        ),
      ],
    );
  }

  Widget _buildCardRow2(String? senderId, String? receiverId) {
    const baseStyle = TextStyle(color: AdminColors.textSecondary, fontSize: 12);
    
    if (_searchQuery.isEmpty) {
      return Text(
        'From: ${senderId ?? '—'} ➜ To: ${receiverId ?? '—'}',
        style: baseStyle,
      );
    }

    return Row(
      children: [
        const Text('From: ', style: baseStyle),
        Flexible(
          child: _buildHighlightedText(senderId ?? '—', baseStyle: baseStyle),
        ),
        const Text(' ➜ To: ', style: baseStyle),
        Flexible(
          child: _buildHighlightedText(receiverId ?? '—', baseStyle: baseStyle),
        ),
      ],
    );
  }

  Widget _buildCardRow3(String docId, String controlType, String priority) {
    return Row(
      children: [
        Flexible(
          child: _buildHighlightedText(
            docId,
            baseStyle: const TextStyle(
              color: AdminColors.textMuted,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ),
        if (controlType.isNotEmpty) ...[
          const SizedBox(width: 8),
          _buildTypeBadge(controlType),
        ],
        const SizedBox(width: 8),
        _buildPriorityBadge(priority),
      ],
    );
  }

  Widget _buildCardRow4(dynamic processedAt) {
    String formattedTime = '—';
    if (processedAt != null) {
      try {
        DateTime dateTime;
        if (processedAt is Timestamp) {
          dateTime = processedAt.toDate();
        } else if (processedAt is String) {
          dateTime = DateTime.parse(processedAt);
        } else {
          formattedTime = '—';
          dateTime = DateTime.now(); // Won't be used
        }
        if (processedAt is Timestamp || processedAt is String) {
          formattedTime = DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
        }
      } catch (e) {
        formattedTime = '—';
      }
    }
    
    const baseStyle = TextStyle(color: AdminColors.textMuted, fontSize: 11);
    
    if (_searchQuery.isEmpty) {
      return Text('Processed: $formattedTime', style: baseStyle);
    }

    return Row(
      children: [
        const Text('Processed: ', style: baseStyle),
        Flexible(
          child: _buildHighlightedText(formattedTime, baseStyle: baseStyle),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    
    switch (status) {
      case 'dispatched':
        bgColor = AdminColors.statusInfo.withValues(alpha: 0.15);
        textColor = AdminColors.statusInfo;
      case 'intercepted':
        bgColor = AdminColors.statusWarning.withValues(alpha: 0.15);
        textColor = AdminColors.statusWarning;
      case 'pending':
      default:
        bgColor = AdminColors.slateLight.withValues(alpha: 0.15);
        textColor = AdminColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: _buildHighlightedText(
        status,
        baseStyle: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTypeBadge(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AdminColors.slateMedium.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: _buildHighlightedText(
        type,
        baseStyle: const TextStyle(
          color: AdminColors.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    Color bgColor;
    Color textColor;
    
    switch (priority) {
      case 'urgent':
        bgColor = AdminColors.rubyRed.withValues(alpha: 0.15);
        textColor = AdminColors.rubyRed;
      case 'normal':
      default:
        bgColor = AdminColors.slateLight.withValues(alpha: 0.15);
        textColor = AdminColors.textMuted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: _buildHighlightedText(
        priority,
        baseStyle: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildExpandedContent(Map<String, dynamic> item) {
    final payload = item['payload'];
    final hasPayload = payload != null && 
        (payload is! Map || (payload).isNotEmpty) &&
        (payload is! List || (payload).isNotEmpty) &&
        (payload is! String || (payload).isNotEmpty);

    if (!hasPayload) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AdminColors.slateDarkest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'No payload.',
          style: TextStyle(
            color: AdminColors.textMuted,
            fontSize: 12,
            fontFamily: 'monospace',
          ),
        ),
      );
    }

    final sanitizedPayload = _sanitizeForJson(payload);
    final prettyJson = const JsonEncoder.withIndent('  ').convert(sanitizedPayload);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminColors.slateDarkest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: _buildSyntaxHighlightedJson(prettyJson),
    );
  }

  Widget _buildHighlightedText(String text, {required TextStyle baseStyle}) {
    if (_searchQuery.isEmpty) {
      return Text(text, style: baseStyle, overflow: TextOverflow.ellipsis);
    }

    final query = _searchQuery.toLowerCase();
    final textLower = text.toLowerCase();
    
    if (!textLower.contains(query)) {
      return Text(text, style: baseStyle, overflow: TextOverflow.ellipsis);
    }

    final spans = <TextSpan>[];
    int start = 0;
    int index = textLower.indexOf(query);
    
    while (index != -1) {
      // Add non-matching text before the match
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index), style: baseStyle));
      }
      // Add matching text in white
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: baseStyle.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
      ));
      start = index + query.length;
      index = textLower.indexOf(query, start);
    }
    
    // Add remaining non-matching text
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: baseStyle));
    }

    return RichText(
      text: TextSpan(children: spans),
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Recursively converts Timestamp objects to ISO 8601 strings for JSON serialization
  dynamic _sanitizeForJson(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    } else if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _sanitizeForJson(v)));
    } else if (value is List) {
      return value.map(_sanitizeForJson).toList();
    }
    return value;
  }

  /// Builds a syntax-highlighted JSON widget with pretty colors
  Widget _buildSyntaxHighlightedJson(String jsonString) {
    final spans = <TextSpan>[];
    
    // JSON syntax highlighting colors
    const keyColor = Color(0xFF7DD3FC);       // Light blue for keys
    const stringColor = Color(0xFF86EFAC);    // Light green for string values
    const numberColor = Color(0xFFFCD34D);    // Yellow for numbers
    const boolColor = Color(0xFFF472B6);      // Pink for booleans
    const nullColor = Color(0xFFA78BFA);      // Purple for null
    const punctuationColor = Color(0xFF94A3B8); // Slate for brackets/punctuation
    
    const baseStyle = TextStyle(
      fontSize: 12,
      fontFamily: 'monospace',
    );
    
    // Regex patterns for JSON tokens
    final keyPattern = RegExp(r'"([^"\\]|\\.)*"\s*:');
    final stringPattern = RegExp(r'"([^"\\]|\\.)*"');
    final numberPattern = RegExp(r'-?\d+\.?\d*([eE][+-]?\d+)?');
    final boolPattern = RegExp(r'\b(true|false)\b');
    final nullPattern = RegExp(r'\bnull\b');
    
    int i = 0;
    while (i < jsonString.length) {
      final remaining = jsonString.substring(i);
      
      // Check for key (string followed by colon)
      final keyMatch = keyPattern.matchAsPrefix(remaining);
      if (keyMatch != null) {
        final matched = keyMatch.group(0)!;
        // Split into key string and colon
        final colonIndex = matched.lastIndexOf(':');
        final keyPart = matched.substring(0, colonIndex);
        final colonPart = matched.substring(colonIndex);
        spans.add(TextSpan(text: keyPart, style: baseStyle.copyWith(color: keyColor)));
        spans.add(TextSpan(text: colonPart, style: baseStyle.copyWith(color: punctuationColor)));
        i += matched.length;
        continue;
      }
      
      // Check for string value
      final stringMatch = stringPattern.matchAsPrefix(remaining);
      if (stringMatch != null) {
        spans.add(TextSpan(
          text: stringMatch.group(0),
          style: baseStyle.copyWith(color: stringColor),
        ));
        i += stringMatch.group(0)!.length;
        continue;
      }
      
      // Check for boolean
      final boolMatch = boolPattern.matchAsPrefix(remaining);
      if (boolMatch != null) {
        spans.add(TextSpan(
          text: boolMatch.group(0),
          style: baseStyle.copyWith(color: boolColor),
        ));
        i += boolMatch.group(0)!.length;
        continue;
      }
      
      // Check for null
      final nullMatch = nullPattern.matchAsPrefix(remaining);
      if (nullMatch != null) {
        spans.add(TextSpan(
          text: nullMatch.group(0),
          style: baseStyle.copyWith(color: nullColor),
        ));
        i += nullMatch.group(0)!.length;
        continue;
      }
      
      // Check for number
      final numberMatch = numberPattern.matchAsPrefix(remaining);
      if (numberMatch != null) {
        spans.add(TextSpan(
          text: numberMatch.group(0),
          style: baseStyle.copyWith(color: numberColor),
        ));
        i += numberMatch.group(0)!.length;
        continue;
      }
      
      // Check for punctuation (brackets, commas, etc.)
      final char = jsonString[i];
      if ('{[]},'.contains(char)) {
        spans.add(TextSpan(
          text: char,
          style: baseStyle.copyWith(color: punctuationColor),
        ));
        i++;
        continue;
      }
      
      // Whitespace and other characters
      spans.add(TextSpan(
        text: char,
        style: baseStyle.copyWith(color: punctuationColor),
      ));
      i++;
    }
    
    return SelectableText.rich(
      TextSpan(children: spans),
    );
  }

  void _showFullJsonModal(Map<String, dynamic> item) {
    final sanitizedItem = _sanitizeForJson(item) as Map<String, dynamic>;
    final prettyJson = const JsonEncoder.withIndent('  ').convert(sanitizedItem);
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AdminColors.slateDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header row with title and copy button
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Full Document JSON',
                        style: TextStyle(
                          color: AdminColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: prettyJson));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Copied!', style: TextStyle(color: AdminColors.emeraldGreen)),
                            duration: Duration(seconds: 1),
                            backgroundColor: AdminColors.slateMedium,
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      color: AdminColors.textSecondary,
                      tooltip: 'Copy to clipboard',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // JSON content
                Flexible(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AdminColors.slateDarkest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: SingleChildScrollView(
                      child: _buildSyntaxHighlightedJson(prettyJson),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Close button
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        color: AdminColors.emeraldGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
