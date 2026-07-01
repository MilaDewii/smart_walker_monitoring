import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../models/alert_model.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class NotificationService {
  final FirebaseDatabase _db;
  final String walkerId;

static final String _oneSignalAppId =
    dotenv.env['ONESIGNAL_APP_ID']!;

static final String _oneSignalApiKey =
    dotenv.env['ONESIGNAL_API_KEY']!;

  NotificationService({
    required this.walkerId,
    FirebaseDatabase? database,
  }) : _db = database ?? FirebaseDatabase.instance;

  // =========================================================
  // FIREBASE REFERENCE
  // =========================================================

  // =========================================================
  // FIREBASE REFERENCE
  // =========================================================

  DatabaseReference get _notifRef => _db.ref('Walkers/$walkerId/notification');
  DatabaseReference get _idsRef => _db.ref('Walkers/$walkerId/oneSignalIds');
  DatabaseReference _notifItemRef(String notifId) => _notifRef.child(notifId);

  // =========================================================
  // SAVE ONESIGNAL ID (MULTI DEVICE)
  // =========================================================

  Future<void> saveOneSignalId() async {
    try {
      final id = OneSignal.User.pushSubscription.id;
      if (id == null || id.isEmpty) {
        debugPrint('[OneSignal] Player ID null/kosong');
        return;
      }
      final deviceKey = id.replaceAll('-', '');
      await _idsRef.child(deviceKey).set(id);
      debugPrint('[OneSignal] ID disimpan: $id');
    } catch (e) {
      debugPrint('[OneSignal] saveOneSignalId error: $e');
    }
  }

  Future<void> cleanupInvalidIds() async {
  try {
    final snap = await _idsRef.get();
    if (!snap.exists || snap.value == null) return;

    if (snap.value is! Map) {
      debugPrint('[OneSignal] oneSignalIds bukan Map, skip cleanup');
      return;
    }

    final map = Map<String, dynamic>.from(snap.value as Map);
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );

    final Map<String, dynamic> updates = {};
    final Set<String> validIds = {};

    for (final entry in map.entries) {
      final key = entry.key;
      final value = entry.value;

      // Hapus kalau value bukan UUID valid (misal: true, null, integer)
      if (value is! String || !uuidRegex.hasMatch(value)) {
        updates[key] = null; // null = hapus di Firebase
        debugPrint('[OneSignal] Hapus entry rusak: $key = $value');
        continue;
      }

      // Hapus duplikat — kalau UUID ini sudah pernah muncul, hapus entry ke-2
      if (validIds.contains(value)) {
        updates[key] = null;
        debugPrint('[OneSignal] Hapus duplikat: $key = $value');
        continue;
      }

      validIds.add(value);
    }

    if (updates.isEmpty) {
      debugPrint('[OneSignal] Tidak ada entry rusak, skip');
      return;
    }

    await _idsRef.update(updates);
    debugPrint('[OneSignal] Cleanup selesai, dihapus: ${updates.length} entry');
  } catch (e) {
    debugPrint('[OneSignal] cleanupInvalidIds error: $e');
  }
}

  // =========================================================
  // REMOVE DEVICE SAAT LOGOUT
  // =========================================================

  Future<void> removeOneSignalId() async {
    try {
      final id = OneSignal.User.pushSubscription.id;
      if (id == null || id.isEmpty) return;
      final deviceKey = id.replaceAll('-', '');
      await _idsRef.child(deviceKey).remove();
      debugPrint('[OneSignal] Device dihapus: $id');
    } catch (e) {
      debugPrint('[OneSignal] removeOneSignalId error: $e');
    }
  }

  // =========================================================
  // AMBIL SEMUA DEVICE (playerIds)
  // =========================================================

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

  // =========================================================
  // SEND: Kirim notif ke semua device
  // =========================================================

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

  // =========================================================
  // WATCH NOTIFICATION
  // =========================================================

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
          debugPrint('[NotificationService] Parse notif error: $e');
          debugPrint('[NotificationService] Parse notif error: $e');
        }
      }

      items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return items;
    });
  }
  // =========================================================
// MARK SAFE
// =========================================================

Future<void> markAsSafe(String notifId) async {
  try {
    await _notifItemRef(notifId).update({'sudahAman': true});
  } catch (e) {
    debugPrint('[NotificationService] markAsSafe error ($notifId): $e');
    rethrow;
  }
}

  // =========================================================
  // FETCH
  // =========================================================

  Future<List<AlertItem>> fetchNotifications() async {
    final snap = await _notifRef.get();

    if (!snap.exists || snap.value == null) {
      return [];
    }

    final map = snap.value as Map<dynamic, dynamic>;

    final List<AlertItem> items = [];

    for (final entry in map.entries) {
      try {
        items.add(
          AlertItem.fromFirebase(
            entry.key.toString(),
            entry.value as Map<dynamic, dynamic>,
          ),
        items.add(
          AlertItem.fromFirebase(
            entry.key.toString(),
            entry.value as Map<dynamic, dynamic>,
          ),
        );
      } catch (e) {
        debugPrint('[NotificationService] Fetch notif error: $e');
        debugPrint('[NotificationService] Fetch notif error: $e');
      }
    }

    items.sort(
      (a, b) => b.timestamp.compareTo(a.timestamp),
    );

    return items;
  }

  // =========================================================
  // MARK READ
  // =========================================================

  // =========================================================
  // MARK READ
  // =========================================================

  Future<void> markAsRead(String notifId) async {
    try {
      await _notifItemRef(notifId).update({'sudahDibaca': true});
    } catch (e) {
      debugPrint('[NotificationService] markAsRead error ($notifId): $e');
      rethrow;
    }
  }

  Future<void> markAllAsRead(List<AlertItem> items) async {
    final unread = items.where((e) => !e.sudahDibaca).toList();
    if (unread.isEmpty) return;

    final Map<String, dynamic> updates = {};
    for (final item in unread) {
      updates['${item.id}/sudahDibaca'] = true;
    }

    try {
      await _notifRef.update(updates);
    } catch (e) {
      debugPrint('[NotificationService] markAllAsRead error: $e');
      rethrow;
    }
  }

  // =========================================================
  // ADD NOTIFICATION
  // =========================================================

  // =========================================================
  // ADD NOTIFICATION
  // =========================================================

  Future<void> addNotification(AlertItem item) async {
    await _notifItemRef(item.id).set(item.toFirebase());
  }

  // =========================================================
  // DELETE
  // =========================================================

  // =========================================================
  // DELETE
  // =========================================================

  Future<void> deleteNotification(String notifId) async {
    await _notifItemRef(notifId).remove();
  }

  Future<void> deleteAllNotifications() async {
    await _notifRef.remove();
  }

  // =========================================================
  // UNREAD COUNT
  // =========================================================

  // =========================================================
  // UNREAD COUNT
  // =========================================================

  Future<int> getUnreadCount() async {
    final items = await fetchNotifications();
    return items.where((e) => !e.sudahDibaca).length;
  }

  Stream<int> watchUnreadCount() {
    return watchNotifications().map(
      (items) => items.where((e) => !e.sudahDibaca).length,
    );
  }

  // =========================================================
  // AUTO PUSH LISTENER (notif lama + notif baru)
  // =========================================================

  StreamSubscription<DatabaseEvent> listenAndPushOneSignal() {
    final Set<String> processed = {};

    return _notifRef
        .orderByChild('timestamp')
        .limitToLast(1)
        .onChildAdded
        .listen(
      (event) async {
        final key = event.snapshot.key ?? "";

        if (processed.contains(key)) return;
        processed.add(key);

        final raw = event.snapshot.value;
        if (raw == null) return;

        final data = Map<String, dynamic>.from(
          raw as Map<dynamic, dynamic>,
        );

        if (data['sudahDibaca'] == true) return;

        final playerIds = await _getAllPlayerIds();

        if (playerIds.isEmpty) return;

        await sendOneSignalNotif(
          playerIds: playerIds,
          title: data['title']?.toString() ?? 'Peringatan',
          body: data['description']?.toString() ?? '',
          level: data['level']?.toString() ?? 'tinggi',
          data: {
            'notifId': key,
            'walkerId': walkerId,
            'latitude': data['latitude']?.toString() ?? "0",
            'longitude': data['longitude']?.toString() ?? "0",
          },
        );
        debugPrint('[OneSignal] Push notif lama: $key');
      }
    });

    // Step 2: Listen notif BARU yang masuk setelah app dibuka
    return _notifRef.onChildAdded.listen((event) async {
      final key = event.snapshot.key ?? '';
      if (key.isEmpty || processedKeys.contains(key)) return;

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