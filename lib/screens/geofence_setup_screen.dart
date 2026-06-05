import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';

import '../utils/app_colors.dart';
import '../utils/app_routes.dart';
import '../database/database_helper.dart';

class GeofenceSetupScreen extends StatefulWidget {
  /// [fromDashboard] true jika dibuka dari card lokasi (bukan onboarding)
  final bool fromDashboard;
  const GeofenceSetupScreen({super.key, this.fromDashboard = false});

  @override
  State<GeofenceSetupScreen> createState() => _GeofenceSetupScreenState();
}

class _GeofenceSetupScreenState extends State<GeofenceSetupScreen> {
  // ── State ──────────────────────────────────────────────────────────────────
  _Step _step = _Step.permission; // akan di-override di initState
  LatLng? _selectedPoint;
  LatLng? _userLocation;
  bool _loadingLocation = false;
  bool _saving = false;
  String? _walkerId;

  /// Radius geofence dalam meter — bisa diubah via slider
  double _radius = 100.0;
  static const double _minRadius = 30.0;
  static const double _maxRadius = 500.0;

  final MapController _mapController = MapController();

  // ── Init ───────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadWalkerId();
    _checkLocationPermissionOnStart();
  }

  Future<void> _loadWalkerId() async {
    final paired = await DatabaseHelper.instance.getPairedWalkers();
    if (!mounted) return;
    if (paired.isNotEmpty) {
      setState(() => _walkerId = paired.first['walker_id']?.toString());
    }
  }

  /// Cek izin lokasi saat layar dibuka.
  /// Jika sudah granted → langsung ambil lokasi & skip ke halaman peta.
  /// Jika belum → tampilkan halaman izin seperti biasa.
  Future<void> _checkLocationPermissionOnStart() async {
    try {
      final perm = await Geolocator.checkPermission();

      if (perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse) {
        // Izin sudah ada — langsung ambil lokasi tanpa minta ulang
        if (mounted) setState(() => _loadingLocation = true);
        await _getLocationAndGoToMap();
      }
      // else: tetap di halaman permission (_step default = _Step.permission)
    } catch (_) {
      // Gagal cek — tampilkan halaman izin saja
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  // ── Location helpers ───────────────────────────────────────────────────────

  /// Ambil lokasi GPS lalu pindah ke step peta.
  /// Dipanggil baik dari tombol "Aktifkan Lokasi" maupun otomatis saat start.
  Future<void> _getLocationAndGoToMap() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final latlng = LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() {
        _userLocation  = latlng;
        _selectedPoint = latlng;
        _step          = _Step.map;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(latlng, 17);
      });
    } catch (e) {
      if (mounted) _showError('Gagal mendapatkan lokasi: $e');
    }
  }

  /// Dipanggil tombol "Aktifkan Lokasi" — minta izin dulu, lalu ambil posisi.
  Future<void> _requestAndGetLocation() async {
    setState(() => _loadingLocation = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        _showError('Izin lokasi ditolak permanen. Aktifkan di pengaturan.');
        return;
      }
      await _getLocationAndGoToMap();
    } catch (e) {
      if (mounted) _showError('Gagal mendapatkan lokasi: $e');
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  // ── Save ke RTDB ──────────────────────────────────────────────────────────
  Future<void> _saveGeofence() async {
    if (_selectedPoint == null || _walkerId == null) return;

    setState(() => _saving = true);
    try {
      final ref =
          FirebaseDatabase.instance.ref('walkers/$_walkerId/geofence');
      await ref.set({
        'center_latitude' : _selectedPoint!.latitude,
        'center_longitude': _selectedPoint!.longitude,
        'radius'          : _radius,
        'status'          : 'inside',
      });

      if (!mounted) return;
      setState(() => _step = _Step.saved);
    } catch (e) {
      if (mounted) _showError('Gagal menyimpan: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.statusRed));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0F4F8),
        elevation: 0,
        leading: BackButton(color: AppColors.textDark),
        title: Text(
          'Atur Area Aman',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        centerTitle: true,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: switch (_step) {
          _Step.permission => _buildPermissionPage(),
          _Step.map        => _buildMapPage(),
          _Step.saved      => _buildSavedPage(),
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HALAMAN 1 – Izin Lokasi (hanya muncul jika izin belum diberikan)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPermissionPage() {
    return Center(
      key: const ValueKey('permission'),
      child: _loadingLocation
          // Loading saat sedang cek / ambil lokasi otomatis
          ? const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Mendapatkan lokasi...'),
              ],
            )
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.location_on_rounded,
                        size: 52, color: AppColors.primary),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Aktifkan Lokasi',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'GuardianWalk membutuhkan akses lokasi '
                    'untuk membantu menentukan titik rumah '
                    'sebagai area aman lansia.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textGrey,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _requestAndGetLocation,
                      icon: const Icon(Icons.my_location_rounded, size: 20),
                      label: const Text('Aktifkan Lokasi'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HALAMAN 2 – Pilih Titik + Atur Radius
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMapPage() {
    return Column(
      key: const ValueKey('map'),
      children: [
        // Info banner
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.touch_app_rounded,
                  size: 20, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tap pada peta untuk menandai lokasi rumah + area aman langsung',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Peta
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter:
                      _userLocation ?? const LatLng(-7.05, 110.44),
                  initialZoom: 17,
                  onTap: (tapPosition, point) {
                    setState(() => _selectedPoint = point);
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.guardianwalk.app',
                  ),
                  // ── Lingkaran geofence ────────────────────────────────────
                  if (_selectedPoint != null)
                    CircleLayer(circles: [
                      CircleMarker(
                        point: _selectedPoint!,
                        radius: _radius,
                        color: AppColors.statusGreen.withOpacity(0.15),
                        borderColor: AppColors.statusGreen,
                        borderStrokeWidth: 2,
                        useRadiusInMeter: true,
                      ),
                    ]),
                  // ── Marker lokasi user (posisi GPS perangkat — biru) ──────
                  if (_userLocation != null)
                    MarkerLayer(markers: [
                      Marker(
                        point : _userLocation!,
                        width : 36,
                        height: 36,
                        child : Container(
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.blue, width: 2),
                          ),
                          child: const Icon(
                              Icons.person_pin_circle_rounded,
                              color: Colors.blue,
                              size: 20),
                        ),
                      ),
                    ]),
                  // ── Marker rumah (titik yang di-tap) ──────────────────────
                  if (_selectedPoint != null)
                    MarkerLayer(markers: [
                      Marker(
                        point : _selectedPoint!,
                        width : 56,
                        height: 64,
                        child : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: AppColors.statusGreen,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.statusGreen
                                        .withOpacity(0.4),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.home_rounded,
                                  color: Colors.white, size: 22),
                            ),
                            CustomPaint(
                              size: const Size(12, 8),
                              painter:
                                  _TrianglePainter(AppColors.statusGreen),
                            ),
                          ],
                        ),
                      ),
                    ]),
                ],
              ),

              // Tombol kembali ke lokasi user
              Positioned(
                right: 12,
                top: 12,
                child: FloatingActionButton.small(
                  heroTag: 'myLoc',
                  backgroundColor: Colors.white,
                  elevation: 2,
                  onPressed: () {
                    if (_userLocation != null) {
                      _mapController.move(_userLocation!, 17);
                    }
                  },
                  child: Icon(Icons.my_location_rounded,
                      color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),

        // ── Bottom panel ──────────────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                  color: Colors.black12,
                  blurRadius: 12,
                  offset: Offset(0, -4))
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.home_rounded,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Lokasi Rumah Lansia',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_selectedPoint != null) ...[
                _coordRow('Latitude', _selectedPoint!.latitude),
                const SizedBox(height: 4),
                _coordRow('Longitude', _selectedPoint!.longitude),
              ] else
                Text(
                  'Tap pada peta untuk memilih lokasi',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textGrey),
                ),

              const SizedBox(height: 16),

              // ── Slider radius ──────────────────────────────────────────
              Row(
                children: [
                  Icon(Icons.radio_button_unchecked_rounded,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Radius area aman',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_radius.toInt()} m',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.primary,
                  inactiveTrackColor: AppColors.primary.withOpacity(0.2),
                  thumbColor: AppColors.primary,
                  overlayColor: AppColors.primary.withOpacity(0.1),
                  trackHeight: 3,
                ),
                child: Slider(
                  value: _radius,
                  min: _minRadius,
                  max: _maxRadius,
                  divisions: 47,
                  onChanged: (v) =>
                      setState(() => _radius = (v / 10).roundToDouble() * 10),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${_minRadius.toInt()} m',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textGrey)),
                  Text('${_maxRadius.toInt()} m',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textGrey)),
                ],
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_selectedPoint == null || _saving)
                      ? null
                      : _saveGeofence,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_rounded, size: 20),
                  label: Text(
                      _saving ? 'Menyimpan...' : 'Simpan Lokasi & Area Aman'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.statusGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _coordRow(String label, double value) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(label,
              style:
                  TextStyle(fontSize: 12, color: AppColors.textGrey)),
        ),
        Text(
          ': ${value.toStringAsFixed(6)}',
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HALAMAN 3 – Tersimpan
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSavedPage() {
    return Center(
      key: const ValueKey('saved'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (_, v, child) =>
                  Transform.scale(scale: v, child: child),
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.statusGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_rounded,
                    size: 56, color: AppColors.statusGreen),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Area Aman Tersimpan!',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark),
            ),
            const SizedBox(height: 10),
            Text(
              'Lokasi rumah & geofence berhasil disimpan.\nMonitoring area aman kini aktif.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: AppColors.textGrey, height: 1.6),
            ),
            const SizedBox(height: 16),
            if (_selectedPoint != null)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.statusGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.statusGreen.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    _coordRow('Latitude', _selectedPoint!.latitude),
                    const SizedBox(height: 4),
                    _coordRow('Longitude', _selectedPoint!.longitude),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        SizedBox(
                          width: 72,
                          child: Text('Radius',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textGrey)),
                        ),
                        Text(
                          ': ${_radius.toInt()} meter',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (widget.fromDashboard) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushReplacementNamed(
                        context, AppRoutes.monitoring);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
                child: const Text('Mulai Monitoring'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helper ──────────────────────────────────────────────────────────────────
enum _Step { permission, map, saved }

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}