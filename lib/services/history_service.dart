// lib/services/history_service.dart
// ============================================================
// Stream history dari Firebase RTD node:
//   Walkers/{walkerId}/history/{id}
//
// Fix: passing context (sim808, sensors, geofence, location)
// dari parent walker ke setiap history item supaya data
// seperti GPS status, koordinat, sensor tidak kosong.
//
// TAMBAHAN (offline support):
//   - Setiap kali historyStream() menerima data baru dari
//     Firebase, snapshot mentah (merged dengan context) di-
//     simpan ke SQLite (cache_history.extra = json lengkap)
//     supaya bisa dibaca ulang saat offline.
//   - getCachedHistory() membaca balik dari SQLite dan
//     parsing pakai HistoryItem.fromRtd() yang sama, jadi
//     hasilnya identik dengan versi online (sensorData,
//     distanceData, statusSistem, dll tetap lengkap).
//
// FIX STREAM MACET (starvation):
//   - Sebelumnya historyStream() pakai pure debounce (Timer
//     1 detik yang di-reset SETIAP kali ada event baru dari
//     Firebase). Karena node Walkers/$walkerId berubah terus-
//     menerus (sensor update tiap ~500ms dari firmware ESP32),
//     timer itu nyaris TIDAK PERNAH sempat selesai — terus
//     di-cancel ulang sebelum sempat fire. Akibatnya
//     controller.add(items) nyaris tidak pernah terpanggil,
//     sehingga StreamBuilder di UI stuck di data lama (history
//     baru tidak pernah nongol di list utama, walau data
//     sebenarnya sudah ada di Firebase — itu sebabnya detail
//     sheet, yang dibuka lewat fetchOnce()/findByNotification()
//     terpisah, tetap bisa menampilkan data terbaru).
//   - Sekarang pakai throttle dengan batas waktu MAKSIMUM:
//     selain window debounce 1 detik (supaya tidak proses tiap
//     event satu-satu), kita paksa emit paling lambat tiap 2
//     detik sekali walau event terus mengalir tanpa henti.
// ============================================================

import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/history_model.dart';
import 'dart:async';

class HistoryService {
  final String walkerId;

  HistoryService({required this.walkerId});

  // ── Tracking item yang sudah di-cache, supaya tidak menulis
  // ulang ke SQLite untuk data yang isinya sama persis. Tanpa
  // ini, setiap kali ESP32 update sensor (tiap ~500ms) seluruh
  // node walker ikut berubah, historyStream() akan emit ulang,
  // dan SEMUA history (bisa puluhan/ratusan item) akan di-delete
  // + insert ulang ke SQLite berkali-kali per detik — inilah
  // yang menyebabkan ANR (main thread macet) pada testing
  // sebelumnya. Map ini menyimpan "fingerprint" (hash sederhana)
  // dari history_id -> isi JSON terakhir yang sudah dicache.
  final Map<String, String> _lastCachedSignature = {};

  // ── Stream semua history item (online, + caching otomatis) ─
  //
  // Caching ke SQLite TIDAK memblokir emisi stream ke UI (supaya
  // UI tetap responsif & tidak ANR), tapi tetap "cukup cepat"
  // karena hanya menulis history yang benar-benar baru/berubah
  // (lihat _lastCachedSignature di atas). Item lama yang datanya
  // sama persis dengan yang sudah di-cache akan di-skip.
  Stream<List<HistoryItem>> historyStream() {
    final controller = StreamController<List<HistoryItem>>.broadcast();
    Timer? debounceTimer;
    DatabaseEvent? pendingEvent;
    DateTime? lastEmitAt;

    const debounceWindow = Duration(seconds: 1);
    const maxWait = Duration(seconds: 2);

    void emitNow() {
      final ev = pendingEvent;
      if (ev == null) return;
      lastEmitAt = DateTime.now();
      final items = _processEvent(ev);
      if (!controller.isClosed) controller.add(items);
    }

    final sub = FirebaseDatabase.instance
        .ref('Walkers/$walkerId')
        .onValue
        .listen((event) {
      // Simpan event terbaru, tapi TUNDA pemrosesan (debounce),
      // KECUALI sudah lewat batas waktu maksimum sejak emit
      // terakhir — dalam kasus itu, emit langsung supaya stream
      // tidak pernah "starvation" walau event Firebase datang
      // tanpa henti.
      pendingEvent = event;

      final now = DateTime.now();
      final overdue =
          lastEmitAt == null || now.difference(lastEmitAt!) >= maxWait;

      debounceTimer?.cancel();

      if (overdue) {
        emitNow();
      } else {
        debounceTimer = Timer(debounceWindow, emitNow);
      }
    }, onError: (e) {
      if (!controller.isClosed) controller.addError(e);
    });

    controller.onCancel = () {
      debounceTimer?.cancel();
      sub.cancel();
    };

    return controller.stream;
  }

  // Pindahkan isi logic parsing lama (yang tadinya di dalam .map())
  // ke method terpisah ini supaya bisa dipanggil dari debounce timer:
  List<HistoryItem> _processEvent(DatabaseEvent event) {
    if (event.snapshot.value == null) return <HistoryItem>[];
    final raw = event.snapshot.value;
    if (raw is! Map) return <HistoryItem>[];

    final walkerData = Map<dynamic, dynamic>.from(raw);
    final walkerContext = _buildContext(walkerData);

    final historyRaw = walkerData['history'];
    if (historyRaw == null || historyRaw is! Map) return <HistoryItem>[];

    final items = <HistoryItem>[];
    final toCache = <MapEntry<String, Map<dynamic, dynamic>>>[];

    for (final entry in (historyRaw as Map).entries) {
      final id = entry.key.toString();
      final value = entry.value;
      if (value is! Map) continue;

      try {
        final merged = _mergeContext(
          Map<dynamic, dynamic>.from(value),
          walkerContext,
        );
        items.add(HistoryItem.fromRtd(id, merged));

        final signature = _quickSignature(merged);
        if (_lastCachedSignature[id] != signature) {
          _lastCachedSignature[id] = signature;
          toCache.add(MapEntry(id, merged));
        }
      } catch (e) {
        debugPrint('[HistoryService] skip $id: $e');
      }
    }

    items.sort((a, b) {
      // FIX: sort pakai rawTimestamp (DateTime asli), BUKAN string
      // date/time hasil format tampilan ("02 Jul 2026"). Membandingkan
      // string yang diawali angka HARI (bukan tahun) bikin urutan salah
      // total begitu lewat batas bulan/tahun — item baru bisa "ketumpuk"
      // di bawah item lama, kelihatan seperti history tidak update.
      final ta = a.rawTimestamp;
      final tb = b.rawTimestamp;
      if (ta != null && tb != null) return tb.compareTo(ta);
      if (ta == null && tb == null) return 0;
      return ta == null ? 1 : -1; // yang timestamp-nya null taruh di bawah
    });

    if (toCache.isNotEmpty) {
      _cacheBatch(toCache);
    }

    return items;
  }

  // Fingerprint murah (bukan cryptographic hash) untuk mendeteksi
  // apakah isi history item berubah dibanding versi yang terakhir
  // di-cache. Cukup pakai panjang + beberapa field kunci, tidak
  // perlu encode JSON penuh di sini (itu baru dilakukan saat
  // benar-benar akan ditulis ke SQLite).
  String _quickSignature(Map<dynamic, dynamic> merged) {
    return '${merged['timestamp']}|${merged['status']}|'
        '${merged['title']}|${merged.length}';
  }

  // Tulis sekumpulan history item ke SQLite secara berurutan
  // (tetap di-await per item supaya tidak ada write yang saling
  // tabrakan), tapi dipanggil sebagai fire-and-forget dari sisi
  // historyStream() supaya tidak memblokir UI.
  Future<void> _cacheBatch(
    List<MapEntry<String, Map<dynamic, dynamic>>> toCache,
  ) async {
    for (final entry in toCache) {
      await _cacheToSqlite(entry.key, entry.value);
    }
  }

  // ── Simpan satu history item ke SQLite (cache_history) ─────
  // Disimpan idempotent: pakai history_id sebagai marker di
  // kolom title (prefix khusus) supaya tidak dobel terus-
  // terusan tiap kali Firebase emit ulang data yang sama.
  // Strategi sederhana: hapus dulu entry dengan id yang sama
  // (disimpan di kolom 'type' = 'history_raw:<id>'), baru insert.
  Future<void> _cacheToSqlite(
    String historyId,
    Map<dynamic, dynamic> merged,
  ) async {
    try {
      final db = await DatabaseHelper.instance.database;

      final jsonStr = jsonEncode(_sanitizeForJson(merged));

      final marker = 'history_raw:$historyId';

      // Hapus versi lama entry ini kalau ada (supaya tidak
      // numpuk record duplikat untuk history_id yang sama)
      await db.delete(
        'cache_history',
        where: 'type = ?',
        whereArgs: [marker],
      );

      await db.insert('cache_history', {
        'type': marker,
        'title': merged['title']?.toString() ?? 'Kejadian',
        'subtitle':
            (merged['subtitle'] ?? merged['subtittle'] ?? '').toString(),
        'status': merged['status']?.toString() ?? '-',
        'latitude': null,
        'longitude': null,
        'extra': jsonStr,
        'created_at':
            merged['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Caching gagal tidak boleh mengganggu stream utama
      debugPrint('[HistoryService] cache gagal untuk $historyId: $e');
    }
  }

  // jsonEncode tidak terima tipe non-primitif (misal DateTime
  // dari Firebase ServerValue, atau key non-String di Map
  // bertingkat). Fungsi ini membersihkan Map<dynamic,dynamic>
  // jadi Map<String,dynamic> murni yang aman di-jsonEncode.
  dynamic _sanitizeForJson(dynamic value) {
    if (value is Map) {
      return value.map(
        (k, v) => MapEntry(k.toString(), _sanitizeForJson(v)),
      );
    }
    if (value is List) {
      return value.map(_sanitizeForJson).toList();
    }
    return value;
  }

  // ── Baca history dari cache SQLite (untuk mode offline) ────
  // Mengembalikan List<HistoryItem> yang diparse persis sama
  // seperti versi online, karena pakai HistoryItem.fromRtd()
  // dengan JSON yang disimpan utuh.
  Future<List<HistoryItem>> getCachedHistory() async {
    try {
      final db = await DatabaseHelper.instance.database;

      final rows = await db.query(
        'cache_history',
        where: "type LIKE 'history_raw:%'",
        orderBy: 'created_at DESC',
      );

      final items = <HistoryItem>[];
      for (final row in rows) {
        try {
          final extraStr = row['extra']?.toString();
          if (extraStr == null || extraStr.isEmpty) continue;

          final decoded = jsonDecode(extraStr) as Map<String, dynamic>;
          final id = (row['type'] as String).replaceFirst('history_raw:', '');

          items.add(HistoryItem.fromRtd(id, decoded));
        } catch (e) {
          debugPrint('[HistoryService] gagal parse cache row: $e');
        }
      }

      return items;
    } catch (e) {
      debugPrint('[HistoryService] getCachedHistory error: $e');
      return [];
    }
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
      // FIX: sama seperti di _processEvent — pakai rawTimestamp,
      // bukan string date/time hasil format tampilan.
      final ta = a.rawTimestamp;
      final tb = b.rawTimestamp;
      if (ta != null && tb != null) return tb.compareTo(ta);
      if (ta == null && tb == null) return 0;
      return ta == null ? 1 : -1;
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

    // kondisiGeofence — selalu dari parent (real-time geofence status)
    merged['_ctx_kondisiGeofence'] = ctx['_ctx_kondisiGeofence'];

    // lokasiJarakPusat — history node dulu
    if (item['lokasiJarakPusat'] != null) {
      final val = item['lokasiJarakPusat'];
      final d =
          val is num ? val.toDouble() : double.tryParse(val.toString()) ?? 0.0;
      merged['_ctx_jarakDariPusat'] = '${d.toStringAsFixed(1)} m';
    } else {
      merged['_ctx_jarakDariPusat'] = ctx['_ctx_jarakDariPusat'];
    }

    // distanceData — history node dulu (sudah ditulis Arduino)
    final dist = item['distanceData'];
    if (dist is Map && dist.isNotEmpty) {
      // Sudah ada di history, model akan baca langsung dari raw['distanceData']
      merged['_ctx_hcsrFront'] = dist['hcsr04_front'];
      merged['_ctx_hcsrBack'] = dist['hcsr04_back'];
    } else {
      // Fallback: sensor live dari parent
      merged['_ctx_hcsrFront'] = ctx['_ctx_hcsrFront'];
      merged['_ctx_hcsrBack'] = ctx['_ctx_hcsrBack'];
    }

    // sensorData IMU — history node dulu (sudah ditulis Arduino)
    final sd = item['sensorData'];
    if (sd is Map && sd.isNotEmpty) {
      merged['_ctx_accel_x'] = sd['accel_x'];
      merged['_ctx_accel_y'] = sd['accel_y'];
      merged['_ctx_accel_z'] = sd['accel_z'];
      merged['_ctx_gyro_x'] = sd['gyro_x'];
      merged['_ctx_gyro_y'] = sd['gyro_y'];
      merged['_ctx_gyro_z'] = sd['gyro_z'];
    } else {
      merged['_ctx_accel_x'] = ctx['_ctx_accel_x'];
      merged['_ctx_accel_y'] = ctx['_ctx_accel_y'];
      merged['_ctx_accel_z'] = ctx['_ctx_accel_z'];
      merged['_ctx_gyro_x'] = ctx['_ctx_gyro_x'];
      merged['_ctx_gyro_y'] = ctx['_ctx_gyro_y'];
      merged['_ctx_gyro_z'] = ctx['_ctx_gyro_z'];
    }

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

    // Hapus juga dari cache lokal supaya tidak muncul lagi
    // saat offline padahal sudah dihapus di Firebase.
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete(
        'cache_history',
        where: 'type = ?',
        whereArgs: ['history_raw:$historyId'],
      );
    } catch (e) {
      debugPrint('[HistoryService] gagal hapus cache untuk $historyId: $e');
    }
  }

  Future<void> clearAllHistory() async {
    final ref = FirebaseDatabase.instance.ref('Walkers/$walkerId/history');

    await ref.remove();

    // Bersihkan juga seluruh cache history lokal
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete(
        'cache_history',
        where: "type LIKE 'history_raw:%'",
      );
    } catch (e) {
      debugPrint('[HistoryService] gagal clear cache history: $e');
    }
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