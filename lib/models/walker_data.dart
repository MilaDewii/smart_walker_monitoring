import 'package:latlong2/latlong.dart';

class WalkerData {
  final LatLng  position;
  final bool    jatuh;
  final double  fallConfidence;
  final double  fallImpact;
  final double  fuzzyRisk;      // 0.0–1.0 dari Firebase fuzzy_risk
  final double  gyroPeak;       // °/s dari Firebase gyro_peak
  final double  azFiltered;     // g dari Firebase az_filtered
  final double  diamDetik;
  final double jarakDariPusat;      // detik dari Firebase diam_detik
  final bool    gpsAktif;
  final bool    mpuAktif;
  final bool    ultrasonicFront;
  final bool    ultrasonicBack;
  final bool    walkerActive;
  final String  status;          // 'normal' | 'waspada' | 'bahaya'
  final String  geofenceStatus;  // 'inside' | 'outside'
  final double  geofenceRadius;
  final LatLng  geofenceCenter;
  final String  lastUpdate;
  final int     langkah;


  const WalkerData({
    required this.position,
    required this.jatuh,
    required this.fallConfidence,
    required this.fallImpact,
    required this.fuzzyRisk,
    required this.gyroPeak,
    required this.azFiltered,
    required this.diamDetik,
    required this.jarakDariPusat,
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
    position        : LatLng(-7.051234, 110.442123),
    jatuh           : false,
    fallConfidence  : 0,
    fallImpact      : 0,
    fuzzyRisk       : 0,
    gyroPeak        : 0,
    azFiltered      : 1.0,
    diamDetik       : 0,
    jarakDariPusat  : 0,
    gpsAktif        : false,
    mpuAktif        : false,
    ultrasonicFront : false,
    ultrasonicBack  : false,
    walkerActive    : false,
    status          : 'normal',
    geofenceStatus  : 'inside',
    geofenceRadius  : 100,
    geofenceCenter  : LatLng(-7.051, 110.442),
    lastUpdate      : '-',
    langkah         : 0,
  );

  bool get isInSafeZone => geofenceStatus == 'inside';

  // Helper label untuk UI
  // Berdasarkan fuzzyRisk (lebih akurat dari sekedar bool jatuh)
  String get statusLabel {
    if (jatuh || fuzzyRisk >= 0.45) return 'bahaya';
    if (fuzzyRisk >= 0.30)          return 'waspada';
    return 'normal';
  }

  bool get mendekatiGeofence =>
    geofenceStatus == 'inside' &&
    geofenceRadius > 0 &&
    (geofenceRadius - jarakDariPusat) <= 2.0;

  // Persentase risiko untuk progress bar (0–100)
  int get riskPercent => (fuzzyRisk * 100).round().clamp(0, 100);
}