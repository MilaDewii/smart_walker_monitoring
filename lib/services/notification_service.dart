import 'dart:async';
import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/alert_model.dart';
import '../database/database_helper.dart';
import '../database/database_helper.dart' as db_helper;

class NotificationService {
  final FirebaseDatabase _db;
  final String walkerId;

  // ── Local feedback (suara & getar) ──────────────────────
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _alertSound = true;
  bool _vibration = true;
  String _soundMode = 'Normal'; // Silent | Normal | Loud

  NotificationService({
    required this.walkerId,
    FirebaseDatabase? database,
  }) : _db = database ?? FirebaseDatabase.instance {
    // ── FIX: dengarkan error internal AudioPlayer supaya kalau ada
    //    masalah pemutaran (file corrupt, codec tidak didukung, dsb)
    //    itu hanya di-log, bukan jadi unhandled exception yang lolos
    //    ke root zone dan berpotensi menjatuhkan app.
    _audioPlayer.onPlayerStateChanged.listen(
      (state) {},
      onError: (e) => debugPrint('[NotificationService] AudioPlayer stream error: $e'),
    );
  }

  // =========================================================
  // FIREBASE REFERENCE
  // =========================================================

  DatabaseReference get _notifRef => _db.ref('Walkers/$walkerId/notification');
  DatabaseReference get _tokensRef => _db.ref('Walkers/$walkerId/fcmTokens');
  DatabaseReference _notifItemRef(String notifId) => _notifRef.child(notifId);

  // =========================================================
  // SAVE FCM TOKEN (MULTI DEVICE)
  // =========================================================

  Future<void> saveFCMToken() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();

      final token = await messaging.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[FCM] Token null/kosong');
        return;
      }

      final deviceKey = token.hashCode.toRadixString(16);
      await _tokensRef.child(deviceKey).set(token);
      debugPrint('[FCM] Token disimpan: $token');

      messaging.onTokenRefresh.listen((newToken) async {
        try {
          final newKey = newToken.hashCode.toRadixString(16);
          await _tokensRef.child(newKey).set(newToken);
          debugPrint('[FCM] Token diperbarui: $newToken');
        } catch (e) {
          debugPrint('[FCM] onTokenRefresh error: $e');
        }
      });
    } catch (e) {
      debugPrint('[FCM] saveFCMToken error: $e');
    }
  }

  // =========================================================
  // CLEANUP TOKEN TIDAK VALID
  // =========================================================

  Future<void> cleanupInvalidTokens() async {
    try {
      final snap = await _tokensRef.get();
      if (!snap.exists || snap.value == null) return;
      if (snap.value is! Map) return;

      final map = Map<String, dynamic>.from(snap.value as Map);
      final Map<String, dynamic> updates = {};
      final Set<String> seen = {};

      for (final entry in map.entries) {
        final key = entry.key;
        final value = entry.value;

        if (value is! String || value.isEmpty) {
          updates[key] = null;
          debugPrint('[FCM] Hapus token rusak: $key');
          continue;
        }
        if (seen.contains(value)) {
          updates[key] = null;
          debugPrint('[FCM] Hapus token duplikat: $key');
          continue;
        }
        seen.add(value);
      }

      if (updates.isEmpty) return;
      await _tokensRef.update(updates);
      debugPrint('[FCM] Cleanup selesai, dihapus: ${updates.length} token');
    } catch (e) {
      debugPrint('[FCM] cleanupInvalidTokens error: $e');
    }
  }

  // =========================================================
  // REMOVE TOKEN SAAT LOGOUT
  // =========================================================

  Future<void> removeFCMToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      final deviceKey = token.hashCode.toRadixString(16);
      await _tokensRef.child(deviceKey).remove();
      debugPrint('[FCM] Token dihapus: $token');
    } catch (e) {
      debugPrint('[FCM] removeFCMToken error: $e');
    }
  }

  // =========================================================
  // AMBIL SEMUA TOKEN
  // =========================================================

  Future<List<String>> _getAllFCMTokens() async {
    try {
      final snap = await _tokensRef.get();
      if (!snap.exists || snap.value == null) return [];
      final map = Map<String, dynamic>.from(snap.value as Map);
      return map.values
          .where((v) => v is String && v.isNotEmpty)
          .map((v) => v.toString())
          .toList();
    } catch (e) {
      debugPrint('[FCM] _getAllFCMTokens error: $e');
      return [];
    }
  }

  // =========================================================
  // SEND FCM — via Google Apps Script (proxy)
  // =========================================================

  static const String _gasUrl =
      "https://script.google.com/macros/s/AKfycbwM0zB7KqrgjFSUmOIu_hbP2XU4dP-kmgbsDSVo4unXM4FHbc3yJ55Bxo9kZPdPpMds8g/exec";

  Future<void> sendFCMNotif({
    required List<String> tokens,
    required String title,
    required String body,
    required String level,
    required Map<String, String> data,
  }) async {
    if (tokens.isEmpty) {
      debugPrint('[FCM] tokens kosong, tidak kirim notif');
      return;
    }

    try {
      var resp = await http.post(
        Uri.parse(_gasUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'tokens': tokens,
          'title': title,
          'bodyText': body,
          'data': data,
        }),
      );

      int redirectCount = 0;
      while ((resp.statusCode == 301 || resp.statusCode == 302) &&
          redirectCount < 5) {
        final location = resp.headers['location'];
        debugPrint('[FCM] Redirect ke: $location');
        if (location == null || location.isEmpty) break;
        resp = await http.get(Uri.parse(location));
        redirectCount++;
      }

      debugPrint('[FCM] GAS: ${resp.statusCode} ${resp.body}');
    } catch (e) {
      debugPrint('[FCM] sendFCMNotif error: $e');
    }
  }

  static const String _cacheType = 'notification';

  Future<void> cacheNotifications(List<AlertItem> items) async {
    try {
      final helper = DatabaseHelper.instance;
      await helper.clearCacheByType(_cacheType);

      for (final item in items) {
        await helper.saveCacheHistory(
          type: _cacheType,
          title: item.id,
          subtitle: item.title,
          status: item.level.name,
          latitude: item.location.latitude,
          longitude: item.location.longitude,
          extra: jsonEncode(item.toFirebase()),
        );
      }

      debugPrint('[NotifCache] Tersimpan ${items.length} notifikasi ke cache');
    } catch (e) {
      debugPrint('[NotifCache] cacheNotifications error: $e');
    }
  }

  Future<List<AlertItem>> getCachedNotifications() async {
    try {
      final helper = DatabaseHelper.instance;
      final rows = await helper.getCacheByType(_cacheType);

      final List<AlertItem> items = [];
      for (final row in rows) {
        try {
          final extraStr = row['extra']?.toString();
          if (extraStr == null || extraStr.isEmpty) continue;

          final data = jsonDecode(extraStr) as Map<String, dynamic>;
          final key = row['title']?.toString() ?? data['id']?.toString() ?? '';

          items.add(AlertItem.fromFirebase(key, data));
        } catch (e) {
          debugPrint('[NotifCache] Parse cache error: $e');
        }
      }

      items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return items;
    } catch (e) {
      debugPrint('[NotifCache] getCachedNotifications error: $e');
      return [];
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
  // FETCH
  // =========================================================

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
        debugPrint('[NotificationService] Fetch notif error: $e');
      }
    }

    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return items;
  }

  // =========================================================
  // MARK READ / SAFE
  // =========================================================

  Future<void> markAsRead(String notifId) async {
    try {
      await _notifItemRef(notifId).update({'sudahDibaca': true});
    } catch (e) {
      debugPrint('[NotificationService] markAsRead error ($notifId): $e');
      rethrow;
    }
  }

  Future<void> markAsSafe(String notifId) async {
    try {
      await _notifItemRef(notifId).update({'sudahAman': true});
    } catch (e) {
      debugPrint('[NotificationService] markAsSafe error ($notifId): $e');
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
  // ADD / DELETE
  // =========================================================

  Future<void> addNotification(AlertItem item) async {
    await _notifItemRef(item.id).set(item.toFirebase());
  }

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
    return watchNotifications()
        .map((items) => items.where((e) => !e.sudahDibaca).length);
  }

  // =========================================================
  // LOCAL FEEDBACK SETTINGS
  // =========================================================

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
  // LOCAL FEEDBACK — getar & suara
  // =========================================================

  Future<void> playAlertFeedback(String level) async {
    // ── FIX: bungkus seluruh fungsi. Ini yang paling sering kepanggil
    //    persis di saat notifikasi masuk/muncul, jadi kalau ada error
    //    di sini (baik dari plugin vibration maupun audioplayers) yang
    //    paling cocok dengan gejala "app keluar sendiri pas ada
    //    jendela notif" yang dilaporkan user.
    try {
      if (level == 'aman') return;

      // ── GETAR ──
      if (_vibration) {
        try {
          final hasVibrator = await Vibration.hasVibrator();
          if (hasVibrator == true) {
            await Vibration.vibrate(pattern: _getVibrationPattern(level));
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
            // ── FIX: kalau file suara tidak ada / corrupt / codec
            //    tidak didukung device, ini akan gagal di sini dan
            //    hanya di-log, bukan menjatuhkan app.
            debugPrint('[NotificationService] play sound error: $e');
          }
        }
      }
    } catch (e, st) {
      debugPrint('[NotificationService] playAlertFeedback error: $e\n$st');
    }
  }

  List<int> _getVibrationPattern(String level) {
    final bool isLoud = _soundMode == 'Loud';
    final bool isSilent = _soundMode == 'Silent';

    if (level == 'darurat') {
      if (isLoud) return [0, 600, 150, 600, 150, 600];
      if (isSilent) return [0, 200];
      return [0, 400, 200, 400];
    }
    if (isLoud) return [0, 400, 200, 400];
    if (isSilent) return [0, 150];
    return [0, 250];
  }

  String _getSoundFile(String level) =>
      level == 'darurat' ? 'sounds/darurat.mp3' : 'sounds/waspada.mp3';

  double _getVolume() {
    switch (_soundMode) {
      case 'Loud':
        return 1.0;
      case 'Silent':
        return 0.0;
      default:
        return 0.6;
    }
  }

  // =========================================================
  // PUSH HELPER
  // =========================================================

  Future<void> _pushIfUnread(String key, Map<String, dynamic> data) async {
    try {
      if (data['sudahDibaca'] == true) return;

      final tokens = await _getAllFCMTokens();
      if (tokens.isEmpty) {
        debugPrint('[FCM] fcmTokens tidak ada, skip push: $key');
        return;
      }

      await sendFCMNotif(
        tokens: tokens,
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
      debugPrint('[FCM] Push notif: $key ke ${tokens.length} device');
    } catch (e) {
      debugPrint('[FCM] _pushIfUnread error ($key): $e');
    }
  }

  // =========================================================
  // AUTO PUSH LISTENER
  // =========================================================

  Future<StreamSubscription<DatabaseEvent>> listenAndPushFCM() async {
    final Set<String> processed = {};

    // ── FIX (AKAR MASALAH CRASH): `onChildAdded` di Firebase akan
    //    otomatis memicu event untuk SETIAP child yang SUDAH ADA di
    //    database pada saat listener ini dipasang — bukan cuma yang
    //    baru ditambahkan setelahnya. Karena Set `processed` di atas
    //    selalu kosong di awal (direset tiap app start), SEMUA histori
    //    notifikasi lama (bisa puluhan/ratusan) ikut diproses ulang
    //    sekaligus setiap kali listener ini dipasang: push FCM + request
    //    ke Google Apps Script + vibrasi + suara, semua ditembak beruntun
    //    dalam hitungan detik. Ini yang membebani main thread sampai
    //    Android meng-ANR / paksa tutup app (persis pola di log:
    //    "Skipped 679 frames", "Message ack timed out", tombstone).
    //
    //    Solusinya: ambil snapshot SEMUA notifikasi yang sudah ada
    //    DULU (sekali saja, sebelum listener dipasang), lalu tandai
    //    semuanya sebagai "processed". Dengan begitu `onChildAdded`
    //    cuma akan benar-benar memproses notifikasi yang muncul
    //    SETELAH snapshot ini diambil (yaitu yang benar-benar baru).
    try {
      final snap = await _notifRef.get();
      if (snap.exists && snap.value is Map) {
        final map = Map<dynamic, dynamic>.from(snap.value as Map);
        processed.addAll(map.keys.map((k) => k.toString()));
        debugPrint(
          '[FCM] Snapshot awal: ${processed.length} notif lama diabaikan (tidak di-replay)',
        );
      }
    } catch (e) {
      debugPrint('[FCM] Gagal ambil snapshot awal notifikasi: $e');
    }

    return _notifRef.onChildAdded.listen(
      (event) async {
        try {
          final key = event.snapshot.key ?? '';
          if (key.isEmpty || processed.contains(key)) return;
          processed.add(key);

          final raw = event.snapshot.value;
          if (raw == null) return;

          final data = Map<String, dynamic>.from(raw as Map);

          if (data['sudahDibaca'] != true) {
            await loadLocalFeedbackSettings();
            final level = data['level']?.toString() ?? 'waspada';
            await playAlertFeedback(level);
          }

          await _pushIfUnread(key, data);
        } catch (e, st) {
          debugPrint('[FCM] listenAndPushFCM item error: $e\n$st');
        }
      },
      onError: (e, st) {
        // ── FIX: onChildAdded juga butuh onError, kalau tidak,
        //    error dari stream Firebase (misalnya permission
        //    denied/koneksi) bisa jadi unhandled error di zone
        //    root yang berujung crash.
        debugPrint('[FCM] listenAndPushFCM stream error: $e\n$st');
      },
    );
  }

  // =========================================================
  // CLEANUP
  // =========================================================

  void dispose() {
    try {
      _audioPlayer.dispose();
    } catch (e) {
      debugPrint('[NotificationService] dispose error: $e');
    }
  }
}