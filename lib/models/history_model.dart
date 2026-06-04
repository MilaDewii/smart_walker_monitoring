// lib/models/history_model.dart
// ============================================================
// MODEL HISTORY — disesuaikan persis dengan struktur RTD
//
// Struktur RTD yang sudah dikonfirmasi:
//   sensorData     : flat object {accel_x,y,z, gyro_x,y,z}
//   SensorData     : sama persis (capital S, alias)
//   distanceData   : flat object {hcsr04_back, hcsr04_front}
//   statusSistem   : {gpsConnected, gsmConnected, imuNormal}
//   tindakanSistem : map {0: "...", 1: "..."}
//   lokasiJarakPusat : number (double)
//   category / type : keduanya diterima
//   subtitle / subtittle : keduanya diterima
//   timestamp      : "2026-06-02 21:25:00"
//   Tidak ada field battery
// ============================================================

import 'package:flutter/material.dart';
import 'dart:math' as math;

// ── Enum kategori ─────────────────────────────────────────────
enum HistoryCategory {
  jatuh,
  hambatanDepan,
  hambatanBelakang,
  geofence,
  sensor,
  walker,
  aktivitas,
}

// ── Enum status ───────────────────────────────────────────────
enum HistoryStatus { bahaya, peringatan, aman, info }

// ── SensorDataPoint — dihitung dari flat IMU object ───────────
// RTD: sensorData { accel_x, accel_y, accel_z, gyro_x, gyro_y, gyro_z }
// Chart butuh resultante: accel = sqrt(x²+y²+z²), gyro = sqrt(x²+y²+z²)
class SensorDataPoint {
  final double accel;
  final double gyro;
  const SensorDataPoint({required this.accel, required this.gyro});

  /// Parse dari flat IMU object RTD
  factory SensorDataPoint.fromFlatMap(Map<String, dynamic> m) {
    final ax = (m['accel_x'] as num?)?.toDouble() ?? 0.0;
    final ay = (m['accel_y'] as num?)?.toDouble() ?? 0.0;
    final az = (m['accel_z'] as num?)?.toDouble() ?? 0.0;
    final gx = (m['gyro_x']  as num?)?.toDouble() ?? 0.0;
    final gy = (m['gyro_y']  as num?)?.toDouble() ?? 0.0;
    final gz = (m['gyro_z']  as num?)?.toDouble() ?? 0.0;
    return SensorDataPoint(
      accel: math.sqrt(ax * ax + ay * ay + az * az),
      gyro:  math.sqrt(gx * gx + gy * gy + gz * gz),
    );
  }
}

// ── DistanceDataPoint — dari flat distanceData object ─────────
// RTD: distanceData { hcsr04_back: 18, hcsr04_front: 45 }
// Chart butuh list titik, kita buat 2 titik dari 2 sensor
class DistanceDataPoint {
  final String label;
  final double distance;
  const DistanceDataPoint({required this.label, required this.distance});

  static List<DistanceDataPoint> fromFlatMap(Map<String, dynamic> m) {
    final back  = (m['hcsr04_back']  as num?)?.toDouble();
    final front = (m['hcsr04_front'] as num?)?.toDouble();
    final result = <DistanceDataPoint>[];
    if (back  != null) result.add(DistanceDataPoint(label: 'Belakang', distance: back));
    if (front != null) result.add(DistanceDataPoint(label: 'Depan',    distance: front));
    return result;
  }
}

// ── RingkasanSensor — dibangun dari node sensors + distanceData ─
class RingkasanSensor {
  final String hcsr04Depan;
  final String statusDepan;
  final String hcsr04Belakang;
  final String statusBelakang;
  final String mpu6050;
  final String statusMpu;
  final String gpsJarak;
  final String statusGps;

  const RingkasanSensor({
    required this.hcsr04Depan,
    required this.statusDepan,
    required this.hcsr04Belakang,
    required this.statusBelakang,
    required this.mpu6050,
    required this.statusMpu,
    required this.gpsJarak,
    required this.statusGps,
  });

  /// Dibangun dari data yang tersedia di node history
  factory RingkasanSensor.fromHistoryMap(Map<String, dynamic> m) {
    // distanceData flat
    final rawDist = m['distanceData'];
    String backVal = '-', frontVal = '-';
    if (rawDist is Map) {
      final back  = rawDist['hcsr04_back'];
      final front = rawDist['hcsr04_front'];
      if (back  != null) backVal  = '$back cm';
      if (front != null) frontVal = '$front cm';
    }

    // hcsrStatus
    final hcsrStatus = m['hcsrStatus'] as String? ?? '-';
    final hcsrJarak  = (m['hcsrJarak'] as num?)?.toDouble();
    final threshold  = (m['hcsrThreshold'] as num?)?.toDouble() ?? 60.0;

    // imuNormal dari statusSistem
    final rawSS    = m['statusSistem'];
    bool imuNormal = true;
    if (rawSS is Map) {
      imuNormal = rawSS['imuNormal'] as bool? ?? true;
    }

    // lokasi
    final coord = m['lokasiKoordinat'] as String? ?? '-';

    return RingkasanSensor(
      hcsr04Depan:    frontVal,
      statusDepan:    frontVal == '-' ? '-' : 'Terukur',
      hcsr04Belakang: backVal,
      statusBelakang: hcsrStatus,
      mpu6050:        imuNormal ? 'Normal' : 'Anomali',
      statusMpu:      imuNormal ? 'Aman'   : 'Anomali',
      gpsJarak:       coord,
      statusGps:      coord == '-' ? 'Tidak Aktif' : 'Aktif',
    );
  }
}

// ── StatusSistem — tanpa battery, sesuai RTD ─────────────────
// RTD: { gpsConnected, gsmConnected, imuNormal }
class StatusSistem {
  final bool gpsConnected;
  final bool gsmConnected;
  final bool imuNormal;

  const StatusSistem({
    required this.gpsConnected,
    required this.gsmConnected,
    required this.imuNormal,
  });

  factory StatusSistem.fromMap(Map<String, dynamic> m) => StatusSistem(
        gpsConnected: m['gpsConnected'] as bool? ?? false,
        gsmConnected: m['gsmConnected'] as bool? ?? false,
        imuNormal:    m['imuNormal']    as bool? ?? true,
      );
}

// ── HistoryExtra ──────────────────────────────────────────────
class HistoryExtra {
  final String           jenisKejadian;
  final double?          skorAnomali;
  final String           statusDeteksiLansia;
  final String           jarakTerukur;
  final String           sensor;
  final String           statusBahaya;

  final double?          hcsrJarak;
  final double?          hcsrThreshold;
  final String?          hcsrStatus;

  final List<DistanceDataPoint> distanceData;
  final List<SensorDataPoint>   sensorData;
  final Map<String, String>     dataTerukur;

  final RingkasanSensor?        ringkasanSensor;

  final String?          lokasiNama;
  final String?          lokasiKoordinat;
  final String           kondisiGeofence;
  final String?          lokasiJarakPusat;

  final StatusSistem?           statusSistem;
  final List<String>            tindakanSistem;

  const HistoryExtra({
    required this.jenisKejadian,
    this.skorAnomali,
    required this.statusDeteksiLansia,
    required this.jarakTerukur,
    required this.sensor,
    required this.statusBahaya,
    this.hcsrJarak,
    this.hcsrThreshold,
    this.hcsrStatus,
    this.distanceData = const [],
    this.sensorData   = const [],
    this.dataTerukur  = const {},
    this.ringkasanSensor,
    this.lokasiNama,
    this.lokasiKoordinat,
    this.kondisiGeofence = '-',
    this.lokasiJarakPusat,
    this.statusSistem,
    this.tindakanSistem = const [],
  });

  factory HistoryExtra.fromMap(Map<String, dynamic> m) {
    // ── distanceData (flat: {hcsr04_back, hcsr04_front}) ────
    final rawDist = m['distanceData'];
    List<DistanceDataPoint> distanceData = [];
    if (rawDist is Map) {
      distanceData = DistanceDataPoint.fromFlatMap(
          Map<String, dynamic>.from(rawDist));
    }

    // ── sensorData (flat IMU object, key bisa 'sensorData' atau 'SensorData') ──
    final rawSensor = m['sensorData'] ?? m['SensorData'];
    List<SensorDataPoint> sensorData = [];
    if (rawSensor is Map) {
      sensorData = [SensorDataPoint.fromFlatMap(
          Map<String, dynamic>.from(rawSensor))];
    }

    // ── dataTerukur — dibangun dari sensorData flat ──────────
    final dataTerukur = <String, String>{};
    if (rawSensor is Map) {
      final ax = rawSensor['accel_x'];
      final ay = rawSensor['accel_y'];
      final az = rawSensor['accel_z'];
      final gx = rawSensor['gyro_x'];
      final gy = rawSensor['gyro_y'];
      final gz = rawSensor['gyro_z'];
      if (ax != null) dataTerukur['Accel X'] = '$ax g';
      if (ay != null) dataTerukur['Accel Y'] = '$ay g';
      if (az != null) dataTerukur['Accel Z'] = '$az m/s²';
      if (gx != null) dataTerukur['Gyro X']  = '$gx °/s';
      if (gy != null) dataTerukur['Gyro Y']  = '$gy °/s';
      if (gz != null) dataTerukur['Gyro Z']  = '$gz °/s';
    }

    // ── tindakanSistem (map {0: "...", 1: "..."} atau list) ──
    final rawTindakan = m['tindakanSistem'];
    final tindakanSistem = <String>[];
    if (rawTindakan is Map) {
      final sorted = rawTindakan.entries.toList()
        ..sort((a, b) {
          final ai = int.tryParse(a.key.toString()) ?? 0;
          final bi = int.tryParse(b.key.toString()) ?? 0;
          return ai.compareTo(bi);
        });
      tindakanSistem.addAll(sorted.map((e) => e.value.toString()));
    } else if (rawTindakan is List) {
      tindakanSistem.addAll(rawTindakan.map((e) => e.toString()));
    }

    // ── statusSistem ─────────────────────────────────────────
    StatusSistem? statusSistem;
    final rawSS = m['statusSistem'];
    if (rawSS is Map) {
      statusSistem = StatusSistem.fromMap(Map<String, dynamic>.from(rawSS));
    }

    // ── ringkasanSensor — dibangun otomatis dari data ada ────
    final ringkasan = RingkasanSensor.fromHistoryMap(m);

    // ── lokasiJarakPusat — bisa number atau string di RTD ────
    String? lokasiJarakPusat;
    final rawJarak = m['lokasiJarakPusat'];
    if (rawJarak != null) {
      lokasiJarakPusat = rawJarak is num
          ? '${rawJarak.toStringAsFixed(1)} m dari pusat'
          : rawJarak.toString();
    }

    return HistoryExtra(
      jenisKejadian:       m['jenisKejadian']       as String? ?? '-',
      skorAnomali:         (m['skorAnomali']         as num?)?.toDouble(),
      statusDeteksiLansia: m['statusDeteksiLansia']  as String? ?? '-',
      jarakTerukur:        m['jarakTerukur']         as String? ?? '-',
      sensor:              m['sensor']               as String? ?? '-',
      statusBahaya:        m['statusBahaya']         as String? ?? '-',
      hcsrJarak:           (m['hcsrJarak']           as num?)?.toDouble(),
      hcsrThreshold:       (m['hcsrThreshold']       as num?)?.toDouble(),
      hcsrStatus:          m['hcsrStatus']           as String?,
      distanceData:        distanceData,
      sensorData:          sensorData,
      dataTerukur:         dataTerukur,
      ringkasanSensor:     ringkasan,
      lokasiNama:          m['lokasiNama']           as String?,
      lokasiKoordinat:     m['lokasiKoordinat']      as String?,
      kondisiGeofence:     m['kondisiGeofence']      as String? ?? '-',
      lokasiJarakPusat:    lokasiJarakPusat,
      statusSistem:        statusSistem,
      tindakanSistem:      tindakanSistem,
    );
  }
}

// ── HistoryItem ───────────────────────────────────────────────
class HistoryItem {
  final String          id;
  final HistoryCategory category;
  final HistoryStatus   status;
  final String          title;
  final String          subtitle;
  final String          date;
  final String          time;
  final IconData        icon;
  final Map<String, String> meta;
  final HistoryExtra    extra;

  const HistoryItem({
    required this.id,
    required this.category,
    required this.status,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.time,
    required this.icon,
    this.meta = const {},
    required this.extra,
  });

  factory HistoryItem.fromMap(String id, Map<String, dynamic> m) {
    // category — coba 'category' dulu, fallback ke 'type'
    final catRaw = (m['category'] ?? m['type']) as String? ?? 'aktivitas';
    final category = _parseCategory(catRaw);
    final status   = _parseStatus(m['status'] as String? ?? 'info');

    // subtitle — handle typo 'subtittle'
    final subtitle = (m['subtitle'] ?? m['subtittle']) as String? ?? '';

    // timestamp — format "2026-06-02 21:25:00"
    final ts     = m['timestamp'] as String? ?? '';
    final parsed = _parseTimestamp(ts);

    return HistoryItem(
      id:       id,
      category: category,
      status:   status,
      title:    m['title']   as String? ?? 'Kejadian',
      subtitle: subtitle,
      date:     parsed.$1,
      time:     parsed.$2,
      icon:     _iconFor(category, status),
      meta:     _buildMeta(m),
      extra:    HistoryExtra.fromMap(m),
    );
  }

  static HistoryCategory _parseCategory(String raw) {
    switch (raw.toLowerCase().replaceAll(' ', '')) {
      case 'jatuh':            return HistoryCategory.jatuh;
      case 'hambatandepan':    return HistoryCategory.hambatanDepan;
      case 'hambatanbelakang': return HistoryCategory.hambatanBelakang;
      case 'geofence':         return HistoryCategory.geofence;
      case 'sensor':           return HistoryCategory.sensor;
      case 'walker':           return HistoryCategory.walker;
      default:                 return HistoryCategory.aktivitas;
    }
  }

  static HistoryStatus _parseStatus(String raw) {
    switch (raw.toLowerCase()) {
      case 'danger':
      case 'bahaya':     return HistoryStatus.bahaya;
      case 'warning':
      case 'peringatan': return HistoryStatus.peringatan;
      case 'safe':
      case 'aman':       return HistoryStatus.aman;
      default:           return HistoryStatus.info;
    }
  }

  static (String, String) _parseTimestamp(String ts) {
    try {
      final dt = DateTime.parse(ts.replaceAll(' ', 'T'));
      const months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      final date =
          '${dt.day.toString().padLeft(2, '0')} ${months[dt.month]} ${dt.year}';
      final h    = dt.hour > 12
          ? dt.hour - 12
          : (dt.hour == 0 ? 12 : dt.hour);
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final time =
          '${h.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $ampm';
      return (date, time);
    } catch (_) {
      return ('-', '-');
    }
  }

  static IconData _iconFor(HistoryCategory cat, HistoryStatus status) {
    switch (cat) {
      case HistoryCategory.jatuh:
        return Icons.personal_injury_rounded;
      case HistoryCategory.hambatanBelakang:
        return status == HistoryStatus.bahaya
            ? Icons.personal_injury_rounded
            : Icons.sensors_rounded;
      case HistoryCategory.hambatanDepan:
        return Icons.front_hand_rounded;
      case HistoryCategory.geofence:
        return Icons.location_off_rounded;
      case HistoryCategory.sensor:
        return Icons.sensors_rounded;
      case HistoryCategory.walker:
        return Icons.accessible_rounded;
      case HistoryCategory.aktivitas:
        return Icons.check_circle_outline_rounded;
    }
  }

  static Map<String, String> _buildMeta(Map<String, dynamic> m) {
    final meta = <String, String>{};
    final jarakTerukur = m['jarakTerukur'] as String?;
    final sensor       = m['sensor']       as String?;
    final statusBahaya = m['statusBahaya'] as String?;
    if (jarakTerukur != null && jarakTerukur != '-')
      meta['Jarak']  = jarakTerukur;
    if (sensor != null && sensor != '-')
      meta['Sensor'] = sensor;
    if (statusBahaya != null && statusBahaya != '-')
      meta['Status'] = statusBahaya;
    return meta;
  }
}