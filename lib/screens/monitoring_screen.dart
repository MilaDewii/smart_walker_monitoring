import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart';
import '../utils/app_routes.dart';
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
  // --- Simple event model for local search within this single-user screen
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  final List<Map<String, String>> _events = [
    {
      'id': 'e1',
      'title': 'Anomali Gerakan',
      'description': 'Perubahan pola gerak tidak biasa terdeteksi',
      'time': '10:47',
      'date': '2025-04-08'
    },
    {
      'id': 'e2',
      'title': 'Potensi Jatuh',
      'description': 'Sensor mendeteksi benturan dan penurunan akselerasi',
      'time': '11:00',
      'date': '2025-04-08'
    },
    {
      'id': 'e3',
      'title': 'Update Lokasi',
      'description': 'Lansia bergerak ke koordinat baru',
      'time': '11:05',
      'date': '2025-04-08'
    },
  ];

  List<Map<String, String>> get _filteredEvents {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _events;
    return _events.where((e) {
      return e['title']!.toLowerCase().contains(q) ||
          e['description']!.toLowerCase().contains(q) ||
          (e['time'] ?? '').toLowerCase().contains(q) ||
          (e['date'] ?? '').toLowerCase().contains(q);
    }).toList();
  }

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
                      // If user typed a search query, show matching events/results
                      if (_searchQuery.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildSearchResults(),
                        )
                      else
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
      color: const Color(0xFFF0F4F8),
      child: Column(
        children: [
          Row(
            children: [
              // Foto profil - bisa diklik ke profile screen
              GestureDetector(
                onTap: () {
                  // Navigator.pushNamed(context, AppRoutes.profile);
                },
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withOpacity(0.15),
                  child: Text(
                    'M', // ← nanti diganti dinamis dari data user
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Teks hallo + monitoring lansia
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hallo, Mila',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textGrey,
                      ),
                    ),
                    Text(
                      'Monitoring $_namaLansia',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
              // Tombol notifikasi biru
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.notifications_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.notification);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Search bar for single-user logs/events
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 6),
                Icon(Icons.search, color: AppColors.textGrey, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textDark), // <-- ukuran teks input
                    decoration: InputDecoration(
                      hintText: 'Cari kejadian, waktu, atau keterangan...',
                      hintStyle:
                          TextStyle(fontSize: 13, color: AppColors.textGrey),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.clear, color: AppColors.textGrey),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
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
                      userAgentPackageName: 'com.guardianwalk.app',
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
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, AppRoutes.location);
                  },
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
                  '$_langkah langkah hari ini',
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
                  _jatuh
                      ? 'Jatuh Terdeteksi'
                      : _status == 'peringatan'
                          ? 'Resiko meningkat'
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

  Widget _buildSearchResults() {
    final results = _filteredEvents;
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hasil Pencarian',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark)),
          const SizedBox(height: 8),
          if (results.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Tidak ada hasil untuk "$_searchQuery"',
                  style: TextStyle(color: AppColors.textGrey)),
            )
          else
            ...results.map((e) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(e['title'] ?? ''),
                  subtitle:
                      Text('${e['date']} • ${e['time']}\n${e['description']}'),
                  isThreeLine: true,
                  onTap: () {
                    // For now, just show a simple snackbar; could open detail view
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Buka: ${e['title']}'),
                    ));
                  },
                ))
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
}
