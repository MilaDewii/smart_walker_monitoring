import 'package:firebase_database/firebase_database.dart';

import '../models/alert_model.dart';
import 'package:flutter/foundation.dart';

// ============================================================
// NOTIFICATION SERVICE
// ============================================================
/// Mengelola operasi RTDB untuk notifikasi walker.
/// Path: Walkers/{walkerId}/notifications/{notifId}/
///
/// CATATAN STRUKTUR FIREBASE:
/// Walkers/
///   {walkerId}/
///     notifications/
///       notif_001/
///         id: "notif_001"       ← field id di dalam node
///         sudahDibaca: false
///         ...
///
/// Node key (notif_001) dan field id harus SAMA agar markAllAsRead bekerja.
/// Jika berbeda, gunakan markAsRead(item.id) yang menggunakan field id.
class NotificationService {
  final FirebaseDatabase _db;
  final String walkerId;

  NotificationService({
    required this.walkerId,
    FirebaseDatabase? database,
  }) : _db = database ?? FirebaseDatabase.instance;

  // ── Ref helper ───────────────────────────────────────────
  DatabaseReference get _notifRef => _db.ref('Walkers/$walkerId/notification');

  DatabaseReference _notifItemRef(String notifId) => _notifRef.child(notifId);

  // ── READ: Stream realtime ─────────────────────────────────
  /// Stream list notifikasi, diurutkan timestamp terbaru di atas.
  Stream<List<AlertItem>> watchNotifications() {
    return _notifRef.onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return <AlertItem>[];

      final map = data as Map<dynamic, dynamic>;
      final List<AlertItem> items = [];

      for (final entry in map.entries) {
        try {
          final item = AlertItem.fromFirebase(
            entry.key.toString(),
            entry.value as Map<dynamic, dynamic>,
          );
          items.add(item);
        } catch (e) {
          // Skip item yang gagal di-parse agar stream tidak putus
          debugPrint('[NotificationService] Gagal parse notif '
              '${entry.key}: $e');
        }
      }

      // Sort: terbaru di atas berdasarkan timestamp string
      items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return items;
    });
  }

  // ── READ: One-time fetch ──────────────────────────────────
  Future<List<AlertItem>> fetchNotifications() async {
    final snap = await _notifRef.get();
    if (!snap.exists || snap.value == null) return [];

    final map = snap.value as Map<dynamic, dynamic>;
    final List<AlertItem> items = [];

    for (final entry in map.entries) {
      try {
        final item = AlertItem.fromFirebase(
          entry.key.toString(),
          entry.value as Map<dynamic, dynamic>,
        );
        items.add(item);
      } catch (e) {
        debugPrint('[NotificationService] Gagal parse notif '
            '${entry.key}: $e');
      }
    }

    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return items;
  }

  // ── UPDATE: Tandai satu notif sudah dibaca ────────────────
  /// [notifId] harus sama dengan node key di Firebase (misal "notif_001").
  /// Gunakan item.id yang sudah di-assign dari node key saat fromFirebase.
  Future<void> markAsRead(String notifId) async {
    try {
      await _notifItemRef(notifId).update({'sudahDibaca': true});
    } catch (e) {
      debugPrint('[NotificationService] markAsRead error ($notifId): $e');
      rethrow;
    }
  }

  // ── UPDATE: Tandai semua sudah dibaca ────────────────────
  /// FIX: Menggunakan multi-path update dalam satu transaksi RTDB
  /// agar efisien (1 write request) dan atomic.
  ///
  /// Key pada [updates] adalah path relatif dari _notifRef,
  /// contoh: "notif_001/sudahDibaca" = true
  Future<void> markAllAsRead(List<AlertItem> items) async {
    // Hanya update yang belum dibaca agar tidak buang-buang write quota
    final unread = items.where((item) => !item.sudahDibaca).toList();
    if (unread.isEmpty) return;

    try {
      final Map<String, dynamic> updates = {};
      for (final item in unread) {
        // Path relatif dari _notifRef → "notif_001/sudahDibaca"
        updates['${item.id}/sudahDibaca'] = true;
      }
      // Satu kali write untuk semua notif (atomic multi-path update)
      await _notifRef.update(updates);
    } catch (e) {
      debugPrint('[NotificationService] markAllAsRead error: $e');
      rethrow;
    }
  }

  // ── WRITE: Tambah / update notifikasi ────────────────────
  Future<void> addNotification(AlertItem item) async {
    try {
      await _notifItemRef(item.id).set(item.toFirebase());
    } catch (e) {
      debugPrint('[NotificationService] addNotification error: $e');
      rethrow;
    }
  }

  // ── DELETE: Hapus satu notifikasi ────────────────────────
  Future<void> deleteNotification(String notifId) async {
    try {
      await _notifItemRef(notifId).remove();
    } catch (e) {
      debugPrint('[NotificationService] deleteNotification error: $e');
      rethrow;
    }
  }

  // ── DELETE: Hapus semua notifikasi ───────────────────────
  /// Berguna untuk fitur "Hapus Semua" di UI jika diperlukan.
  Future<void> deleteAllNotifications() async {
    try {
      await _notifRef.remove();
    } catch (e) {
      debugPrint('[NotificationService] deleteAllNotifications error: $e');
      rethrow;
    }
  }

  // ── UTIL: Hitung unread count (one-time) ─────────────────
  /// Dipakai untuk badge angka di bottom nav bar.
  Future<int> getUnreadCount() async {
    final items = await fetchNotifications();
    return items.where((i) => !i.sudahDibaca).length;
  }

  // ── UTIL: Stream unread count (realtime) ─────────────────
  /// Dipakai untuk badge angka live di bottom nav bar.
  Stream<int> watchUnreadCount() {
    return watchNotifications().map(
      (items) => items.where((i) => !i.sudahDibaca).length,
    );
  }
}
