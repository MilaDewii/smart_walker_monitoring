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
  final bool fromDashboard;
  const GeofenceSetupScreen({super.key, this.fromDashboard = false});

  @override
  State<GeofenceSetupScreen> createState() => _GeofenceSetupScreenState();
}

class _GeofenceSetupScreenState extends State<GeofenceSetupScreen> {
  _Step   _step           = _Step.permission;
  LatLng? _selectedPoint;
  LatLng? _userLocation;
  bool    _loadingLocation  = false;
  bool    _loadingGeofence  = false; // loading ambil geofence lama
  bool    _saving           = false;
  String? _walkerId;
  double  _radius           = 100.0;
  bool    _radiusChanged    = false;
  bool    _tapModeActive    = true;

  // Geofence yang sudah ada di Firebase (untuk restore)
  LatLng? _existingGeofenceCenter;
  double? _existingRadius;

  static const double _minRadius = 30.0;
  static const double _maxRadius = 500.0;

  final MapController _mapController = MapController();

  bool get _step1Done => _selectedPoint != null;
  bool get _step2Done => _radiusChanged;

  @override
  void initState() {
    super.initState();
    _loadWalkerIdAndGeofence();
  }

  // ── Load walker ID + geofence yang sudah ada ──────────────────────────────
  Future<void> _loadWalkerIdAndGeofence() async {
    final paired = await DatabaseHelper.instance.getPairedWalkers();
    if (!mounted) return;

    if (paired.isEmpty) {
      // Tidak ada walker → langsung minta izin lokasi
      await _checkLocationPermissionOnStart();
      return;
    }

    final walkerId = paired.first['walker_id']?.toString();
    setState(() {
      _walkerId         = walkerId;
      _loadingGeofence  = true;
    });

    try {
      // Ambil geofence yang sudah ada dari Firebase
      if (walkerId != null && walkerId.isNotEmpty) {
        final snap = await FirebaseDatabase.instance
            .ref('Walkers/$walkerId/geofence')
            .get();

        if (snap.exists && snap.value is Map) {
          final geo = Map<dynamic, dynamic>.from(snap.value as Map);
          final lat = _toDouble(geo['center_latitude'],  0.0);
          final lng = _toDouble(geo['center_longitude'], 0.0);
          final rad = _toDouble(geo['radius'], 100.0);

          if (lat != 0.0 || lng != 0.0) {
            // Ada geofence sebelumnya → restore titik & radius
            setState(() {
              _existingGeofenceCenter = LatLng(lat, lng);
              _existingRadius         = rad;
              _selectedPoint          = LatLng(lat, lng); // ← restore!
              _radius                 = rad;
              _radiusChanged          = true; // sudah ada radius
            });
          }
        }
      }
    } catch (_) {}

    if (mounted) setState(() => _loadingGeofence = false);

    // Setelah load geofence, lanjut cek izin lokasi
    await _checkLocationPermissionOnStart();
  }

  Future<void> _checkLocationPermissionOnStart() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse) {
        if (mounted) setState(() => _loadingLocation = true);
        await _getLocationAndGoToMap();
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  Future<void> _getLocationAndGoToMap() async {
    try {
      final pos    = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final latlng = LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;

      setState(() {
        _userLocation = latlng;
        // Kalau belum ada titik terpilih → set ke posisi user
        // Kalau sudah ada (restore dari Firebase) → jangan overwrite
        _selectedPoint ??= latlng;
        _step = _Step.map;
      });

      // Center peta ke geofence lama kalau ada, kalau tidak ke posisi user
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final centerTo = _existingGeofenceCenter ?? latlng;
        _mapController.move(centerTo, 17);
      });
    } catch (e) {
      if (mounted) _showError('Gagal mendapatkan lokasi: $e');
    }
  }

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

  Future<void> _saveGeofence() async {
    if (_selectedPoint == null) {
      _showError('Pilih titik lokasi rumah dulu di peta');
      return;
    }
    if (_walkerId == null || _walkerId!.isEmpty) {
      _showError('Walker ID tidak ditemukan.');
      return;
    }
    setState(() => _saving = true);
    try {
      await FirebaseDatabase.instance
          .ref('Walkers/$_walkerId/geofence')
          .update({
        'center_latitude' : _selectedPoint!.latitude,
        'center_longitude': _selectedPoint!.longitude,
        'radius'          : _radius,
        'status'          : 'inside',
        'jarakDariPusat'  : 0.0,
        'last_check'      : DateTime.now().toString().substring(0, 19),
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

  double _toDouble(dynamic v, double fb) {
    if (v is num)    return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fb;
    return fb;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0F4F8),
        elevation: 0,
        leading: BackButton(color: AppColors.textDark),
        title: Text(
          _step == _Step.saved ? 'Tersimpan!' : 'Atur Area Aman',
          style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark),
        ),
        centerTitle: true,
      ),
      body: _loadingGeofence
          // Loading saat ambil geofence dari Firebase
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Memuat pengaturan area aman...'),
                ],
              ),
            )
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: switch (_step) {
                _Step.permission => _buildPermissionPage(),
                _Step.map        => _buildMapPage(),
                _Step.saved      => _buildSavedPage(),
              },
            ),
    );
  }

  // ── STEP 1: Izin Lokasi ───────────────────────────────────────────────────
  Widget _buildPermissionPage() {
    return Center(
      key: const ValueKey('permission'),
      child: _loadingLocation
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
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.location_on_rounded,
                        size: 52, color: AppColors.primary),
                  ),
                  const SizedBox(height: 28),
                  Text('Aktifkan Lokasi',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark)),
                  const SizedBox(height: 12),
                  Text(
                    'GuardianWalk membutuhkan akses lokasi untuk '
                    'menentukan titik rumah sebagai area aman lansia.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14, color: AppColors.textGrey, height: 1.6),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _requestAndGetLocation,
                      icon : const Icon(Icons.my_location_rounded, size: 20),
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

  // ── STEP 2: Peta ──────────────────────────────────────────────────────────
  Widget _buildMapPage() {
    return Column(
      key: const ValueKey('map'),
      children: [
        _buildStepGuide(),
        // Banner info kalau ada geofence lama
        if (_existingGeofenceCenter != null)
          Container(
            margin  : const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color       : AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border      : Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Area aman sebelumnya sudah dimuat. '
                    'Tap peta atau geser marker untuk mengubah.',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.primary),
                  ),
                ),
                // Tombol reset ke posisi user
                if (_userLocation != null)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedPoint = _userLocation;
                        _existingGeofenceCenter = null;
                      });
                      _mapController.move(_userLocation!, 17);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color       : AppColors.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Reset',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _existingGeofenceCenter
                      ?? _userLocation
                      ?? const LatLng(-7.05, 110.44),
                  initialZoom: 17,
                  onTap: (_, point) {
                    if (_tapModeActive) {
                      setState(() => _selectedPoint = point);
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate         : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.guardianwalk.app',
                  ),
                  if (_selectedPoint != null)
                    CircleLayer(circles: [
                      CircleMarker(
                        point            : _selectedPoint!,
                        radius           : _radius,
                        color            : AppColors.statusGreen.withOpacity(0.15),
                        borderColor      : AppColors.statusGreen,
                        borderStrokeWidth: 2,
                        useRadiusInMeter : true,
                      ),
                    ]),
                  // Marker posisi HP (biru)
                  if (_userLocation != null)
                    MarkerLayer(markers: [
                      Marker(
                        point : _userLocation!,
                        width : 36, height: 36,
                        child : Container(
                          decoration: BoxDecoration(
                            color : Colors.blue.withOpacity(0.2),
                            shape : BoxShape.circle,
                            border: Border.all(color: Colors.blue, width: 2),
                          ),
                          child: const Icon(Icons.person_pin_circle_rounded,
                              color: Colors.blue, size: 18),
                        ),
                      ),
                    ]),
                  // Marker rumah terpilih
                  if (_selectedPoint != null)
                    MarkerLayer(markers: [
                      Marker(
                        point : _selectedPoint!,
                        width : 42, height: 48,
                        child : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color    : AppColors.statusGreen,
                                shape    : BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color     : AppColors.statusGreen.withOpacity(0.4),
                                    blurRadius: 10, spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.home_rounded,
                                  color: Colors.white, size: 20),
                            ),
                            CustomPaint(
                              size   : const Size(10, 6),
                              painter: _TrianglePainter(AppColors.statusGreen),
                            ),
                          ],
                        ),
                      ),
                    ]),
                ],
              ),

              // Badge mode tap
              Positioned(
                top: 12, left: 0, right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _tapModeActive = !_tapModeActive),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding : const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color       : _tapModeActive
                            ? AppColors.primary
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow   : [
                          BoxShadow(
                              color    : Colors.black.withOpacity(0.12),
                              blurRadius: 8),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _tapModeActive
                                ? Icons.touch_app_rounded
                                : Icons.pan_tool_rounded,
                            size : 16,
                            color: _tapModeActive
                                ? Colors.white
                                : AppColors.textGrey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _tapModeActive
                                ? 'Mode Pilih — Tap peta untuk pilih rumah'
                                : 'Mode Geser — Tap untuk aktifkan pilih',
                            style: TextStyle(
                              fontSize  : 11,
                              fontWeight: FontWeight.w600,
                              color     : _tapModeActive
                                  ? Colors.white
                                  : AppColors.textGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // FAB kanan
              Positioned(
                right: 12, top: 52,
                child: Column(
                  children: [
                    FloatingActionButton.small(
                      heroTag        : 'myLoc',
                      backgroundColor: Colors.white,
                      elevation      : 2,
                      tooltip        : 'Ke posisi saya',
                      onPressed      : () {
                        if (_userLocation != null) {
                          _mapController.move(_userLocation!, 17);
                        }
                      },
                      child: Icon(Icons.my_location_rounded,
                          color: AppColors.primary),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                      heroTag        : 'setMyLoc',
                      backgroundColor: AppColors.primary,
                      elevation      : 2,
                      tooltip        : 'Set lokasi rumah ke posisi saya',
                      onPressed      : () {
                        if (_userLocation != null) {
                          setState(() {
                            _selectedPoint          = _userLocation;
                            _existingGeofenceCenter = null;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content : Text('🏠 Lokasi rumah diset ke posisi Anda'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      child: const Icon(Icons.home_rounded, color: Colors.white),
                    ),
                    // Tombol kembali ke geofence lama
                    if (_existingGeofenceCenter != null) ...[
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag        : 'prevGeo',
                        backgroundColor: Colors.orange,
                        elevation      : 2,
                        tooltip        : 'Ke area aman sebelumnya',
                        onPressed      : () {
                          _mapController.move(_existingGeofenceCenter!, 17);
                          setState(() => _selectedPoint = _existingGeofenceCenter);
                        },
                        child: const Icon(Icons.history_rounded,
                            color: Colors.white),
                      ),
                    ],
                  ],
                ),
              ),

              // Legend
              Positioned(
                left: 12, bottom: 8,
                child: Container(
                  padding   : const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color       : Colors.white.withOpacity(0.93),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow   : [
                      BoxShadow(
                          color    : Colors.black.withOpacity(0.08),
                          blurRadius: 6),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize      : MainAxisSize.min,
                    children          : [
                      _legendItem(Colors.blue,
                          Icons.person_pin_circle_rounded, 'Posisi Anda (GPS HP)'),
                      const SizedBox(height: 5),
                      _legendItem(AppColors.statusGreen,
                          Icons.home_rounded, 'Rumah Lansia'),
                      const SizedBox(height: 5),
                      _legendItem(AppColors.statusGreen,
                          Icons.radio_button_unchecked_rounded,
                          'Area Aman (${_radius.toInt()} m)'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildBottomPanel(),
      ],
    );
  }

  Widget _legendItem(Color color, IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children    : [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 10, color: AppColors.textDark)),
      ],
    );
  }

  Widget _buildStepGuide() {
    return Container(
      margin  : const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding : const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color       : const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(12),
        border      : Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          _stepBadge(1, _step1Done, 'Pilih\nRumah',
              sublabel: _step1Done ? 'Terpilih ✓' : 'Tap peta'),
          _stepLine(_step1Done),
          _stepBadge(2, _step2Done, 'Atur\nRadius',
              sublabel: _step2Done
                  ? '${_radius.toInt()} m ✓'
                  : 'Geser slider'),
          _stepLine(_step2Done),
          _stepBadge(3, false, 'Simpan',
              sublabel: _step1Done ? 'Siap!' : 'Tunggu...'),
        ],
      ),
    );
  }

  Widget _stepBadge(int num, bool done, String label,
      {String sublabel = ''}) {
    final isActive = (num == 1 && !_step1Done) ||
        (num == 2 && _step1Done && !_step2Done);
    return Expanded(
      child: Column(
        children: [
          AnimatedContainer(
            duration  : const Duration(milliseconds: 300),
            width     : 30, height: 30,
            decoration: BoxDecoration(
              color    : done
                  ? AppColors.statusGreen
                  : isActive
                      ? AppColors.primary
                      : AppColors.primary.withOpacity(0.1),
              shape    : BoxShape.circle,
              boxShadow: done
                  ? [BoxShadow(
                      color    : AppColors.statusGreen.withOpacity(0.3),
                      blurRadius: 6)]
                  : [],
            ),
            child: Center(
              child: done
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : Text('$num',
                      style: TextStyle(
                          fontSize  : 13,
                          fontWeight: FontWeight.bold,
                          color     : isActive
                              ? Colors.white
                              : AppColors.primary)),
            ),
          ),
          const SizedBox(height: 3),
          Text(label,
              textAlign: TextAlign.center,
              style    : TextStyle(
                  fontSize  : 9,
                  fontWeight: FontWeight.w600,
                  color     : done
                      ? AppColors.statusGreen
                      : AppColors.textDark)),
          if (sublabel.isNotEmpty)
            Text(sublabel,
                textAlign: TextAlign.center,
                style    : TextStyle(
                    fontSize: 8,
                    color   : done
                        ? AppColors.statusGreen
                        : AppColors.textGrey)),
        ],
      ),
    );
  }

  Widget _stepLine(bool active) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width   : 24, height: 2,
      color   : active
          ? AppColors.statusGreen
          : AppColors.textGrey.withOpacity(0.3),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      decoration: const BoxDecoration(
        color      : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft : Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
              color    : Colors.black12,
              blurRadius: 12,
              offset   : Offset(0, -4))
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card lokasi terpilih
          AnimatedContainer(
            duration  : const Duration(milliseconds: 300),
            padding   : const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color       : _selectedPoint != null
                  ? AppColors.statusGreen.withOpacity(0.06)
                  : const Color(0xFFF0F4F8),
              borderRadius: BorderRadius.circular(10),
              border      : Border.all(
                color: _selectedPoint != null
                    ? AppColors.statusGreen.withOpacity(0.3)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration  : const Duration(milliseconds: 300),
                  width     : 36, height: 36,
                  decoration: BoxDecoration(
                    color: _selectedPoint != null
                        ? AppColors.statusGreen
                        : AppColors.textGrey.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.home_rounded, size: 20,
                      color: _selectedPoint != null
                          ? Colors.white
                          : AppColors.textGrey),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _selectedPoint != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.check_circle_rounded,
                                    size: 13, color: AppColors.statusGreen),
                                const SizedBox(width: 4),
                                Text(
                                  _existingGeofenceCenter == _selectedPoint
                                      ? 'Lokasi Lama (Tap peta untuk ubah)'
                                      : 'Lokasi Rumah Dipilih',
                                  style: TextStyle(
                                      fontSize  : 12,
                                      fontWeight: FontWeight.bold,
                                      color     : AppColors.statusGreen)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Lat: ${_selectedPoint!.latitude.toStringAsFixed(6)}\n'
                              'Lng: ${_selectedPoint!.longitude.toStringAsFixed(6)}',
                              style: TextStyle(
                                  fontSize: 11, color: AppColors.textGrey),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Belum Ada Lokasi Dipilih',
                                style: TextStyle(
                                    fontSize  : 12,
                                    fontWeight: FontWeight.w600,
                                    color     : AppColors.textGrey)),
                            const SizedBox(height: 2),
                            Text('👆 Tap peta atau tekan tombol 🏠',
                                style: TextStyle(
                                    fontSize: 11, color: AppColors.textGrey)),
                          ],
                        ),
                ),
                if (_selectedPoint != null)
                  GestureDetector(
                    onTap: () => setState(() => _selectedPoint = null),
                    child: Icon(Icons.close_rounded,
                        size: 18, color: AppColors.textGrey),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Slider radius
          Row(
            children: [
              Icon(Icons.radio_button_unchecked_rounded,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Radius Area Aman',
                  style: TextStyle(
                      fontSize  : 13,
                      fontWeight: FontWeight.w600,
                      color     : AppColors.textDark)),
              const Spacer(),
              AnimatedContainer(
                duration  : const Duration(milliseconds: 300),
                padding   : const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color       : _radiusChanged
                      ? AppColors.statusGreen.withOpacity(0.12)
                      : AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border      : _radiusChanged
                      ? Border.all(
                          color: AppColors.statusGreen.withOpacity(0.4))
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_radiusChanged)
                      const Icon(Icons.check_circle_rounded,
                          size: 12, color: AppColors.statusGreen),
                    if (_radiusChanged) const SizedBox(width: 4),
                    Text('${_radius.toInt()} m',
                        style: TextStyle(
                            fontSize  : 13,
                            fontWeight: FontWeight.bold,
                            color     : _radiusChanged
                                ? AppColors.statusGreen
                                : AppColors.primary)),
                  ],
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _radiusChanged
                  ? 'Area aman ${_radius.toInt()} meter dari titik rumah ✓'
                  : 'Geser slider untuk mengatur luas area aman',
              style: TextStyle(
                  fontSize: 10,
                  color   : _radiusChanged
                      ? AppColors.statusGreen
                      : AppColors.primary),
            ),
          ),

          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor  : _radiusChanged
                  ? AppColors.statusGreen
                  : AppColors.primary,
              inactiveTrackColor: (_radiusChanged
                      ? AppColors.statusGreen
                      : AppColors.primary)
                  .withOpacity(0.2),
              thumbColor        : _radiusChanged
                  ? AppColors.statusGreen
                  : AppColors.primary,
              overlayColor      : (_radiusChanged
                      ? AppColors.statusGreen
                      : AppColors.primary)
                  .withOpacity(0.1),
              trackHeight       : 4,
            ),
            child: Slider(
              value    : _radius,
              min      : _minRadius,
              max      : _maxRadius,
              divisions: 47,
              label    : '${_radius.toInt()} m',
              onChanged: (v) => setState(() {
                _radius        = (v / 10).roundToDouble() * 10;
                _radiusChanged = true;
              }),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_minRadius.toInt()} m',
                  style: TextStyle(fontSize: 10, color: AppColors.textGrey)),
              Text('${_maxRadius.toInt()} m',
                  style: TextStyle(fontSize: 10, color: AppColors.textGrey)),
            ],
          ),

          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_selectedPoint == null || _saving)
                  ? null
                  : _saveGeofence,
              icon : _saving
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_rounded, size: 20),
              label: Text(_saving
                  ? 'Menyimpan...'
                  : _selectedPoint == null
                      ? 'Pilih lokasi rumah dulu di peta'
                      : 'Simpan Lokasi & Area Aman'),
              style: ElevatedButton.styleFrom(
                backgroundColor        : _selectedPoint != null
                    ? AppColors.statusGreen
                    : Colors.grey.shade300,
                foregroundColor        : Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                padding   : const EdgeInsets.symmetric(vertical: 14),
                shape     : RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle : const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── STEP 3: Tersimpan ─────────────────────────────────────────────────────
  Widget _buildSavedPage() {
    return Center(
      key: const ValueKey('saved'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween   : Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              curve   : Curves.elasticOut,
              builder : (_, v, child) =>
                  Transform.scale(scale: v, child: child),
              child: Container(
                width : 100, height: 100,
                decoration: BoxDecoration(
                  color: AppColors.statusGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_rounded,
                    size: 56, color: AppColors.statusGreen),
              ),
            ),
            const SizedBox(height: 24),
            Text('Area Aman Tersimpan!',
                style: TextStyle(
                    fontSize  : 22,
                    fontWeight: FontWeight.bold,
                    color     : AppColors.textDark)),
            const SizedBox(height: 10),
            Text(
              'Lokasi rumah & area aman berhasil disimpan.\nMonitoring geofence kini aktif.',
              textAlign: TextAlign.center,
              style    : TextStyle(
                  fontSize: 14, color: AppColors.textGrey, height: 1.6),
            ),
            const SizedBox(height: 16),
            if (_selectedPoint != null)
              Container(
                padding   : const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color       : AppColors.statusGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border      : Border.all(
                      color: AppColors.statusGreen.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    _infoRow(Icons.location_on_rounded, 'Latitude',
                        _selectedPoint!.latitude.toStringAsFixed(6)),
                    const SizedBox(height: 6),
                    _infoRow(Icons.location_on_rounded, 'Longitude',
                        _selectedPoint!.longitude.toStringAsFixed(6)),
                    const SizedBox(height: 6),
                    _infoRow(Icons.radio_button_unchecked_rounded,
                        'Radius', '${_radius.toInt()} meter'),
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
                  padding   : const EdgeInsets.symmetric(vertical: 14),
                  shape     : RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle : const TextStyle(
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

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.statusGreen),
        const SizedBox(width: 8),
        Text('$label  ',
            style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  fontSize  : 12,
                  fontWeight: FontWeight.w600,
                  color     : AppColors.textDark)),
        ),
      ],
    );
  }
}

enum _Step { permission, map, saved }

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path  = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(_) => false;
}