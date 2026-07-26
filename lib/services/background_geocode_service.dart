// lib/services/background_geocode_service.dart
//
// Auto-geocode SEMUA history item yang lokasiNama-nya masih placeholder,
// berjalan di background TANPA perlu user membuka detail satu-satu.

import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../models/history_model.dart';
import 'geocoding_service.dart';

class _GeocodeTask {
  final String walkerId;
  final String historyId;
  final double lat;
  final double lng;
  _GeocodeTask({
    required this.walkerId,
    required this.historyId,
    required this.lat,
    required this.lng,
  });
}

class BackgroundGeocodeService {
  BackgroundGeocodeService._internal();
  static final BackgroundGeocodeService instance =
      BackgroundGeocodeService._internal();

  static const Duration _requestGap = Duration(milliseconds: 1100);
  static const Duration _failureCooldown = Duration(minutes: 5);

  final List<_GeocodeTask> _queue = [];
  final Set<String> _queued = {};
  final Set<String> _resolved = {};
  final Map<String, DateTime> _lastFailure = {};
  bool _isProcessing = false;

  String _key(String walkerId, String historyId) => '$walkerId/$historyId';

  void scanAndQueue(List<HistoryItem> items, String walkerId) {
    for (final item in items) {
      final key = _key(walkerId, item.id);

      if (_resolved.contains(key) || _queued.contains(key)) continue;

      final lastFail = _lastFailure[key];
      if (lastFail != null &&
          DateTime.now().difference(lastFail) < _failureCooldown) {
        continue;
      }

      final lokasiNama = item.extra.lokasiNama;
      final koordStr = item.extra.lokasiKoordinat;

      if (!GeocodingService.needsGeocoding(lokasiNama)) continue;
      if (koordStr == null) continue;

      final coord = GeocodingService.parseCoordString(koordStr);
      if (coord == null) continue;
      if (coord.lat == 0.0 && coord.lng == 0.0) continue;

      _queued.add(key);
      _queue.add(_GeocodeTask(
        walkerId: walkerId,
        historyId: item.id,
        lat: coord.lat,
        lng: coord.lng,
      ));
    }

    if (!_isProcessing && _queue.isNotEmpty) {
      _processQueue();
    }
  }

  Future<void> _processQueue() async {
    _isProcessing = true;
    try {
      while (_queue.isNotEmpty) {
        final task = _queue.removeAt(0);
        final key = _key(task.walkerId, task.historyId);

        try {
          final nama =
              await GeocodingService.getLocationName(task.lat, task.lng);

          final berhasil = nama != GeocodingService.fallbackNotFound &&
              nama != GeocodingService.fallbackNoGps;

          if (berhasil) {
            await FirebaseDatabase.instance
                .ref('Walkers/${task.walkerId}/history/${task.historyId}/lokasiNama')
                .set(nama);
            _resolved.add(key);
          } else {
            _lastFailure[key] = DateTime.now();
          }
        } catch (e) {
          debugPrint('[BackgroundGeocodeService] gagal geocode $key: $e');
          _lastFailure[key] = DateTime.now();
        } finally {
          _queued.remove(key);
        }

        if (_queue.isNotEmpty) {
          await Future.delayed(_requestGap);
        }
      }
    } finally {
      _isProcessing = false;
      if (_queue.isNotEmpty) {
        _processQueue();
      }
    }
  }
}