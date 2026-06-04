import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../utils/app_colors.dart';
import '../utils/app_routes.dart';
import 'package:firebase_database/firebase_database.dart';
import '../database/database_helper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Tidak auto-pindah, user klik tombol sendiri
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // Logo SVG - ukuran besar seperti design
              SvgPicture.asset(
                'assets/images/Guardian.svg',
                width: 300,
                height: 300,
              ),
              const SizedBox(height: 32),

              // Teks "Guardian" + "Walk" dengan style berbeda
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Guardian',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w400, // tipis
                        color: AppColors.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    TextSpan(
                      text: 'Walk',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w200,
                        color: AppColors.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Garis pemisah
              Container(
                width: double.infinity,
                height: 1.5,
                color: AppColors.primary.withOpacity(0.3),
              ),
              const SizedBox(height: 13),

              // Tagline
              Text(
                'SMART ELDERY SAFETY SYSTEM',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textGrey,
                  letterSpacing: 2.0,
                ),
              ),

              const Spacer(flex: 2),

              // Tombol Mulai Sekarang
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      await FirebaseDatabase.instance.ref("test").set({
                        "status": "connected",
                        "time": DateTime.now().toString(),
                      });

                      print("Firebase RTDB Connected");

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Firebase Connected"),
                          ),
                        );

                        final session =
                            await DatabaseHelper.instance.getLoginSession();

                        print("SESSION SPLASH:");
                        print(session);

                        // belum login
                        if (session == null) {
                          Navigator.pushReplacementNamed(
                            context,
                            AppRoutes.onboarding,
                          );

                          return;
                        }

                        // cek walker pernah dipairing
                        final pairedWalker =
                            await DatabaseHelper.instance.getPairedWalkers();

                        print("PAIRED WALKER:");
                        print(pairedWalker);

                        // login tapi belum scan walker
                        if (pairedWalker.isEmpty) {
                          Navigator.pushReplacementNamed(
                            context,
                            AppRoutes.connectWalker,
                          );
                        } else {
                          // login + walker sudah tersambung
                          Navigator.pushReplacementNamed(
                            context,
                            AppRoutes.monitoring,
                          );
                        }
                      }
                    } catch (e) {
                      print("Firebase Error: $e");

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Firebase Error: $e"),
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Mulai Sekarang',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
