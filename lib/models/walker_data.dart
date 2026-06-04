import 'package:latlong2/latlong.dart';

class WalkerData {
  final LatLng  position;
  final bool    jatuh;
  final double  fallConfidence;
  final double  fallImpact;
  final bool    gpsAktif;
  final bool    mpuAktif;
  final bool    ultrasonicFront;
  final bool    ultrasonicBack;
  final bool    walkerActive;
  final String  status;          // 'aman' | 'peringatan' | 'bahaya'
  final String  geofenceStatus;  // 'inside' | 'outside'
  final double  geofenceRadius;  // dari RTD geofence.radius
  final LatLng  geofenceCenter;  // dari RTD geofence.center_lat/lng
  final String  lastUpdate;
  final int     langkah;

  const WalkerData({
    required this.position,
    required this.jatuh,
    required this.fallConfidence,
    required this.fallImpact,
    required this.gpsAktif,
    required this.mpuAktif,
    required this.ultrasonicFront,
    required this.ultrasonicBack,
    required this.walkerActive,
    required this.status,
    required this.geofenceStatus,
    required this.geofenceRadius,
    required this.geofenceCenter,
    required this.lastUpdate,
    required this.langkah,
  });

  factory WalkerData.empty() => const WalkerData(
    position       : LatLng(-7.051234, 110.442123),
    jatuh          : false,
    fallConfidence : 0,
    fallImpact     : 0,
    gpsAktif       : false,
    mpuAktif       : false,
    ultrasonicFront: false,
    ultrasonicBack : false,
    walkerActive   : false,
    status         : 'aman',
    geofenceStatus : 'inside',
    geofenceRadius : 100,
    geofenceCenter : LatLng(-7.051, 110.442),
    lastUpdate     : '-',
    langkah        : 0,
  );

  bool get isInSafeZone => geofenceStatus == 'inside';
}