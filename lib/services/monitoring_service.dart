import 'package:firebase_database/firebase_database.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import 'dart:async';
import '../models/walker_data.dart';
import '../models/alert_model.dart';
import 'history_service.dart';
import 'notification_service.dart';

class MonitoringService {
  MonitoringService._();
  static final MonitoringService instance = MonitoringService._();

  bool _lastFallState       = false;
  bool _lastWaspadaState    = false;
  bool _lastGeofenceOutside = false;
  bool _lastMendekatiState  = false;

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
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final parsed = _parse(data);

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
    // DARURAT: jatuh confirmed
    if (parsed.jatuh && !_lastFallState) {
      _lastFallState    = true;
      _lastWaspadaState = false;

      await HistoryService(walkerId: walkerId).saveHistory(
        eventType:   'fall_detection',
        description: 'Lansia terdeteksi jatuh',
      );

      await NotificationService(walkerId: walkerId).addNotification(
        AlertItem(
          id:          'notif_${DateTime.now().millisecondsSinceEpoch}',
          title:       'Peringatan Jatuh',
          level:       AlertLevel.darurat,
          time:        '',
          date:        '',
          description: 'Lansia terdeteksi jatuh (risiko: ${parsed.riskPercent}%)',
          score:       parsed.fallConfidence,
          durasiDetik: 0,
          sudahDibaca: false,
          location:    parsed.position,
          timestamp:   DateTime.now().toIso8601String(),
          rawDate:     DateTime.now().toString(),
        ),
      );
    }

    // WASPADA: miring/mau jatuh (fuzzyRisk >= 0.30, belum jatuh)
    final isWaspada = !parsed.jatuh && parsed.fuzzyRisk >= 0.30;
    if (isWaspada && !_lastWaspadaState && !_lastFallState) {
      _lastWaspadaState = true;

      await NotificationService(walkerId: walkerId).addNotification(
        AlertItem(
          id:          'notif_${DateTime.now().millisecondsSinceEpoch}',
          title:       'Gerakan Perlu Diperhatikan',
          level:       AlertLevel.waspada,
          time:        '',
          date:        '',
          description: 'Terdeteksi gerakan tidak normal (risiko: ${parsed.riskPercent}%)',
          score:       parsed.fuzzyRisk,
          durasiDetik: 0,
          sudahDibaca: false,
          location:    parsed.position,
          timestamp:   DateTime.now().toIso8601String(),
          rawDate:     DateTime.now().toString(),
        ),
      );
    }

    if (!parsed.jatuh) _lastFallState    = false;
    if (!isWaspada)    _lastWaspadaState = false;
  }

  // =========================================================
  // GEOFENCE
  // =========================================================
  Future<void> _handleGeofence(WalkerData parsed, String walkerId) async {
    final isOutside   = parsed.geofenceStatus == 'outside';
    final isMendekati = parsed.mendekatiGeofence;

    // DARURAT: keluar geofence
    if (isOutside && !_lastGeofenceOutside) {
      _lastGeofenceOutside = true;
      _lastMendekatiState  = false;

      await HistoryService(walkerId: walkerId).saveHistory(
        eventType:   'geofence',
        description: 'Lansia keluar zona aman',
      );

      await NotificationService(walkerId: walkerId).addNotification(
        AlertItem(
          id:          'notif_${DateTime.now().millisecondsSinceEpoch}',
          title:       'Keluar Area Aman',
          level:       AlertLevel.darurat,
          time:        '',
          date:        '',
          description: 'Lansia keluar area aman yang ditetapkan',
          score:       0,
          durasiDetik: 0,
          sudahDibaca: false,
          location:    parsed.position,
          timestamp:   DateTime.now().toIso8601String(),
          rawDate:     DateTime.now().toString(),
        ),
      );
    }

    // WASPADA: mendekati batas geofence (sisa <= 2m, masih inside)
    if (isMendekati && !_lastMendekatiState && !isOutside) {
      _lastMendekatiState = true;

      final sisa = (parsed.geofenceRadius - parsed.jarakDariPusat)
          .toStringAsFixed(1);

      await NotificationService(walkerId: walkerId).addNotification(
        AlertItem(
          id:          'notif_${DateTime.now().millisecondsSinceEpoch}',
          title:       'Mendekati Batas Area Aman',
          level:       AlertLevel.waspada,
          time:        '',
          date:        '',
          description: 'Lansia mendekati batas area aman, sisa $sisa m',
          score:       0,
          durasiDetik: 0,
          sudahDibaca: false,
          location:    parsed.position,
          timestamp:   DateTime.now().toIso8601String(),
          rawDate:     DateTime.now().toString(),
        ),
      );
    }

    if (!isOutside)   _lastGeofenceOutside = false;
    if (!isMendekati) _lastMendekatiState  = false;
  }

  // =========================================================
  // PARSE FIREBASE DATA
  // =========================================================
  WalkerData _parse(Map<dynamic, dynamic> data) {

    // fall_detetction (typo di ESP32)
    final fall = _asMap(
      data['fall_detetction'] ?? data['fall_detection'],
    );

    final jatuh      = fall['fall_detected'] == true || fall['jatuh'] == true;
    final confidence = _toDouble(fall['confidence'],  0);
    final impact     = _toDouble(fall['impact'],      0);
    final fuzzyRisk  = _toDouble(fall['fuzzy_risk'],  0);
    final gyroPeak   = _toDouble(fall['gyro_peak'],   0);
    final azFiltered = _toDouble(fall['az_filtered'], 1.0);
    final diamDetik  = _toDouble(fall['diam_detik'],  0);

    // Status berdasarkan fuzzyRisk
    final String status;
    if (jatuh || fuzzyRisk >= 0.45) {
      status = 'bahaya';
    } else if (fuzzyRisk >= 0.30) {
      status = 'waspada';
    } else {
      status = 'normal';
    }

    // Lokasi
    final loc        = _asMap(data['location']);
    final lat        = _toDouble(loc['latitude'],    0);
    final lng        = _toDouble(loc['longitude'],   0);
    final lastUpdate = loc['last_update']?.toString() ?? '-';

    // Geofence
    final geo    = _asMap(data['geofence']);
    final geoLat = _toDouble(geo['center_latitude'],  0);
    final geoLng = _toDouble(geo['center_longitude'], 0);
    final radius = _toDouble(geo['radius'],           100);

    // Hitung jarak dari pusat geofence
    final jarakDariPusat = (lat == 0 || lng == 0 || geoLat == 0 || geoLng == 0)
        ? 0.0
        : _haversine(lat, lng, geoLat, geoLng);

    final isInSafeZone = (lat == 0 || lng == 0 || geoLat == 0 || geoLng == 0)
        ? true
        : jarakDariPusat <= radius;

    // Sensors
    final sensors  = _asMap(data['sensors']);
    final sim808   = _asMap(sensors['sim808']);
    final gpsAktif = sim808['gps_status'] == true
        || sensors['gps_active'] == true;

    // Langkah
    final activity = _asMap(data['activity']);

    final langkah =
        _toInt(activity['langkah'], 0) + _toInt(activity['steps'], 0);

    // ultrasonicBack: true jika user_detected = true
    final hcsrBack   = _asMap(sensors['hcsr04_back']);
    final hcsrFront  = _asMap(sensors['hcsr04_front']);
    final ultraBack  = hcsrBack['user_detected']      == true;
    final ultraFront = hcsrFront['obstacle_detected'] == true;

    return WalkerData(
      position:        LatLng(lat, lng),
      jatuh:           jatuh,
      fallConfidence:  confidence,
      fallImpact:      impact,
      fuzzyRisk:       fuzzyRisk,
      gyroPeak:        gyroPeak,
      azFiltered:      azFiltered,
      diamDetik:       diamDetik,
      gpsAktif:        gpsAktif,
      mpuAktif:        sensors['mpu_active'] == true,
      ultrasonicFront: ultraFront,
      ultrasonicBack:  ultraBack,
      walkerActive:    data['walker_active'] == true,
      status:          status,
      geofenceStatus:  isInSafeZone ? 'inside' : 'outside',
      geofenceRadius:  radius,
      geofenceCenter:  LatLng(geoLat, geoLng),
      jarakDariPusat:  jarakDariPusat,
      lastUpdate:      lastUpdate,
      langkah:         langkah,
    );
  }

  // =========================================================
  // HELPERS
  // =========================================================
  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r    = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a    = math.pow(math.sin(dLat / 2), 2) +
                 math.cos(_rad(lat1)) * math.cos(_rad(lat2)) *
                 math.pow(math.sin(dLon / 2), 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _rad(double deg) => deg * math.pi / 180;

  Map<dynamic, dynamic> _asMap(dynamic v) {
    if (v is Map) {
      return Map<dynamic, dynamic>.from(v);
    }
    return {};
  }

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

  void stopMonitoring() => _eventSub?.cancel();
}