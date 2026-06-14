// lib/services/monitoring_service.dart
// Fix:
//  1. geofenceStatus dihitung dari Haversine, BUKAN dari geo['status'] RTD
//  2. position diambil dari location/latitude & longitude (untuk marker lansia)
//  3. lastUpdate dari location/last_update (bukan root)

import 'package:firebase_database/firebase_database.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
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
    // ── fall_detection ─────────────────────────────────────────────────────
    // Handle typo 'fall_detetction' dan nama benar 'fall_detection'
    final fall       = _asMap(data['fall_detection'] ?? data['fall_detetction']);
    final jatuh      = fall['fall_detected'] == true;
    final confidence = _toDouble(fall['confidence'], 0);
    final impact     = _toDouble(fall['impact_value'], 0);

    // ── location ───────────────────────────────────────────────────────────
    final loc        = _asMap(data['location']);
    final lat        = _toDouble(loc['latitude'],  0.0);
    final lng        = _toDouble(loc['longitude'], 0.0);
    // Ambil lastUpdate dari location/last_update dulu, fallback ke status/last_update
    final lastUpdate = loc['last_update']?.toString()
                    ?? _asMap(data['status'])['last_update']?.toString()
                    ?? data['last_update']?.toString()
                    ?? '-';

    // ── geofence ───────────────────────────────────────────────────────────
    final geo    = _asMap(data['geofence']);
    final geoLat = _toDouble(geo['center_latitude'],  0.0);
    final geoLng = _toDouble(geo['center_longitude'], 0.0);
    final radius = _toDouble(geo['radius'], 100);

    // ── Hitung geofenceStatus dari Haversine, BUKAN dari geo['status'] ────
    // Ini penting supaya langsung update saat geofence diubah di app
    // tanpa harus menunggu ESP update field 'status' di RTD
    final bool isInSafeZone;
    if (lat == 0.0 && lng == 0.0) {
      // GPS belum fix → anggap aman supaya tidak false alarm
      isInSafeZone = true;
    } else if (geoLat == 0.0 && geoLng == 0.0) {
      // Geofence belum diatur
      isInSafeZone = true;
    } else {
      final dist = _haversine(lat, lng, geoLat, geoLng);
      isInSafeZone = dist <= radius;
    }
    final geoStatus = isInSafeZone ? 'inside' : 'outside';

    // ── sensors ────────────────────────────────────────────────────────────
    final sensors    = _asMap(data['sensors']);
    final mpuAktif   = sensors['mpu6050']      is Map;
    final ultraFront = sensors['hcsr04_front'] is Map;
    final ultraBack  = sensors['hcsr04_back']  is Map;

    // GPS aktif — cek dari sim808 atau sensors
    final sim808   = _asMap(data['sim808']);
    final gpsAktif = sim808['gps_status'] == true
                  || sensors['gps_active'] == true;

    // ── status walker ──────────────────────────────────────────────────────
    final statusNode   = _asMap(data['status']);
    final walkerActive = statusNode['walker_active'] == true
                      || statusNode['connected'] == true
                      || data['walker_active'] == true;

    // ── Tentukan status string ─────────────────────────────────────────────
    final String statusStr;
    if (jatuh || !isInSafeZone) {
      statusStr = 'bahaya';
    } else if (confidence >= 0.4) {
      statusStr = 'peringatan';
    } else {
      final rawStatus = statusNode['geofance_status']?.toString()
                     ?? data['status']?.toString()
                     ?? 'normal';
      if (rawStatus == 'danger'  || rawStatus == 'bahaya')    statusStr = 'bahaya';
      else if (rawStatus == 'warning' || rawStatus == 'peringatan') statusStr = 'peringatan';
      else statusStr = 'normal';
    }

    // ── activity ───────────────────────────────────────────────────────────
    final activity = _asMap(data['activity']);
    final langkah  = _toInt(activity['langkah'], 0)
                   + _toInt(activity['steps'],   0);

    return WalkerData(
      position       : LatLng(lat, lng),
      jatuh          : jatuh,
      fallConfidence : confidence,
      fallImpact     : impact,
      gpsAktif       : gpsAktif,
      mpuAktif       : mpuAktif,
      ultrasonicFront: ultraFront,
      ultrasonicBack : ultraBack,
      walkerActive   : walkerActive,
      status         : statusStr,
      geofenceStatus : geoStatus,   // ← dari Haversine, bukan RTD field
      geofenceRadius : radius,
      geofenceCenter : LatLng(geoLat, geoLng),
      lastUpdate     : lastUpdate,
      langkah        : langkah,
    );
  }

  // ── Haversine distance dalam meter ────────────────────────────────────────
  double _haversine(double lat1, double lng1, double lat2, double lng2) {
    const r    = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a    = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_rad(lat1)) * math.cos(_rad(lat2)) *
        math.pow(math.sin(dLng / 2), 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _rad(double deg) => deg * math.pi / 180;

  Map<dynamic, dynamic> _asMap(dynamic v) =>
      v is Map ? Map<dynamic, dynamic>.from(v) : {};

  double _toDouble(dynamic v, double fb) {
    if (v is num)    return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fb;
    return fb;
  }

  int _toInt(dynamic v, int fb) {
    if (v is num)    return v.toInt();
    if (v is String) return int.tryParse(v) ?? fb;
    return fb;
  }
}