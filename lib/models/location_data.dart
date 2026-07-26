import 'package:latlong2/latlong.dart';

/// Model data lokasi lansia + geofence, dipakai oleh LocationService,
/// LocationCard, dan LocationScreen.
///
/// geofenceStatus: 'inside' | 'mendekati' | 'outside'
///   - inside    : di dalam area aman, jarak ke garis > _mendekatiThreshold
///   - mendekati : masih di dalam area aman, tapi sisa jarak ke garis
///                 <= _mendekatiThreshold (default 2 meter) -> KUNING
///   - outside   : sudah keluar area aman -> MERAH
class LocationData {
  final LatLng  lansiaPos;
  final LatLng  geofenceCenter;
  final double  geofenceRadius;
  final String  geofenceStatus;
  final String  lastUpdate;
  final bool    connected;
  final bool    isInSafeZone;

  /// true kalau masih di dalam area tapi sisa jarak ke garis <= threshold
  final bool    mendekatiGeofence;

  /// jarak lurus (meter) dari posisi lansia ke titik pusat geofence
  final double  jarakDariPusat;

  const LocationData({
    required this.lansiaPos,
    required this.geofenceCenter,
    required this.geofenceRadius,
    required this.geofenceStatus,
    required this.lastUpdate,
    required this.connected,
    required this.isInSafeZone,
    required this.mendekatiGeofence,
    required this.jarakDariPusat,
  });

  factory LocationData.empty() => const LocationData(
        lansiaPos        : LatLng(0.0, 0.0),
        geofenceCenter   : LatLng(0.0, 0.0),
        geofenceRadius   : 100,
        geofenceStatus   : 'inside',
        lastUpdate       : '-',
        connected        : false,
        isInSafeZone     : true,
        mendekatiGeofence: false,
        jarakDariPusat   : 0.0,
      );

  /// Sisa jarak (meter) dari posisi lansia ke garis geofence.
  /// Positif = masih di dalam, negatif = sudah di luar.
  double get sisaJarakKeGaris => geofenceRadius - jarakDariPusat;
}