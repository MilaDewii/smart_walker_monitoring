// lib/services/history_service.dart
// ============================================================
// Stream history dari Firebase RTD node:
//   Walkers/{walkerId}/history/{id}
//
// Fix: passing context (sim808, sensors, geofence, location)
// dari parent walker ke setiap history item supaya data
// seperti GPS status, koordinat, sensor tidak kosong.
// ============================================================

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../models/history_model.dart';

class HistoryService {
  final String walkerId;

  HistoryService({required this.walkerId});

  // ── Stream semua history item ──────────────────────────────
  Stream<List<HistoryItem>> historyStream() {
    // Listen ke seluruh node walker sekaligus supaya bisa
    // pakai data sim808 / sensors / geofence / location
    // sebagai konteks untuk setiap history item
    return FirebaseDatabase.instance
        .ref('Walkers/$walkerId')
        .onValue
        .map((event) {
      if (event.snapshot.value == null) return <HistoryItem>[];
      final raw = event.snapshot.value;
      if (raw is! Map) return <HistoryItem>[];

      final walkerData = Map<dynamic, dynamic>.from(raw);

      // ── Ambil context dari parent walker ──
      final walkerContext = _buildContext(walkerData);

      // ── Parse history items ──
      final historyRaw = walkerData['history'];
      if (historyRaw == null || historyRaw is! Map) return <HistoryItem>[];

      final items = <HistoryItem>[];
      for (final entry in (historyRaw as Map).entries) {
        final id = entry.key.toString();
        final value = entry.value;
        if (value is! Map) continue;

        try {
          // Merge context ke dalam tiap history item
          final merged = _mergeContext(
            Map<dynamic, dynamic>.from(value),
            walkerContext,
          );
          items.add(HistoryItem.fromRtd(id, merged));
        } catch (e) {
          debugPrint('[HistoryService] skip $id: $e');
        }
      }

      items.sort((a, b) {
        final cmpDate = b.date.compareTo(a.date);
        if (cmpDate != 0) return cmpDate;
        return b.time.compareTo(a.time);
      });

      return items;
    });
  }

  // ── One-time fetch ─────────────────────────────────────────
  Future<List<HistoryItem>> fetchOnce() async {
    final snapshot =
        await FirebaseDatabase.instance.ref('Walkers/$walkerId').get();

    if (!snapshot.exists || snapshot.value == null) return [];
    final raw = snapshot.value;
    if (raw is! Map) return [];

    final walkerData = Map<dynamic, dynamic>.from(raw);
    final walkerContext = _buildContext(walkerData);

    final historyRaw = walkerData['history'];
    if (historyRaw == null || historyRaw is! Map) return [];

    final items = <HistoryItem>[];
    for (final entry in (historyRaw as Map).entries) {
      final id = entry.key.toString();
      final value = entry.value;
      if (value is! Map) continue;
      try {
        final merged = _mergeContext(
          Map<dynamic, dynamic>.from(value),
          walkerContext,
        );
        debugPrint('===================');
        debugPrint('History ID : $id');
        debugPrint('Data       : $merged');
        items.add(HistoryItem.fromRtd(id, merged));
      } catch (e) {
        debugPrint('[HistoryService] fetchOnce skip $id: $e');
      }
    }

    items.sort((a, b) {
      final cmpDate = b.date.compareTo(a.date);
      if (cmpDate != 0) return cmpDate;
      return b.time.compareTo(a.time);
    });

    return items;
  }

  // ── Build context dari parent walker node ──────────────────
  // Mengambil data yang relevan dari sim808, sensors,
  // geofence, location untuk dipakai sebagai fallback
  // di history item yang tidak punya field lengkap
  Map<String, dynamic> _buildContext(Map<dynamic, dynamic> walker) {
    final sim808 = _asMap(walker['sim808']);
    final sensors = _asMap(walker['sensors']);
    final geofence = _asMap(walker['geofence']);
    final location = _asMap(walker['location']);
    final status = _asMap(walker['status']);
    final mpu6050 = _asMap(sensors['mpu6050']);
    final hcsrBack = _asMap(sensors['hcsr04_back']);
    final hcsrFront = _asMap(sensors['hcsr04_front']);

    return {
      // sim808 → status sistem
      '_ctx_gsmConnected': sim808['internet_status'] == true ||
          (sim808['gsm_signal'] != null &&
              _toDouble(sim808['gsm_signal'], 0) > 0),
      '_ctx_gpsConnected': sim808['gps_status'] == true,
      '_ctx_imuNormal': status['anomaly_detected'] != true,

      // location → koordinat fallback
      '_ctx_lokasiKoordinat': location['latitude'] != null
          ? '${location['latitude']},${location['longitude']}'
          : null,

      // geofence → kondisi & jarak
      '_ctx_kondisiGeofence': geofence['status']?.toString() ?? '-',
      '_ctx_jarakDariPusat': geofence['jarakDariPusat'] != null
          ? '${_toDouble(geofence['jarakDariPusat'], 0).toStringAsFixed(1)} m'
          : null,

      // sensors → distanceData fallback
      '_ctx_hcsrBack': hcsrBack['distance'],
      '_ctx_hcsrFront': hcsrFront['distance'],

      // mpu6050 → sensorData fallback
      '_ctx_accel_x': mpu6050['accel_x'],
      '_ctx_accel_y': mpu6050['accel_y'],
      '_ctx_accel_z': mpu6050['accel_z'],
      '_ctx_gyro_x': mpu6050['gyro_x'],
      '_ctx_gyro_y': mpu6050['gyro_y'],
      '_ctx_gyro_z': mpu6050['gyro_z'],
    };
  }

  // ── Merge context ke history item ─────────────────────────
  // Hanya isi field yang kosong/null di history item
  Map<dynamic, dynamic> _mergeContext(
    Map<dynamic, dynamic> item,
    Map<String, dynamic> ctx,
  ) {
    final merged = Map<dynamic, dynamic>.from(item);

    // GPS connected
    merged['_ctx_gsmConnected'] =
        ctx['_ctx_gsmConnected'] ?? merged['_ctx_gsmConnected'];
    merged['_ctx_gpsConnected'] =
        ctx['_ctx_gpsConnected'] ?? merged['_ctx_gpsConnected'];
    merged['_ctx_imuNormal'] =
        ctx['_ctx_imuNormal'] ?? merged['_ctx_imuNormal'];

    // lokasiKoordinat — pakai dari history dulu, fallback ctx
// kalau history punya koordinat 0,0 (tidak valid), pakai dari ctx
    final existingKoord = merged['_ctx_lokasiKoordinat']?.toString() ??
        merged['lokasiKoordinat']?.toString();
    final isKoordTidakValid = existingKoord == null ||
        existingKoord.isEmpty ||
        existingKoord == '0.000000,0.000000' ||
        existingKoord == '0,0' ||
        existingKoord.startsWith('0.0000');

    if (isKoordTidakValid) {
      merged['_ctx_lokasiKoordinat'] = ctx['_ctx_lokasiKoordinat'];
    } else {
      merged['_ctx_lokasiKoordinat'] ??= ctx['_ctx_lokasiKoordinat'];
    }

    // kondisiGeofence
    merged['_ctx_kondisiGeofence'] = ctx['_ctx_kondisiGeofence'];
    merged['_ctx_jarakDariPusat'] ??= ctx['_ctx_jarakDariPusat'];

    // sensor fallback
    merged['_ctx_hcsrBack'] = ctx['_ctx_hcsrBack'];
    merged['_ctx_hcsrFront'] = ctx['_ctx_hcsrFront'];
    merged['_ctx_accel_x'] = ctx['_ctx_accel_x'];
    merged['_ctx_accel_y'] = ctx['_ctx_accel_y'];
    merged['_ctx_accel_z'] = ctx['_ctx_accel_z'];
    merged['_ctx_gyro_x'] = ctx['_ctx_gyro_x'];
    merged['_ctx_gyro_y'] = ctx['_ctx_gyro_y'];
    merged['_ctx_gyro_z'] = ctx['_ctx_gyro_z'];

    return merged;
  }

  static Map<dynamic, dynamic> _asMap(dynamic v) =>
      v is Map ? Map<dynamic, dynamic>.from(v) : {};

  static double _toDouble(dynamic v, double fallback) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  // ── Save history baru ke Firebase ─────────────────────────
  Future<void> saveHistory({
    required String eventType,
    required String description,
  }) async {
    final ref = FirebaseDatabase.instance.ref('Walkers/$walkerId/history');

    final snapshot = await ref.get();
    final count = snapshot.exists && snapshot.value is Map
        ? (snapshot.value as Map).length + 1
        : 1;
    final newKey = 'history_${count.toString().padLeft(3, '0')}';

    final now = DateTime.now();
    await ref.child(newKey).set({
      'date': '${now.year}-${_pad(now.month)}-${_pad(now.day)}',
      'time': '${_pad(now.hour)}:${_pad(now.minute)}:${_pad(now.second)}',
      'event_type': eventType,
      'description': description,
      'lokasiKoordinat': null,
    });
  }

  Future<void> deleteHistory(String historyId) async {
    final ref =
        FirebaseDatabase.instance.ref('Walkers/$walkerId/history/$historyId');

    await ref.remove();
  }

  Future<void> clearAllHistory() async {
    final ref = FirebaseDatabase.instance.ref('Walkers/$walkerId/history');

    await ref.remove();
  }

// ── Cari history item berdasarkan timestamp + title ────────
  Future<HistoryItem?> findByNotification({
    required String timestamp,
    required String title,
  }) async {
    try {
      final items = await fetchOnce();
      if (items.isEmpty) return null;

      final dt = DateTime.tryParse(timestamp.replaceAll(' ', 'T'));
      if (dt == null) return null;

      const months = [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Ags',
        'Sep',
        'Okt',
        'Nov',
        'Des'
      ];
      final targetDate =
          '${dt.day.toString().padLeft(2, '0')} ${months[dt.month]} ${dt.year}';

      debugPrint(
          '[HistoryService] Cari history: date=$targetDate title=$title');

      // Coba exact match: tanggal + title sama
      final exactMatch = items.where((i) {
        final sameDate = i.date == targetDate;
        final sameTitle = i.title.toLowerCase().contains(title.toLowerCase()) ||
            title.toLowerCase().contains(i.title.toLowerCase());
        return sameDate && sameTitle;
      }).toList();

      if (exactMatch.isNotEmpty) {
        debugPrint('[HistoryService] Exact match: ${exactMatch.first.id}');
        return exactMatch.first;
      }

      // Fallback: cari berdasarkan kategori yang relevan
      final categoryMatch = items.where((i) {
        final sameDate = i.date == targetDate;
        final titleLower = title.toLowerCase();
        final isHambatan = titleLower.contains('hambatan') &&
            (i.category == HistoryCategory.hambatanDepan ||
                i.category == HistoryCategory.hambatanBelakang);
        final isJatuh =
            titleLower.contains('jatuh') && i.category == HistoryCategory.jatuh;
        final isGeofence = titleLower.contains('geofence') &&
            i.category == HistoryCategory.geofence;
        return sameDate && (isHambatan || isJatuh || isGeofence);
      }).toList();

      if (categoryMatch.isNotEmpty) {
        debugPrint(
            '[HistoryService] Category match: ${categoryMatch.first.id}');
        return categoryMatch.first;
      }

      // Fallback terakhir: item terbaru di hari itu
      final sameDay = items.where((i) => i.date == targetDate).toList();
      if (sameDay.isNotEmpty) {
        debugPrint('[HistoryService] Date-only match: ${sameDay.first.id}');
        return sameDay.first;
      }

      debugPrint('[HistoryService] Tidak ada match sama sekali');
      return null;
    } catch (e) {
      debugPrint('[HistoryService] findByNotification error: $e');
      return null;
    }
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
