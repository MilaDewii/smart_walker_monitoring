// lib/services/history_service.dart
// ============================================================
// HISTORY SERVICE — Stream real-time dari Firebase RTD
// Path: Walkers/{walkerId}/history/{id}
// ============================================================

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/history_model.dart';

class HistoryService {
  final String walkerId;

  HistoryService({required this.walkerId});

  DatabaseReference get _ref =>
      FirebaseDatabase.instance.ref('Walkers/$walkerId/history');

  // ── Stream real-time ──────────────────────────────────────
  Stream<List<HistoryItem>> historyStream() {
    return _ref.onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return <HistoryItem>[];

      final rawMap = Map<String, dynamic>.from(data as Map);
      final items  = <HistoryItem>[];

      rawMap.forEach((key, value) {
        try {
          if (value is Map) {
            items.add(HistoryItem.fromMap(
                key, Map<String, dynamic>.from(value)));
          }
        } catch (e) {
          debugPrint('[HistoryService] Skip item $key: $e');
        }
      });

      return items;
    });
  }

  // ── Fetch satu item ───────────────────────────────────────
  Future<HistoryItem?> fetchItem(String historyId) async {
    final snap = await _ref.child(historyId).get();
    if (!snap.exists || snap.value == null) return null;
    return HistoryItem.fromMap(
        historyId, Map<String, dynamic>.from(snap.value as Map));
  }

  // ── Push history baru (dari logika deteksi) ───────────────
  Future<void> pushHistory(Map<String, dynamic> data) async {
    await _ref.push().set(data);
  }
}