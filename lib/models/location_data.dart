import 'package:latlong2/latlong.dart';

class LocationData {
  final LatLng  lansiaPos;
  final LatLng  geofenceCenter;
  final double  geofenceRadius;
  final String  geofenceStatus;
  final String  lastUpdate;
  final bool    connected;

  const LocationData({
    required this.lansiaPos,
    required this.geofenceCenter,
    required this.geofenceRadius,
    required this.geofenceStatus,
    required this.lastUpdate,
    required this.connected,
  });

  factory LocationData.empty() => const LocationData(
    lansiaPos      : LatLng(-7.051234, 110.442123),
    geofenceCenter : LatLng(-7.051,    110.442),
    geofenceRadius : 100,
    geofenceStatus : 'inside',
    lastUpdate     : '-',
    connected      : false,
  );

  bool get isInSafeZone => geofenceStatus == 'inside';
}