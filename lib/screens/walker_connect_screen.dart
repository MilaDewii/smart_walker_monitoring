import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_routes.dart';

class WalkerConnectScreen extends StatelessWidget {
  const WalkerConnectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F0FB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // ── Header ──────────────────────────────────
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor:
                        AppColors.primary.withOpacity(0.12),
                    child: const Icon(Icons.person_rounded,
                        color: AppColors.primary, size: 26),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Haillo, Mia',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textGrey)),
                      Text('Monitoring Lansia',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark)),
                    ],
                  ),
                ],
              ),

              const Spacer(),

              // ── Illustration area ────────────────────────
              Center(
                child: Column(
                  children: [
                    // Icon
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: AppColors.statusRed.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.bluetooth_disabled_rounded,
                        size: 48,
                        color: AppColors.statusRed,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title
                    const Text(
                      'Walker Belum Terhubung',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Subtitle
                    const Text(
                      'Hubungkan GuardianWalk untuk mulai\nmonitoring lokasi, aktivitas,\ndan deteksi jatuh secara realtime.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textGrey,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // ── Button ──────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(
                      context, AppRoutes.qrConnect),
                  icon: const Icon(Icons.qr_code_scanner_rounded,
                      size: 20),
                  label: const Text(
                    'Hubungkan Walker',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Skip ────────────────────────────────────
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pushReplacementNamed(
                      context, AppRoutes.monitoring),
                  child: const Text(
                    'Lewati untuk saat ini',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textGrey,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}