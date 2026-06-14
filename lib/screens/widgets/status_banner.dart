import 'package:flutter/material.dart';
import '../../models/walker_data.dart';
import '../../utils/app_colors.dart';

class StatusBanner extends StatelessWidget {
  final WalkerData walkerData;

  const StatusBanner({super.key, required this.walkerData});

  // ── Tentukan level status ─────────────────────────────────────────────────
  // MERAH  : jatuh terdeteksi ATAU lansia tidak terdeteksi di belakang walker
  //          ATAU keluar geofence
  // KUNING : confidence tinggi (resiko jatuh) → waspada
  // HIJAU  : semua aman
  _StatusLevel get _level {
    // Merah: jatuh / tidak ada lansia di belakang / keluar area
    if (walkerData.jatuh ||
        !walkerData.ultrasonicBack ||
        walkerData.geofenceStatus == 'outside') {
      return _StatusLevel.darurat;
    }
    // Kuning: confidence >= 40% → gerakan berisiko
    if (walkerData.fallConfidence >= 0.4 ||
        walkerData.status == 'peringatan') {
      return _StatusLevel.waspada;
    }
    return _StatusLevel.aman;
  }

  Color get _bgColor {
    switch (_level) {
      case _StatusLevel.darurat:
        return const Color(0xFFE53935);
      case _StatusLevel.waspada:
        return const Color(0xFFFFA726);
      case _StatusLevel.aman:
        return const Color.fromARGB(255, 34, 197, 94);
    }
  }

  String get _title {
    switch (_level) {
      case _StatusLevel.darurat:
        return 'Status Lansia : Darurat';
      case _StatusLevel.waspada:
        return 'Status Lansia : Waspada';
      case _StatusLevel.aman:
        return 'Status Lansia : Aman';
    }
  }

  String get _subtitle {
    if (walkerData.jatuh) {
      return 'Terdeteksi Jatuh! Segera Periksa Lansia !';
    }
    if (!walkerData.ultrasonicBack) {
      return 'Lansia Tidak Terdeteksi, Segera Periksa Lansia !';
    }
    if (walkerData.geofenceStatus == 'outside') {
      return 'Terdeteksi Kelainan, Segera Periksa Lansia !';
    }
    if (_level == _StatusLevel.waspada) {
      return 'Gerakan Berisiko Terdeteksi, Harap Perhatikan !';
    }
    return 'Tidak ada kejadian darurat';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _bgColor.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Ikon status
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _level == _StatusLevel.aman
                  ? Icons.check_circle_outline_rounded
                  : _level == _StatusLevel.waspada
                      ? Icons.warning_amber_rounded
                      : Icons.crisis_alert_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          // Teks
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.92),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Pulse dot (hanya darurat/waspada)
          if (_level != _StatusLevel.aman)
            _PulseDot(color: Colors.white),
        ],
      ),
    );
  }
}

// ── Level enum ──────────────────────────────────────────────────────────────
enum _StatusLevel { darurat, waspada, aman }

// ── Animated pulse dot ──────────────────────────────────────────────────────
class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}