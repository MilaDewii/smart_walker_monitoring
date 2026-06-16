import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../models/alert_model.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';

class NotificationService {
  final FirebaseDatabase _db;
  final String walkerId;
  static const String _oneSignalAppId = "5b4eba8b-7292-4705-a67c-1810e621e035";
  static const String _oneSignalApiKey =
      "os_v2_app_lnhlvc3ssjdqljt4daiomipagv4424nure3ujhfqbccu7rf2xcnaecasfyvvtckgeqohpiqwbqnva5o3nhoft3eklw24wpajetqxwhi";

  NotificationService({
    required this.walkerId,
    FirebaseDatabase? database,
  }) : _db = database ?? FirebaseDatabase.instance;

  DatabaseReference get _notifRef => _db.ref('Walkers/$walkerId/notification');
  DatabaseReference get _idsRef => _db.ref('Walkers/$walkerId/oneSignalIds');
  DatabaseReference _notifItemRef(String notifId) => _notifRef.child(notifId);

  // ── READ: Stream realtime ─────────────────────────────────
  Stream<List<AlertItem>> watchNotifications() {
    return _notifRef.onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return <AlertItem>[];
      final map = data as Map<dynamic, dynamic>;
      final List<AlertItem> items = [];
      for (final entry in map.entries) {
        try {
          items.add(AlertItem.fromFirebase(
            entry.key.toString(),
            entry.value as Map<dynamic, dynamic>,
          ));
        } catch (e) {
          debugPrint('[NotificationService] Gagal parse notif ${entry.key}: $e');
        }
      }
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
        items.add(AlertItem.fromFirebase(
          entry.key.toString(),
          entry.value as Map<dynamic, dynamic>,
        ));
      } catch (e) {
        debugPrint('[NotificationService] Gagal parse notif ${entry.key}: $e');
      }
    }
    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return items;
  }

  // ── SAVE: Simpan playerID per device ─────────────────────
  Future<void> saveOneSignalId() async {
    try {
      final id = OneSignal.User.pushSubscription.id;
      if (id == null || id.isEmpty) {
        debugPrint('[OneSignal] Player ID null/kosong');
        return;
      }
      // Gunakan seluruh id sebagai key (hapus tanda -)
      final deviceKey = id.replaceAll('-', '');
      await _idsRef.child(deviceKey).set(id);
      debugPrint('[OneSignal] ID disimpan: $id');
    } catch (e) {
      debugPrint('[OneSignal] saveOneSignalId error: $e');
    }
  }

  // ── Ambil semua playerIds dari Firebase ──────────────────
  Future<List<String>> _getAllPlayerIds() async {
    try {
      final snap = await _idsRef.get();
      if (!snap.exists || snap.value == null) return [];
      final map = Map<String, dynamic>.from(snap.value as Map);
      return map.values.map((v) => v.toString()).toList();
    } catch (e) {
      debugPrint('[OneSignal] _getAllPlayerIds error: $e');
      return [];
    }
  }

  // ── SEND: Kirim notif ke semua device ────────────────────
  Future<void> sendOneSignalNotif({
    required List<String> playerIds,
    required String title,
    required String body,
    required String level,
    required Map<String, String> data,
  }) async {
    if (playerIds.isEmpty) {
      debugPrint('[OneSignal] playerIds kosong, tidak kirim notif');
      return;
    }
    try {
      final resp = await http.post(
        Uri.parse('https://api.onesignal.com/notifications'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Key $_oneSignalApiKey',
        },
        body: jsonEncode({
          'app_id': _oneSignalAppId,
          'include_subscription_ids': playerIds,
          'headings': {'en': title},
          'contents': {'en': body},
          'data': data,
          'priority': 10,
        }),
      );
      debugPrint('[OneSignal] ${resp.statusCode} ${resp.body}');
    } catch (e) {
      debugPrint('[OneSignal] sendOneSignalNotif error: $e');
    }
  }

  // ── UPDATE: Tandai satu notif sudah dibaca ────────────────
  Future<void> markAsRead(String notifId) async {
    try {
      await _notifItemRef(notifId).update({'sudahDibaca': true});
    } catch (e) {
      debugPrint('[NotificationService] markAsRead error ($notifId): $e');
      rethrow;
    }
  }

  // ── UPDATE: Tandai semua sudah dibaca ────────────────────
  Future<void> markAllAsRead(List<AlertItem> items) async {
    final unread = items.where((item) => !item.sudahDibaca).toList();
    if (unread.isEmpty) return;
    try {
      final Map<String, dynamic> updates = {};
      for (final item in unread) {
        updates['${item.id}/sudahDibaca'] = true;
      }
      await _notifRef.update(updates);
    } catch (e) {
      debugPrint('[NotificationService] markAllAsRead error: $e');
      rethrow;
    }
  }

  // ── WRITE: Tambah notifikasi ──────────────────────────────
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
  Future<void> deleteAllNotifications() async {
    try {
      await _notifRef.remove();
    } catch (e) {
      debugPrint('[NotificationService] deleteAllNotifications error: $e');
      rethrow;
    }
  }

  // ── UTIL: Unread count ────────────────────────────────────
  Future<int> getUnreadCount() async {
    final items = await fetchNotifications();
    return items.where((i) => !i.sudahDibaca).length;
  }

  Stream<int> watchUnreadCount() {
    return watchNotifications().map(
      (items) => items.where((i) => !i.sudahDibaca).length,
    );
  }

  // ── LISTENER: Push OneSignal saat ada notif baru ─────────
  StreamSubscription<DatabaseEvent> listenAndPushOneSignal() {
    final Set<String> _processedKeys = {};

    // Step 1: Kirim push untuk notif LAMA yang belum dibaca
    _notifRef.get().then((snap) async {
      if (!snap.exists || snap.value == null) return;
      final map = Map<String, dynamic>.from(snap.value as Map);

      final playerIds = await _getAllPlayerIds();
      if (playerIds.isEmpty) {
        debugPrint('[OneSignal] Tidak ada playerIds tersimpan');
        return;
      }

      for (final entry in map.entries) {
        final key = entry.key.toString();
        final data = Map<String, dynamic>.from(entry.value as Map);

        if (data['sudahDibaca'] == true) continue;

        _processedKeys.add(key);

        await sendOneSignalNotif(
          playerIds: playerIds,
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

    // Step 2: Listen notif BARU
    return _notifRef.onChildAdded.listen((event) async {
      final key = event.snapshot.key ?? '';
      if (key.isEmpty || _processedKeys.contains(key)) return;

      final raw = event.snapshot.value;
      if (raw == null) return;

      final data = Map<String, dynamic>.from(raw as Map);
      if (data['sudahDibaca'] == true) return;

      debugPrint('[OneSignal] Notif baru diterima: $key');

      final playerIds = await _getAllPlayerIds();
      if (playerIds.isEmpty) {
        debugPrint('[OneSignal] oneSignalIds tidak ada');
        return;
      }

      await sendOneSignalNotif(
        playerIds: playerIds,
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
      debugPrint('[OneSignal] Push notif baru: $key ke ${playerIds.length} device');
    });
  }
}