import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'database/database_helper.dart';
import 'services/notification_service.dart';
import 'utils/app_colors.dart';
import 'utils/app_routes.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/notif_screen.dart';
import 'screens/main_navigation.dart';
import 'screens/scan_qr_screen.dart';
import 'screens/walker_connect_screen.dart';
import 'screens/history_screen.dart';
import 'screens/location_screen.dart';
import 'screens/geofence_setup_screen.dart';
import 'services/fcm_handler.dart';
import 'services/monitoring_service.dart';

final navigatorKey = GlobalKey<NavigatorState>();

// HARUS top-level function — dipanggil saat app terminated
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // ── FIX: bungkus try-catch. Handler ini dijalankan di isolate
  //    terpisah oleh sistem saat app background/terminated; kalau
  //    Firebase.initializeApp() gagal di sini (race condition,
  //    konfigurasi belum siap, dsb) sebaiknya cuma di-log, tidak
  //    ikut membuat proses background mati.
  try {
    await Firebase.initializeApp();
    debugPrint('[FCM] Background message: ${message.messageId}');
    // Tidak perlu push lagi — FCM sudah tampilkan notif otomatis
    // saat app di background/terminated kalau ada "notification" payload
  } catch (e, st) {
    debugPrint('[FCM] Background handler error: $e\n$st');
  }
}

Future<void> main() async {
  // ── FIX: bungkus seluruh startup dengan runZonedGuarded sebagai
  //    jaring pengaman terakhir. Kalau ada exception async yang lolos
  //    dari semua try-catch di tempat lain (misalnya dari listener
  //    stream Firebase yang belum ditangani), ini akan menangkapnya
  //    supaya app tidak langsung force-close, cukup di-log.
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // ── FIX: tangkap juga error yang muncul dari Flutter framework
    //    (widget build error dsb) supaya ter-log dengan jelas alih-alih
    //    hanya menampilkan red screen / diam-diam force close di release.
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('[FlutterError] ${details.exceptionAsString()}');
    };

    try {
      await Firebase.initializeApp();
      print('Firebase initialized successfully');
    } catch (e, st) {
      debugPrint('[Startup] Firebase.initializeApp gagal: $e\n$st');
    }

    // Inisialisasi local notifications — WAJIB sebelum FCM listener
    // dipasang, supaya notifikasi bisa ditampilkan manual saat app
    // sedang dibuka (foreground).
    await initLocalNotifications(navigatorKey);

    // Setup FCM background handler — HARUS sebelum runApp
    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    } catch (e, st) {
      debugPrint('[Startup] onBackgroundMessage gagal didaftarkan: $e\n$st');
    }

    // Setup handler klik notif FCM
    setupFCMClickHandler(navigatorKey);

    try {
      await DatabaseHelper.instance.database;
      await DatabaseHelper.instance.initializeSettings();
      await DatabaseHelper.instance.checkTables();
    } catch (e, st) {
      debugPrint('[Startup] DatabaseHelper init gagal: $e\n$st');
    }

    try {
      FirebaseDatabase.instance.ref('.info/connected').onValue.listen(
        (event) {
          final isConnected = event.snapshot.value == true;
          print('Firebase RTDB Connected: $isConnected');
        },
        onError: (e) {
          debugPrint('[Startup] .info/connected stream error: $e');
        },
      );
    } catch (e) {
      debugPrint('[Startup] Gagal listen .info/connected: $e');
    }

    runApp(const MyApp());

    // Dijalankan SETELAH runApp — tidak blocking UI
    _startNotificationListener();
  }, (error, stackTrace) {
    debugPrint('[UncaughtError] $error\n$stackTrace');
  });
}

Future<void> _startNotificationListener() async {
  try {
    final paired    = await DatabaseHelper.instance.getLastPairedWalker();
    final walkerId  = paired?['walker_id']?.toString();

    if (walkerId == null || walkerId.isEmpty) {
      debugPrint('[FCM] Listener tidak distart — walkerId kosong');
      return;
    }

    final service = NotificationService(walkerId: walkerId);
    await service.cleanupInvalidTokens();

    // Tunggu FCM token tersedia (maks 10 detik)
    String? token;
    for (int i = 0; i < 20; i++) {
      token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) break;
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (token == null || token.isEmpty) {
      debugPrint('[FCM] Token tidak tersedia setelah 10 detik');
    } else {
      await service.saveFCMToken();
      debugPrint('[FCM] Token tersimpan: $token');
    }

    await service.listenAndPushFCM();
    debugPrint('[FCM] Listener aktif untuk walker: $walkerId');
  } catch (e, st) {
    debugPrint('[FCM] _startNotificationListener error: $e\n$st');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'GuardianWalk',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        fontFamily: 'Poppins',
      ),
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash:         (context) => const SplashScreen(),
        AppRoutes.register:       (context) => const RegisterScreen(),
        AppRoutes.login:          (context) => const LoginScreen(),
        AppRoutes.monitoring:     (context) => const MainNavigation(),
        AppRoutes.onboarding:     (context) => const OnboardingScreen(),
        AppRoutes.notification:   (context) => const NotificationScreen(),
        AppRoutes.qrConnect:      (context) => const QrConnectScreen(),
        AppRoutes.connectWalker:  (context) => const WalkerConnectScreen(),
        AppRoutes.location:       (context) => const LocationScreen(),
        AppRoutes.geofenceSetup:  (context) => const GeofenceSetupScreen(),
        AppRoutes.history: (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          String? openHistoryId;
          if (args is Map) openHistoryId = args['openHistoryId']?.toString();
          return HistoryScreen(openHistoryId: openHistoryId);
        },
      },
    );
  }
}