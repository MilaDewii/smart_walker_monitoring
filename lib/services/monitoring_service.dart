import 'package:firebase_database/firebase_database.dart';
import 'package:latlong2/latlong.dart';
import '../models/walker_data.dart';

class MonitoringService {
  MonitoringService._();
  static final MonitoringService instance = MonitoringService._();

  Stream<WalkerData> watchWalker(String walkerId) {
    return FirebaseDatabase.instance
        .ref('Walkers/$walkerId')
        .onValue
        .map((event) {
      if (event.snapshot.value == null) return WalkerData.empty();
      final raw = event.snapshot.value;
      if (raw is! Map) return WalkerData.empty();
      return _parse(Map<dynamic, dynamic>.from(raw));
    });
  }

  WalkerData _parse(Map<dynamic, dynamic> data) {
    // ── fall_detecion (typo di RTD kamu) ──
    final fall       = _asMap(data['fall_detecion']);
    final jatuh      = fall['fall_detected'] == true;
    final confidence = _toDouble(fall['confidence'], 0);
    final impact     = _toDouble(fall['impact_value'], 0);

    // ── location ──
    final loc        = _asMap(data['location']);
    final lat        = _toDouble(loc['latitude'],  -7.051234);
    final lng        = _toDouble(loc['longitude'], 110.442123);
    final lastUpdate = loc['last_update']?.toString() ?? '-';

    // ── geofence ──
    final geo        = _asMap(data['geofence']);
    final geoLat     = _toDouble(geo['center_latitude'],  -7.051);
    final geoLng     = _toDouble(geo['center_longitude'], 110.442);
    final radius     = _toDouble(geo['radius'], 100);
    final geoStatus  = geo['status']?.toString() ?? 'inside';

    // ── sensors ──
    final sensors    = _asMap(data['sensors']);
    final mpuAktif   = sensors['mpu6050']      != null;
    final ultraFront = sensors['hcsr04_front']  != null;
    final ultraBack  = sensors['hcsr04_back']   != null;

    // ── status ──
    final st           = _asMap(data['status']);
    final connected    = st['connected']       == true;
    final walkerActive = st['walker_active']   == true;
    final fallDet      = st['fall_detected']   == true;
    final anomaly      = st['anomaly_detected']== true;

    // ── activity ──
    final activity = _asMap(data['activity']);
    final langkah  = _toInt(activity['steps'], 0);

    final String statusStr;
    if (fallDet)       statusStr = 'bahaya';
    else if (anomaly)  statusStr = 'peringatan';
    else               statusStr = 'aman';

    return WalkerData(
      position       : LatLng(lat, lng),
      jatuh          : jatuh,
      fallConfidence : confidence,
      fallImpact     : impact,
      gpsAktif       : connected,
      mpuAktif       : mpuAktif,
      ultrasonicFront: ultraFront,
      ultrasonicBack : ultraBack,
      walkerActive   : walkerActive,
      status         : statusStr,
      geofenceStatus : geoStatus,
      geofenceRadius : radius,
      geofenceCenter : LatLng(geoLat, geoLng),
      lastUpdate     : lastUpdate,
      langkah        : langkah,
    );
  }

  Map<dynamic, dynamic> _asMap(dynamic v) =>
      v is Map ? Map<dynamic, dynamic>.from(v) : {};

  double _toDouble(dynamic v, double fallback) {
    if (v is num)    return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  int _toInt(dynamic v, int fallback) {
    if (v is num)    return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }
}