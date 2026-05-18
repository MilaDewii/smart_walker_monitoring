import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/app_colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // ── MODE EDIT ──
  bool _isEditing = false;

  // ── DATA USER ──
  String _namaLengkap = 'Mila Dewi';
  String _email = 'mila@gmail.com';
  String _noHp = '081234567890';
  final String _role = 'Caregiver / User';
  File? _fotoFile;

  // Controllers untuk mode edit
  late TextEditingController _namaCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _noHpCtrl;

  // ── DATA DEVICE WALKER ──
  final String _walkerId = 'GW-001';
  final String _statusDevice = 'Connected';
  final int _battery = 89;

  // ── STATUS KONEKSI ──
  final bool _wifi = true;
  final bool _bluetooth = true;
  final bool _gps = true;

  // ── STATISTIK MONITORING ──
  final int _totalMonitoring = 128;
  final int _riwayatBahaya = 4;
  final int _riwayatWarning = 12;

  @override
  void initState() {
    super.initState();
    _namaCtrl = TextEditingController(text: _namaLengkap);
    _emailCtrl = TextEditingController(text: _email);
    _noHpCtrl = TextEditingController(text: _noHp);
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _emailCtrl.dispose();
    _noHpCtrl.dispose();
    super.dispose();
  }

  // ── TOGGLE EDIT / SIMPAN ──────────────────────────────
  void _toggleEdit() {
    if (_isEditing) {
      setState(() {
        _namaLengkap = _namaCtrl.text.trim();
        _email = _emailCtrl.text.trim();
        _noHp = _noHpCtrl.text.trim();
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profil berhasil disimpan!'),
          backgroundColor: AppColors.statusGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      setState(() {
        _namaCtrl.text = _namaLengkap;
        _emailCtrl.text = _email;
        _noHpCtrl.text = _noHp;
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

  // ── GANTI FOTO ───────────────────────────────────────
  Future<void> _pilihFoto(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked != null) {
      setState(() => _fotoFile = File(picked.path));
    }
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
              Text(
                'Ganti Foto Profil',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark),
              ),
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
                    onPressed: () {
                      setState(() => _fotoFile = null);
                      Navigator.pop(ctx);
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
                      _buildPairingDevice(),
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
          SvgPicture.asset('assets/images/Guardian.svg', width: 40, height: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hallo, $_namaLengkap',
                    style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                Text(
                  'Profil Saya',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark),
                ),
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
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }

  // ── 1. FOTO & NAMA ───────────────────────────────────
  Widget _buildFotoNama() {
    return _buildCard(
      child: Column(
        children: [
          GestureDetector(
            onTap: _showPilihFotoSheet,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.primary.withOpacity(0.15),
                  backgroundImage:
                      _fotoFile != null ? FileImage(_fotoFile!) : null,
                  child: _fotoFile == null
                      ? Icon(Icons.person, size: 52, color: AppColors.primary)
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
          TextButton(
            onPressed: _showPilihFotoSheet,
            child: Text(
              'Ganti Foto',
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600),
            ),
          ),
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

  // ── 2. INFORMASI AKUN ────────────────────────────────
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
          _isEditing
              ? _buildEditField(
                  controller: _namaCtrl,
                  icon: Icons.badge_outlined,
                  hint: 'Nama Lengkap',
                )
              : _buildInfoRow(Icons.badge_outlined, 'Nama Lengkap', _namaLengkap),
          _buildDivider(),
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
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textGrey)),
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
        ],
      ),
    );
  }

  // ── 3. INFORMASI DEVICE WALKER ───────────────────────
  Widget _buildInfoWalker() {
    final bool isConnected = _statusDevice == 'Connected';
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Device Walker', Icons.bluetooth_connected),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.qr_code_2, 'Walker ID', _walkerId),
          _buildDivider(),
          Row(
            children: [
              Icon(Icons.wifi_tethering, color: AppColors.textGrey, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Status Device',
                    style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
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
                    Text(
                      _statusDevice,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isConnected
                              ? AppColors.statusGreen
                              : AppColors.statusRed),
                    ),
                  ],
                ),
              ),
            ],
          ),
          _buildDivider(),
          Row(
            children: [
              Icon(Icons.battery_charging_full,
                  color: _batteryColor(_battery), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Battery',
                    style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
              ),
              SizedBox(
                width: 80,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$_battery%',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _batteryColor(_battery))),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _battery / 100,
                        minHeight: 6,
                        backgroundColor: Colors.grey.shade200,
                        color: _batteryColor(_battery),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _batteryColor(int pct) {
    if (pct >= 60) return AppColors.statusGreen;
    if (pct >= 30) return AppColors.statusYellow;
    return AppColors.statusRed;
  }

  // ── 4. PAIRING DEVICE ────────────────────────────────
  Widget _buildPairingDevice() {
    return InkWell(
      onTap: () => _showPairingDialog(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primary.withOpacity(0.75)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.qr_code_scanner,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Pair Device',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text('Scan QR untuk menghubungkan walker baru',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white, size: 24),
          ],
        ),
      ),
    );
  }

  // ── 5. STATUS KONEKSI ────────────────────────────────
  Widget _buildStatusKoneksi() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Status Koneksi', Icons.signal_cellular_alt),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildKoneksiChip(Icons.wifi, 'WiFi', _wifi),
              const SizedBox(width: 8),
              _buildKoneksiChip(Icons.bluetooth, 'Bluetooth', _bluetooth),
              const SizedBox(width: 8),
              _buildKoneksiChip(Icons.gps_fixed, 'GPS', _gps),
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
                    color: aktif
                        ? AppColors.statusGreen
                        : AppColors.statusRed)),
            Text(aktif ? 'Aktif' : 'Nonaktif',
                style: TextStyle(fontSize: 10, color: AppColors.textGrey)),
          ],
        ),
      ),
    );
  }

  // ── 6. STATISTIK MONITORING ──────────────────────────
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

  // ── 7 & 8. EDIT PROFILE + LOGOUT ─────────────────────
  Widget _buildTombolEditLogout() {
    return Column(
      children: [
        // Edit / Simpan toggle
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _toggleEdit,
            icon: Icon(
                _isEditing ? Icons.save_outlined : Icons.edit_outlined,
                size: 18),
            label: Text(
              _isEditing ? 'Simpan Perubahan' : 'Edit Profile',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _isEditing ? AppColors.statusGreen : AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Logout — solid merah penuh (bukan outline)
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showLogoutConfirm(context),
            icon: const Icon(Icons.logout, size: 18, color: Colors.white),
            label: const Text(
              'Logout',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
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
      builder: (ctx) => Padding(
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
            _buildPasswordField('Password Lama', oldCtrl),
            const SizedBox(height: 12),
            _buildPasswordField('Password Baru', newCtrl),
            const SizedBox(height: 12),
            _buildPasswordField('Konfirmasi Password Baru', confirmCtrl),
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
      ),
    );
  }

  Widget _buildPasswordField(String hint, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      obscureText: true,
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
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      ),
    );
  }

  void _showPairingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textGrey)),
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
            child: Text('Batal',
                style: TextStyle(color: AppColors.textGrey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Scan',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.logout, color: AppColors.statusRed),
            const SizedBox(width: 8),
            const Text('Logout', style: TextStyle(fontSize: 16)),
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
            onPressed: () {
              Navigator.pop(ctx);
              // TODO: clear token, navigate to login
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusRed,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Logout',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── EDIT FIELD ────────────────────────────────────────
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

  // ── HELPERS ───────────────────────────────────────────
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