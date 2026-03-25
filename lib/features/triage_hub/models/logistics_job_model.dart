import 'package:cloud_firestore/cloud_firestore.dart';

enum LogisticsStatus { open, bidding, awarded, inTransit, arrived, completed }

class LogisticsJobModel {
  final String id, orderId, carrierId;
  final LogisticsStatus status;
  final double? lat, lng;
  final int distanceMeters;
  final DateTime lastUpdate;

  const LogisticsJobModel(
      {required this.id,
      required this.orderId,
      required this.status,
      required this.carrierId,
      this.lat,
      this.lng,
      required this.distanceMeters,
      required this.lastUpdate});

  factory LogisticsJobModel.fromFirestore(DocumentSnapshot doc) {
    final dynamic data = doc.data();
    final dynamic loc = data['currentLocation'] ?? {};

    final String statusStr = (data['status'] ?? 'open').toString();
    LogisticsStatus status = LogisticsStatus.open;
    if (statusStr == 'awarded') status = LogisticsStatus.awarded;
    if (statusStr == 'in_transit') status = LogisticsStatus.inTransit;
    if (statusStr == 'arrived') status = LogisticsStatus.arrived;
    if (statusStr == 'completed') status = LogisticsStatus.completed;

    return LogisticsJobModel(
      id: doc.id,
      orderId: (data['orderId'] ?? 'N/A').toString(),
      carrierId: (data['awardedCarrierId'] ?? 'Unassigned').toString(),
      status: status,
      lat: (loc['lat'] is num) ? (loc['lat'] as num).toDouble() : null,
      lng: (loc['lng'] is num) ? (loc['lng'] as num).toDouble() : null,
      distanceMeters: (loc['distanceToDestinationMeters'] is num)
          ? (loc['distanceToDestinationMeters'] as num).toInt()
          : 0,
      lastUpdate: loc['updatedAt'] != null
          ? DateTime.tryParse(loc['updatedAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
