import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local2local/features/triage_hub/providers/app_providers.dart';
import 'package:local2local/features/triage_hub/theme/admin_theme.dart';

/// Fleet Map Page - Real-time GPS view of logistics carriers and talent
class FleetMapPage extends ConsumerWidget {
  const FleetMapPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentApp = ref.watch(currentAppProvider);

    // Mock fleet data
    final carriers = currentApp == AppTenant.kaskflow
        ? _kaskflowCarriers
        : _moonlitelyCarriers;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with stats
          _FleetHeader(carriers: carriers),
          const SizedBox(height: 24),
          // Map placeholder
          _MapPlaceholder(carriers: carriers),
          const SizedBox(height: 24),
          // Active carriers list
          Row(
            children: [
              const Text(
                'Active Fleet',
                style: TextStyle(
                  color: AdminColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              _FilterToggle(label: 'Carriers', isActive: true),
              const SizedBox(width: 8),
              _FilterToggle(label: 'Talent', isActive: true),
              const SizedBox(width: 8),
              _FilterToggle(label: 'Alerts', isActive: false, isAlert: true),
            ],
          ),
          const SizedBox(height: 16),
          _CarriersList(carriers: carriers),
        ],
      ),
    );
  }
}

/// Fleet header with summary stats
class _FleetHeader extends StatelessWidget {
  final List<_CarrierData> carriers;

  const _FleetHeader({required this.carriers});

  @override
  Widget build(BuildContext context) {
    final activeCount = carriers.where((c) => c.status == 'active').length;
    final enRouteCount = carriers.where((c) => c.status == 'en_route').length;
    final idleCount = carriers.where((c) => c.status == 'idle').length;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AdminColors.slateMedium,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.borderDefault),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AdminColors.statusInfo.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.gps_fixed_rounded,
              color: AdminColors.statusInfo,
              size: 28,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fleet Map',
                  style: TextStyle(
                    color: AdminColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Real-time GPS tracking of logistics carriers and talent',
                  style: TextStyle(color: AdminColors.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          _StatPill(
            label: 'Active',
            value: activeCount.toString(),
            color: AdminColors.emeraldGreen,
          ),
          const SizedBox(width: 12),
          _StatPill(
            label: 'En Route',
            value: enRouteCount.toString(),
            color: AdminColors.statusInfo,
          ),
          const SizedBox(width: 12),
          _StatPill(
            label: 'Idle',
            value: idleCount.toString(),
            color: AdminColors.textMuted,
          ),
        ],
      ),
    );
  }
}

/// Stat pill widget
class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: AdminColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Filter toggle button
class _FilterToggle extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isAlert;

  const _FilterToggle({
    required this.label,
    required this.isActive,
    this.isAlert = false,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isAlert ? AdminColors.rubyRed : AdminColors.emeraldGreen;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? activeColor.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? activeColor : AdminColors.borderDefault,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive ? activeColor : AdminColors.textMuted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: isActive ? activeColor : AdminColors.textSecondary,
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

/// Map placeholder with simulated carrier positions
class _MapPlaceholder extends StatelessWidget {
  final List<_CarrierData> carriers;

  const _MapPlaceholder({required this.carriers});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 350,
      decoration: BoxDecoration(
        color: AdminColors.slateMedium,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.borderDefault),
      ),
      child: Stack(
        children: [
          // Grid background
          CustomPaint(
            size: const Size(double.infinity, 350),
            painter: _GridPainter(),
          ),
          // Carrier markers
          ...carriers.asMap().entries.map((entry) {
            final index = entry.key;
            final carrier = entry.value;
            // Distribute markers across the map
            final left = 50.0 + (index % 4) * 180.0 + (index * 23) % 50;
            final top = 40.0 + (index ~/ 4) * 120.0 + (index * 17) % 40;
            return Positioned(
              left: left,
              top: top,
              child: _CarrierMarker(carrier: carrier),
            );
          }),
          // Legend
          Positioned(
            bottom: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AdminColors.slateDark.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LegendItem(color: AdminColors.emeraldGreen, label: 'Active'),
                  const SizedBox(width: 16),
                  _LegendItem(color: AdminColors.statusInfo, label: 'En Route'),
                  const SizedBox(width: 16),
                  _LegendItem(color: AdminColors.textMuted, label: 'Idle'),
                  const SizedBox(width: 16),
                  _LegendItem(color: AdminColors.rubyRed, label: 'Alert'),
                ],
              ),
            ),
          ),
          // Zoom controls
          Positioned(
            bottom: 16,
            right: 16,
            child: Column(
              children: [
                _MapControl(icon: Icons.add, onTap: () {}),
                const SizedBox(height: 4),
                _MapControl(icon: Icons.remove, onTap: () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Grid painter for map background
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AdminColors.borderDefault.withValues(alpha: 0.3)
      ..strokeWidth = 1;

    // Vertical lines
    for (var x = 0.0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    // Horizontal lines
    for (var y = 0.0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Carrier marker on map
class _CarrierMarker extends StatelessWidget {
  final _CarrierData carrier;

  const _CarrierMarker({required this.carrier});

  Color get statusColor {
    if (carrier.hasAlert) return AdminColors.rubyRed;
    switch (carrier.status) {
      case 'active':
        return AdminColors.emeraldGreen;
      case 'en_route':
        return AdminColors.statusInfo;
      default:
        return AdminColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${carrier.name}\n${carrier.type} • ${carrier.currentTask}',
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: statusColor,
          shape: BoxShape.circle,
          border: Border.all(color: AdminColors.slateDarkest, width: 2),
          boxShadow: [
            BoxShadow(
              color: statusColor.withValues(alpha: 0.4),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          carrier.type == 'carrier' ? Icons.local_shipping : Icons.person,
          color: AdminColors.slateDarkest,
          size: 16,
        ),
      ),
    );
  }
}

/// Legend item
class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: AdminColors.textMuted, fontSize: 11),
        ),
      ],
    );
  }
}

/// Map control button
class _MapControl extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MapControl({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AdminColors.slateDark,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AdminColors.borderDefault),
        ),
        child: Icon(icon, color: AdminColors.textSecondary, size: 18),
      ),
    );
  }
}

/// Carriers list
class _CarriersList extends StatelessWidget {
  final List<_CarrierData> carriers;

  const _CarriersList({required this.carriers});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.slateMedium,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.borderDefault),
      ),
      child: Column(
        children: carriers.asMap().entries.map((entry) {
          final carrier = entry.value;
          final isLast = entry.key == carriers.length - 1;
          return _CarrierTile(carrier: carrier, isLast: isLast);
        }).toList(),
      ),
    );
  }
}

/// Individual carrier tile
class _CarrierTile extends StatelessWidget {
  final _CarrierData carrier;
  final bool isLast;

  const _CarrierTile({required this.carrier, required this.isLast});

  Color get statusColor {
    if (carrier.hasAlert) return AdminColors.rubyRed;
    switch (carrier.status) {
      case 'active':
        return AdminColors.emeraldGreen;
      case 'en_route':
        return AdminColors.statusInfo;
      default:
        return AdminColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AdminColors.borderDefault)),
      ),
      child: Row(
        children: [
          // Status indicator
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              carrier.type == 'carrier' ? Icons.local_shipping : Icons.person,
              color: statusColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      carrier.name,
                      style: const TextStyle(
                        color: AdminColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AdminColors.slateLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        carrier.id,
                        style: const TextStyle(
                          color: AdminColors.textMuted,
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    if (carrier.hasAlert) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AdminColors.rubyRed.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning_amber, size: 12, color: AdminColors.rubyRed),
                            SizedBox(width: 4),
                            Text(
                              'ALERT',
                              style: TextStyle(
                                color: AdminColors.rubyRed,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  carrier.currentTask,
                  style: const TextStyle(color: AdminColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          // Location
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on, size: 14, color: AdminColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    carrier.location,
                    style: const TextStyle(color: AdminColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Updated ${carrier.lastUpdate}',
                style: const TextStyle(color: AdminColors.textMuted, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Carrier data model
class _CarrierData {
  final String id;
  final String name;
  final String type;
  final String status;
  final String currentTask;
  final String location;
  final String lastUpdate;
  final bool hasAlert;

  const _CarrierData({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.currentTask,
    required this.location,
    required this.lastUpdate,
    this.hasAlert = false,
  });
}

/// Mock data for Kaskflow
const _kaskflowCarriers = [
  _CarrierData(
    id: 'CAR_001',
    name: 'Express Delivery Unit #1',
    type: 'carrier',
    status: 'en_route',
    currentTask: 'Delivering ORD_9912 to 123 Main St',
    location: 'Edmonton, AB',
    lastUpdate: '2 min ago',
  ),
  _CarrierData(
    id: 'CAR_002',
    name: 'Heavy Freight Truck #7',
    type: 'carrier',
    status: 'active',
    currentTask: 'Loading at Warehouse C',
    location: 'Calgary, AB',
    lastUpdate: '30 sec ago',
  ),
  _CarrierData(
    id: 'WRK_445',
    name: 'John D.',
    type: 'talent',
    status: 'active',
    currentTask: 'Shift in progress - Warehouse B',
    location: 'Edmonton, AB',
    lastUpdate: '1 min ago',
  ),
  _CarrierData(
    id: 'CAR_003',
    name: 'Refrigerated Unit #3',
    type: 'carrier',
    status: 'en_route',
    currentTask: 'Route RT_445 - Edmonton to Calgary',
    location: 'Red Deer, AB',
    lastUpdate: '5 min ago',
    hasAlert: true,
  ),
  _CarrierData(
    id: 'WRK_223',
    name: 'Sarah M.',
    type: 'talent',
    status: 'idle',
    currentTask: 'Available for assignment',
    location: 'Calgary, AB',
    lastUpdate: '15 min ago',
  ),
  _CarrierData(
    id: 'CAR_005',
    name: 'Express Van #12',
    type: 'carrier',
    status: 'active',
    currentTask: 'Pickup at Supplier XYZ',
    location: 'Edmonton, AB',
    lastUpdate: '45 sec ago',
  ),
];

/// Mock data for Moonlitely
const _moonlitelyCarriers = [
  _CarrierData(
    id: 'CAR_M01',
    name: 'Night Delivery Unit #1',
    type: 'carrier',
    status: 'active',
    currentTask: 'Evening route - Downtown Vancouver',
    location: 'Vancouver, BC',
    lastUpdate: '1 min ago',
  ),
  _CarrierData(
    id: 'WRK_M12',
    name: 'Alex K.',
    type: 'talent',
    status: 'en_route',
    currentTask: 'Delivering ORD_M_8823',
    location: 'Burnaby, BC',
    lastUpdate: '3 min ago',
    hasAlert: true,
  ),
  _CarrierData(
    id: 'CAR_M03',
    name: 'Premium Service Van #5',
    type: 'carrier',
    status: 'idle',
    currentTask: 'Awaiting dispatch',
    location: 'Richmond, BC',
    lastUpdate: '20 min ago',
  ),
  _CarrierData(
    id: 'WRK_M08',
    name: 'Lisa T.',
    type: 'talent',
    status: 'active',
    currentTask: 'Customer support - Priority call',
    location: 'Vancouver, BC',
    lastUpdate: '30 sec ago',
  ),
];
