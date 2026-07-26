import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../utils/app_colors.dart';
import '../utils/app_routes.dart';
import '../database/database_helper.dart';
// import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _MonitoringStats {
  const _MonitoringStats({
    required this.total,
    required this.danger,
    required this.warning,
  });

  final int total;
  final int danger;
  final int warning;
}

class _ProfileScreenState extends State<ProfileScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  bool _isEditing = false;

  // ── DATA USER ──
  String _namaLengkap = 'Mila Dewi';
  String _email = 'mila@gmail.com';
  String _noHp = '081234567890';
  final String _role = 'Caregiver / User';
  File? _fotoFile;

  late TextEditingController _namaCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _noHpCtrl;
  // Password visibility for change-password dialog
  bool _oldObscure = true;
  bool _newObscure = true;
  bool _confirmObscure = true;

  // ── DATA LANSIA ──
  String _namaLansia = 'Siti Aminah';
  String _umurLansia = '74';
  String _jenisKelaminLansia = 'Perempuan';

  // ── DATA DEVICE WALKER ──
  String _walkerId = '-';
  String _statusDevice = 'Tidak Aktif';
  // final int _battery = 89;
  StreamSubscription<DatabaseEvent>? _walkerSub;
  StreamSubscription<DatabaseEvent>? _firebaseConnectedSub;

  // ── STATUS KONEKSI ──
  // final bool _wifi = true;
  // final bool _bluetooth = true;
  bool _gps = false;
  bool _gsm = false;
  bool _firebaseRtd = false;

  // ── STATISTIK MONITORING ──
  int _totalMonitoring = 0;
  int _riwayatBahaya = 0;
  int _riwayatWarning = 0;

  Future<void> _loadProfile() async {
    final profile = await _db.getProfile();
    final pairedWalkers = await _db.getPairedWalkers();
    final resolvedWalkerId = await _resolveWalkerId(pairedWalkers);

    if (!mounted) return;

    setState(() {
      if (profile != null) {
        _namaLengkap = profile['nama'] ?? '';
        _email = profile['email'] ?? '';
        _noHp = profile['no_hp'] ?? '';

        _namaLansia = profile['nama_lansia'] ?? '';
        _umurLansia = profile['umur_lansia']?.toString() ?? '';

        _jenisKelaminLansia = profile['jenis_kelamin_lansia'] ?? '';

        final fotoPath = profile['foto']?.toString() ?? '';
        if (fotoPath.isNotEmpty && File(fotoPath).existsSync()) {
          _fotoFile = File(fotoPath);
        } else {
          _fotoFile = null;
        }
      }

      if (resolvedWalkerId != null) {
        _walkerId = resolvedWalkerId;
      } else {
        _walkerId = '-';
        _statusDevice = 'Tidak Aktif';
        _gps = false;
        _gsm = false;
        _totalMonitoring = 0;
        _riwayatBahaya = 0;
        _riwayatWarning = 0;
      }
    });

    _listenFirebaseConnection();
    if (_walkerId != '-') {
      _listenWalkerProfile(_walkerId);
    }
  }

  Future<String?> _resolveWalkerId(
    List<Map<String, dynamic>> pairedWalkers,
  ) async {
    final storedWalker = pairedWalkers.isNotEmpty ? pairedWalkers.first : null;
    final storedId = storedWalker?['walker_id']?.toString();
    final candidates = <String>[
      if (storedId != null && storedId.isNotEmpty) ...[
        if (_legacyWalkerAlias(storedId) != null) _legacyWalkerAlias(storedId)!,
        storedId,
      ],
      // 'walker_001',
    ];

    for (final candidate in candidates.toSet()) {
      final snapshot =
          await FirebaseDatabase.instance.ref('Walkers/$candidate').get();
      if (!snapshot.exists) continue;

      if (storedWalker == null) {
        await _db.savePairedWalker(
          walkerId: candidate,
          pairedDate: DateTime.now().toIso8601String(),
        );
      } else if (storedId != candidate) {
        await _db.updatePairedWalker(
          id: storedWalker['id'] as int,
          walkerId: candidate,
          pairedDate: storedWalker['paired_date']?.toString() ??
              DateTime.now().toIso8601String(),
        );
      }

      return candidate;
    }

    return storedId?.isNotEmpty == true ? storedId : null;
  }

  String? _legacyWalkerAlias(String walkerId) {
    final match = RegExp(r'^GW-(\d+)$', caseSensitive: false).firstMatch(
      walkerId.trim(),
    );
    if (match == null) return null;

    final number = int.tryParse(match.group(1) ?? '');
    if (number == null) return null;

    return 'walker_${number.toString().padLeft(3, '0')}';
  }

  void _listenFirebaseConnection() {
    _firebaseConnectedSub?.cancel();
    _firebaseConnectedSub = FirebaseDatabase.instance
        .ref('.info/connected')
        .onValue
        .listen((event) {
      if (!mounted) return;
      setState(() => _firebaseRtd = event.snapshot.value == true);
    });
  }

  void _listenWalkerProfile(String walkerId) {
    _walkerSub?.cancel();
    _walkerSub = FirebaseDatabase.instance
        .ref('Walkers/$walkerId')
        .onValue
        .listen((event) {
      if (!mounted) return;

      final raw = event.snapshot.value;
      if (raw is! Map) {
        setState(() {
          _statusDevice = 'Tidak Aktif';
          _gps = false;
          _gsm = false;
          _totalMonitoring = 0;
          _riwayatBahaya = 0;
          _riwayatWarning = 0;
        });
        return;
      }

      final walker = Map<dynamic, dynamic>.from(raw);
      final status = _asMap(walker['status']);
      final sensors = _asMap(walker['sensors']);
      final sim808 = _asMap(walker['sim808']).isNotEmpty
          ? _asMap(walker['sim808'])
          : _asMap(sensors['sim808']);
      final history = _asMap(walker['history']);

      final isConnected = walker['walker_active'] == true ||
      status.toString().toLowerCase() == 'normal' ||
      status.toString().toLowerCase() == 'bahaya';
      final stats = _countMonitoringStats(history);

      setState(() {
        _statusDevice = isConnected ? 'Aktif' : 'Tidak Aktif';
        _gps = sim808['gps_status'] == true;
        _gsm = sim808['internet_status'] == true ||
            _toDouble(sim808['gsm_signal'], 0) > 0;
        _totalMonitoring = stats.total;
        _riwayatBahaya = stats.danger;
        _riwayatWarning = stats.warning;
      });
    });
  }

  _MonitoringStats _countMonitoringStats(Map<dynamic, dynamic> history) {
    var total = 0;
    var danger = 0;
    var warning = 0;

    for (final value in history.values) {
      if (value is! Map) continue;
      total++;

      final item = Map<dynamic, dynamic>.from(value);
      final status = item['status']?.toString().toLowerCase() ?? '';
      final statusBahaya = item['statusBahaya']?.toString().toLowerCase() ?? '';

      if (status == 'danger' ||
          status == 'bahaya' ||
          statusBahaya.contains('bahaya')) {
        danger++;
      } else if (status == 'warning' ||
          status == 'peringatan' ||
          statusBahaya.contains('peringatan') ||
          statusBahaya.contains('warning')) {
        warning++;
      }
    }

    return _MonitoringStats(
      total: total,
      danger: danger,
      warning: warning,
    );
  }

  Map<dynamic, dynamic> _asMap(dynamic value) =>
      value is Map ? Map<dynamic, dynamic>.from(value) : {};

  double _toDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  @override
  void initState() {
    super.initState();

    _namaCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _noHpCtrl = TextEditingController();

    _loadProfile();
  }

  @override
  void dispose() {
    _walkerSub?.cancel();
    _firebaseConnectedSub?.cancel();
    _namaCtrl.dispose();
    _emailCtrl.dispose();
    _noHpCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleEdit() async {
    if (_isEditing) {
      final profile = await _db.getProfile();

      if (profile == null) {
        // simpan baru
        await _db.saveProfile(
          nama: _namaCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          noHp: _noHpCtrl.text.trim(),
          foto: _fotoFile?.path ?? '',
          namaLansia: _namaLansia,
          umurLansia: int.parse(_umurLansia),
          jenisKelaminLansia: _jenisKelaminLansia,
        );
      } else {
        // update
        await _db.updateProfile(
          id: profile['id'],
          nama: _namaCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          noHp: _noHpCtrl.text.trim(),
          foto: _fotoFile?.path ?? '',
          namaLansia: _namaLansia,
          umurLansia: int.parse(_umurLansia),
          jenisKelaminLansia: _jenisKelaminLansia,
        );
      }

      setState(() {
        _namaLengkap = _namaCtrl.text.trim();
        _email = _emailCtrl.text.trim();
        _noHp = _noHpCtrl.text.trim();

        _isEditing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Profil berhasil disimpan"),
          backgroundColor: AppColors.statusGreen,
        ),
      );
    } else {
      _namaCtrl.text = _namaLengkap;
      _emailCtrl.text = _email;
      _noHpCtrl.text = _noHp;

      setState(() {
        _isEditing = true;
      });
    }
  }

  void _cancelEdit() {
    setState(() {
      _namaCtrl.text = _namaLengkap;
      _emailCtrl.text = _email;
      _noHpCtrl.text = _noHp;
      _isEditing = false;
    });
  }

  Future<void> _pilihFoto(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked != null) {
      final savedPhoto = await _copyPhotoToAppStorage(File(picked.path));
      await _saveProfilePhoto(savedPhoto.path);

      if (!mounted) return;
      setState(() => _fotoFile = savedPhoto);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Foto profil berhasil disimpan'),
          backgroundColor: AppColors.statusGreen,
        ),
      );
    }
  }

  Future<File> _copyPhotoToAppStorage(File source) async {
    final dbPath = await getDatabasesPath();
    final photoDir = Directory(p.join(dbPath, 'profile_photos'));
    if (!await photoDir.exists()) {
      await photoDir.create(recursive: true);
    }

    final extension = p.extension(source.path);
    final fileName =
        'profile_${DateTime.now().millisecondsSinceEpoch}$extension';
    return source.copy(p.join(photoDir.path, fileName));
  }

  Future<void> _saveProfilePhoto(String path) async {
    final profile = await _db.getProfile();
    if (profile == null) return;

    await _db.updateProfile(
      id: profile['id'],
      nama: _namaLengkap,
      email: _email,
      noHp: _noHp,
      foto: path,
      namaLansia: _namaLansia,
      umurLansia: int.tryParse(_umurLansia) ?? 0,
      jenisKelaminLansia: _jenisKelaminLansia,
    );
  }

  Future<void> _removeProfilePhoto() async {
    final oldPhoto = _fotoFile;
    await _saveProfilePhoto('');

    if (oldPhoto != null && await oldPhoto.exists()) {
      await oldPhoto.delete();
    }

    if (!mounted) return;
    setState(() => _fotoFile = null);
  }

  void _showPilihFotoSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Ganti Foto Profil',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildFotoOption(
                      icon: Icons.camera_alt_outlined,
                      label: 'Kamera',
                      onTap: () {
                        Navigator.pop(ctx);
                        _pilihFoto(ImageSource.camera);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildFotoOption(
                      icon: Icons.photo_library_outlined,
                      label: 'Galeri',
                      onTap: () {
                        Navigator.pop(ctx);
                        _pilihFoto(ImageSource.gallery);
                      },
                    ),
                  ),
                ],
              ),
              if (_fotoFile != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _removeProfilePhoto();
                    },
                    icon: Icon(Icons.delete_outline,
                        color: AppColors.statusRed, size: 18),
                    label: Text('Hapus Foto',
                        style: TextStyle(color: AppColors.statusRed)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFotoOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 32),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
          ],
        ),
      ),
    );
  }

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
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildFotoNama(),
                      const SizedBox(height: 16),
                      _buildInfoAkun(),
                      const SizedBox(height: 16),
                      _buildInfoWalker(),
                      const SizedBox(height: 16),
                      _buildStatusKoneksi(),
                      const SizedBox(height: 16),
                      _buildInfoMonitoring(),
                      const SizedBox(height: 16),
                      _buildTombolEditLogout(),
                      const SizedBox(height: 24),
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
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary.withOpacity(0.15),
            backgroundImage: _fotoFile != null ? FileImage(_fotoFile!) : null,
            child: _fotoFile == null
                ? Text(
                    _namaLengkap.isNotEmpty
                        ? _namaLengkap[0].toUpperCase()
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
                Text('Hallo, $_namaLengkap',
                    style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                Text('Profil Saya',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark)),
              ],
            ),
          ),
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
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.notification);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── FOTO & NAMA ──────────────────────────────────────
  Widget _buildFotoNama() {
    return _buildCard(
      child: Column(
        children: [
          // Klik foto → langsung kamera
          GestureDetector(
            onTap: () => _pilihFoto(ImageSource.camera),
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.primary.withOpacity(0.15),
                  backgroundImage:
                      _fotoFile != null ? FileImage(_fotoFile!) : null,
                  child: _fotoFile == null
                      ? Text(
                          _namaLengkap.isNotEmpty
                              ? _namaLengkap[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        )
                      : null,
                ),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt,
                      color: Colors.white, size: 15),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Klik "Ganti Foto" → pilihan kamera atau galeri
          TextButton.icon(
            onPressed: _showPilihFotoSheet,
            icon: Icon(Icons.photo_library_outlined,
                size: 16, color: AppColors.primary),
            label: Text(
              'Ganti Foto',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Nama
          _isEditing
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildEditField(
                    controller: _namaCtrl,
                    icon: Icons.badge_outlined,
                    hint: 'Nama Lengkap',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark),
                  ),
                )
              : Text(
                  _namaLengkap,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark),
                ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _role,
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ── INFORMASI AKUN ───────────────────────────────────
  Widget _buildInfoAkun() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text('Informasi Akun',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark)),
              const Spacer(),
              if (_isEditing)
                GestureDetector(
                  onTap: _cancelEdit,
                  child: Text('Batal',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.statusRed,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Nama
          _isEditing
              ? _buildEditField(
                  controller: _namaCtrl,
                  icon: Icons.badge_outlined,
                  hint: 'Nama Lengkap',
                )
              : _buildInfoRow(
                  Icons.badge_outlined, 'Nama Lengkap', _namaLengkap),
          _buildDivider(),

          // Email
          _isEditing
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _buildEditField(
                    controller: _emailCtrl,
                    icon: Icons.email_outlined,
                    hint: 'Email',
                    keyboardType: TextInputType.emailAddress,
                  ),
                )
              : _buildInfoRow(Icons.email_outlined, 'Email', _email),
          _buildDivider(),

          // Nomor HP
          _isEditing
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _buildEditField(
                    controller: _noHpCtrl,
                    icon: Icons.phone_outlined,
                    hint: 'Nomor HP',
                    keyboardType: TextInputType.phone,
                  ),
                )
              : _buildInfoRow(Icons.phone_outlined, 'Nomor HP', _noHp),
          _buildDivider(),

          // Password
          InkWell(
            onTap: () => _showUbahPassword(context),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Password',
                        style:
                            TextStyle(fontSize: 13, color: AppColors.textGrey)),
                  ),
                  Text('Ubah Password',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, color: AppColors.primary, size: 18),
                ],
              ),
            ),
          ),
          _buildDivider(),

          // ── DATA LANSIA ──
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Row(
              children: [
                Icon(Icons.elderly, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Text('Data Lansia',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark)),
              ],
            ),
          ),
          _buildInfoRow(Icons.person_outline, 'Nama Lansia', _namaLansia),
          _buildDivider(),
          _buildInfoRow(Icons.cake_outlined, 'Umur', '$_umurLansia tahun'),
          _buildDivider(),
          _buildInfoRow(
            _jenisKelaminLansia == 'Laki-laki' ? Icons.male : Icons.female,
            'Jenis Kelamin',
            _jenisKelaminLansia,
          ),
        ],
      ),
    );
  }

  // ── INFORMASI DEVICE WALKER ──────────────────────────
  Widget _buildInfoWalker() {
    final bool isConnected = _statusDevice == 'Aktif';
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Device Walker', Icons.directions_walk),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.qr_code_2, 'Walker ID', _walkerId),
          _buildDivider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Icon(Icons.wifi_tethering, color: AppColors.textGrey, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Status Device',
                      style:
                          TextStyle(fontSize: 13, color: AppColors.textGrey)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isConnected
                            ? AppColors.statusGreen
                            : AppColors.statusRed)
                        .withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isConnected
                              ? AppColors.statusGreen
                              : AppColors.statusRed,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(_statusDevice,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isConnected
                                  ? AppColors.statusGreen
                                  : AppColors.statusRed)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  } //

// ── STATUS KONEKSI ───────────────────────────────────  ✅ Sekarang di luar _buildInfoWalker
  Widget _buildStatusKoneksi() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Status Koneksi', Icons.signal_cellular_alt),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildKoneksiChip(Icons.signal_cellular_alt, 'GSM Network', _gsm),
              const SizedBox(width: 8),
              _buildKoneksiChip(Icons.gps_fixed, 'GPS', _gps),
              const SizedBox(width: 8),
              _buildKoneksiChip(Icons.cloud_done, 'Firebase RTD', _firebaseRtd),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKoneksiChip(IconData icon, String label, bool aktif) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: aktif
              ? AppColors.statusGreen.withOpacity(0.1)
              : AppColors.statusRed.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: aktif
                ? AppColors.statusGreen.withOpacity(0.3)
                : AppColors.statusRed.withOpacity(0.2),
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: aktif ? AppColors.statusGreen : AppColors.statusRed,
                size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color:
                        aktif ? AppColors.statusGreen : AppColors.statusRed)),
            Text(aktif ? 'Aktif' : 'Nonaktif',
                style: TextStyle(fontSize: 10, color: AppColors.textGrey)),
          ],
        ),
      ),
    );
  }

  // ── STATISTIK MONITORING ─────────────────────────────
  Widget _buildInfoMonitoring() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Statistik Monitoring', Icons.bar_chart),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatItem(
                  '$_totalMonitoring', 'Total\nMonitoring', AppColors.primary),
              _buildStatDivider(),
              _buildStatItem(
                  '$_riwayatBahaya', 'Riwayat\nBahaya', AppColors.statusRed),
              _buildStatDivider(),
              _buildStatItem('$_riwayatWarning', 'Riwayat\nWarning',
                  AppColors.statusYellow),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
        ],
      ),
    );
  }

  Widget _buildStatDivider() =>
      Container(width: 1, height: 40, color: Colors.grey.shade200);

  // ── TOMBOL EDIT & LOGOUT ─────────────────────────────
  Widget _buildTombolEditLogout() {
    return Column(
      children: [
        // Edit / Simpan dengan gradient
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isEditing
                  ? [
                      AppColors.statusGreen,
                      AppColors.statusGreen.withOpacity(0.8)
                    ]
                  : [AppColors.primary, AppColors.primary.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: (_isEditing ? AppColors.statusGreen : AppColors.primary)
                    .withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: _toggleEdit,
            icon: Icon(
              _isEditing ? Icons.check_circle_outline : Icons.edit_outlined,
              size: 20,
              color: Colors.white,
            ),
            label: Text(
              _isEditing ? 'Simpan Perubahan' : 'Edit Profile',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Logout outlined elegan
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.statusRed.withOpacity(0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: () => _showLogoutConfirm(context),
            icon: Icon(Icons.logout_rounded,
                size: 20, color: AppColors.statusRed),
            label: Text(
              'Keluar Akun',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppColors.statusRed,
                letterSpacing: 0.3,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  // ── DIALOGS ───────────────────────────────────────────
  void _showUbahPassword(BuildContext context) {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        bool oldObscureLocal = true;
        bool newObscureLocal = true;
        bool confirmObscureLocal = true;
        return StatefulBuilder(builder: (ctx, sbSetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ubah Password',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark)),
                const SizedBox(height: 16),
                _buildPasswordField('Password Lama', oldCtrl,
                    obscure: oldObscureLocal,
                    onToggle: () =>
                        sbSetState(() => oldObscureLocal = !oldObscureLocal)),
                const SizedBox(height: 12),
                _buildPasswordField('Password Baru', newCtrl,
                    obscure: newObscureLocal,
                    onToggle: () =>
                        sbSetState(() => newObscureLocal = !newObscureLocal)),
                const SizedBox(height: 12),
                _buildPasswordField('Konfirmasi Password Baru', confirmCtrl,
                    obscure: confirmObscureLocal,
                    onToggle: () => sbSetState(
                        () => confirmObscureLocal = !confirmObscureLocal)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Password berhasil diubah!'),
                          backgroundColor: AppColors.statusGreen,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Simpan',
                        style: TextStyle(color: Colors.white, fontSize: 14)),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _buildPasswordField(String hint, TextEditingController ctrl,
      {required bool obscure, required VoidCallback onToggle}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textGrey, fontSize: 13),
        filled: true,
        fillColor: const Color(0xFFF0F4F8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        prefixIcon:
            Icon(Icons.lock_outline, color: AppColors.textGrey, size: 18),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility,
              color: AppColors.textGrey, size: 18),
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      ),
    );
  }

  // ignore: unused_element
  void _showPairingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.qr_code_scanner, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('Pair Device',
                style: TextStyle(fontSize: 16, color: AppColors.textDark)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4F8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.primary.withOpacity(0.3), width: 2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_2, size: 80, color: AppColors.primary),
                  const SizedBox(height: 8),
                  Text('Arahkan ke QR Walker',
                      style:
                          TextStyle(fontSize: 12, color: AppColors.textGrey)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Scan QR yang ada di perangkat walker untuk menghubungkan.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textGrey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: TextStyle(color: AppColors.textGrey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Scan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.logout, color: AppColors.statusRed),
            const SizedBox(width: 8),
            const Text('Keluar Akun', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: const Text(
          'Apakah kamu yakin ingin keluar dari akun ini?',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);

              await _logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Keluar',
              style: TextStyle(color: Colors.white),
            ),
          )
        ],
      ),
    );
  }

  Future<void> _logout() async {
    // hapus session login
    await DatabaseHelper.instance.logout();

    if (!mounted) return;

    // ── FIX: pakai `rootNavigator: true`. Kalau ProfileScreen ini
    //    berada di dalam bottom navigation (MainNavigation) yang tiap
    //    tab-nya punya Navigator sendiri-sendiri (pola umum biar state
    //    per-tab gak reset saat pindah tab), maka
    //    `Navigator.pushNamedAndRemoveUntil(context, ...)` tanpa
    //    `rootNavigator: true` bisa jadi cuma menemukan & me-reset
    //    Navigator LOKAL tab Profile — bukan Navigator utama milik
    //    MaterialApp yang menyimpan route 'login'. Akibatnya, alih-alih
    //    pindah ke halaman Login, tab Profile cuma balik ke rute awal
    //    tab itu sendiri, lalu bottom nav (yang tidak ikut ter-reset)
    //    tetap menampilkan tab Monitoring di baliknya — persis gejala
    //    "klik keluar malah balik ke Monitoring".
    Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
    );
  }

  // ── HELPERS ───────────────────────────────────────────
  Widget _buildEditField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    TextAlign textAlign = TextAlign.start,
    TextStyle? style,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textAlign: textAlign,
      style: style ??
          TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textGrey, fontSize: 13),
        filled: true,
        fillColor: AppColors.primary.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.primary.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.primary.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        prefixIcon: Icon(icon, color: AppColors.primary, size: 18),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      ),
    );
  }

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

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark)),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textGrey, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
          ),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark)),
        ],
      ),
    );
  }

  Widget _buildDivider() => Divider(height: 1, color: Colors.grey.shade100);
}