import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'database/database_helper.dart';
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
// import 'screens/history_screen.dart'; // Removed to clear analyzer warning
import 'screens/location_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  print('Firebase initialized successfully');

  // Inisialisasi SQLite
  await DatabaseHelper.instance.database;
  // await DatabaseHelper.instance.logout();
  await DatabaseHelper.instance.checkTables();

  FirebaseDatabase.instance.ref('.info/connected').onValue.listen((event) {
    final isConnected = event.snapshot.value == true;
    print('Firebase Realtime Database connected: $isConnected');
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      },
    );
  }
}
