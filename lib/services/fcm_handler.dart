import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../database/database_helper.dart';
import '../models/alert_model.dart';
import '../services/notification_service.dart';
import '../screens/notif_screen.dart' show NotificationDetailScreen;
import '../services/history_service.dart';
import '../utils/app_routes.dart';

final FlutterLocalNotificationsPlugin _localNotif =
    FlutterLocalNotificationsPlugin();

// ID channel notifikasi — HARUS sama persis di 3 tempat:
// 1. AndroidManifest.xml (meta-data default_notification_channel_id,
//    di level <application>, BUKAN di dalam <activity>)
// 2. createNotificationChannel() di bawah (dibuat lebih awal, sebelum
//    notifikasi apapun masuk -- ini yang dipakai sistem utk notif
//    background/terminated)
// 3. AndroidNotificationDetails di _showLocalNotification() (dipakai utk
//    notif manual saat app foreground)
const String _channelId = 'guardianwalk_alert';
const String _channelName = 'Guardian Walk Alerts';
const String _channelDesc = 'Notifikasi peringatan GuardianWalk';

// =========================================================
// INIT LOCAL NOTIFICATIONS
// =========================================================
Future<void> initLocalNotifications(
  GlobalKey<NavigatorState> navigatorKey,
) async {
  try {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _localNotif.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // ── FIX: seluruh callback dibungkus try-catch. Callback ini
        //    dipanggil dari native (plugin channel) sehingga kalau ada
        //    exception yang lolos tanpa ditangkap, ada risiko itu
        //    ikut menjatuhkan proses app di beberapa versi Android.
        try {
          final payload = response.payload;
          if (payload == null || payload.isEmpty) {
            debugPrint('[FCM] Local notif payload kosong');
            return;
          }
          final data = Map<String, dynamic>.from(jsonDecode(payload) as Map);
          debugPrint('[FCM] Tap notif lokal (foreground): $data');
          _navigateToDetail(navigatorKey, data);
        } catch (e, st) {
          debugPrint('[FCM] Gagal proses tap notif lokal: $e\n$st');
        }
      },
    );

    // ── FIX: buat channel EKSPLISIT di sini, sebelum notifikasi apapun
    //    masuk.
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.high,
      );

      await _localNotif
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      debugPrint('[FCM] Notification channel "$_channelId" siap dibuat');
    }
  } catch (e, st) {
    // ── FIX: kalau init plugin gagal (misalnya res icon tidak
    //    ditemukan, atau masalah platform channel lain), jangan biarkan
    //    ini melempar exception yang belum tertangkap ke main() —
    //    cukup log, app tetap lanjut jalan walau tanpa local notif.
    debugPrint('[FCM] initLocalNotifications gagal: $e\n$st');
  }
}

Future<void> _showLocalNotification(RemoteMessage message) async {
  // ── FIX: seluruh isi fungsi dibungkus try-catch. Sebelumnya kalau
  //    _localNotif.show() melempar PlatformException (misalnya karena
  //    payload/icon/channel bermasalah di level native), exception ini
  //    tidak tertangkap sama sekali dan berpotensi menjatuhkan app
  //    tepat saat notifikasi masuk — persis gejala yang dilaporkan user.
  try {
    final title = message.data['title']?.toString() ??
        message.notification?.title ??
        'Peringatan';
    final body =
        message.data['body']?.toString() ?? message.notification?.body ?? '';

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      playSound: false,
      enableVibration: false,
    );

    const notifDetails = NotificationDetails(android: androidDetails);

    await _localNotif.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notifDetails,
      payload: jsonEncode({
        'notifId': message.data['notifId']?.toString() ?? '',
        'walkerId': message.data['walkerId']?.toString() ?? '',
      }),
    );
  } catch (e, st) {
    debugPrint('[FCM] _showLocalNotification gagal: $e\n$st');
  }
}

void setupFCMClickHandler(GlobalKey<NavigatorState> navigatorKey) {
  // ── App FOREGROUND — tampilkan notif lokal ──────────────
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    // ── FIX: bungkus seluruh handler. Ini listener stream FCM;
    //    kalau salah satu langkah di dalamnya (show notif, play
    //    feedback) melempar error tak tertangani, sebaiknya app tetap
    //    hidup dan lanjut menerima pesan berikutnya.
    try {
      debugPrint('[FCM] Foreground message: ${message.data}');

      await _showLocalNotification(message);

      final walkerId = message.data['walkerId']?.toString();
      if (walkerId != null && walkerId.isNotEmpty) {
        final service = NotificationService(walkerId: walkerId);
        await service.loadLocalFeedbackSettings();
        await service.playAlertFeedback(
          message.data['level']?.toString() ?? 'waspada',
        );
      }
    } catch (e, st) {
      debugPrint('[FCM] onMessage handler error: $e\n$st');
    }
  });

  // ── App BACKGROUND — user tap notif ────────────────────
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    try {
      debugPrint('[FCM] Tap dari background: ${message.data}');
      _navigateToDetail(navigatorKey, message.data);
    } catch (e, st) {
      debugPrint('[FCM] onMessageOpenedApp error: $e\n$st');
    }
  });

  // ── App TERMINATED — user tap notif ────────────────────
  FirebaseMessaging.instance.getInitialMessage().then((message) {
    try {
      if (message != null) {
        debugPrint('[FCM] Tap dari terminated: ${message.data}');
        Future.delayed(const Duration(milliseconds: 1000), () {
          _navigateToDetail(navigatorKey, message.data);
        });
      }
    } catch (e, st) {
      debugPrint('[FCM] getInitialMessage error: $e\n$st');
    }
  });
}

Future<void> _navigateToDetail(
  GlobalKey<NavigatorState> navigatorKey,
  Map<String, dynamic> data,
) async {
  // ── FIX: bungkus seluruh alur navigasi. Sebelumnya, kalau salah
  //    satu await di sini gagal (fetch RTDB, baca file foto, dsb),
  //    exception naik tanpa tertangkap.
  try {
    final notifId = data['notifId']?.toString();
    final walkerId = data['walkerId']?.toString();

    debugPrint('[FCM] notifId=$notifId walkerId=$walkerId');

    if (notifId == null ||
        notifId.isEmpty ||
        walkerId == null ||
        walkerId.isEmpty) {
      debugPrint('[FCM] notifId/walkerId kosong, batal navigasi');
      return;
    }

    await _waitForNavigatorReady(navigatorKey);
    if (navigatorKey.currentState == null) {
      debugPrint('[FCM] Navigator tidak pernah siap, batal navigasi');
      return;
    }
    await Future.delayed(const Duration(milliseconds: 300));

    final service = NotificationService(walkerId: walkerId);
    final items = await service.fetchNotifications();
    debugPrint('[FCM] fetched ${items.length} notif dari RTDB');

    AlertItem? item;
    for (final a in items) {
      if (a.id == notifId) {
        item = a;
        break;
      }
    }

    if (item == null) {
      debugPrint('[FCM] notifId $notifId tidak ditemukan, ke halaman notif');
      navigatorKey.currentState?.pushNamed(AppRoutes.notification);
      return;
    }

    await service.markAsRead(item.id);

    final profile = await DatabaseHelper.instance.getProfile();
    final namaLengkap = profile?['nama']?.toString() ?? 'User';
    final namaLansia = profile?['nama_lansia']?.toString() ?? 'Nama Lansia';
    final fotoPath = profile?['foto']?.toString() ?? '';
    File? fotoFile;
    try {
      if (fotoPath.isNotEmpty && File(fotoPath).existsSync()) {
        fotoFile = File(fotoPath);
      }
    } catch (e) {
      // ── FIX: akses file foto profil bisa gagal (path tidak valid,
      //    permission dicabut, dsb) — jangan sampai menggagalkan
      //    seluruh proses navigasi hanya karena foto tidak terbaca.
      debugPrint('[FCM] Gagal baca foto profil: $e');
      fotoFile = null;
    }

    final historyService = HistoryService(walkerId: walkerId);
    final historyItem = await historyService.findByNotification(
      timestamp: item.timestamp,
      title: item.title,
    );
    debugPrint('[FCM] historyItem id: ${historyItem?.id}');

    await _waitForNavigatorReady(navigatorKey);
    if (navigatorKey.currentState == null) {
      debugPrint('[FCM] Navigator tidak siap (kedua kali), batal navigasi');
      return;
    }

    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => NotificationDetailScreen(
          item: item!.copyWith(sudahDibaca: true),
          namaLansia: namaLansia,
          namaLengkap: namaLengkap,
          fotoFile: fotoFile,
          service: service,
          historyItem: historyItem,
        ),
      ),
    );
    debugPrint('[FCM] Navigasi ke NotificationDetailScreen berhasil');
  } catch (e, st) {
    debugPrint('[FCM] _navigateToDetail error: $e\n$st');
  }
}

Future<void> _waitForNavigatorReady(GlobalKey<NavigatorState> key) async {
  int attempts = 0;
  while (key.currentState == null && attempts < 50) {
    await Future.delayed(const Duration(milliseconds: 100));
    attempts++;
  }
}