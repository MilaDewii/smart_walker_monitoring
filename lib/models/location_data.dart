import 'package:latlong2/latlong.dart';

class LocationData {
  final LatLng lansiaPos;
  final LatLng geofenceCenter;
  final double geofenceRadius;
  final String geofenceStatus;
  final String lastUpdate;
  final bool   connected;
  final bool   isInSafeZone; // ← jadikan field, bukan getter

  const LocationData({
    required this.lansiaPos,
    required this.geofenceCenter,
    required this.geofenceRadius,
    required this.geofenceStatus,
    required this.lastUpdate,
    required this.connected,
    required this.isInSafeZone, // ← tambah
  });

  factory LocationData.empty() => const LocationData(
    lansiaPos      : LatLng(0, 0),           // ← ganti dari hardcode koordinat
    geofenceCenter : LatLng(-7.051, 110.442),
    geofenceRadius : 100,
    geofenceStatus : 'inside',
    lastUpdate     : '-',
    connected      : false,
    isInSafeZone   : true,                   // ← default aman
  );
}