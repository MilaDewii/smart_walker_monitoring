// lib/models/history_model.dart

import 'package:flutter/material.dart';

enum HistoryStatus { bahaya, peringatan, aman, info }

enum HistoryCategory {
  jatuh,
  geofence,
  sensor,
  aktivitas,
  hambatanDepan,
  hambatanBelakang,
  walker,
}

class SensorDataPoint {
  final double accel;
  final double gyro;
  const SensorDataPoint({required this.accel, required this.gyro});
}

class DistanceDataPoint {
  final String label;
  final double distance;
  const DistanceDataPoint({required this.label, required this.distance});
}

class RingkasanSensor {
  final String hcsr04Depan;
  final String hcsr04Belakang;
  final String mpu6050;
  final String gpsJarak;
  final String statusDepan;
  final String statusBelakang;
  final String statusMpu;
  final String statusGps;

  const RingkasanSensor({
    required this.hcsr04Depan,
    required this.hcsr04Belakang,
    required this.mpu6050,
    required this.gpsJarak,
    required this.statusDepan,
    required this.statusBelakang,
    required this.statusMpu,
    required this.statusGps,
  });
}

class StatusSistem {
  final bool gsmConnected;
  final bool gpsConnected;
  final bool imuNormal;

  const StatusSistem({
    required this.gsmConnected,
    required this.gpsConnected,
    required this.imuNormal,
  });
}

class HistoryExtra {
  final String jenisKejadian;
  final double? skorAnomali;
  final String statusDeteksiLansia;
  final String jarakTerukur;
  final String sensor;
  final String statusBahaya;
  final double? hcsrJarak;
  final double? hcsrThreshold;
  final String? hcsrStatus;
  final List<DistanceDataPoint> distanceData;
  final List<SensorDataPoint> sensorData;
  final Map<String, String> dataTerukur;
  final RingkasanSensor? ringkasanSensor;
  final String? lokasiNama;
  final String? lokasiKoordinat;
  final String? lokasiJarakPusat;
  final String kondisiGeofence;
  final StatusSistem? statusSistem;
  final List<String> tindakanSistem;

  const HistoryExtra({
    this.jenisKejadian = '-',
    this.skorAnomali,
    this.statusDeteksiLansia = '-',
    this.jarakTerukur = '-',
    this.sensor = '-',
    this.statusBahaya = '-',
    this.hcsrJarak,
    this.hcsrThreshold,
    this.hcsrStatus,
    this.distanceData = const [],
    this.sensorData = const [],
    this.dataTerukur = const {},
    this.ringkasanSensor,
    this.lokasiNama,
    this.lokasiKoordinat,
    this.lokasiJarakPusat,
    this.kondisiGeofence = '-',
    this.statusSistem,
    this.tindakanSistem = const [],
  });
}

class HistoryItem {
  final String id;
  final String title;
  final String subtitle;
  final String date;
  final String time;
  final DateTime? rawTimestamp;
  final HistoryStatus status;
  final HistoryCategory category;
  final IconData icon;
  final Map<String, String> meta;
  final HistoryExtra extra;

  const HistoryItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.time,
    this.rawTimestamp,
    required this.status,
    required this.category,
    required this.icon,
    this.meta = const {},
    this.extra = const HistoryExtra(),
  });

  factory HistoryItem.fromRtd(String id, Map<dynamic, dynamic> raw) {
    final ts = raw['timestamp']?.toString() ?? '';
    final datePart = _parseDate(ts);
    final timePart = _parseTime(ts);
    final parsedTs = DateTime.tryParse(ts.replaceAll(' ', 'T'));

    final statusStr = (raw['status']?.toString() ?? '').toLowerCase();
    final status = _parseStatus(statusStr);

    final catStr =
        (raw['category'] ?? raw['type'] ?? '').toString().toLowerCase();
    // Arduino tulis sensor: "HC-SR04 Belakang" atau "HC-SR04 Depan"
    // Gunakan field sensor untuk bedakan hambatan depan vs belakang
    final sensorField = (raw['sensor'] ?? '').toString().toLowerCase();
    HistoryCategory category;
    if (catStr == 'fall' || catStr.contains('jatuh')) {
      category = HistoryCategory.jatuh;
    } else if (catStr == 'geofence' || catStr.contains('geofence')) {
      category = HistoryCategory.geofence;
    } else if (sensorField.contains('belakang') ||
        sensorField.contains('back') ||
        catStr.contains('belakang')) {
      category = HistoryCategory.hambatanBelakang;
    } else if (sensorField.contains('depan') ||
        sensorField.contains('front') ||
        catStr.contains('depan')) {
      category = HistoryCategory.hambatanDepan;
    } else if (catStr.contains('aktivitas')) {
      category = HistoryCategory.aktivitas;
    } else {
      category = HistoryCategory.sensor;
    }

    final subtitle = (raw['subtitle'] ?? raw['subtittle'] ?? '').toString();

    // ── distanceData — coba dari history dulu, fallback ctx ──
    final distMap = _asMap(raw['distanceData']);
    final distanceData = <DistanceDataPoint>[];

    final backVal = distMap['hcsr04_back'] ?? raw['_ctx_hcsrBack'];
    final frontVal = distMap['hcsr04_front'] ?? raw['_ctx_hcsrFront'];

    if (backVal != null) {
      distanceData.add(DistanceDataPoint(
          label: 'Belakang', distance: _toDouble(backVal, 0)));
    }
    if (frontVal != null) {
      distanceData.add(
          DistanceDataPoint(label: 'Depan', distance: _toDouble(frontVal, 0)));
    }

    // ── sensorData — fallback ke ctx (mpu6050 dari parent) ──
    final sensorMap = _asMap(raw['sensorData']);
    final ax = _toDouble(sensorMap['accel_x'] ?? raw['_ctx_accel_x'], 0);
    final ay = _toDouble(sensorMap['accel_y'] ?? raw['_ctx_accel_y'], 0);
    final az = _toDouble(sensorMap['accel_z'] ?? raw['_ctx_accel_z'], 0);
    final gx = _toDouble(sensorMap['gyro_x'] ?? raw['_ctx_gyro_x'], 0);
    final gy = _toDouble(sensorMap['gyro_y'] ?? raw['_ctx_gyro_y'], 0);
    final gz = _toDouble(sensorMap['gyro_z'] ?? raw['_ctx_gyro_z'], 0);

    final hasSensor = sensorMap.isNotEmpty || raw['_ctx_accel_x'] != null;
    final sensorData = hasSensor
        ? [
            SensorDataPoint(accel: ax, gyro: gx),
            SensorDataPoint(accel: ay, gyro: gy),
            SensorDataPoint(accel: az, gyro: gz),
          ]
        : <SensorDataPoint>[];

    final dataTerukur = <String, String>{};
    if (hasSensor) {
      dataTerukur['Accel X'] = '${ax.toStringAsFixed(2)} g';
      dataTerukur['Accel Y'] = '${ay.toStringAsFixed(2)} g';
      dataTerukur['Accel Z'] = '${az.toStringAsFixed(2)} g';
      dataTerukur['Gyro X'] = '${gx.toStringAsFixed(2)} °/s';
      dataTerukur['Gyro Y'] = '${gy.toStringAsFixed(2)} °/s';
      dataTerukur['Gyro Z'] = '${gz.toStringAsFixed(2)} °/s';
    }

    // ── HC-SR04 ──
    final hcsrJarakRaw = _toDouble(raw['hcsrJarak'], 0);
    final hcsrJarak = hcsrJarakRaw > 0
        ? hcsrJarakRaw
        : frontVal != null && _toDouble(frontVal, 0) > 0
            ? _toDouble(frontVal, 0)
            : backVal != null && _toDouble(backVal, 0) > 0
                ? _toDouble(backVal, 0)
                : null;
    final hcsrThreshold = raw['hcsrThreshold'] != null
        ? _toDouble(raw['hcsrThreshold'], 30)
        : null;
    final hcsrStatus = raw['hcsrStatus']?.toString();

    // Kalau lokasiJarakPusat = 0, pakai dari ctx
    final jarakPusatHistory = raw['lokasiJarakPusat'];
    final jarakPusatCtx = raw['_ctx_jarakDariPusat'];
    final jarakPusatRaw = (jarakPusatHistory != null &&
            jarakPusatHistory.toString() != '0' &&
            jarakPusatHistory.toString() != '0.0')
        ? jarakPusatHistory
        : jarakPusatCtx;
    final lokasiJarakPusat = jarakPusatRaw != null
        ? (jarakPusatRaw is String && jarakPusatRaw.contains('m')
            ? jarakPusatRaw
            : '${_toDouble(jarakPusatRaw, 0).toStringAsFixed(1)} m')
        : null;

    // ── lokasiKoordinat — cek validitas, fallback ke ctx kalau 0,0 ──
    final rawKoord = raw['lokasiKoordinat']?.toString();
    final ctxKoord = raw['_ctx_lokasiKoordinat']?.toString();
    final lokasiKoordinat = _isValidKoord(rawKoord)
        ? rawKoord
        : _isValidKoord(ctxKoord)
            ? ctxKoord
            : null;

    // ── kondisiGeofence — history dulu, fallback ctx ──
    final kondisiGeofence = raw['kondisiGeofence']?.toString() ??
        raw['_ctx_kondisiGeofence']?.toString() ??
        '-';

    // ── Ringkasan sensor ──
    RingkasanSensor? ringkasan;
    if (distanceData.isNotEmpty || hasSensor) {
      final back =
          backVal != null ? '${_toDouble(backVal, 0).toInt()} cm' : '-';
      final front =
          frontVal != null ? '${_toDouble(frontVal, 0).toInt()} cm' : '-';
      final threshold = hcsrThreshold ?? 30.0;
      ringkasan = RingkasanSensor(
        hcsr04Depan: front,
        hcsr04Belakang: back,
        mpu6050: hasSensor ? 'Aktif' : '-',
        gpsJarak: lokasiJarakPusat ?? '-',
        statusDepan: frontVal != null && _toDouble(frontVal, 999) < threshold
            ? 'Ada Hambatan'
            : 'Aman',
        statusBelakang: backVal != null && _toDouble(backVal, 999) < threshold
            ? 'Terdeteksi'
            : 'Tidak Terdeteksi',
        statusMpu: (raw['skorAnomali'] != null &&
                _toDouble(raw['skorAnomali'], 0) > 0.5)
            ? 'Anomali'
            : 'Normal',
        statusGps: lokasiKoordinat != null ? 'Aktif' : 'Tidak Aktif',
      );
    }

    // ── tindakanSistem ──
    final tindakanRaw = raw['tindakanSistem'];
    final tindakan = <String>[];
    if (tindakanRaw is List) {
      tindakan.addAll(tindakanRaw.map((e) => e.toString()));
    } else if (tindakanRaw is Map) {
      final sorted = tindakanRaw.entries.toList()
        ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
      tindakan.addAll(sorted.map((e) => e.value.toString()));
    }

    // ── statusSistem — baca dari field statusSistem di history dulu,
// fallback ke ctx dari parent walker ──
    final statusSistemRaw = raw['statusSistem'];
    final statusSistemMap = statusSistemRaw is Map
        ? Map<dynamic, dynamic>.from(statusSistemRaw)
        : null;

    final hasSystemData = statusSistemMap != null ||
        raw['_ctx_gsmConnected'] != null ||
        raw['_ctx_gpsConnected'] != null ||
        raw['_ctx_imuNormal'] != null;

    final statusSistem = hasSystemData
        ? StatusSistem(
            // Prioritas: statusSistem di history → ctx dari parent walker
            gsmConnected: statusSistemMap != null
                ? _toBool(statusSistemMap['gsmConnected'])
                : _toBool(raw['_ctx_gsmConnected']),
            gpsConnected: statusSistemMap != null
                ? _toBool(statusSistemMap['gpsConnected'])
                : _toBool(raw['_ctx_gpsConnected']),
            imuNormal: statusSistemMap != null
                ? _toBool(statusSistemMap['imuNormal'])
                : _toBool(raw['_ctx_imuNormal']),
          )
        : null;

    // ── meta ──
    final meta = <String, String>{};

    if (hcsrJarak != null) {
      meta['Jarak'] = '${hcsrJarak.toInt()} cm';
    }

    if (raw['skorAnomali'] != null) {
      meta['Anomali'] = _toDouble(raw['skorAnomali'], 0).toStringAsFixed(2);
    }

    if (raw['lokasiNama'] != null) {
      meta['Lokasi'] = raw['lokasiNama'].toString();
    }

    final extra = HistoryExtra(
      jenisKejadian: raw['jenisKejadian']?.toString() ?? '-',
      skorAnomali:
          raw['skorAnomali'] != null ? _toDouble(raw['skorAnomali'], 0) : null,
      statusDeteksiLansia: raw['statusDeteksiLansia']?.toString() ?? '-',
      jarakTerukur: raw['jarakTerukur']?.toString() ?? '-',
      sensor: raw['sensor']?.toString() ?? '-',
      statusBahaya: raw['statusBahaya']?.toString() ?? '-',
      hcsrJarak: hcsrJarak,
      hcsrThreshold: hcsrThreshold,
      hcsrStatus: hcsrStatus,
      distanceData: distanceData,
      sensorData: sensorData,
      dataTerukur: dataTerukur,
      ringkasanSensor: ringkasan,
      lokasiNama: (raw['lokasiNama']?.toString() == 'Unknown' ||
              raw['lokasiNama']?.toString() == null)
          ? (lokasiKoordinat != null ? 'Koordinat GPS' : null)
          : raw['lokasiNama']?.toString(),
      lokasiKoordinat: lokasiKoordinat,
      lokasiJarakPusat: lokasiJarakPusat,
      kondisiGeofence: kondisiGeofence,
      statusSistem: statusSistem,
      tindakanSistem: tindakan,
    );

    return HistoryItem(
      id: id,
      title: raw['title']?.toString() ?? 'Kejadian',
      subtitle: subtitle,
      date: datePart,
      time: timePart,
      rawTimestamp: parsedTs,
      status: status,
      category: category,
      icon: _iconOf(category),
      meta: meta,
      extra: extra,
    );
  }

  factory HistoryItem.fromCache(
    Map<String, dynamic> data,
  ) {
    HistoryStatus status = HistoryStatus.info;

    switch ((data['status'] ?? '').toString().toLowerCase()) {
      case 'bahaya':
        status = HistoryStatus.bahaya;
        break;
      case 'peringatan':
        status = HistoryStatus.peringatan;
        break;
      case 'aman':
        status = HistoryStatus.aman;
        break;
    }

    HistoryCategory category = HistoryCategory.sensor;

    switch ((data['type'] ?? '').toString().toLowerCase()) {
      case 'geofence':
        category = HistoryCategory.geofence;
        break;
      case 'jatuh':
        category = HistoryCategory.jatuh;
        break;
      case 'hambatan_depan':
        category = HistoryCategory.hambatanDepan;
        break;
      case 'hambatan_belakang':
        category = HistoryCategory.hambatanBelakang;
        break;
      case 'walker':
        category = HistoryCategory.walker;
        break;
    }

    final createdAt = data['created_at']?.toString() ?? '';
    final parsedTs = DateTime.tryParse(createdAt.replaceAll(' ', 'T'));

    return HistoryItem(
      id: data['id'].toString(),
      title: data['title'] ?? '',
      subtitle: data['subtitle'] ?? '',
      date: _parseDate(createdAt),
      time: _parseTime(createdAt),
      rawTimestamp: parsedTs,
      status: status,
      category: category,
      icon: _iconOf(category),
      meta: const {},
      extra: const HistoryExtra(),
    );
  }

  static HistoryStatus _parseStatus(String s) {
    if (s == 'danger' || s == 'bahaya' || s == 'darurat') {
      return HistoryStatus.bahaya;
    }
    if (s == 'warning' || s == 'peringatan' || s == 'waspada') {
      return HistoryStatus.peringatan;
    }
    if (s == 'info') return HistoryStatus.info;
    return HistoryStatus.aman;
  }

  static HistoryCategory _parseCategory(String s) {
    if (s.contains('jatuh') || s == 'fall') {
      return HistoryCategory.jatuh;
    }

    if (s.contains('geofence')) {
      return HistoryCategory.geofence;
    }

    if (s.contains('belakang')) {
      return HistoryCategory.hambatanBelakang;
    }

    if (s.contains('depan') || s == 'obstacle') {
      return HistoryCategory.hambatanDepan;
    }

    if (s.contains('aktivitas')) {
      return HistoryCategory.aktivitas;
    }

    if (s.contains('walker')) {
      return HistoryCategory.walker;
    }

    return HistoryCategory.sensor;
  }

  static IconData _iconOf(HistoryCategory cat) {
    switch (cat) {
      case HistoryCategory.jatuh:
        return Icons
            .accessibility_new_rounded; // sama kayak notif level darurat
      case HistoryCategory.geofence:
        return Icons.warning_amber_rounded; // sama kayak notif level tinggi
      case HistoryCategory.hambatanBelakang:
        return Icons.directions_walk_rounded; // sama kayak notif level waspada
      case HistoryCategory.hambatanDepan:
        return Icons.directions_walk_rounded; // sama kayak notif level waspada
      case HistoryCategory.aktivitas:
        return Icons.directions_walk_rounded;
      case HistoryCategory.walker:
        return Icons.accessibility_new_rounded;
      case HistoryCategory.sensor:
        return Icons.sensors_rounded;
    }
  }

  static Map<dynamic, dynamic> _asMap(dynamic v) =>
      v is Map ? Map<dynamic, dynamic>.from(v) : {};

  static double _toDouble(dynamic v, double fallback) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  static bool _isValidKoord(String? k) {
    if (k == null || k.isEmpty) return false;
    if (k == '0.000000,0.000000' || k == '0,0') return false;
    if (k.startsWith('0.0000')) return false;
    try {
      final parts = k.split(',');
      if (parts.length < 2) return false;
      final lat = double.parse(parts[0].trim());
      final lng = double.parse(parts[1].trim());
      return lat != 0.0 || lng != 0.0;
    } catch (_) {
      return false;
    }
  }

  static bool _toBool(dynamic v) {
    if (v is bool) return v;
    if (v is String) {
      final value = v.toLowerCase();
      return value == 'true' || value == '1';
    }
    if (v is num) return v != 0;
    return false;
  }

  static String _parseDate(String ts) {
    try {
      final dt = DateTime.parse(ts.replaceAll(' ', 'T'));
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
      return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month]} ${dt.year}';
    } catch (_) {
      return ts.isNotEmpty ? ts.split(' ').first : '-';
    }
  }

  static String _parseTime(String ts) {
    try {
      final dt = DateTime.parse(ts.replaceAll(' ', 'T'));
      final h24 = dt.hour;
      final m = dt.minute.toString().padLeft(2, '0');
      final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
      final ampm = h24 >= 12 ? 'PM' : 'AM';
      return '${h12.toString().padLeft(2, '0')}:$m $ampm';
    } catch (_) {
      return '-';
    }
  }
}