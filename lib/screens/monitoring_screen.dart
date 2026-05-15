import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart';
import '../utils/app_colors.dart';

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  String _status = 'aman';

  final String _namaLansia = 'Nama Lansia';
  final int _langkah = 1200;
  final bool _jatuh = false;
  final LatLng _posisiLansia = LatLng(-7.0051, 110.4381);

  Color get _statusColor {
    switch (_status) {
      case 'bahaya':
        return AppColors.statusRed;
      case 'peringatan':
        return AppColors.statusYellow;
      default:
        return AppColors.statusGreen;
    }
  }

  String get _statusText {
    switch (_status) {
      case 'bahaya':
        return 'Status Lansia : Darurat';
      case 'peringatan':
        return 'Status Lansia : Waspada';
      default:
        return 'Status Lansia : Aman';
    }
  }

  String get _statusSubText {
    switch (_status) {
      case 'bahaya':
        return 'Terdeteksi Kelainan, Segera Periksa Lansia !';
      case 'peringatan':
        return 'Terdeteksi Kelainan, Segera Periksa Lansia !';
      default:
        return 'Tidak ada kejadian darurat';
    }
  }

  // Asset helper berdasarkan status
  String get _asetOrang {
    switch (_status) {
      case 'bahaya':
        return 'assets/images/org merah.png';
      case 'peringatan':
        return 'assets/images/org kuning.svg';
      default:
        return 'assets/images/org ijo.png';
    }
  }

  String get _asetJatuh {
    switch (_status) {
      case 'bahaya':
        return 'assets/images/jatuh merah.png';
      case 'peringatan':
        return 'assets/images/jatuh kuning.png';
      default:
        return 'assets/images/jatuh ijo.svg';
    }
  }

  String get _asetGraf {
    switch (_status) {
      case 'bahaya':
        return 'assets/images/graf merah.png';
      case 'peringatan':
        return 'assets/images/graf kuning.svg';
      default:
        return 'assets/images/graf ijo.png';
    }
  }

  String get _asetPeringatan {
    switch (_status) {
      case 'bahaya':
        return 'assets/images/peringatan merah.png';
      case 'peringatan':
        return 'assets/images/peringatan kuning.png';
      default:
        return 'assets/images/peringatan ijo.svg';
    }
  }

  // Helper widget gambar (support png dan svg)
  Widget _buildAsset(String path, {double size = 40}) {
    if (path.endsWith('.svg')) {
      return SvgPicture.asset(path, width: size, height: size);
    }
    return Image.asset(path, width: size, height: size);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8), // ← abu terang, sama dgn header
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFB8D4F0), // ← biru muda sesuai desainmu
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildStatusBar(),
                      const SizedBox(height: 12),
                      _buildPeta(),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            _buildAktivitas(),
                            const SizedBox(height: 12),
                            _buildResikoJatuh(),
                            const SizedBox(height: 12),
                            _buildStatusSensor(),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── HEADER ───────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      color: const Color(0xFFF0F4F8), // ← abu terang, bukan biru
      child: Column(
        children: [
          Row(
            children: [
              // Logo Guardian
              SvgPicture.asset(
                'assets/images/Guardian.svg',
                width: 40,
                height: 40,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hallo, Mia',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textGrey,
                      ),
                    ),
                    Text(
                      'Monitoring Lansia',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
              // Tombol notifikasi — biru solid sesuai desain
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary, // ← biru solid
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.notifications_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                  onPressed: () {},
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Search bar
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: AppColors.textGrey, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Search...',
                  style: TextStyle(color: AppColors.textGrey, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── STATUS BAR ────────────────────────────────────────
  Widget _buildStatusBar() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _statusColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _statusSubText,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Tombol ganti status (testing UI)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (val) => setState(() => _status = val),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'aman',
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        color: AppColors.statusGreen, size: 18),
                    const SizedBox(width: 8),
                    const Text('Aman'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'peringatan',
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: AppColors.statusYellow, size: 18),
                    const SizedBox(width: 8),
                    const Text('Peringatan'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'bahaya',
                child: Row(
                  children: [
                    Icon(Icons.dangerous_outlined,
                        color: AppColors.statusRed, size: 18),
                    const SizedBox(width: 8),
                    const Text('Bahaya'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── PETA ─────────────────────────────────────────────
  Widget _buildPeta() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Lokasi Lansia',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Area Aman',
                      style: TextStyle(
                        fontSize: 11,
                        color: _statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Peta
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              child: SizedBox(
                height: 180,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: _posisiLansia,
                    initialZoom: 15,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    ),
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: _posisiLansia,
                          radius: 80,
                          color: AppColors.statusGreen.withOpacity(0.15),
                          borderColor: AppColors.statusGreen,
                          borderStrokeWidth: 2,
                          useRadiusInMeter: true,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _posisiLansia,
                          width: 40,
                          height: 40,
                          child: Icon(
                            Icons.location_pin,
                            color: _statusColor,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Koordinat + tombol
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Text(
                    'Latitude : ${_posisiLansia.latitude.toStringAsFixed(4)}',
                    style: TextStyle(fontSize: 11, color: AppColors.textGrey),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Longitude : ${_posisiLansia.longitude.toStringAsFixed(4)}',
                    style: TextStyle(fontSize: 11, color: AppColors.textGrey),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.statusGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Terhubung',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.statusGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text(
                    'Lihat Lokasi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── AKTIVITAS ─────────────────────────────────────────
  Widget _buildAktivitas() {
    return _buildCard(
      child: Row(
        children: [
          _buildAsset(_asetOrang, size: 48),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aktivitas',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  'Perubahan Pola Pergerakan',
                  style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                ),
              ],
            ),
          ),
          _buildAsset(_asetGraf, size: 48),
        ],
      ),
    );
  }

  // ── RESIKO JATUH ─────────────────────────────────────
  Widget _buildResikoJatuh() {
    return _buildCard(
      child: Row(
        children: [
          _buildAsset(_asetJatuh, size: 48),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resiko Jatuh',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  _status == 'bahaya'
                      ? 'Jatuh Terdeteksi'
                      : _status == 'peringatan'
                          ? 'Terdeteksi'
                          : 'Tidak Terdeteksi',
                  style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                ),
              ],
            ),
          ),
          _buildAsset(_asetPeringatan, size: 36),
        ],
      ),
    );
  }

  // ── STATUS SENSOR ─────────────────────────────────────
  Widget _buildStatusSensor() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Status Sensor',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          Text(
            'Sensor yang sedang aktif',
            style: TextStyle(fontSize: 12, color: AppColors.textGrey),
          ),
          const SizedBox(height: 12),
          _buildSensorItem('MPU', true),
          const SizedBox(height: 8),
          _buildSensorItem('GPS', true),
          const SizedBox(height: 8),
          _buildSensorItem('Ultrasonic', false),
        ],
      ),
    );
  }

  Widget _buildSensorItem(String nama, bool aktif) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: aktif ? AppColors.statusGreen : AppColors.statusRed,
          ),
        ),
        const SizedBox(width: 10),
        Text(nama, style: TextStyle(fontSize: 13, color: AppColors.textDark)),
        const Spacer(),
        Text(
          aktif ? 'Aktif' : 'Tidak Aktif',
          style: TextStyle(
            fontSize: 12,
            color: aktif ? AppColors.statusGreen : AppColors.statusRed,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ── CARD WRAPPER ──────────────────────────────────────
  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
