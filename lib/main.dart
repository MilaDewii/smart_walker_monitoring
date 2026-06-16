import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'database/database_helper.dart';
import 'services/notification_service.dart'; // ← TAMBAH
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
import 'services/onesignal_handler.dart';
import 'services/monitoring_service.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  print('Firebase initialized successfully');

  OneSignal.initialize("5b4eba8b-7292-4705-a67c-1810e621e035");
  await OneSignal.Notifications.requestPermission(true);

  // Pasang handler klik notif — cukup SEKALI
  setupOneSignalClickHandler(navigatorKey);

  // Inisialisasi SQLite
  await DatabaseHelper.instance.database;
  await DatabaseHelper.instance.initializeSettings();
  await DatabaseHelper.instance.checkTables();

  // ← TAMBAH: start listener push notif sejak app buka
  await _startNotificationListener();

  FirebaseDatabase.instance.ref('.info/connected').onValue.listen((event) {
    final isConnected = event.snapshot.value == true;
    print('Firebase RTDB Connected: $isConnected');
  });

  runApp(const MyApp());
  // ← HAPUS: setupOneSignalClickHandler yang duplikat di sini
}

// ← TAMBAH fungsi ini
Future<void> _startNotificationListener() async {
  try {
    final paired = await DatabaseHelper.instance.getLastPairedWalker();
    final walkerId = paired?['walker_id']?.toString();

    if (walkerId == null || walkerId.isEmpty) {
      debugPrint('[OneSignal] Listener tidak distart — walkerId kosong');
      return;
    }

    final service = NotificationService(walkerId: walkerId);

    MonitoringService.instance.startEventMonitoring(walkerId);

    // Tunggu OneSignal Player ID tersedia (maks 10 detik)
    String? playerId;
    for (int i = 0; i < 20; i++) {
      playerId = OneSignal.User.pushSubscription.id;
      if (playerId != null && playerId.isNotEmpty) break;
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (playerId == null || playerId.isEmpty) {
      debugPrint('[OneSignal] Player ID tidak tersedia setelah 10 detik');
    } else {
      await service.saveOneSignalId();
      debugPrint('[OneSignal] Player ID tersimpan: $playerId');
    }

    service.listenAndPushOneSignal();
    debugPrint('[OneSignal] Listener aktif untuk walker: $walkerId');
  } catch (e) {
    debugPrint('[OneSignal] _startNotificationListener error: $e');
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
        ),
        fontFamily: 'Poppins',
      ),
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash: (context) => const SplashScreen(),
        AppRoutes.register: (context) => const RegisterScreen(),
        AppRoutes.login: (context) => const LoginScreen(),
        AppRoutes.monitoring: (context) => const MainNavigation(),
        AppRoutes.onboarding: (context) => const OnboardingScreen(),
        AppRoutes.notification: (context) => const NotificationScreen(),
        AppRoutes.qrConnect: (context) => const QrConnectScreen(),
        AppRoutes.connectWalker: (context) => const WalkerConnectScreen(),
        AppRoutes.location: (context) => const LocationScreen(),
        AppRoutes.geofenceSetup: (context) => const GeofenceSetupScreen(),
        // KODE BARU
        AppRoutes.history: (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          String? openHistoryId;
          if (args is Map) {
            openHistoryId = args['openHistoryId']?.toString();
          }
          return HistoryScreen(openHistoryId: openHistoryId);
        },
      },
    );
  }
}
