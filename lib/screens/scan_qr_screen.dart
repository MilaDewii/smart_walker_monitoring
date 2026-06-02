import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_routes.dart';

// ============================================================
// COLORS
// ============================================================
class _C {
  static const Color primary      = AppColors.primary;    // #1E3A8A
  static const Color secondary    = AppColors.secondary;  // #3B82F6
  static const Color bgPage       = Color(0xFFE8F0FB);
  static const Color white        = AppColors.white;
  // static const Color textDark     = AppColors.textDark;
  static const Color textMid      = AppColors.textGrey;
}

// ============================================================
// QR CONNECT SCREEN
// ============================================================
class QrConnectScreen extends StatefulWidget {
  const QrConnectScreen({super.key});

  @override
  State<QrConnectScreen> createState() => _QrConnectScreenState();
}

class _QrConnectScreenState extends State<QrConnectScreen>
    with TickerProviderStateMixin {

  bool _isScanning = false;
  bool _connected  = false;

  late AnimationController _scanLineCtrl;
  late Animation<double>   _scanLineAnim;

  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  late AnimationController _cornerCtrl;
  late Animation<double>   _cornerAnim;

  @override
  void initState() {
    super.initState();

    // Scan line animasi naik turun
    _scanLineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _scanLineAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _scanLineCtrl, curve: Curves.easeInOut),
    );

    // Pulse animasi pada lingkaran
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Corner fade-in
    _cornerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _cornerAnim = CurvedAnimation(parent: _cornerCtrl, curve: Curves.easeOut);
    _cornerCtrl.forward();
  }

  @override
  void dispose() {
    _scanLineCtrl.dispose();
    _pulseCtrl.dispose();
    _cornerCtrl.dispose();
    super.dispose();
  }

  void _startScan() {
    setState(() => _isScanning = true);
    _scanLineCtrl.repeat(reverse: true);

    // Simulasi koneksi berhasil setelah 3 detik
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      _scanLineCtrl.stop();
      setState(() {
        _isScanning = false;
        _connected  = true;
      });
    });
  }

  void _goToHome() {
    Navigator.pushReplacementNamed(context, AppRoutes.monitoring);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.primary,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopSection(),
            Expanded(child: _buildBottomSheet()),
          ],
        ),
      ),
    );
  }

  // ── Top Section (biru tua, logo + judul) ─────────────────
  Widget _buildTopSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      child: Column(
        children: [
          // Logo + nama app
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.directions_walk_rounded,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 10),
              const Text(
                'GuardianWalk',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          // Judul & subtitle
          const Text(
            'Hubungkan Walker Anda',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Scan QR pada walker untuk mulai\nmonitoring secara realtime',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom Sheet putih ────────────────────────────────────
  Widget _buildBottomSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: _C.bgPage,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
        child: Column(
          children: [
            _buildQrBox(),
            const SizedBox(height: 20),
            _buildHint(),
            const SizedBox(height: 28),
            _buildActionButton(),
            const SizedBox(height: 16),
            _buildSkipButton(),
          ],
        ),
      ),
    );
  }

  // ── QR Box ───────────────────────────────────────────────
  Widget _buildQrBox() {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, __) {
        return Transform.scale(
          scale: _isScanning ? _pulseAnim.value : 1.0,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _C.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: _C.primary.withOpacity(0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                // Status badge
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: _connected
                      ? _buildStatusBadge(
                          'Terhubung!',
                          Icons.check_circle_rounded,
                          AppColors.statusGreen,
                          const Color(0xFFDCFCE7),
                          key: const ValueKey('connected'),
                        )
                      : _isScanning
                          ? _buildStatusBadge(
                              'Memindai...',
                              Icons.radar_rounded,
                              _C.secondary,
                              _C.bgPage,
                              key: const ValueKey('scanning'),
                            )
                          : _buildStatusBadge(
                              'Siap Scan',
                              Icons.qr_code_scanner_rounded,
                              _C.primary,
                              _C.bgPage,
                              key: const ValueKey('ready'),
                            ),
                ),
                const SizedBox(height: 20),

                // QR Frame
                FadeTransition(
                  opacity: _cornerAnim,
                  child: SizedBox(
                    width: 220,
                    height: 220,
                    child: Stack(
                      children: [
                        // Background abu
                        Container(
                          decoration: BoxDecoration(
                            color: _C.bgPage,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),

                        // QR placeholder / connected state
                        Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 500),
                            child: _connected
                                ? _buildConnectedCenter()
                                : _buildQrPlaceholder(),
                          ),
                        ),

                        // Scan line
                        if (_isScanning)
                          AnimatedBuilder(
                            animation: _scanLineAnim,
                            builder: (_, __) {
                              return Positioned(
                                top: _scanLineAnim.value * 200,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 2,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        _C.secondary.withOpacity(0),
                                        _C.secondary,
                                        _C.secondary.withOpacity(0),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _C.secondary.withOpacity(0.6),
                                        blurRadius: 6,
                                      )
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                        // Corner brackets
                        ..._buildCorners(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(
    String label,
    IconData icon,
    Color color,
    Color bg, {
    Key? key,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }

  Widget _buildQrPlaceholder() {
    return Column(
      key: const ValueKey('placeholder'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.qr_code_2_rounded,
          size: 100,
          color: _C.primary.withOpacity(0.25),
        ),
        const SizedBox(height: 8),
        Text(
          'Arahkan ke QR Walker',
          style: TextStyle(
              fontSize: 11,
              color: _C.textMid.withOpacity(0.7)),
        ),
      ],
    );
  }

  Widget _buildConnectedCenter() {
    return Column(
      key: const ValueKey('done'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFFDCFCE7),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded,
              size: 40, color: AppColors.statusGreen),
        ),
        const SizedBox(height: 12),
        const Text('Walker Terdeteksi',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.statusGreen)),
        const SizedBox(height: 4),
        Text('ID: GW-2025-0042',
            style: TextStyle(fontSize: 11, color: _C.textMid)),
      ],
    );
  }

  // Empat sudut bracket
  List<Widget> _buildCorners() {
    const double size = 22;
    const double thick = 3.5;
    final color = _isScanning ? _C.secondary : _C.primary;

    Widget corner({
      required AlignmentGeometry alignment,
      required Border border,
    }) =>
        Align(
          alignment: alignment,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              border: border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );

    return [
      corner(
        alignment: Alignment.topLeft,
        border: Border(
          top:  BorderSide(color: color, width: thick),
          left: BorderSide(color: color, width: thick),
        ),
      ),
      corner(
        alignment: Alignment.topRight,
        border: Border(
          top:   BorderSide(color: color, width: thick),
          right: BorderSide(color: color, width: thick),
        ),
      ),
      corner(
        alignment: Alignment.bottomLeft,
        border: Border(
          bottom: BorderSide(color: color, width: thick),
          left:   BorderSide(color: color, width: thick),
        ),
      ),
      corner(
        alignment: Alignment.bottomRight,
        border: Border(
          bottom: BorderSide(color: color, width: thick),
          right:  BorderSide(color: color, width: thick),
        ),
      ),
    ];
  }

  // ── Hint text ────────────────────────────────────────────
  Widget _buildHint() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.info_outline_rounded,
            size: 14, color: _C.textMid.withOpacity(0.7)),
        const SizedBox(width: 6),
        Text(
          'Pastikan QR terlihat jelas dan berada di dekat kamera',
          style: TextStyle(
              fontSize: 11,
              color: _C.textMid.withOpacity(0.8)),
        ),
      ],
    );
  }

  // ── Tombol utama ─────────────────────────────────────────
  Widget _buildActionButton() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _connected
          ? _buildMainBtn(
              key: const ValueKey('btn_go'),
              label: 'Mulai Monitoring',
              icon: Icons.monitor_heart_rounded,
              color: AppColors.statusGreen,
              onTap: _goToHome,
            )
          : _isScanning
              ? _buildMainBtn(
                  key: const ValueKey('btn_scanning'),
                  label: 'Memindai...',
                  icon: Icons.hourglass_top_rounded,
                  color: _C.secondary,
                  onTap: null,
                )
              : _buildMainBtn(
                  key: const ValueKey('btn_start'),
                  label: 'Mulai Scan',
                  icon: Icons.qr_code_scanner_rounded,
                  color: _C.primary,
                  onTap: _startScan,
                ),
    );
  }

  Widget _buildMainBtn({
    required Key key,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: onTap != null ? color : color.withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
          boxShadow: onTap != null
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Skip / Lewati ────────────────────────────────────────
  Widget _buildSkipButton() {
    if (_connected) return const SizedBox.shrink();
    return GestureDetector(
      onTap: _goToHome,
      child: Text(
        'Lewati untuk saat ini',
        style: TextStyle(
          fontSize: 12,
          color: _C.textMid.withOpacity(0.7),
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}