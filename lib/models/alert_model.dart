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
  final String time;
  final String date;
  final String description;
  final double score;
  final int durasiDetik;
  bool sudahDibaca;
  final LatLng location;
  final String timestamp;
  final String rawDate;

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

  factory AlertItem.fromFirebase(String key, Map<dynamic, dynamic> data) {
    final levelStr = (data['level'] ?? 'tinggi').toString();
    final level = AlertLevelExtension.fromString(levelStr);

    final lat = _toDoubleStrict(data['latitude']) ?? 0.0;
    final lng = _toDoubleStrict(data['longitude']) ?? 0.0;

    // ← FIX: pakai $key bukan $id (id belum terdefinisi di sini)
    if (lat == 0.0 && lng == 0.0) {
      debugPrint('[AlertItem] $key: lat/lng kosong, lokasi tidak tersedia');
    }

    final rawTs      = (data['timestamp'] ?? '').toString();
    final rawTime    = (data['time'] ?? '').toString();
    final rawDateStr = (data['date'] ?? '').toString();

    final timePart    = _parseTime(rawTime, rawTs);
    final datePart    = _parseDate(rawDateStr.isNotEmpty ? rawDateStr : rawTs);
    final rawDateOnly = rawDateStr.isNotEmpty
        ? rawDateStr.split(' ').first
        : rawTs.split(' ').first;

    return AlertItem(
      id:          (data['id'] ?? key).toString(),
      title:       (data['title'] ?? '').toString(),
      level:       level,
      time:        timePart,
      date:        datePart,
      description: (data['description'] ?? '').toString(),
      score:       _toDoubleStrict(data['score']) ?? 0.0,
      durasiDetik: _toInt(data['durasiDetik']) ?? 0,
      sudahDibaca: data['sudahDibaca'] == true,
      location:    LatLng(lat, lng),
      timestamp:   rawTs,
      rawDate:     rawDateOnly,
    );
  }

  Map<String, dynamic> toFirebase() {
    return {
      'id':          id,
      'title':       title,
      'level':       level.name,
      'description': description,
      'score':       score,
      'durasiDetik': durasiDetik,
      'sudahDibaca': sudahDibaca,
      'latitude':    location.latitude,
      'longitude':   location.longitude,
      'timestamp':   timestamp,
      'date':        rawDate,
    };
  }

  AlertItem copyWith({bool? sudahDibaca}) {
    return AlertItem(
      id:          id,
      title:       title,
      level:       level,
      time:        time,
      date:        date,
      description: description,
      score:       score,
      durasiDetik: durasiDetik,
      sudahDibaca: sudahDibaca ?? this.sudahDibaca,
      location:    location,
      timestamp:   timestamp,
      rawDate:     rawDate,
    );
  }

  // ── Helpers ──────────────────────────────────────────────

  static double? _toDoubleStrict(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    final str = v.toString().trim();
    if (str.isEmpty) return null;
    return double.tryParse(str);
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    final str = v.toString().trim();
    if (str.isEmpty) return null;
    return int.tryParse(str);
  }

  static String _parseTime(String rawTime, String rawTimestamp) {
    if (rawTime.isNotEmpty) {
      try {
        final parts = rawTime.split(':');
        if (parts.length >= 2) {
          return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')} WIB';
        }
      } catch (_) {}
    }
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

  static String _parseDate(String raw) {
    const months = [
      '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    try {
      final datePart = raw.split(' ').first;
      final parts    = datePart.split('-');
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