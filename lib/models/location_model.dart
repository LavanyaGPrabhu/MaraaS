import 'package:cloud_firestore/cloud_firestore.dart';

class MaraaSLocation {
  final String? id;
  final String name;
  final double lat;
  final double lng;
  final int capacity;
  final int currentCount;

  MaraaSLocation({
    this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.capacity,
    this.currentCount = 0,
  });

  factory MaraaSLocation.fromDoc(DocumentSnapshot d) {
    final data = d.data() as Map<String, dynamic>;
    return MaraaSLocation(
      id: d.id,
      name: data['name'] ?? 'Unknown',
      lat: (data['lat'] as num).toDouble(),
      lng: (data['lng'] as num).toDouble(),
      capacity: (data['capacity'] as num).toInt(),
      currentCount: (data['currentCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'lat': lat,
    'lng': lng,
    'capacity': capacity,
    'currentCount': currentCount,
  };
}
