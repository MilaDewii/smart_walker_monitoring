import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_colors.dart';
import '../utils/app_routes.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import '../database/database_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _namaUser = 'User';
  File? _fotoFile;
  // ── 1. GEOFENCE ──────────────────────────────────────
  double _safeRadius = 50.0; // meter

  // ── 2. SENSOR CALIBRATION ────────────────────────────
  bool _calibMPU = false;
  bool _calibUltrasonic = false;
  bool _calibGPS = false;

  // ── 3. THRESHOLD ─────────────────────────────────────
  double _warningThreshold = 0.7;
  double _dangerThreshold = 1.0;

  // ── 4. NOTIFICATION ──────────────────────────────────
  bool _alertSound = true;
  bool _vibration = true;
  String _soundMode = 'Normal'; // Normal | Silent | Loud

  // ── 5. PAIR DEVICE — handled via dialog ──────────────

  // ── 6. CONNECTION ─────────────────────────────────────
  // final bool _wifiStatus = true;
  // final bool _bluetoothStatus = true;
  // final bool _sim808Status = false;

  // ── 7. EMERGENCY CONTACT ─────────────────────────────
  int? _emergencyId;

  List<Map<String, dynamic>> _emergencyContacts = [];
  String _emergencyName = '';
  String _emergencyPhone = '';
  String _emergencyRelation = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadSettings();
    _loadEmergencyContact();
  }

  Future<void> _loadProfile() async {
    final profile = await DatabaseHelper.instance.getProfile();
    if (!mounted) return;
    setState(() {
      _namaUser = profile?['nama']?.toString() ?? 'User';

      final fotoPath = profile?['foto']?.toString() ?? '';

      if (fotoPath.isNotEmpty && File(fotoPath).existsSync()) {
        _fotoFile = File(fotoPath);
      } else {
        _fotoFile = null;
      }
    });
  }

  Future<void> _loadSettings() async {
    final settings = await DatabaseHelper.instance.getSettings();

    if (!mounted) return;

    if (settings != null) {
      setState(() {
        _safeRadius = (settings['geofence_radius'] ?? 50).toDouble();

        _warningThreshold = (settings['warning_threshold'] ?? 0.7).toDouble();

        _dangerThreshold = (settings['danger_threshold'] ?? 1.0).toDouble();

        _calibMPU = (settings['mpu6050_calibration'] ?? 0) == 1;

        _calibUltrasonic = (settings['ultrasonic_calibration'] ?? 0) == 1;

        _calibGPS = (settings['gps_calibration'] ?? 0) == 1;

        _alertSound = (settings['alert_sound'] ?? 1) == 1;

        _vibration = (settings['vibration'] ?? 1) == 1;

        _soundMode = settings['sound_mode'] ?? 'Normal';
      });
    }
  }

  Future<void> _loadEmergencyContact() async {
    final contacts = await DatabaseHelper.instance.getEmergencyContacts();

    if (!mounted) return;

    setState(() {
      _emergencyContacts = contacts;
    });
  }

  Future<void> _saveSettings() async {
    final settings = await DatabaseHelper.instance.getSettings();

    if (settings == null) {
      await DatabaseHelper.instance.saveSettings(
        geofenceRadius: _safeRadius.toInt(),
        warningThreshold: _warningThreshold,
        dangerThreshold: _dangerThreshold,
        mpu6050Calibration: _calibMPU ? 1 : 0,
        ultrasonicCalibration: _calibUltrasonic ? 1 : 0,
        gpsCalibration: _calibGPS ? 1 : 0,
        alertSound: _alertSound ? 1 : 0,
        vibration: _vibration ? 1 : 0,
        soundMode: _soundMode,
      );
    } else {
      await DatabaseHelper.instance.updateSettings(
        id: settings['id'],
        geofenceRadius: _safeRadius.toInt(),
        warningThreshold: _warningThreshold,
        dangerThreshold: _dangerThreshold,
        mpu6050Calibration: _calibMPU ? 1 : 0,
        ultrasonicCalibration: _calibUltrasonic ? 1 : 0,
        gpsCalibration: _calibGPS ? 1 : 0,
        alertSound: _alertSound ? 1 : 0,
        vibration: _vibration ? 1 : 0,
        soundMode: _soundMode,
      );
    }
  }

  Future<void> _callEmergencyContact(String phone) async {
    final cleanNumber = phone.replaceAll(' ', '').replaceAll('-', '');

    final Uri phoneUri = Uri(
      scheme: 'tel',
      path: cleanNumber,
    );

    await launchUrl(
      phoneUri,
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _saveEmergencyContact() async {
    if (_emergencyId == null) {
      // simpan baru

      await DatabaseHelper.instance.saveEmergencyContact(
        contactName: _emergencyName,
        contactNumber: _emergencyPhone,
        relationship: _emergencyRelation,
      );
    } else {
      // update data lama

      await DatabaseHelper.instance.updateEmergencyContact(
        id: _emergencyId!,
        contactName: _emergencyName,
        contactNumber: _emergencyPhone,
        relationship: _emergencyRelation,
      );
    }

    await _loadEmergencyContact();
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
                      _buildGeofence(),
                      const SizedBox(height: 16),
                      _buildThreshold(),
                      const SizedBox(height: 16),
                      _buildSensorCalibration(),
                      const SizedBox(height: 16),
                      _buildNotification(),
                      const SizedBox(height: 16),
                      _buildPairDevice(),
                      const SizedBox(height: 16),
                      _buildEmergencyContact(),
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
            radius: 22,
            backgroundColor: AppColors.primary.withOpacity(0.15),
            backgroundImage: _fotoFile != null ? FileImage(_fotoFile!) : null,
            child: _fotoFile == null
                ? Text(
                    _namaUser.isNotEmpty ? _namaUser[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 18,
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
                  style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                ),
                Text(
                  'Pengaturan',
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
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.notification),
            ),
          ),
        ],
      ),
    );
  }

  // ── 1. GEOFENCE SETTING ──────────────────────────────
  Widget _buildGeofence() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
              'Geofence Setting', Icons.fence_outlined, AppColors.primary),
          const SizedBox(height: 4),
          Text('Atur radius zona aman lansia',
              style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
          const SizedBox(height: 16),
          // Radius display
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.statusGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    Icon(Icons.radar, color: AppColors.statusGreen, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Safe Radius',
                        style:
                            TextStyle(fontSize: 13, color: AppColors.textGrey)),
                    Text(
                      '${_safeRadius.toInt()} meter',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.statusGreen),
                    ),
                  ],
                ),
              ),
              // Input langsung
              SizedBox(
                width: 72,
                child: TextField(
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: '${_safeRadius.toInt()}',
                    hintStyle: TextStyle(color: AppColors.textGrey),
                    filled: true,
                    fillColor: const Color(0xFFF0F4F8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    suffixText: 'm',
                    suffixStyle:
                        TextStyle(fontSize: 11, color: AppColors.textGrey),
                  ),
                  onChanged: (val) {
                    final v = double.tryParse(val);
                    if (v != null && v >= 10 && v <= 500) {
                      setState(() => _safeRadius = v);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.statusGreen,
              inactiveTrackColor: AppColors.statusGreen.withOpacity(0.2),
              thumbColor: AppColors.statusGreen,
              overlayColor: AppColors.statusGreen.withOpacity(0.15),
              trackHeight: 6,
            ),
            child: Slider(
              value: _safeRadius.clamp(10, 500),
              min: 10,
              max: 500,
              divisions: 49,
              onChanged: (v) {
                setState(() {
                  _safeRadius = v;
                });

                _saveSettings();
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('10 m',
                  style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
              Text('500 m',
                  style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
            ],
          ),
          const SizedBox(height: 12),
          // Quick select preset
          Row(
            children: [
              _buildPresetChip('10m', 10),
              const SizedBox(width: 8),
              _buildPresetChip('50m', 50),
              const SizedBox(width: 8),
              _buildPresetChip('100m', 100),
              const SizedBox(width: 8),
              _buildPresetChip('200m', 200),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, double value) {
    final bool selected = _safeRadius == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _safeRadius = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.statusGreen
                : AppColors.statusGreen.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? AppColors.statusGreen
                  : AppColors.statusGreen.withOpacity(0.2),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.statusGreen),
          ),
        ),
      ),
    );
  }

  // ── 2. THRESHOLD SETTING ─────────────────────────────
  Widget _buildThreshold() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
              'Threshold Setting', Icons.tune, AppColors.statusYellow),
          const SizedBox(height: 4),
          Text('Ambang batas deteksi warning & bahaya',
              style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
          const SizedBox(height: 16),
          // Warning threshold
          _buildThresholdRow(
            label: 'Warning Threshold',
            value: _warningThreshold,
            color: AppColors.statusYellow,
            icon: Icons.warning_amber_rounded,
            min: 0.1,
            max: 0.9,
            onChanged: (v) {
              if (v < _dangerThreshold) {
                setState(() {
                  _warningThreshold = v;
                });

                _saveSettings();
              }
            },
          ),
          const SizedBox(height: 16),
          // Danger threshold
          _buildThresholdRow(
            label: 'Danger Threshold',
            value: _dangerThreshold,
            color: AppColors.statusRed,
            icon: Icons.dangerous_outlined,
            min: 0.5,
            max: 2.0,
            onChanged: (v) {
              if (v > _warningThreshold) {
                setState(() {
                  _dangerThreshold = v;
                });
                _saveSettings();
              }
            },
          ),
          const SizedBox(height: 12),
          // Info hint
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.primary, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Warning < Danger. Sensor akan trigger alert bila nilai melebihi threshold.',
                    style: TextStyle(fontSize: 11, color: AppColors.textGrey),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThresholdRow({
    required String label,
    required double value,
    required Color color,
    required IconData icon,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                value.toStringAsFixed(2),
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold, color: color),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            inactiveTrackColor: color.withOpacity(0.2),
            thumbColor: color,
            overlayColor: color.withOpacity(0.15),
            trackHeight: 5,
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: ((max - min) * 10).toInt(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  // ── 3. SENSOR CALIBRATION ────────────────────────────
  Widget _buildSensorCalibration() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Sensor Calibration', Icons.settings_input_antenna,
              AppColors.primary),
          const SizedBox(height: 4),
          Text('Kalibrasi sensor sebelum digunakan',
              style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
          const SizedBox(height: 16),
          _buildCalibItem(
            name: 'MPU6050',
            subtitle: 'Akselerometer & Giroskop',
            icon: Icons.sensors,
            isDone: _calibMPU,
            onCalibrate: () => _runCalibration('MPU6050', () {
              setState(() {
                _calibMPU = true;
              });

              _saveSettings();
            }),
          ),
          _buildDivider(),
          _buildCalibItem(
            name: 'Ultrasonic',
            subtitle: 'Sensor Jarak',
            icon: Icons.radar,
            isDone: _calibUltrasonic,
            onCalibrate: () => _runCalibration('Ultrasonic', () {
              setState(() {
                _calibUltrasonic = true;
              });
              _saveSettings();
            }),
          ),
          _buildDivider(),
          _buildCalibItem(
            name: 'GPS',
            subtitle: 'Lokasi & Tracking',
            icon: Icons.gps_fixed,
            isDone: _calibGPS,
            onCalibrate: () => _runCalibration('GPS', () {
              setState(() {
                _calibGPS = true;
              });

              _saveSettings();
            }),
          ),
          if (_calibMPU || _calibUltrasonic || _calibGPS) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                setState(() {
                  _calibMPU = false;
                  _calibUltrasonic = false;
                  _calibGPS = false;
                });

                await _saveSettings();
              },
              child: Text(
                'Reset semua kalibrasi',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.statusRed,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCalibItem({
    required String name,
    required String subtitle,
    required IconData icon,
    required bool isDone,
    required VoidCallback onCalibrate,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDone
                  ? AppColors.statusGreen.withOpacity(0.1)
                  : AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                color: isDone ? AppColors.statusGreen : AppColors.primary,
                size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark)),
                Text(subtitle,
                    style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
              ],
            ),
          ),
          isDone
              ? Row(
                  children: [
                    Icon(Icons.check_circle,
                        color: AppColors.statusGreen, size: 18),
                    const SizedBox(width: 4),
                    Text('Terkalibrasi',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.statusGreen,
                            fontWeight: FontWeight.w600)),
                  ],
                )
              : ElevatedButton(
                  onPressed: onCalibrate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Kalibrasi'),
                ),
        ],
      ),
    );
  }

  void _runCalibration(String sensor, VoidCallback onDone) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        // Auto close after 2s (simulate calibration)
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          if (Navigator.canPop(context)) Navigator.pop(context);
          onDone();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$sensor berhasil dikalibrasi!'),
              backgroundColor: AppColors.statusGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        });
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text('Mengkalibrasi $sensor...',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark)),
              const SizedBox(height: 6),
              Text('Harap jangan gerakkan perangkat',
                  style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ── 4. NOTIFICATION SOUND ────────────────────────────
  Widget _buildNotification() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Notifikasi & Suara',
              Icons.notifications_active_outlined, AppColors.statusYellow),
          const SizedBox(height: 12),
          // Alert Sound toggle
          _buildToggleRow(
            icon: Icons.volume_up_outlined,
            iconColor: AppColors.primary,
            label: 'Alert Sound',
            subtitle: 'Putar suara saat deteksi bahaya',
            value: _alertSound,
            onChanged: (v) {
              setState(() {
                _alertSound = v;
              });

              _saveSettings();
            },
          ),
          _buildDivider(),
          // Vibration toggle
          _buildToggleRow(
            icon: Icons.vibration,
            iconColor: AppColors.primary,
            label: 'Vibration',
            subtitle: 'Getar saat ada peringatan',
            value: _vibration,
            onChanged: (v) {
              setState(() {
                _vibration = v;
              });

              _saveSettings();
            },
          ),
          _buildDivider(),
          // Sound Mode selector
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.speaker_outlined,
                      color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mode Suara',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark)),
                      Text('Atur volume alert',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.textGrey)),
                    ],
                  ),
                ),
                // Segmented control manual
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4F8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: ['Silent', 'Normal', 'Loud'].map((mode) {
                      final bool selected = _soundMode == mode;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _soundMode = mode;
                          });

                          _saveSettings();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            mode,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? Colors.white
                                    : AppColors.textGrey),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark)),
                Text(subtitle,
                    style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  // ── 5. PAIR DEVICE ───────────────────────────────────
  Widget _buildPairDevice() {
    return GestureDetector(
      onTap: () => _showPairingDialog(context),
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
                  Text('Pair New Walker',
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

  void _showPairingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.qr_code_scanner, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('Scan QR Walker',
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
              'Temukan QR code di bagian bawah perangkat walker Guardian.',
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
            onPressed: () => Navigator.pushNamed(context, '/qr-connect'),
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

  // ignore: unused_element
  Widget _buildConnectionItem({
    required IconData icon,
    required String label,
    required String detail,
    required bool isActive,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.statusGreen.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon,
                color: isActive ? AppColors.statusGreen : Colors.grey,
                size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark)),
                Text(detail,
                    style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.statusGreen.withOpacity(0.12)
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isActive ? 'Aktif' : 'Nonaktif',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isActive ? AppColors.statusGreen : Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  // ── 7. EMERGENCY CONTACT ─────────────────────────────
  Widget _buildEmergencyContact() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            'Emergency Contact',
            Icons.contact_phone_outlined,
            AppColors.statusRed,
          ),

          const SizedBox(height: 8),

          Text(
            'Kontak yang dihubungi saat bahaya',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textGrey,
            ),
          ),

          const SizedBox(height: 16),

          // LIST KONTAK
          ..._emergencyContacts.map((contact) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.statusRed.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.statusRed.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    child: Text(
                      contact['contact_name'][0].toUpperCase(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contact['contact_name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "${contact['relationship']} • ${contact['contact_number']}",
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.call),
                    onPressed: () async {
                      await _callEmergencyContact(
                        contact['contact_number'],
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      _showEditEmergencyContact(
                        context,
                        contact,
                      );
                    },
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 12),

          // TOMBOL TAMBAH
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                _showAddEmergencyContact();
              },
              icon: const Icon(Icons.add),
              label: const Text("Tambah Emergency Contact"),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditEmergencyContact(
    BuildContext context,
    Map<String, dynamic> contact,
  ) {
    final nameCtrl = TextEditingController(
      text: contact['contact_name'],
    );

    final phoneCtrl = TextEditingController(
      text: contact['contact_number'],
    );

    final relCtrl = TextEditingController(
      text: contact['relationship'],
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
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
            Row(
              children: [
                Icon(
                  Icons.contact_phone_outlined,
                  color: AppColors.statusRed,
                ),
                const SizedBox(width: 8),
                Text(
                  'Edit Emergency Contact',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildContactField(
              nameCtrl,
              Icons.person_outline,
              'Nama Kontak',
            ),
            const SizedBox(height: 12),
            _buildContactField(
              phoneCtrl,
              Icons.phone_outlined,
              'Nomor HP',
              type: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            _buildContactField(
              relCtrl,
              Icons.people_outline,
              'Hubungan',
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  _emergencyId = contact['id'];

                  _emergencyName = nameCtrl.text.trim();

                  _emergencyPhone = phoneCtrl.text.trim();

                  _emergencyRelation = relCtrl.text.trim();

                  await _saveEmergencyContact();

                  Navigator.pop(ctx);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'Emergency contact berhasil diperbarui!',
                      ),
                      backgroundColor: AppColors.statusGreen,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.statusRed,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                  ),
                ),
                child: const Text(
                  'Simpan',
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddEmergencyContact() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final relationCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildContactField(
                nameCtrl,
                Icons.person,
                "Nama",
              ),
              const SizedBox(height: 12),
              _buildContactField(
                phoneCtrl,
                Icons.phone,
                "Nomor HP",
                type: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              _buildContactField(
                relationCtrl,
                Icons.people,
                "Hubungan",
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  await DatabaseHelper.instance.saveEmergencyContact(
                    contactName: nameCtrl.text,
                    contactNumber: phoneCtrl.text,
                    relationship: relationCtrl.text,
                  );

                  await _loadEmergencyContact();

                  Navigator.pop(ctx);
                },
                child: const Text("Simpan"),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContactField(
    TextEditingController ctrl,
    IconData icon,
    String hint, {
    TextInputType type = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textGrey, fontSize: 13),
        filled: true,
        fillColor: const Color(0xFFF0F4F8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        prefixIcon: Icon(icon, color: AppColors.textGrey, size: 18),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
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

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark)),
      ],
    );
  }

  Widget _buildDivider() => Divider(height: 1, color: Colors.grey.shade100);
}
