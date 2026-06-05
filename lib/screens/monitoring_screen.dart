import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../database/database_helper.dart';
import '../models/walker_data.dart';
import '../services/monitoring_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_routes.dart';
import 'widgets/location_card.dart';

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  // ── Data ───────────────────────────────────────────────────────────────────
  String _namaUser = 'User';
  String _namaLansia = 'Nama Lansia';
  File? _fotoFile;
  String? _walkerId;
  WalkerData _walkerData = WalkerData.empty();

  StreamSubscription<WalkerData>? _walkerSub;

  // ── Search ─────────────────────────────────────────────────────────────────
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // ── Events lokal ───────────────────────────────────────────────────────────
  final List<Map<String, String>> _events = [
    {
      'id': 'e1',
      'title': 'Anomali Gerakan',
      'description': 'Perubahan pola gerak tidak biasa terdeteksi',
      'time': '10:47',
      'date': '2025-04-08',
    },
    {
      'id': 'e2',
      'title': 'Potensi Jatuh',
      'description': 'Sensor mendeteksi benturan dan penurunan akselerasi',
      'time': '11:00',
      'date': '2025-04-08',
    },
    {
      'id': 'e3',
      'title': 'Update Lokasi',
      'description': 'Lansia bergerak ke koordinat baru',
      'time': '11:05',
      'date': '2025-04-08',
    },
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final profile = await DatabaseHelper.instance.getProfile();
    final pairedWalkers = await DatabaseHelper.instance.getPairedWalkers();

    if (!mounted) return;

    final walkerId = pairedWalkers.isNotEmpty
        ? pairedWalkers.first['walker_id']?.toString()
        : null;

    setState(() {
      _namaLansia = profile?['nama_lansia']?.toString() ?? _namaLansia;
      _namaUser = profile?['nama']?.toString() ?? 'User';
      _walkerId = walkerId;

      final fotoPath = profile?['foto']?.toString() ?? '';
      if (fotoPath.isNotEmpty && File(fotoPath).existsSync()) {
        _fotoFile = File(fotoPath);
      } else {
        _fotoFile = null;
      }
    });

    if (walkerId == null || walkerId.isEmpty) return;

    _walkerSub?.cancel(); // pastikan tidak double subscribe
    _walkerSub =
        MonitoringService.instance.watchWalker(walkerId).listen((data) {
      if (!mounted) return;
      setState(() => _walkerData = data);
    });
  }

  @override
  void dispose() {
    _walkerSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GETTER
  // ═══════════════════════════════════════════════════════════════════════════
  String get _status => _walkerData.status;
  bool get _jatuh => _walkerData.jatuh;
  double get _confidence => _walkerData.fallConfidence;
  double get _impact => _walkerData.fallImpact;
  bool get _mpuAktif => _walkerData.mpuAktif;
  bool get _gpsAktif => _walkerData.gpsAktif;
  bool get _ultraFront => _walkerData.ultrasonicFront;
  bool get _ultraBack => _walkerData.ultrasonicBack;
  bool get _walkerActive => _walkerData.walkerActive;
  String get _geofence => _walkerData.geofenceStatus;
  String get _lastUpdate => _walkerData.lastUpdate;

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

  Color get _geofenceBadgeColor =>
      _geofence == 'inside' ? AppColors.statusGreen : AppColors.statusRed;

  // ── Asset helpers ──────────────────────────────────────────────────────────
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

  Widget _buildAsset(String path, {double size = 40}) {
    if (path.endsWith('.svg')) {
      return SvgPicture.asset(path, width: size, height: size);
    }
    return Image.asset(path, width: size, height: size);
  }

  // ── Search ─────────────────────────────────────────────────────────────────
  List<Map<String, String>> get _filteredEvents {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _events;
    return _events
        .where(
          (e) =>
              e['title']!.toLowerCase().contains(q) ||
              e['description']!.toLowerCase().contains(q) ||
              (e['time'] ?? '').toLowerCase().contains(q) ||
              (e['date'] ?? '').toLowerCase().contains(q),
        )
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFB8D4F0),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: LocationCard(
                          walkerData: _walkerData,
                          walkerId: _walkerId,
                          parentContext: context,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _searchQuery.trim().isNotEmpty
                            ? _buildSearchResults()
                            : Column(
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

  // ═══════════════════════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      color: const Color(0xFFF0F4F8),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withOpacity(0.15),
                backgroundImage:
                    _fotoFile != null ? FileImage(_fotoFile!) : null,
                child: _fotoFile == null
                    ? Text(
                        _namaUser.isNotEmpty
                            ? _namaUser[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hallo, $_namaUser',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textGrey),
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
              _walkerStatusBadge(),
              const SizedBox(width: 8),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.notifications_outlined,
                      color: Colors.white, size: 22),
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.notification),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Search bar
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
                        fontSize: 13, color: AppColors.textDark),
                    decoration: InputDecoration(
                      hintText: 'Cari kejadian, waktu, atau keterangan...',
                      hintStyle: TextStyle(
                          fontSize: 13, color: AppColors.textGrey),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: Icon(Icons.clear, color: AppColors.textGrey),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _walkerStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (_walkerActive
                ? AppColors.statusGreen
                : AppColors.statusRed)
            .withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _walkerActive
                  ? AppColors.statusGreen
                  : AppColors.statusRed,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            _walkerActive ? 'Aktif' : 'Offline',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _walkerActive
                  ? AppColors.statusGreen
                  : AppColors.statusRed,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AKTIVITAS
  // ═══════════════════════════════════════════════════════════════════════════
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
                  '${_walkerData.langkah} langkah hari ini',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textGrey),
                ),
              ],
            ),
          ),
          _buildAsset(_asetGraf, size: 48),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RESIKO JATUH
  // ═══════════════════════════════════════════════════════════════════════════
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
                      ? 'Jatuh Terdeteksi!'
                      : _status == 'peringatan'
                          ? 'Resiko Meningkat'
                          : 'Tidak Terdeteksi',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _jatuh
                        ? AppColors.statusRed
                        : _status == 'peringatan'
                            ? AppColors.statusYellow
                            : AppColors.statusGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Confidence: ${(_confidence * 100).toStringAsFixed(0)}%'
                  '  •  Impact: ${_impact.toStringAsFixed(1)}',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textGrey),
                ),
              ],
            ),
          ),
          _buildAsset(_asetPeringatan, size: 36),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STATUS SENSOR
  // ═══════════════════════════════════════════════════════════════════════════
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
          _sensorItem('MPU6050', _mpuAktif),
          _sensorItem('GPS / Koneksi', _gpsAktif),
          _sensorItem('Ultrasonic Front', _ultraFront),
          _sensorItem('Ultrasonic Back', _ultraBack),
          _sensorItem('Walker Aktif', _walkerActive),
          const Divider(height: 20, thickness: 0.8),
          // Geofence info
          Row(
            children: [
              Icon(Icons.fence_rounded,
                  size: 14, color: AppColors.textGrey),
              const SizedBox(width: 6),
              Text(
                'Geofence: ',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textGrey),
              ),
              Text(
                _geofence == 'inside'
                    ? 'Di dalam area aman'
                    : 'Di luar area!',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _geofenceBadgeColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.access_time_rounded,
                  size: 14, color: AppColors.textGrey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Update terakhir: $_lastUpdate',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textGrey),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sensorItem(String nama, bool aktif) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  aktif ? AppColors.statusGreen : AppColors.statusRed,
              boxShadow: aktif
                  ? [
                      BoxShadow(
                          color:
                              AppColors.statusGreen.withOpacity(0.4),
                          blurRadius: 4)
                    ]
                  : [],
            ),
          ),
          const SizedBox(width: 10),
          Text(nama,
              style: TextStyle(
                  fontSize: 13, color: AppColors.textDark)),
          const Spacer(),
          Text(
            aktif ? 'Aktif' : 'Tidak Aktif',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color:
                  aktif ? AppColors.statusGreen : AppColors.statusRed,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CARD WRAPPER
  // ═══════════════════════════════════════════════════════════════════════════
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

  // ═══════════════════════════════════════════════════════════════════════════
  // SEARCH RESULTS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSearchResults() {
    final results = _filteredEvents;
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hasil Pencarian',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          if (results.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Tidak ada hasil untuk "$_searchQuery"',
                style: TextStyle(color: AppColors.textGrey),
              ),
            )
          else
            ...results.map(
              (e) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.history_rounded,
                    color: AppColors.primary.withOpacity(0.6)),
                title: Text(
                  e['title'] ?? '',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${e['date']} • ${e['time']}\n${e['description']}',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textGrey),
                ),
                isThreeLine: true,
                onTap: () =>
                    ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Buka: ${e['title']}')),
                ),
              ),
            ),
        ],
      ),
    );
  }
}