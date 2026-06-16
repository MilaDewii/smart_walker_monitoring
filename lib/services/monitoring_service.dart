import 'package:firebase_database/firebase_database.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import '../models/walker_data.dart';
import 'history_service.dart';
import 'notification_service.dart';
import '../models/alert_model.dart';
import 'dart:async';

class MonitoringService {
  MonitoringService._();
  static final MonitoringService instance = MonitoringService._();

  bool _lastFallState = false;
  bool _lastGeofenceOutside = false;

  StreamSubscription? _eventSub;

  // =========================================================
  // WATCH DATA REALTIME
  // =========================================================
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

  // =========================================================
  // START MONITORING EVENT
  // =========================================================
  void startEventMonitoring(String walkerId) {
    _eventSub?.cancel();

    _eventSub = FirebaseDatabase.instance
        .ref('Walkers/$walkerId')
        .onValue
        .listen((event) async {
      if (event.snapshot.value == null) return;

      final data = Map<dynamic, dynamic>.from(
        event.snapshot.value as Map,
      );

      final parsed = _parse(data);

      print("MONITORING ACTIVE");
      print("Fall: ${parsed.jatuh}");
      print("Geofence: ${parsed.geofenceStatus}");

      await _handleFallDetection(parsed, walkerId);
      await _handleGeofence(parsed, walkerId);
    });
  }

  // =========================================================
  // FALL DETECTION
  // =========================================================
  Future<void> _handleFallDetection(
    WalkerData parsed,
    String walkerId,
  ) async {
    // baru jatuh (false -> true)
    if (parsed.jatuh && !_lastFallState) {
      _lastFallState = true;

      print("FALL DETECTED");

      await HistoryService(
        walkerId: walkerId,
      ).saveHistory(
        eventType: "fall_detection",
        description: "Lansia terdeteksi jatuh",
      );

      await NotificationService(
        walkerId: walkerId,
      ).addNotification(
        AlertItem(
          id: "notif_${DateTime.now().millisecondsSinceEpoch}",
          title: "Peringatan Jatuh",
          level: AlertLevel.darurat,
          time: "",
          date: "",
          description: "Lansia terdeteksi jatuh",
          score: parsed.fallConfidence,
          durasiDetik: 0,
          sudahDibaca: false,
          location: parsed.position,
          timestamp: DateTime.now().toIso8601String(),
          rawDate: DateTime.now().toString(),
        ),
      );
    }

    // reset state
    if (!parsed.jatuh) {
      _lastFallState = false;
    }
  }

  // =========================================================
  // GEOFENCE
  // =========================================================
  Future<void> _handleGeofence(
    WalkerData parsed,
    String walkerId,
  ) async {
    bool isOutside = parsed.geofenceStatus == "outside";

    // baru keluar zona
    if (isOutside && !_lastGeofenceOutside) {
      _lastGeofenceOutside = true;

      print("OUTSIDE GEOFENCE");

      await HistoryService(
        walkerId: walkerId,
      ).saveHistory(
        eventType: "geofence",
        description: "Lansia keluar zona aman",
      );

      await NotificationService(
        walkerId: walkerId,
      ).addNotification(
        AlertItem(
          id: "notif_${DateTime.now().millisecondsSinceEpoch}",
          title: "Geofence Warning",
          level: AlertLevel.tinggi,
          time: "",
          date: "",
          description: "Lansia keluar area aman",
          score: 0,
          durasiDetik: 0,
          sudahDibaca: false,
          location: parsed.position,
          timestamp: DateTime.now().toIso8601String(),
          rawDate: DateTime.now().toString(),
        ),
      );
    }

    // reset kalau balik masuk zona
    if (!isOutside) {
      _lastGeofenceOutside = false;
    }
  }

  // =========================================================
  // PARSE FIREBASE DATA
  // =========================================================
  WalkerData _parse(Map<dynamic, dynamic> data) {
    final fall = _asMap(
      data['fall_detection'] ?? data['fall_detetction'],
    );

    final jatuh = fall['fall_detected'] == true;
    final confidence = _toDouble(fall['confidence'], 0);
    final impact = _toDouble(fall['impact_value'], 0);

    final loc = _asMap(data['location']);
    final lat = _toDouble(loc['latitude'], 0);
    final lng = _toDouble(loc['longitude'], 0);

    final lastUpdate = loc['last_update']?.toString() ??
        _asMap(data['status'])['last_update']?.toString() ??
        "-";

    final geo = _asMap(data['geofence']);
    final geoLat = _toDouble(geo['center_latitude'], 0);
    final geoLng = _toDouble(geo['center_longitude'], 0);
    final radius = _toDouble(geo['radius'], 100);

    bool isInSafeZone;

    if (lat == 0 || lng == 0) {
      isInSafeZone = true;
    } else if (geoLat == 0 || geoLng == 0) {
      isInSafeZone = true;
    } else {
      double dist = _haversine(lat, lng, geoLat, geoLng);
      isInSafeZone = dist <= radius;
    }

    String geoStatus = isInSafeZone ? "inside" : "outside";

    final sensors = _asMap(data['sensors']);

    final sim808 = _asMap(data['sim808']);
    final gpsAktif =
        sim808['gps_status'] == true || sensors['gps_active'] == true;

    final activity = _asMap(data['activity']);

    final langkah =
        _toInt(activity['langkah'], 0) + _toInt(activity['steps'], 0);

    return WalkerData(
      position: LatLng(lat, lng),
      jatuh: jatuh,
      fallConfidence: confidence,
      fallImpact: impact,
      gpsAktif: gpsAktif,
      mpuAktif: sensors['mpu6050'] is Map,
      ultrasonicFront: sensors['hcsr04_front'] is Map,
      ultrasonicBack: sensors['hcsr04_back'] is Map,
      walkerActive: true,
      status: jatuh ? "bahaya" : "normal",
      geofenceStatus: geoStatus,
      geofenceRadius: radius,
      geofenceCenter: LatLng(geoLat, geoLng),
      lastUpdate: lastUpdate,
      langkah: langkah,
    );
  }

  // =========================================================
  // HAVERSINE
  // =========================================================
  double _haversine(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371000.0;

    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);

    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.pow(math.sin(dLon / 2), 2);

    return r *
        2 *
        math.atan2(
          math.sqrt(a),
          math.sqrt(1 - a),
        );
  }

  double _rad(double deg) => deg * math.pi / 180;

  Map<dynamic, dynamic> _asMap(dynamic v) {
    if (v is Map) {
      return Map<dynamic, dynamic>.from(v);
    }
    return {};
  }

  double _toDouble(dynamic v, double fallback) {
    if (v is num) return v.toDouble();
    if (v is String) {
      return double.tryParse(v) ?? fallback;
    }
    return fallback;
  }

  int _toInt(dynamic v, int fallback) {
    if (v is num) return v.toInt();
    if (v is String) {
      return int.tryParse(v) ?? fallback;
    }
    return fallback;
  }

  void stopMonitoring() {
    _eventSub?.cancel();
  }
}
