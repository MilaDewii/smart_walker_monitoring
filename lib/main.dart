import 'package:flutter/material.dart';
import 'utils/app_colors.dart';
import 'utils/app_routes.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/monitoring_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/notif_screen.dart';
import 'screens/main_navigation.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GuardianWalk',
      debugShowCheckedModeBanner: false, // hilangkan banner "DEBUG"
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
        ),
        fontFamily: 'Poppins', // nanti tambahkan font
      ),
      initialRoute: AppRoutes.onboarding,
      routes: {
        AppRoutes.splash: (context) => const SplashScreen(),
        AppRoutes.login: (context) => const LoginScreen(),
        AppRoutes.register: (context) => const RegisterScreen(),
        AppRoutes.monitoring: (context) => const MainNavigation(),
        AppRoutes.onboarding: (context) => const OnboardingScreen(),
        AppRoutes.notification: (context) => const NotificationScreen(),
      },
    );
  }
}
