import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../models/alert_model.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';

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
  static const String _oneSignalAppId = "5b4eba8b-7292-4705-a67c-1810e621e035";
  static const String _oneSignalApiKey =
      "os_v2_app_lnhlvc3ssjdqljt4daiomipagvncus2bbjeu7yuvyfuxbi7tqx356eii46z4blek6uoupf6f3qb6zdg3g26acshelvwngfnfcw54glq";

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

  Future<void> saveOneSignalId() async {
    try {
      final id = OneSignal.User.pushSubscription.id;
      if (id == null || id.isEmpty) {
        debugPrint('[OneSignal] Player ID null/kosong');
        return;
      }
      await _db.ref('Walkers/$walkerId/oneSignalId').set(id);
      debugPrint('[OneSignal] ID disimpan: $id');
    } catch (e) {
      debugPrint('[OneSignal] saveOneSignalId error: $e');
    }
  }

  Future<void> sendOneSignalNotif({
    required String playerId,
    required String title,
    required String body,
    required String level,
    required Map<String, String> data,
  }) async {
    try {
      final resp = await http.post(
        Uri.parse('https://api.onesignal.com/notifications'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Key $_oneSignalApiKey', // ganti "Basic" → "Key"
        },
        body: jsonEncode({
          'app_id': _oneSignalAppId,
          'include_subscription_ids': [playerId], // ganti include_player_ids
          'headings': {'en': title},
          'contents': {'en': body},
          'data': data,
          'priority': 10,
        }),
      );
      debugPrint('[OneSignal] ${resp.statusCode} ${resp.body}');
    } catch (e) {
      debugPrint('[OneSignal] error: $e');
    }
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

  // ── LISTENER: Push OneSignal saat ada notif baru ─────────
  StreamSubscription<DatabaseEvent> listenAndPushOneSignal() {
    final startTime = DateTime.now().millisecondsSinceEpoch;
    final Set<String> _processedKeys = {};

    // Step 1: Kirim push untuk notif LAMA yang sudah ada & belum dibaca
    _notifRef.get().then((snap) async {
      if (!snap.exists || snap.value == null) return;
      final map = Map<String, dynamic>.from(snap.value as Map);

      final idSnap = await _db.ref('Walkers/$walkerId/oneSignalId').get();
      if (!idSnap.exists || idSnap.value == null) return;
      final playerId = idSnap.value.toString();

      for (final entry in map.entries) {
        final key = entry.key.toString();
        final data = Map<String, dynamic>.from(entry.value as Map);

        if (data['sudahDibaca'] == true) continue; // skip yang sudah dibaca

        _processedKeys.add(key); // tandai sudah diproses

        await sendOneSignalNotif(
          playerId: playerId,
          title: data['title']?.toString() ?? 'Peringatan',
          body: data['description']?.toString() ?? '',
          level: data['level']?.toString() ?? 'tinggi',
          data: {
            'notifId': key,
            'walkerId': walkerId,
            'latitude': data['latitude']?.toString() ?? '0',
            'longitude': data['longitude']?.toString() ?? '0',
            'level': data['level']?.toString() ?? 'tinggi',
          },
        );
        debugPrint('[OneSignal] Push notif lama: $key');
      }
    });

    // Step 2: Listen notif BARU yang masuk setelah app dibuka
    return _notifRef.onChildAdded.listen((event) async {
      final key = event.snapshot.key ?? '';
      if (key.isEmpty) return;

      // Skip kalau sudah diproses di Step 1 (notif lama)
      if (_processedKeys.contains(key)) return;

      final raw = event.snapshot.value;
      if (raw == null) return;

      final data = Map<String, dynamic>.from(raw as Map);
      if (data['sudahDibaca'] == true) return;

      debugPrint('[OneSignal] Notif baru diterima: $key');

      final idSnap = await _db.ref('Walkers/$walkerId/oneSignalId').get();
      if (!idSnap.exists || idSnap.value == null) {
        debugPrint('[OneSignal] oneSignalId tidak ada');
        return;
      }

      await sendOneSignalNotif(
        playerId: idSnap.value.toString(),
        title: data['title']?.toString() ?? 'Peringatan',
        body: data['description']?.toString() ?? '',
        level: data['level']?.toString() ?? 'tinggi',
        data: {
          'notifId': key,
          'walkerId': walkerId,
          'latitude': data['latitude']?.toString() ?? '0',
          'longitude': data['longitude']?.toString() ?? '0',
          'level': data['level']?.toString() ?? 'tinggi',
        },
      );
      debugPrint('[OneSignal] Push notif baru: $key');
    });
  }
}
