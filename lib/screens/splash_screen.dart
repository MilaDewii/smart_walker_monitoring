import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../utils/app_colors.dart';
import '../utils/app_routes.dart';
import '../database/database_helper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _onMulai() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final session = await DatabaseHelper.instance.getLoginSession();
      print("SESSION SPLASH: $session");

      if (!mounted) return;

      if (session == null) {
        Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
        return;
      }

      final pairedWalker = await DatabaseHelper.instance.getPairedWalkers();
      print("PAIRED WALKER: $pairedWalker");

      if (!mounted) return;

      if (pairedWalker.isEmpty) {
        Navigator.pushReplacementNamed(context, AppRoutes.connectWalker);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.monitoring);
      }
    } catch (e) {
      print("Error saat navigasi: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Terjadi kesalahan: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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

              SvgPicture.asset(
                'assets/images/logo_guard.svg',
                width: 300,
                height: 300,
              ),
              const SizedBox(height: 32),

              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Guardian',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w400,
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

              Container(
                width: double.infinity,
                height: 1.5,
                color: AppColors.primary.withOpacity(0.3),
              ),
              const SizedBox(height: 13),

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

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _onMulai,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
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