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
import 'widgets/status_banner.dart';
// import '../services/notification_service.dart';
// import 'package:firebase_database/firebase_database.dart';

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen>
    with SingleTickerProviderStateMixin {
  // ── Data ───────────────────────────────────────────────────────────────────
  String     _namaUser   = 'User';
  String     _namaLansia = 'Nama Lansia';
  File?      _fotoFile;
  String?    _walkerId;
  WalkerData _walkerData = WalkerData.empty();

  StreamSubscription<WalkerData>? _walkerSub;

  // NotificationService? _notifService;
  // StreamSubscription<DatabaseEvent>? _notifSub;

  // ── Animasi kedip saat bahaya ─────────────────────────────────────────────
  late AnimationController _blinkCtrl;
  late Animation<double>   _blinkAnim;

  // ── Search ────────────────────────────────────────────────────────────────
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // ── Events lokal ──────────────────────────────────────────────────────────
  final List<Map<String, String>> _events = [
    {
      'id':          'e1',
      'title':       'Anomali Gerakan',
      'description': 'Perubahan pola gerak tidak biasa terdeteksi',
      'time':        '10:47',
      'date':        '2025-04-08',
    },
    {
      'id':          'e2',
      'title':       'Potensi Jatuh',
      'description': 'Sensor mendeteksi benturan dan penurunan akselerasi',
      'time':        '11:00',
      'date':        '2025-04-08',
    },
    {
      'id':          'e3',
      'title':       'Update Lokasi',
      'description': 'Lansia bergerak ke koordinat baru',
      'time':        '11:05',
      'date':        '2025-04-08',
    },
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    _blinkCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _blinkAnim = Tween<double>(begin: 0.05, end: 0.25).animate(_blinkCtrl);
    _init();
  }

  Future<void> _init() async {
    final profile       = await DatabaseHelper.instance.getProfile();
    final pairedWalkers = await DatabaseHelper.instance.getPairedWalkers();
    if (!mounted) return;

    final walkerId = pairedWalkers.isNotEmpty
        ? pairedWalkers.first['walker_id']?.toString()
        : null;

    setState(() {
      _namaLansia = profile?['nama_lansia']?.toString() ?? _namaLansia;
      _namaUser   = profile?['nama']?.toString()        ?? 'User';
      _walkerId   = walkerId;
      final fotoPath = profile?['foto']?.toString() ?? '';
      _fotoFile = (fotoPath.isNotEmpty && File(fotoPath).existsSync())
          ? File(fotoPath)
          : null;
    });

    if (walkerId == null || walkerId.isEmpty) return;

    _walkerSub?.cancel();
    _walkerSub = MonitoringService.instance
        .watchWalker(walkerId)
        .listen((data) {
      if (!mounted) return;
      setState(() => _walkerData = data);
    });

// ── Tambahan baru: start listener notifikasi OneSignal ────
    // _notifService = NotificationService(walkerId: walkerId);
    // _notifSub?.cancel();
    // _notifSub = _notifService!.listenAndPushOneSignal();
  }

  @override
  void dispose() {
    _walkerSub?.cancel();
    // _notifSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GETTER
  // ═══════════════════════════════════════════════════════════════════════════
  String get _status       => _walkerData.statusLabel;
  bool   get _jatuh        => _walkerData.jatuh;
  bool   get _mpuAktif     => _walkerData.mpuAktif;
  bool   get _gpsAktif     => _walkerData.gpsAktif;
  bool   get _ultraFront   => _walkerData.ultrasonicFront;
  bool   get _ultraBack    => _walkerData.ultrasonicBack;
  bool   get _walkerActive => _walkerData.walkerActive;
  String get _geofence     => _walkerData.geofenceStatus;
  String get _lastUpdate   => _walkerData.lastUpdate;

  Color get _statusColor {
    if (_jatuh || _walkerData.geofenceStatus == 'outside' || !_ultraBack) {
      return AppColors.statusRed;
    }
    if (_status == 'waspada' ||
        _walkerData.mendekatiGeofence ||
        _ultraFront) {
      return AppColors.statusYellow;
    }
    return AppColors.statusGreen;
  }

    Color get _geofenceBadgeColor {
      if (_geofence == 'outside') return AppColors.statusRed;
      if (_walkerData.mendekatiGeofence) return AppColors.statusYellow;
      return AppColors.statusGreen;
    }

  String get _riskLabel {
    final r = _walkerData.fuzzyRisk;
    if (r >= 0.75) return 'Risiko sangat tinggi';
    if (r >= 0.45) return 'Risiko tinggi — kemungkinan jatuh';
    if (r >= 0.30) return 'Risiko sedang — perlu diperhatikan';
    if (r >= 0.15) return 'Risiko rendah — kondisi normal';
    return 'Aman — tidak ada indikasi jatuh';
  }

  String get _impactLabel {
    final i = _walkerData.fallImpact;
    if (i >= 2.0) return 'Benturan sangat keras';
    if (i >= 1.5) return 'Benturan keras';
    if (i >= 0.8) return 'Guncangan cukup besar';
    if (i >= 0.3) return 'Guncangan ringan';
    return 'Gerakan normal';
  }

  String get _gyroLabel {
    final g = _walkerData.gyroPeak;
    if (g >= 200) return 'Rotasi sangat cepat (indikasi jatuh)';
    if (g >= 130) return 'Rotasi cepat';
    if (g >= 60)  return 'Rotasi sedang';
    return 'Rotasi normal';
  }

  String get _posisiLabel {
    final az = _walkerData.azFiltered;
    if (az >= 0.85) return 'Berdiri tegak';
    if (az >= 0.50) return 'Sedikit condong';
    if (az >= 0.20) return 'Sangat condong / hampir rebah';
    return 'Posisi rebah — kemungkinan jatuh';
  }

  String get _diamLabel {
    final d = _walkerData.diamDetik;
    if (d >= 45) return '${d.toStringAsFixed(0)} dtk — sangat lama tidak bergerak';
    if (d >= 15) return '${d.toStringAsFixed(0)} dtk — cukup lama diam';
    if (d >= 5)  return '${d.toStringAsFixed(0)} dtk — sebentar diam';
    return 'Bergerak aktif';
  }

  String get _asetOrang {
    if (_jatuh || _status == 'bahaya') return 'assets/images/org merah.png';
    if (_status == 'waspada')          return 'assets/images/org kuning.svg';
    return 'assets/images/org ijo.png';
  }

  String get _asetJatuh {
    if (_jatuh || _status == 'bahaya') return 'assets/images/jatuh merah.png';
    if (_status == 'waspada')          return 'assets/images/jatuh kuning.png';
    return 'assets/images/jatuh ijo.svg';
  }

  String get _asetGraf {
    if (_jatuh || _status == 'bahaya') return 'assets/images/graf merah.png';
    if (_status == 'waspada')          return 'assets/images/graf kuning.svg';
    return 'assets/images/graf ijo.png';
  }

  Widget _buildAsset(String path, {double size = 40}) {
    if (path.endsWith('.svg')) {
      return SvgPicture.asset(path, width: size, height: size);
    }
    return Image.asset(path, width: size, height: size);
  }

  List<Map<String, String>> get _filteredEvents {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _events;
    return _events.where((e) =>
        e['title']!.toLowerCase().contains(q) ||
        e['description']!.toLowerCase().contains(q) ||
        (e['time'] ?? '').toLowerCase().contains(q) ||
        (e['date'] ?? '').toLowerCase().contains(q),
    ).toList();
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
            if (!_jatuh && _status == 'waspada') _buildWaspadaBanner(),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFB8D4F0),
                  borderRadius: BorderRadius.only(
                    topLeft:  Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: StatusBanner(walkerData: _walkerData),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: LocationCard(
                          walkerData:    _walkerData,
                          walkerId:      _walkerId,
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
  // BANNER WASPADA
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildWaspadaBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      color: AppColors.statusYellow,
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '⚠️  Gerakan tidak normal terdeteksi — pantau kondisi $_namaLansia',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DIALOG DETAIL JATUH
  // ═══════════════════════════════════════════════════════════════════════════
  void _showFallDetailDialog() {
    final int riskPct = _walkerData.riskPercent;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: AppColors.statusRed, size: 22),
            const SizedBox(width: 8),
            const Text('Detail Kejadian Jatuh',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize:       MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dialogRow('Status', 'Jatuh terdeteksi', AppColors.statusRed),
            const SizedBox(height: 12),
            Text('Tingkat risiko jatuh:',
                style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
            const SizedBox(height: 4),
            Text(_riskLabel,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value:           (_walkerData.fuzzyRisk).clamp(0.0, 1.0),
                minHeight:       8,
                backgroundColor: Colors.grey.shade200,
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.statusRed),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text('$riskPct%',
                  style: TextStyle(
                      fontSize:   11,
                      color:      AppColors.statusRed,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 10),
            _dialogRow('Benturan', _impactLabel, null),
            const SizedBox(height: 6),
            _dialogRow('Rotasi',   _gyroLabel,   null),
            const SizedBox(height: 6),
            _dialogRow('Posisi',   _posisiLabel, null),
            const SizedBox(height: 6),
            _dialogRow('Diam',     _diamLabel,   null),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:        AppColors.statusRed.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Segera periksa kondisi $_namaLansia dan pastikan ia dalam keadaan baik.',
                style: TextStyle(
                    fontSize:   12,
                    color:      AppColors.statusRed,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup')),
        ],
      ),
    );
  }

  Widget _dialogRow(String label, String value, Color? valueColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ',
            style: TextStyle(
                fontSize:   13,
                color:      AppColors.textGrey,
                fontWeight: FontWeight.w500)),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  fontSize:   13,
                  color:      valueColor ?? AppColors.textDark,
                  fontWeight: valueColor != null
                      ? FontWeight.bold
                      : FontWeight.normal)),
        ),
      ],
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
              CircleAvatar(
                radius:          24,
                backgroundColor: AppColors.primary.withOpacity(0.15),
                backgroundImage:
                    _fotoFile != null ? FileImage(_fotoFile!) : null,
                child: _fotoFile == null
                    ? Text(
                        _namaUser.isNotEmpty ? _namaUser[0].toUpperCase() : '?',
                        style: TextStyle(
                            fontSize:   20,
                            fontWeight: FontWeight.bold,
                            color:      AppColors.primary),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hallo, $_namaUser',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textGrey)),
                    Text('Monitoring $_namaLansia',
                        style: TextStyle(
                            fontSize:   18,
                            fontWeight: FontWeight.bold,
                            color:      AppColors.textDark)),
                  ],
                ),
              ),
              _walkerStatusBadge(),
              const SizedBox(width: 8),
              Container(
                width:  44,
                height: 44,
                decoration: BoxDecoration(
                  color:        AppColors.primary,
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
          Container(
            height:  42,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color:        Colors.white,
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
                    onChanged:  (v) => setState(() => _searchQuery = v),
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textDark),
                    decoration: InputDecoration(
                      hintText:  'Cari kejadian, waktu, atau keterangan...',
                      hintStyle: TextStyle(
                          fontSize: 13, color: AppColors.textGrey),
                      border:   InputBorder.none,
                      isDense:  true,
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
        color: (_walkerActive ? AppColors.statusGreen : AppColors.statusRed)
            .withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width:  7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  _walkerActive ? AppColors.statusGreen : AppColors.statusRed,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            _walkerActive ? 'Aktif' : 'Offline',
            style: TextStyle(
              fontSize:   11,
              fontWeight: FontWeight.w600,
              color:
                  _walkerActive ? AppColors.statusGreen : AppColors.statusRed,
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
                Text('Aktivitas',
                    style: TextStyle(
                        fontSize:   15,
                        fontWeight: FontWeight.bold,
                        color:      AppColors.textDark)),
                Text('${_walkerData.langkah} langkah hari ini',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textGrey)),
              ],
            ),
          ),
          _buildAsset(_asetGraf, size: 48),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RESIKO JATUH — card putih, kedip merah-putih saat bahaya
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildResikoJatuh() {
    final bool  isBahaya  = _jatuh || _status == 'bahaya';
    final bool  isWaspada = !isBahaya && _status == 'waspada';
    final int   riskPct   = _walkerData.riskPercent;
    final Color theme     = _statusColor;

    final Color cardBg = isWaspada
        ? AppColors.statusYellow.withOpacity(0.06)
        : Colors.white;

    // ── Isi card (dipisah agar bisa dipakai oleh AnimatedBuilder) ────────────
    final Widget isiCard = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // Header
        Row(
          children: [
            _buildAsset(_asetJatuh, size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Deteksi Jatuh',
                      style: TextStyle(
                          fontSize:   15,
                          fontWeight: FontWeight.bold,
                          color:      AppColors.textDark)),
                  Text(
                    isBahaya
                        ? '🚨 Jatuh Terdeteksi!'
                        : isWaspada
                            ? '⚠️ Perlu Diperhatikan'
                            : '✅ Kondisi Aman',
                    style: TextStyle(
                        fontSize:   13,
                        fontWeight: FontWeight.bold,
                        color:      theme),
                  ),
                ],
              ),
            ),
            // Badge %
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color:        theme.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$riskPct%',
                style: TextStyle(
                    fontSize:   18,
                    fontWeight: FontWeight.bold,
                    color:      theme),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Progress bar
        Row(
          children: [
            Text('Tingkat Risiko Jatuh',
                style: TextStyle(
                    fontSize:   11,
                    color:      AppColors.textGrey,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(_riskLabel,
                style: TextStyle(
                    fontSize:   11,
                    color:      theme,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value:           _walkerData.fuzzyRisk.clamp(0.0, 1.0),
            minHeight:       10,
            backgroundColor: Colors.grey.shade200,
            valueColor:      AlwaysStoppedAnimation<Color>(theme),
          ),
        ),

        const SizedBox(height: 14),
        const Divider(height: 1, thickness: 0.8),
        const SizedBox(height: 12),

        // 4 indikator sensor
        _sensorInfoRow(
          color:     theme,
          icon:      Icons.vibration_rounded,
          judul:     'Benturan yang terdeteksi',
          deskripsi: 'Seberapa keras guncangan yang dirasakan alat',
          nilai:     _impactLabel,
          nilaiRaw:  '${_walkerData.fallImpact.toStringAsFixed(2)} g',
        ),
        const SizedBox(height: 10),
        _sensorInfoRow(
          color:     theme,
          icon:      Icons.rotate_90_degrees_ccw_rounded,
          judul:     'Kecepatan putaran tubuh',
          deskripsi: 'Seberapa cepat gerakan berputar saat kejadian',
          nilai:     _gyroLabel,
          nilaiRaw:  '${_walkerData.gyroPeak.toStringAsFixed(0)} °/s',
        ),
        const SizedBox(height: 10),
        _sensorInfoRow(
          color:     theme,
          icon:      Icons.accessibility_new_rounded,
          judul:     'Posisi tubuh',
          deskripsi: 'Apakah pengguna masih berdiri atau sudah rebah',
          nilai:     _posisiLabel,
          nilaiRaw:  'az=${_walkerData.azFiltered.toStringAsFixed(2)} g',
        ),
        const SizedBox(height: 10),
        _sensorInfoRow(
          color:     theme,
          icon:      Icons.timer_outlined,
          judul:     'Durasi tidak bergerak',
          deskripsi: 'Berapa lama pengguna tidak terdeteksi bergerak',
          nilai:     _diamLabel,
          nilaiRaw:  '${_walkerData.diamDetik.toStringAsFixed(0)} dtk',
        ),

        // Kotak peringatan BAHAYA
        if (isBahaya) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.statusRed.withOpacity(0.09),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: AppColors.statusRed.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: AppColors.statusRed, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sensor mendeteksi $_namaLansia kemungkinan terjatuh. '
                    'Segera periksa kondisinya!',
                    style: TextStyle(
                        fontSize:   12,
                        color:      AppColors.statusRed,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Kotak info WASPADA
        if (isWaspada) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.statusYellow.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.statusYellow.withOpacity(0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Terdeteksi gerakan tidak biasa dari $_namaLansia. '
                    'Perhatikan kondisinya sebentar.',
                    style: TextStyle(
                        fontSize:   12,
                        color:      Colors.orange.shade800,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );

    // Saat BAHAYA: card kedip putih ↔ merah muda

    // Normal / waspada
    return _buildCard(overrideColor: cardBg, child: isiCard);
  }

  // ── Helper baris info sensor ──────────────────────────────────────────────
  Widget _sensorInfoRow({
    required Color    color,
    required IconData icon,
    required String   judul,
    required String   deskripsi,
    required String   nilai,
    required String   nilaiRaw,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width:  36,
          height: 36,
          decoration: BoxDecoration(
            color:        color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(judul,
                  style: TextStyle(
                      fontSize:   12,
                      fontWeight: FontWeight.w600,
                      color:      AppColors.textDark)),
              Text(deskripsi,
                  style: TextStyle(
                      fontSize: 10, color: AppColors.textGrey)),
              const SizedBox(height: 2),
              Text(nilai,
                  style: TextStyle(
                      fontSize:   13,
                      fontWeight: FontWeight.bold,
                      color:      color)),
            ],
          ),
        ),
        Text(nilaiRaw,
            style: TextStyle(
                fontSize:   10,
                color:      AppColors.textGrey,
                fontFamily: 'monospace')),
      ],
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
          Text('Status Sensor',
              style: TextStyle(
                  fontSize:   15,
                  fontWeight: FontWeight.bold,
                  color:      AppColors.textDark)),
          Text('Sensor yang sedang aktif',
              style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
          const SizedBox(height: 12),
          _sensorItem('MPU6050 (Akselerometer)', _mpuAktif),
          _sensorItem('GPS / Koneksi',           _gpsAktif),
          _sensorItem('Sensor Depan (Rintangan)', _ultraFront),
          _sensorItem('Sensor Belakang (Lansia)', _ultraBack),
          _sensorItem('Walker Aktif',             _walkerActive),
          const Divider(height: 20, thickness: 0.8),
          Row(
            children: [
              Icon(Icons.fence_rounded, size: 14, color: AppColors.textGrey),
              const SizedBox(width: 6),
              Text('Area aman: ',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textGrey)),
              Text(
                _geofence == 'inside'
                    ? 'Di dalam area aman'
                    : '⚠️ Di luar area!',
                style: TextStyle(
                    fontSize:   12,
                    fontWeight: FontWeight.w600,
                    color:      _geofenceBadgeColor),
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
                child: Text('Update terakhir: $_lastUpdate',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textGrey)),
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
            width:  10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: aktif ? AppColors.statusGreen : AppColors.statusRed,
              boxShadow: aktif
                  ? [
                      BoxShadow(
                          color:      AppColors.statusGreen.withOpacity(0.4),
                          blurRadius: 4)
                    ]
                  : [],
            ),
          ),
          const SizedBox(width: 10),
          Text(nama, style: TextStyle(fontSize: 13, color: AppColors.textDark)),
          const Spacer(),
          Text(aktif ? 'Aktif' : 'Tidak Aktif',
              style: TextStyle(
                  fontSize:   12,
                  fontWeight: FontWeight.w500,
                  color: aktif
                      ? AppColors.statusGreen
                      : AppColors.statusRed)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CARD WRAPPER
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildCard({required Widget child, Color? overrideColor}) {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        overrideColor ?? Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset:     const Offset(0, 2),
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
          Text('Hasil Pencarian',
              style: TextStyle(
                  fontSize:   15,
                  fontWeight: FontWeight.bold,
                  color:      AppColors.textDark)),
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
                title: Text(e['title'] ?? '',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  '${e['date']} • ${e['time']}\n${e['description']}',
                  style: TextStyle(fontSize: 11, color: AppColors.textGrey),
                ),
                isThreeLine: true,
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Buka: ${e['title']}')),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
