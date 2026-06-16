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

  // GANTI DENGAN API KEY ASLI
  static const String _oneSignalApiKey = "ISI_API_KEY_ONESIGNAL_KAMU";

  NotificationService({
    required this.walkerId,
    FirebaseDatabase? database,
  }) : _db = database ?? FirebaseDatabase.instance;

  // =========================================================
  // FIREBASE REFERENCE
  // =========================================================

  DatabaseReference get _notifRef => _db.ref('Walkers/$walkerId/notification');

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

      // simpan banyak device
      await _db.ref('Walkers/$walkerId/oneSignalIds/$id').set(true);

      debugPrint('[OneSignal] ID disimpan ke oneSignalIds: $id');
    } catch (e) {
      debugPrint('[OneSignal] saveOneSignalId error: $e');
    }
  }

  // =========================================================
  // REMOVE DEVICE SAAT LOGOUT
  // =========================================================

  Future<void> removeOneSignalId() async {
    try {
      final id = OneSignal.User.pushSubscription.id;

      if (id == null || id.isEmpty) return;

      await _db.ref('Walkers/$walkerId/oneSignalIds/$id').remove();

      debugPrint('[OneSignal] Device dihapus: $id');
    } catch (e) {
      debugPrint('[OneSignal] removeOneSignalId error: $e');
    }
  }

  // =========================================================
  // AMBIL SEMUA DEVICE
  // =========================================================

  Future<List<String>> _getAllPlayerIds() async {
    final snap = await _db.ref('Walkers/$walkerId/oneSignalIds').get();

    if (!snap.exists || snap.value == null) {
      return [];
    }

    final map = Map<String, dynamic>.from(snap.value as Map);

    return map.entries
        .where((e) => e.value == true)
        .map((e) => e.key.toString())
        .toList();
  }

  // =========================================================
  // KIRIM KE SEMUA DEVICE SEKALIGUS
  // =========================================================

  Future<void> sendOneSignalNotifToAll({
    required List<String> playerIds,
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    if (playerIds.isEmpty) {
      debugPrint("[OneSignal] Tidak ada device");
      return;
    }

    try {
      final resp = await http.post(
        Uri.parse(
          'https://api.onesignal.com/notifications',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Key $_oneSignalApiKey',
        },
        body: jsonEncode({
          'app_id': _oneSignalAppId,

          // kirim ke semua device
          'include_subscription_ids': playerIds,

          'headings': {'en': title},
          'contents': {'en': body},
          'data': data,
          'priority': 10,
        }),
      );

      debugPrint('[OneSignal] ${resp.statusCode} ${resp.body}');
    } catch (e) {
      debugPrint('[OneSignal] send error: $e');
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
          final item = AlertItem.fromFirebase(
            entry.key.toString(),
            entry.value as Map<dynamic, dynamic>,
          );

          items.add(item);
        } catch (e) {
          debugPrint('[NotificationService] Parse notif error: $e');
        }
      }

      items.sort(
        (a, b) => b.timestamp.compareTo(a.timestamp),
      );

      return items;
    });
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
        );
      } catch (e) {
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

  Future<void> markAsRead(String notifId) async {
    await _notifItemRef(notifId).update({'sudahDibaca': true});
  }

  Future<void> markAllAsRead(List<AlertItem> items) async {
    final unread = items.where((e) => !e.sudahDibaca).toList();

    if (unread.isEmpty) return;

    final Map<String, dynamic> updates = {};

    for (final item in unread) {
      updates['${item.id}/sudahDibaca'] = true;
    }

    await _notifRef.update(updates);
  }

  // =========================================================
  // ADD NOTIFICATION
  // =========================================================

  Future<void> addNotification(AlertItem item) async {
    await _notifItemRef(item.id).set(item.toFirebase());
  }

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
  // AUTO PUSH LISTENER
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

        await sendOneSignalNotifToAll(
          playerIds: playerIds,
          title: data['title']?.toString() ?? "Peringatan",
          body: data['description']?.toString() ?? "",
          data: {
            'notifId': key,
            'walkerId': walkerId,
            'latitude': data['latitude']?.toString() ?? "0",
            'longitude': data['longitude']?.toString() ?? "0",
          },
        );

        debugPrint("[OneSignal] Push dikirim ke ${playerIds.length} device");
      },
    );
  }
}
