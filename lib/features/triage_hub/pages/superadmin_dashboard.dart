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
  // Data Browser state
  String _browserTenant = 'kaskflow';
  String _browserCollection = '';
  bool _dataBrowserExpanded = false;
  Future<List<Map<String, dynamic>>>? _browserFuture;
  List<Map<String, dynamic>> _browserDocuments = [];
  final Set<String> _browserExpandedCards = {};
  final TextEditingController _browserCollectionController = TextEditingController();
  final TextEditingController _browserSearchController = TextEditingController();
  String _browserSearchQuery = '';
  Map<String, String> _browserFieldFilters = {};

  static const List<String> _knownCollections = [
    'activity',
    'agent_bus',
    'agent_registry',
    'carriers',
    'efficacy_audit',
    'evolution_timeline',
    'facilities',
    'interventions',
    'jobs',
    'lessons_learned',
    'logic_locks',
    'logic_proposals',
    'logistics_jobs',
    'orders',
    'platform_feedback',
    'shadow_runs',
    'system_state',
    'telemetry',
  ];

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
    _browserCollectionController.dispose();
    _browserSearchController.dispose();
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
                  'Data',
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
            
            // Main content area - Side-by-side panels (Agent Bus + Data Browser)
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left Panel: Agent Bus Viewer
                  const Expanded(child: AgentBusViewer()),
                  
                  const SizedBox(width: 24),
                  
                  // Right Panel: Data Browser
                  Expanded(
                    child: _buildDataBrowserFullPanel(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataBrowserFullPanel() {
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
          // Header
          Row(
            children: [
              const Icon(
                Icons.storage_rounded,
                color: AdminColors.emeraldGreen,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Data Browser',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Content
          Expanded(
            child: _buildDataBrowserFullContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildDataBrowserFullContent() {
    final resolvedPath = ref.read(superadminRepositoryProvider).resolveCollectionPath(_browserTenant);
    final fullPath = _browserCollection.isNotEmpty 
        ? resolvedPath.replaceAll('agent_bus', _browserCollection)
        : resolvedPath.replaceAll('/agent_bus', '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selector row
        Row(
          children: [
            // Tenant dropdown
            Expanded(
              flex: 1,
              child: _buildBrowserTenantDropdown(),
            ),
            const SizedBox(width: 16),
            // Collection autocomplete
            Expanded(
              flex: 2,
              child: _buildCollectionAutocomplete(),
            ),
            const SizedBox(width: 12),
            // Browse button
            IconButton(
              onPressed: _browserCollection.isNotEmpty ? _executeBrowseQuery : null,
              icon: const Icon(Icons.search),
              color: AdminColors.emeraldGreen,
              disabledColor: AdminColors.textMuted,
              style: IconButton.styleFrom(
                backgroundColor: AdminColors.emeraldGreen.withValues(alpha: 0.15),
                disabledBackgroundColor: AdminColors.slateDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: _browserCollection.isNotEmpty 
                        ? AdminColors.emeraldGreen.withValues(alpha: 0.5) 
                        : AdminColors.borderDefault,
                  ),
                ),
                minimumSize: const Size(44, 44),
              ),
              tooltip: 'Browse collection',
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Resolved path display
        Text(
          _browserCollection.isNotEmpty ? fullPath : '${resolvedPath.replaceAll('/agent_bus', '')}/<collection>',
          style: const TextStyle(
            color: AdminColors.textMuted,
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
        
        // Document list (only shown after query)
        if (_browserFuture != null) ...[
          const SizedBox(height: 16),
          const Divider(color: AdminColors.borderDefault, height: 1),
          const SizedBox(height: 16),
          Expanded(child: _buildBrowserDocumentListFull()),
        ] else
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_open_rounded,
                    size: 48,
                    color: AdminColors.textMuted.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select a collection to browse',
                    style: TextStyle(
                      color: AdminColors.textMuted,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBrowserDocumentListFull() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _browserFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AdminColors.emeraldGreen),
          );
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: AdminColors.rubyRed, fontSize: 13),
            ),
          );
        }
        
        final allDocuments = _browserDocuments.isNotEmpty ? _browserDocuments : (snapshot.data ?? []);
        
        if (allDocuments.isEmpty) {
          return const Center(
            child: Text(
              'No documents found.',
              style: TextStyle(color: AdminColors.textMuted, fontSize: 13),
            ),
          );
        }
        
        // Extract all unique top-level field names across all documents
        final allFieldNames = <String>{};
        for (final doc in allDocuments) {
          for (final key in doc.keys) {
            if (key != '__docId__') {
              allFieldNames.add(key);
            }
          }
        }
        final sortedFieldNames = allFieldNames.toList()..sort();
        
        // Apply filters
        final filteredDocuments = _filterBrowserDocuments(allDocuments);
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search bar
            _buildBrowserSearchBar(),
            const SizedBox(height: 12),
            
            // Field filter chips
            _buildBrowserFieldFilterChips(sortedFieldNames),
            
            // Active field filter inputs
            if (_browserFieldFilters.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildBrowserActiveFilters(),
            ],
            
            const SizedBox(height: 16),
            
            // Document count badge and refresh button
            Row(
              children: [
                Text(
                  '${filteredDocuments.length} of ${allDocuments.length} documents',
                  style: const TextStyle(
                    color: AdminColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _executeBrowseQuery,
                  icon: const Icon(Icons.refresh, size: 16),
                  color: AdminColors.textSecondary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Document cards in a scrollable area
            if (filteredDocuments.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    'No documents match the current filters.',
                    style: const TextStyle(color: AdminColors.textMuted, fontSize: 13),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: filteredDocuments.length,
                  itemBuilder: (context, index) {
                    return _buildBrowserDocumentCard(filteredDocuments[index]);
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDataBrowserPanel() {
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.slateDark.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.borderDefault),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row
          InkWell(
            onTap: () => setState(() => _dataBrowserExpanded = !_dataBrowserExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'Data Browser',
                    style: TextStyle(
                      color: AdminColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => setState(() => _dataBrowserExpanded = !_dataBrowserExpanded),
                    icon: Icon(
                      _dataBrowserExpanded ? Icons.expand_less : Icons.expand_more,
                      color: AdminColors.textSecondary,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
          ),
          
          // Expanded content
          if (_dataBrowserExpanded) ...[
            const Divider(color: AdminColors.borderDefault, height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildDataBrowserContent(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDataBrowserContent() {
    final resolvedPath = ref.read(superadminRepositoryProvider).resolveCollectionPath(_browserTenant);
    final fullPath = _browserCollection.isNotEmpty 
        ? resolvedPath.replaceAll('agent_bus', _browserCollection)
        : resolvedPath.replaceAll('/agent_bus', '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selector row
        Row(
          children: [
            // Tenant dropdown
            Expanded(
              flex: 1,
              child: _buildBrowserTenantDropdown(),
            ),
            const SizedBox(width: 16),
            // Collection autocomplete
            Expanded(
              flex: 2,
              child: _buildCollectionAutocomplete(),
            ),
            const SizedBox(width: 12),
            // Browse button
            IconButton(
              onPressed: _browserCollection.isNotEmpty ? _executeBrowseQuery : null,
              icon: const Icon(Icons.search),
              color: AdminColors.emeraldGreen,
              disabledColor: AdminColors.textMuted,
              style: IconButton.styleFrom(
                backgroundColor: AdminColors.emeraldGreen.withValues(alpha: 0.15),
                disabledBackgroundColor: AdminColors.slateDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: _browserCollection.isNotEmpty 
                        ? AdminColors.emeraldGreen.withValues(alpha: 0.5) 
                        : AdminColors.borderDefault,
                  ),
                ),
                minimumSize: const Size(44, 44),
              ),
              tooltip: 'Browse collection',
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Resolved path display
        Text(
          _browserCollection.isNotEmpty ? fullPath : '${resolvedPath.replaceAll('/agent_bus', '')}/<collection>',
          style: const TextStyle(
            color: AdminColors.textMuted,
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
        
        // Document list (only shown after query)
        if (_browserFuture != null) ...[
          const SizedBox(height: 16),
          const Divider(color: AdminColors.borderDefault, height: 1),
          const SizedBox(height: 16),
          _buildBrowserDocumentList(),
        ],
      ],
    );
  }

  Widget _buildBrowserTenantDropdown() {
    const tenantOptions = [
      ('SYSTEM', 'system_status'),
      ('KASKFLOW', 'kaskflow'),
      ('MOONLITELY', 'moonlitely'),
    ];
    
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AdminColors.slateDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AdminColors.borderDefault),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _browserTenant,
          isExpanded: true,
          dropdownColor: AdminColors.slateDark,
          icon: const Icon(Icons.arrow_drop_down, color: AdminColors.textSecondary),
          style: const TextStyle(color: AdminColors.textPrimary, fontSize: 14),
          items: tenantOptions.map((option) {
            return DropdownMenuItem<String>(
              value: option.$2,
              child: Text(option.$1),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _browserTenant = value;
                _browserFuture = null; // Reset results when tenant changes
                _browserExpandedCards.clear();
                _browserDocuments = [];
                _browserSearchQuery = '';
                _browserSearchController.clear();
                _browserFieldFilters = {};
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildCollectionAutocomplete() {
    return Autocomplete<String>(
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return _knownCollections;
        }
        return _knownCollections.where((collection) =>
            collection.toLowerCase().contains(textEditingValue.text.toLowerCase()));
      },
      onSelected: (selection) {
        setState(() {
          _browserCollection = selection;
          _browserCollectionController.text = selection;
        });
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        // Sync controller text on first build
        if (controller.text.isEmpty && _browserCollection.isNotEmpty) {
          controller.text = _browserCollection;
        }
        return Container(
          height: 44,
          decoration: BoxDecoration(
            color: AdminColors.slateDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AdminColors.borderDefault),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            style: const TextStyle(color: AdminColors.textPrimary, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Collection name...',
              hintStyle: TextStyle(color: AdminColors.textMuted, fontSize: 14),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            onChanged: (value) {
              setState(() => _browserCollection = value);
            },
            onSubmitted: (_) {
              if (_browserCollection.isNotEmpty) {
                _executeBrowseQuery();
              }
            },
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            color: AdminColors.slateDark,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 300),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(
                      option,
                      style: const TextStyle(
                        color: AdminColors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                    onTap: () => onSelected(option),
                    hoverColor: AdminColors.emeraldGreen.withValues(alpha: 0.1),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _executeBrowseQuery() {
    if (_browserCollection.isEmpty) return;
    
    final basePath = ref.read(superadminRepositoryProvider).resolveCollectionPath(_browserTenant);
    final collectionPath = basePath.replaceAll('agent_bus', _browserCollection);
    
    setState(() {
      _browserExpandedCards.clear();
      _browserSearchQuery = '';
      _browserSearchController.clear();
      _browserFieldFilters = {};
      _browserDocuments = [];
      _browserFuture = FirebaseFirestore.instance
          .collection(collectionPath)
          .limit(50)
          .get()
          .then((snapshot) {
            final docs = snapshot.docs.map((doc) {
              final data = Map<String, dynamic>.from(doc.data());
              data['__docId__'] = doc.id;
              return data;
            }).toList();
            // Store documents for client-side filtering
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _browserDocuments = docs);
            });
            return docs;
          });
    });
  }

  Widget _buildBrowserDocumentList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _browserFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: AdminColors.emeraldGreen),
            ),
          );
        }
        
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: AdminColors.rubyRed, fontSize: 13),
            ),
          );
        }
        
        final allDocuments = _browserDocuments.isNotEmpty ? _browserDocuments : (snapshot.data ?? []);
        
        if (allDocuments.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'No documents found.',
              style: TextStyle(color: AdminColors.textMuted, fontSize: 13),
            ),
          );
        }
        
        // Extract all unique top-level field names across all documents
        final allFieldNames = <String>{};
        for (final doc in allDocuments) {
          for (final key in doc.keys) {
            if (key != '__docId__') {
              allFieldNames.add(key);
            }
          }
        }
        final sortedFieldNames = allFieldNames.toList()..sort();
        
        // Apply filters
        final filteredDocuments = _filterBrowserDocuments(allDocuments);
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search bar
            _buildBrowserSearchBar(),
            const SizedBox(height: 12),
            
            // Field filter chips
            _buildBrowserFieldFilterChips(sortedFieldNames),
            
            // Active field filter inputs
            if (_browserFieldFilters.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildBrowserActiveFilters(),
            ],
            
            const SizedBox(height: 16),
            
            // Document count badge and refresh button
            Row(
              children: [
                Text(
                  '${filteredDocuments.length} of ${allDocuments.length} documents',
                  style: const TextStyle(
                    color: AdminColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _executeBrowseQuery,
                  icon: const Icon(Icons.refresh, size: 16),
                  color: AdminColors.textSecondary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Document cards in a constrained scrollable area
            if (filteredDocuments.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No documents match the current filters.',
                  style: const TextStyle(color: AdminColors.textMuted, fontSize: 13),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: filteredDocuments.length,
                  itemBuilder: (context, index) {
                    return _buildBrowserDocumentCard(filteredDocuments[index]);
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildBrowserSearchBar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AdminColors.slateDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AdminColors.borderDefault),
      ),
      child: TextField(
        controller: _browserSearchController,
        style: const TextStyle(color: AdminColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search documents...',
          hintStyle: const TextStyle(color: AdminColors.textMuted, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: AdminColors.textMuted, size: 20),
          suffixIcon: _browserSearchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, color: AdminColors.textMuted, size: 18),
                  onPressed: () {
                    _browserSearchController.clear();
                    setState(() => _browserSearchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (value) => setState(() => _browserSearchQuery = value),
      ),
    );
  }

  Widget _buildBrowserFieldFilterChips(List<String> fieldNames) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: fieldNames.map((field) {
        final isSelected = _browserFieldFilters.containsKey(field);
        return FilterChip(
          label: Text(
            field,
            style: TextStyle(
              color: isSelected ? AdminColors.emeraldGreen : AdminColors.textSecondary,
              fontSize: 12,
            ),
          ),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _browserFieldFilters[field] = '';
              } else {
                _browserFieldFilters.remove(field);
              }
            });
          },
          selectedColor: AdminColors.emeraldGreen.withValues(alpha: 0.15),
          backgroundColor: AdminColors.slateDark,
          side: BorderSide(
            color: isSelected 
                ? AdminColors.emeraldGreen.withValues(alpha: 0.5) 
                : AdminColors.borderDefault,
          ),
          showCheckmark: false,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        );
      }).toList(),
    );
  }

  Widget _buildBrowserActiveFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _browserFieldFilters.entries.map((entry) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AdminColors.slateDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AdminColors.emeraldGreen.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Text(
                '${entry.key}  =  ',
                style: const TextStyle(
                  color: AdminColors.emeraldGreen,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
              ),
              Expanded(
                child: TextField(
                  style: const TextStyle(color: AdminColors.textPrimary, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'value',
                    hintStyle: TextStyle(color: AdminColors.textMuted, fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _browserFieldFilters[entry.key] = value;
                    });
                  },
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _browserFieldFilters.remove(entry.key);
                  });
                },
                icon: const Icon(Icons.close, size: 16),
                color: AdminColors.textMuted,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                tooltip: 'Remove filter',
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  List<Map<String, dynamic>> _filterBrowserDocuments(List<Map<String, dynamic>> documents) {
    return documents.where((doc) {
      // Apply search query filter (shallow, top-level fields only, case-insensitive)
      if (_browserSearchQuery.isNotEmpty) {
        final query = _browserSearchQuery.toLowerCase();
        bool matchesSearch = false;
        for (final entry in doc.entries) {
          if (entry.key == '__docId__') continue;
          final value = entry.value;
          String stringValue;
          if (value is Timestamp) {
            stringValue = value.toDate().toIso8601String();
          } else {
            stringValue = value?.toString() ?? '';
          }
          if (stringValue.toLowerCase().contains(query)) {
            matchesSearch = true;
            break;
          }
        }
        if (!matchesSearch) return false;
      }
      
      // Apply field filters (AND-combined)
      for (final filter in _browserFieldFilters.entries) {
        final fieldName = filter.key;
        final filterValue = filter.value.toLowerCase();
        
        // Skip empty filter values
        if (filterValue.isEmpty) continue;
        
        if (!doc.containsKey(fieldName)) return false;
        
        final docValue = doc[fieldName];
        String stringValue;
        if (docValue is Timestamp) {
          stringValue = docValue.toDate().toIso8601String();
        } else {
          stringValue = docValue?.toString() ?? '';
        }
        
        if (!stringValue.toLowerCase().contains(filterValue)) {
          return false;
        }
      }
      
      return true;
    }).toList();
  }

  Widget _buildBrowserDocumentCard(Map<String, dynamic> document) {
    final docId = document['__docId__'] as String? ?? '';
    final isExpanded = _browserExpandedCards.contains(docId);
    
    // Create a display copy without the internal __docId__ field
    final displayDoc = Map<String, dynamic>.from(document)..remove('__docId__');
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AdminColors.slateDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AdminColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: document ID, copy button, JSON modal button, delete button, expand/collapse
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    docId,
                    style: const TextStyle(
                      color: AdminColors.emeraldGreen,
                      fontSize: 12,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: docId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copied!', style: TextStyle(color: AdminColors.emeraldGreen)),
                        backgroundColor: AdminColors.slateMedium,
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 14),
                  color: AdminColors.textMuted,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  tooltip: 'Copy document ID',
                ),
                IconButton(
                  onPressed: () => _showBrowserJsonModal(docId, displayDoc),
                  icon: const Icon(Icons.data_object, size: 16),
                  color: AdminColors.textMuted,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  tooltip: 'View full JSON',
                ),
                IconButton(
                  onPressed: () => _showDeleteDocumentDialog(docId),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  color: AdminColors.textMuted,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  tooltip: 'Delete document',
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      if (isExpanded) {
                        _browserExpandedCards.remove(docId);
                      } else {
                        _browserExpandedCards.add(docId);
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
            ),
          ),
          
          // Expanded content: formatted JSON
          if (isExpanded) ...[
            const Divider(color: AdminColors.borderDefault, height: 1),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AdminColors.slateDarkest,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: _buildBrowserSyntaxHighlightedJson(
                const JsonEncoder.withIndent('  ').convert(_sanitizeBrowserForJson(displayDoc)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showDeleteDocumentDialog(String docId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AdminColors.slateDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Delete Document',
          style: TextStyle(
            color: AdminColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Delete document $docId from $_browserCollection? This cannot be undone.',
          style: const TextStyle(
            color: AdminColors.textSecondary,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: AdminColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _deleteDocument(docId);
            },
            child: const Text(
              'DELETE',
              style: TextStyle(color: AdminColors.rubyRed, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteDocument(String docId) async {
    final basePath = ref.read(superadminRepositoryProvider).resolveCollectionPath(_browserTenant);
    final collectionPath = basePath.replaceAll('agent_bus', _browserCollection);
    
    try {
      await FirebaseFirestore.instance.collection(collectionPath).doc(docId).delete();
      
      // Remove from local list immediately
      setState(() {
        _browserDocuments.removeWhere((doc) => doc['__docId__'] == docId);
        _browserExpandedCards.remove(docId);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Document $docId deleted.',
              style: const TextStyle(color: AdminColors.emeraldGreen),
            ),
            backgroundColor: AdminColors.slateMedium,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Delete failed: $e',
              style: const TextStyle(color: AdminColors.rubyRed),
            ),
            backgroundColor: AdminColors.slateMedium,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  void _showBrowserJsonModal(String docId, Map<String, dynamic> document) {
    final sanitized = _sanitizeBrowserForJson(document);
    final prettyJson = const JsonEncoder.withIndent('  ').convert(sanitized);
    
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
                // Header row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Document JSON',
                            style: TextStyle(
                              color: AdminColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            docId,
                            style: const TextStyle(
                              color: AdminColors.emeraldGreen,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
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
                      child: _buildBrowserSyntaxHighlightedJson(prettyJson),
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

  /// Recursively converts Timestamp objects to ISO 8601 strings for JSON serialization
  dynamic _sanitizeBrowserForJson(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    } else if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _sanitizeBrowserForJson(v)));
    } else if (value is List) {
      return value.map(_sanitizeBrowserForJson).toList();
    }
    return value;
  }

  /// Builds syntax-highlighted JSON widget
  Widget _buildBrowserSyntaxHighlightedJson(String jsonString) {
    final spans = <TextSpan>[];
    
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
    
    final keyPattern = RegExp(r'"([^"\\]|\\.)*"\s*:');
    final stringPattern = RegExp(r'"([^"\\]|\\.)*"');
    final numberPattern = RegExp(r'-?\d+\.?\d*([eE][+-]?\d+)?');
    final boolPattern = RegExp(r'\b(true|false)\b');
    final nullPattern = RegExp(r'\bnull\b');
    
    int i = 0;
    while (i < jsonString.length) {
      final remaining = jsonString.substring(i);
      
      final keyMatch = keyPattern.matchAsPrefix(remaining);
      if (keyMatch != null) {
        final matched = keyMatch.group(0)!;
        final colonIndex = matched.lastIndexOf(':');
        final keyPart = matched.substring(0, colonIndex);
        final colonPart = matched.substring(colonIndex);
        spans.add(TextSpan(text: keyPart, style: baseStyle.copyWith(color: keyColor)));
        spans.add(TextSpan(text: colonPart, style: baseStyle.copyWith(color: punctuationColor)));
        i += matched.length;
        continue;
      }
      
      final stringMatch = stringPattern.matchAsPrefix(remaining);
      if (stringMatch != null) {
        spans.add(TextSpan(text: stringMatch.group(0), style: baseStyle.copyWith(color: stringColor)));
        i += stringMatch.group(0)!.length;
        continue;
      }
      
      final boolMatch = boolPattern.matchAsPrefix(remaining);
      if (boolMatch != null) {
        spans.add(TextSpan(text: boolMatch.group(0), style: baseStyle.copyWith(color: boolColor)));
        i += boolMatch.group(0)!.length;
        continue;
      }
      
      final nullMatch = nullPattern.matchAsPrefix(remaining);
      if (nullMatch != null) {
        spans.add(TextSpan(text: nullMatch.group(0), style: baseStyle.copyWith(color: nullColor)));
        i += nullMatch.group(0)!.length;
        continue;
      }
      
      final numberMatch = numberPattern.matchAsPrefix(remaining);
      if (numberMatch != null) {
        spans.add(TextSpan(text: numberMatch.group(0), style: baseStyle.copyWith(color: numberColor)));
        i += numberMatch.group(0)!.length;
        continue;
      }
      
      final char = jsonString[i];
      if ('{[]},'.contains(char)) {
        spans.add(TextSpan(text: char, style: baseStyle.copyWith(color: punctuationColor)));
        i++;
        continue;
      }
      
      spans.add(TextSpan(text: char, style: baseStyle.copyWith(color: punctuationColor)));
      i++;
    }
    
    return SelectableText.rich(TextSpan(children: spans));
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

class _phaseSearchQuery {
}

class _phaseSearchController {
}

class _AgentBusInjectionModal extends StatefulWidget {
  final WidgetRef ref;
  
  const _AgentBusInjectionModal({required this.ref});

  @override
  State<_AgentBusInjectionModal> createState() => _AgentBusInjectionModalState();
}

class _AgentBusInjectionModalState extends State<_AgentBusInjectionModal> {
  late String _tenant;
  late bool _shadow;
  int _selectedTab = 0;
  bool _isInjecting = false;
  bool _rawJsonValid = true;

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

  /// Convert tenant index to tenant string
  static String _tenantIndexToString(int index) {
    switch (index) {
      case 0: return 'system_status';
      case 1: return 'kaskflow';
      case 2: return 'moonlitely';
      default: return 'system_status';
    }
  }

  @override
  void initState() {
    super.initState();
    // Read current dashboard selections from providers
    final tenantIndex = widget.ref.read(dashboardTenantIndexProvider);
    _tenant = _tenantIndexToString(tenantIndex);
    _shadow = widget.ref.read(dashboardShadowBusProvider);
    
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _correlationIdController = TextEditingController(text: 'INJECT-$timestamp');
    _senderIdController = TextEditingController(text: 'SUPERADMIN_UI');
    _receiverIdController = TextEditingController(text: 'EVOLUTION_WORKER');
    _hbrIdController = TextEditingController(text: 'HBR-TEST-001');
    _targetPathController = TextEditingController();
    _detailsController = TextEditingController();
    _rawJsonController = TextEditingController(text: _buildDefaultJson());
    _rawJsonController.addListener(_validateRawJson);
  }

  String _buildDefaultJson() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '''{
  "correlation_id": "INJECT-$timestamp",
  "status": "dispatched",
  "provenance": { "sender_id": "SUPERADMIN_UI", "receiver_id": "EVOLUTION_WORKER" },
  "control": { "type": "REQUEST", "priority": "normal" },
  "payload": { "manifest": { "intent": "PROPOSE_LOGIC_CHANGE", "agentId": "SUPERADMIN_UI", "hbrId": "HBR-TEST-001" } }
}''';
  }

  void _validateRawJson() {
    try {
      json.decode(_rawJsonController.text);
      if (!_rawJsonValid) setState(() => _rawJsonValid = true);
    } catch (_) {
      if (_rawJsonValid) setState(() => _rawJsonValid = false);
    }
  }

  @override
  void dispose() {
    _rawJsonController.removeListener(_validateRawJson);
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
                onPressed: _isInjecting || (_selectedTab == 0 && !_rawJsonValid)
                    ? null
                    : _handleInject,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 280,
            child: TextField(
              controller: _rawJsonController,
              maxLines: null,
              minLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
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
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                _rawJsonValid ? Icons.check_circle_outline : Icons.error_outline,
                size: 14,
                color: _rawJsonValid ? AdminColors.emeraldGreen : AdminColors.rubyRed,
              ),
              const SizedBox(width: 6),
              Text(
                _rawJsonValid ? 'Valid JSON' : 'Invalid JSON',
                style: TextStyle(
                  color: _rawJsonValid ? AdminColors.emeraldGreen : AdminColors.rubyRed,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
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