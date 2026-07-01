import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../models/alert_model.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import '../database/database_helper.dart';

class NotificationService {
  final FirebaseDatabase _db;
  final String walkerId;

  static final String _oneSignalAppId = dotenv.env['ONESIGNAL_APP_ID']!;
  static final String _oneSignalApiKey = dotenv.env['ONESIGNAL_API_KEY']!;

  // ── Local feedback (suara & getar) ──────────────────────
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _alertSound = true;
  bool _vibration = true;
  String _soundMode = 'Normal'; // Silent | Normal | Loud

  NotificationService({
    required this.walkerId,
    FirebaseDatabase? database,
  }) : _db = database ?? FirebaseDatabase.instance;

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
  // LOCAL FEEDBACK SETTINGS
  // =========================================================
  // Diambil dari SQLite (diisi lewat SettingsScreen: Alert Sound,
  // Vibration, Sound Mode). Dipanggil ulang tiap ada notif baru
  // supaya selalu pakai nilai terbaru, bukan cache lama.

  Future<void> loadLocalFeedbackSettings() async {
    try {
      final settings = await DatabaseHelper.instance.getSettings();
      if (settings != null) {
        _alertSound = (settings['alert_sound'] ?? 1) == 1;
        _vibration = (settings['vibration'] ?? 1) == 1;
        _soundMode = settings['sound_mode'] ?? 'Normal';
      }
    } catch (e) {
      debugPrint('[NotificationService] loadLocalFeedbackSettings error: $e');
    }
  }

  // =========================================================
  // LOCAL FEEDBACK — getar & suara di HP user
  // =========================================================
  // level: 'waspada' | 'darurat' (level 'aman' tidak masuk notif,
  // jadi tidak perlu ditangani di sini)

  Future<void> playAlertFeedback(String level) async {
    if (level == 'aman') return;

    // ── GETAR ──
    if (_vibration) {
      try {
        final hasVibrator = await Vibration.hasVibrator();
        if (hasVibrator == true) {
          Vibration.vibrate(pattern: _getVibrationPattern(level));
        }
      } catch (e) {
        debugPrint('[NotificationService] vibration error: $e');
      }
    }

    // ── SUARA ──
    if (_alertSound) {
      final volume = _getVolume();
      if (volume > 0) {
        try {
          await _audioPlayer.stop();
          await _audioPlayer.setVolume(volume);
          await _audioPlayer.play(AssetSource(_getSoundFile(level)));
        } catch (e) {
          debugPrint('[NotificationService] play sound error: $e');
        }
      }
    }
  }

  // Pola getar: makin kuat kalau level darurat / mode Loud
  List<int> _getVibrationPattern(String level) {
    final bool isLoud = _soundMode == 'Loud';
    final bool isSilent = _soundMode == 'Silent';

    if (level == 'darurat') {
      if (isLoud) return [0, 600, 150, 600, 150, 600];
      if (isSilent) return [0, 200];
      return [0, 400, 200, 400];
    }
    // level == 'waspada' / lainnya
    if (isLoud) return [0, 400, 200, 400];
    if (isSilent) return [0, 150];
    return [0, 250];
  }

  String _getSoundFile(String level) {
    return level == 'darurat' ? 'sounds/darurat.mp3' : 'sounds/waspada.mp3';
  }

  double _getVolume() {
    switch (_soundMode) {
      case 'Loud':
        return 1.0;
      case 'Silent':
        return 0.0;
      case 'Normal':
      default:
        return 0.6;
    }
  }

  // =========================================================
  // PUSH HELPER (dipakai bersama oleh notif lama & baru)
  // =========================================================

  Future<void> _pushIfUnread(String key, Map<String, dynamic> data) async {
    if (data['sudahDibaca'] == true) return;

    final playerIds = await _getAllPlayerIds();
    if (playerIds.isEmpty) {
      debugPrint('[OneSignal] oneSignalIds tidak ada, skip push: $key');
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
    debugPrint('[OneSignal] Push notif: $key ke ${playerIds.length} device');
  }

  // =========================================================
  // AUTO PUSH LISTENER (notif lama yang belum dibaca + notif baru)
  // =========================================================
  //
  // FIX dari versi sebelumnya:
  // - Sebelumnya ada DUA `return` di fungsi ini, sehingga listener kedua
  //   (notif baru) tidak pernah aktif (unreachable code).
  // - Variabel `processedKeys` dipakai tanpa pernah dideklarasikan
  //   (undefined_identifier).
  // - Sekarang digabung jadi SATU subscription `onChildAdded`, dengan
  //   `Set<String> processed` untuk mencegah duplikat push pada item
  //   yang sama.
  //
  // TAMBAHAN:
  // - Sebelum push OneSignal, jalankan feedback lokal (getar+suara) di
  //   HP user berdasarkan setting terbaru dari SettingsScreen.

  StreamSubscription<DatabaseEvent> listenAndPushOneSignal() {
    final Set<String> processed = {};

    return _notifRef.onChildAdded.listen((event) async {
      final key = event.snapshot.key ?? '';
      if (key.isEmpty || processed.contains(key)) return;
      processed.add(key);

      final raw = event.snapshot.value;
      if (raw == null) return;

      final data = Map<String, dynamic>.from(raw as Map);

      try {
        // Feedback lokal (getar+suara) — hanya untuk notif yang belum dibaca
        if (data['sudahDibaca'] != true) {
          await loadLocalFeedbackSettings();
          final level = data['level']?.toString() ?? 'waspada';
          await playAlertFeedback(level);
        }

        await _pushIfUnread(key, data);
      } catch (e) {
        debugPrint('[OneSignal] listenAndPushOneSignal error ($key): $e');
      }
    });
  }

  // =========================================================
  // CLEANUP
  // =========================================================

  void dispose() {
    _audioPlayer.dispose();
  }
}