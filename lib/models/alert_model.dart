import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

// ============================================================
// ENUM
// ============================================================
enum AlertLevel { tinggi, darurat, waspada }

extension AlertLevelExtension on AlertLevel {
  static AlertLevel fromString(String value) {
    switch (value.toLowerCase()) {
      case 'darurat':
        return AlertLevel.darurat;
      case 'waspada':
        return AlertLevel.waspada;
      case 'tinggi':
      default:
        return AlertLevel.tinggi;
    }
  }

  String get label {
    switch (this) {
      case AlertLevel.darurat:
        return 'Darurat';
      case AlertLevel.waspada:
        return 'Waspada';
      case AlertLevel.tinggi:
        return 'Tinggi';
    }
  }

  IconData get icon {
    switch (this) {
      case AlertLevel.darurat:
        return Icons.accessibility_new_rounded;
      case AlertLevel.waspada:
        return Icons.directions_walk_rounded;
      case AlertLevel.tinggi:
        return Icons.warning_amber_rounded;
    }
  }
}

// ============================================================
// MODEL
// ============================================================
class AlertItem {
  final String id;
  final String title;
  final AlertLevel level;
  final String time;       // formatted "21:25 WIB"
  final String date;       // formatted "02 Juni 2026"
  final String description;
  final double score;
  final int durasiDetik;
  bool sudahDibaca;
  final LatLng location;
  final String timestamp;  // raw ISO string dari Firebase
  final String rawDate;    // raw date string "2026-06-02" untuk filter

  AlertItem({
    required this.id,
    required this.title,
    required this.level,
    required this.time,
    required this.date,
    required this.description,
    required this.score,
    required this.durasiDetik,
    required this.sudahDibaca,
    required this.location,
    required this.timestamp,
    required this.rawDate,
  });

  IconData get icon => level.icon;

  /// Parse dari snapshot Firebase RTDB
  /// key = notif_001, value = Map<String, dynamic>
  factory AlertItem.fromFirebase(String key, Map<dynamic, dynamic> data) {
    final levelStr = (data['level'] ?? 'tinggi').toString();
    final level = AlertLevelExtension.fromString(levelStr);

    // FIX: latitude bisa berupa string kosong "" di Firebase
    // Gunakan _toDoubleStrict yang toleran terhadap string kosong/invalid
    final lat = _toDoubleStrict(data['latitude']) ?? 0.0;
    final lng = _toDoubleStrict(data['longitude']) ?? 0.0;

    // Debug: ingatkan developer jika koordinat tidak valid dari Firebase
    assert(
      !(lat == 0.0 && lng == 0.0),
      '[AlertItem] $key: latitude/longitude kosong atau 0,0! '
      'Pastikan Firebase menyimpan nilai numerik, bukan string kosong "".',
    );

    // timestamp: "2026-06-02 21:25:00"
    final rawTs  = (data['timestamp'] ?? '').toString();
    // time bisa berupa "21:25:00" standalone ATAU bagian dari timestamp
    final rawTime = (data['time'] ?? '').toString();
    // date bisa berupa "2026-06-02" standalone
    final rawDateStr = (data['date'] ?? '').toString();

    final timePart = _parseTime(rawTime, rawTs);
    final datePart = _parseDate(rawDateStr.isNotEmpty ? rawDateStr : rawTs);
    // rawDate untuk keperluan filter "hari ini"
    final rawDateOnly = rawDateStr.isNotEmpty
        ? rawDateStr.split(' ').first
        : rawTs.split(' ').first;

    return AlertItem(
      id: (data['id'] ?? key).toString(),
      title: (data['title'] ?? '').toString(),
      level: level,
      time: timePart,
      date: datePart,
      description: (data['description'] ?? '').toString(),
      score: _toDoubleStrict(data['score']) ?? 0.0,
      durasiDetik: _toInt(data['durasiDetik']) ?? 0,
      sudahDibaca: data['sudahDibaca'] == true,
      location: LatLng(lat, lng),
      timestamp: rawTs,
      rawDate: rawDateOnly,
    );
  }

  Map<String, dynamic> toFirebase() {
    return {
      'id': id,
      'title': title,
      'level': level.name,
      'description': description,
      'score': score,
      'durasiDetik': durasiDetik,
      'sudahDibaca': sudahDibaca,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'timestamp': timestamp,
      'date': rawDate,
    };
  }

  AlertItem copyWith({bool? sudahDibaca}) {
    return AlertItem(
      id: id,
      title: title,
      level: level,
      time: time,
      date: date,
      description: description,
      score: score,
      durasiDetik: durasiDetik,
      sudahDibaca: sudahDibaca ?? this.sudahDibaca,
      location: location,
      timestamp: timestamp,
      rawDate: rawDate,
    );
  }

  // ── Helpers ──────────────────────────────────────────────

  /// FIX: Menangani semua tipe: double, int, num, string angka, string kosong, null
  static double? _toDoubleStrict(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    final str = v.toString().trim();
    if (str.isEmpty) return null; // latitude: "" di Firebase → null → 0.0
    return double.tryParse(str);
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    final str = v.toString().trim();
    if (str.isEmpty) return null;
    return int.tryParse(str);
  }

  /// FIX: Mendukung dua format:
  ///   - "21:25:00"           → standalone time field dari Firebase
  ///   - "2026-06-02 21:25:00" → fallback dari timestamp
  static String _parseTime(String rawTime, String rawTimestamp) {
    // Coba parse dari field time langsung ("21:25:00")
    if (rawTime.isNotEmpty) {
      try {
        final parts = rawTime.split(':');
        if (parts.length >= 2) {
          return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')} WIB';
        }
      } catch (_) {}
    }
    // Fallback: ambil dari timestamp "2026-06-02 21:25:00"
    try {
      final segments = rawTimestamp.split(' ');
      if (segments.length >= 2) {
        final timeParts = segments[1].split(':');
        if (timeParts.length >= 2) {
          return '${timeParts[0].padLeft(2, '0')}:${timeParts[1].padLeft(2, '0')} WIB';
        }
      }
    } catch (_) {}
    return rawTime.isNotEmpty ? rawTime : rawTimestamp;
  }

  /// "2026-06-02" atau "2026-06-02 21:25:00"  →  "02 Juni 2026"
  static String _parseDate(String raw) {
    const months = [
      '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    try {
      final datePart = raw.split(' ').first;
      final parts = datePart.split('-');
      if (parts.length >= 3) {
        final day   = parts[2].padLeft(2, '0');
        final month = int.parse(parts[1]);
        final year  = parts[0];
        return '$day ${months[month]} $year';
      }
    } catch (_) {}
    return raw;
  }
}