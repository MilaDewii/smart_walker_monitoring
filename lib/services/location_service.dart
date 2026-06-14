// lib/services/location_service.dart
// Fix: gunakan dart:math untuk haversine (bukan Taylor approximation)

import 'package:firebase_database/firebase_database.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import '../models/location_data.dart';
import '../database/database_helper.dart';

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  bool _lastOutside = false;

  Stream<LocationData> watchLocation(String walkerId) {
    return FirebaseDatabase.instance
        .ref('Walkers/$walkerId')
        .onValue
        .map((event) {
      if (event.snapshot.value == null) return LocationData.empty();
      final raw = event.snapshot.value;
      if (raw is! Map) return LocationData.empty();
      return _parse(Map<dynamic, dynamic>.from(raw));
    });
  }

  LocationData _parse(Map<dynamic, dynamic> data) {
    final loc        = _asMap(data['location']);
    final lat        = _toDouble(loc['latitude'],  0.0);
    final lng        = _toDouble(loc['longitude'], 0.0);
    final lastUpdate = loc['last_update']?.toString()
                    ?? _asMap(data['status'])['last_update']?.toString()
                    ?? '-';

    final connected = _isRecent(lastUpdate, seconds: 180);

    final geo    = _asMap(data['geofence']);
    final geoLat = _toDouble(geo['center_latitude'],  0.0);
    final geoLng = _toDouble(geo['center_longitude'], 0.0);
    final radius = _toDouble(geo['radius'], 100);

    // ── Hitung dari Haversine ─────────────────────────────────────────────
    final bool isInSafeZone;
    if (lat == 0.0 && lng == 0.0) {
      isInSafeZone = true; // GPS belum fix
    } else if (geoLat == 0.0 && geoLng == 0.0) {
      isInSafeZone = true; // Geofence belum diatur
    } else {
      isInSafeZone = _haversine(lat, lng, geoLat, geoLng) <= radius;
    }

    final geoStatus = isInSafeZone ? 'inside' : 'outside';

    // Trigger event hanya saat baru keluar & GPS valid
    if (!isInSafeZone && !_lastOutside && lat != 0.0 && lng != 0.0) {
      _lastOutside = true;
      DatabaseHelper.instance.saveCacheHistory(
        type     : 'geofence',
        title    : 'Keluar Area Aman',
        subtitle : 'Lansia berada di luar radius geofence',
        status   : 'bahaya',
        latitude : lat,
        longitude: lng,
      );
    }
    if (isInSafeZone) _lastOutside = false;

    return LocationData(
      lansiaPos      : LatLng(lat, lng),
      geofenceCenter : LatLng(geoLat, geoLng),
      geofenceRadius : radius,
      geofenceStatus : geoStatus,
      lastUpdate     : lastUpdate,
      connected      : connected,
      isInSafeZone   : isInSafeZone,
    );
  }

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

  bool _isRecent(String ts, {int seconds = 180}) {
    try {
      final dt   = DateTime.parse(ts.replaceAll(' ', 'T'));
      return DateTime.now().difference(dt).inSeconds.abs() <= seconds;
    } catch (_) { return false; }
  }

  Map<dynamic, dynamic> _asMap(dynamic v) =>
      v is Map ? Map<dynamic, dynamic>.from(v) : {};

  double _toDouble(dynamic v, double fb) {
    if (v is num)    return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fb;
    return fb;
  }
}