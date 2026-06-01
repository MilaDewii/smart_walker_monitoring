import 'package:flutter/material.dart';
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

void main() {
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
      initialRoute: AppRoutes.onboarding,
      routes: {
        AppRoutes.splash: (context) => const SplashScreen(),
        AppRoutes.login: (context) => const LoginScreen(),
        AppRoutes.register: (context) => const RegisterScreen(),
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
