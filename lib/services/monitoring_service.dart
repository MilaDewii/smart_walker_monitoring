import 'package:firebase_database/firebase_database.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import 'dart:async';
import '../models/walker_data.dart';

class MonitoringService {
  MonitoringService._();
  static final MonitoringService instance = MonitoringService._();

  // =========================================================
  // WATCH DATA REALTIME
  // =========================================================
  // Dipakai UI (LocationCard/StatusBanner di MonitoringScreen) untuk
  // nampilin data walker secara realtime.
  //
  // DIDEBOUNCE: tanpa ini, setiap sensor ESP32 update (~2x/detik),
  // seluruh payload node walker di-serialize ulang lewat platform
  // channel dan memicu setState() di MonitoringScreen yang me-rebuild
  // SELURUH screen (termasuk peta di LocationCard) 2x/detik — inilah
  // yang menyebabkan ANR.
  //
  // CATATAN PENTING (perubahan arsitektur):
  // MonitoringService TIDAK LAGI menulis notifikasi/history untuk
  // fall detection & geofence. Sebelumnya ada _handleFallDetection()
  // dan _handleGeofence() yang mendengarkan perubahan data lalu
  // menulis addNotification()/saveHistory() sendiri dari sisi Flutter.
  //
  // Ini DIHAPUS karena:
  // 1. ESP32 SUDAH menulis notifikasi (pushNotification()) dan history
  //    (pushHistory()) langsung ke Firebase dengan skema lengkap &
  //    konsisten (title, category, status, timestamp, sensor data, dll)
  //    setiap kali event jatuh/geofence terdeteksi — lihat checkFall()
  //    dan checkGeofence() di firmware.
  // 2. Versi Flutter (yang dihapus) menulis lewat HistoryService.
  //    saveHistory() yang skemanya TIDAK KOMPATIBEL dengan yang dibaca
  //    HistoryItem.fromRtd() (field 'event_type'/'description' vs yang
  //    diharapkan 'category'/'title'/'timestamp') — menyebabkan history
  //    item muncul dengan title generik "Kejadian", kategori salah
  //    (fallback ke 'sensor'), dan tidak bisa dicocokkan lewat
  //    findByNotification() saat user tap "Lihat Detail" dari halaman
  //    Notifikasi.
  // 3. Kedua sumber (ESP32 + Flutter) mendengarkan perubahan data yang
  //    SAMA, sehingga berpotensi menghasilkan notifikasi & history
  //    DOBEL untuk satu kejadian fisik yang sama.
  //
  // Jadi sekarang: MonitoringService HANYA bertugas menyediakan data
  // WalkerData untuk ditampilkan di UI (MonitoringScreen, LocationCard,
  // dll). Ini tidak mengurangi tampilan status jatuh/geofence real-time
  // sama sekali — badge "Jatuh Terdeteksi!", warna lingkaran geofence,
  // progress bar risiko, dan status sensor tetap tampil normal karena
  // semua itu dibaca LANGSUNG dari data sensor (fall_detetction/*,
  // geofence/*) lewat watchWalker() ini, bukan dari notifikasi/history.
  Stream<WalkerData> watchWalker(String walkerId) {
    late StreamController<WalkerData> controller;
    StreamSubscription<DatabaseEvent>? sub;
    Timer? debounceTimer;
    DatabaseEvent? pendingEvent;

    void emit() {
      final ev = pendingEvent;
      if (ev == null || controller.isClosed) return;

      if (ev.snapshot.value == null) {
        controller.add(WalkerData.empty());
        return;
      }
      final raw = ev.snapshot.value;
      if (raw is! Map) {
        controller.add(WalkerData.empty());
        return;
      }
      controller.add(_parse(Map<dynamic, dynamic>.from(raw)));
    }

    controller = StreamController<WalkerData>.broadcast(
      onListen: () {
        sub = FirebaseDatabase.instance
            .ref('Walkers/$walkerId')
            .onValue
            .listen((event) {
          pendingEvent = event;
          debounceTimer?.cancel();
          // 1 detik cukup untuk data monitoring lansia — tidak perlu
          // update sub-detik, dan ini yang paling menentukan seberapa
          // sering seluruh screen rebuild.
          debounceTimer = Timer(const Duration(seconds: 1), emit);
        }, onError: (e) {
          if (!controller.isClosed) controller.addError(e);
        });
      },
      onCancel: () {
        debounceTimer?.cancel();
        sub?.cancel();
      },
    );

    return controller.stream;
  }

  // =========================================================
  // PARSE FIREBASE DATA
  // =========================================================
  WalkerData _parse(Map<dynamic, dynamic> data) {
    // fall_detetction (typo di ESP32)
    final fall = _asMap(
      data['fall_detetction'] ?? data['fall_detection'],
    );

    final jatuh = fall['fall_detected'] == true || fall['jatuh'] == true;
    final confidence = _toDouble(fall['confidence'], 0);
    final impact = _toDouble(fall['impact'], 0);
    final fuzzyRisk = _toDouble(fall['fuzzy_risk'], 0);
    final gyroPeak = _toDouble(fall['gyro_peak'], 0);
    final azFiltered = _toDouble(fall['az_filtered'], 1.0);
    final diamDetik = _toDouble(fall['diam_detik'], 0);

    // Status berdasarkan fuzzyRisk
    final String status;
    if (jatuh || fuzzyRisk >= 0.45) {
      status = 'darurat';
    } else if (fuzzyRisk >= 0.30) {
      status = 'waspada';
    } else {
      status = 'normal';
    }

    // Lokasi
    final loc = _asMap(data['location']);
    final lat = _toDouble(loc['latitude'], 0);
    final lng = _toDouble(loc['longitude'], 0);
    final lastUpdate = loc['last_update']?.toString() ?? '-';

    // Geofence
    final geo = _asMap(data['geofence']);
    final geoLat = _toDouble(geo['center_latitude'], 0);
    final geoLng = _toDouble(geo['center_longitude'], 0);
    final radius = _toDouble(geo['radius'], 100);

    // Hitung jarak dari pusat geofence
    final jarakDariPusat = (lat == 0 || lng == 0 || geoLat == 0 || geoLng == 0)
        ? 0.0
        : _haversine(lat, lng, geoLat, geoLng);

    final isInSafeZone = (lat == 0 || lng == 0 || geoLat == 0 || geoLng == 0)
        ? true
        : jarakDariPusat <= radius;

    // Sensors
    final sensors = _asMap(data['sensors']);
    final sim808 = _asMap(sensors['sim808']);
    final gpsAktif =
        sim808['gps_status'] == true || sensors['gps_active'] == true;

    // Langkah
    final activity = _asMap(data['activity']);

    final langkah =
        _toInt(activity['langkah'], 0) + _toInt(activity['steps'], 0);

    // ultrasonicBack: true jika user_detected = true
    final hcsrBack = _asMap(sensors['hcsr04_back']);
    final hcsrFront = _asMap(sensors['hcsr04_front']);
    final ultraBack = hcsrBack['user_detected'] == true;
    final ultraFront = hcsrFront['obstacle_detected'] == true;

    return WalkerData(
      position: LatLng(lat, lng),
      jatuh: jatuh,
      fallConfidence: confidence,
      fallImpact: impact,
      fuzzyRisk: fuzzyRisk,
      gyroPeak: gyroPeak,
      azFiltered: azFiltered,
      diamDetik: diamDetik,
      jarakDariPusat: jarakDariPusat,
      gpsAktif: gpsAktif,
      mpuAktif: sensors['mpu_active'] == true,
      ultrasonicFront: ultraFront,
      ultrasonicBack: ultraBack,
      walkerActive: data['walker_active'] == true,
      status: status,
      geofenceStatus: isInSafeZone ? 'inside' : 'outside',
      geofenceRadius: radius,
      geofenceCenter: LatLng(geoLat, geoLng),
      lastUpdate: lastUpdate,
      langkah: langkah,
    );
  }

  // =========================================================
  // HELPERS
  // =========================================================
  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
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
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  int _toInt(dynamic v, int fallback) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }
}