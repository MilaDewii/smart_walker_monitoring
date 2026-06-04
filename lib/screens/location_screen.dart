import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../database/database_helper.dart';
import '../services/location_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_routes.dart';
import '../models/location_data.dart'; 

// ─────────────────────────────────────────────
// COLORS
// ─────────────────────────────────────────────
class _C {
  static const primary    = AppColors.primary;
  static const secondary  = AppColors.secondary;
  static const bgPage     = Color(0xFFE8F0FB);
  static const textDark   = AppColors.textDark;
  static const textMid    = AppColors.textGrey;
  static const amanText   = AppColors.statusGreen;
  static const amanBg     = Color(0xFFDCFCE7);
  static const bahayaText = AppColors.statusRed;
  static const bahayaBg   = Color(0xFFFEE2E2);
}

// ─────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────
class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen>
    with TickerProviderStateMixin {

  // ── Map ───────────────────────────────────
  final MapController _mapController = MapController();

  // ── Data dari RTD via service ─────────────
  String?       _walkerId;
  LocationData  _locationData = LocationData.empty();
  StreamSubscription<LocationData>? _locationSub;

  // ── Path history ──────────────────────────
  final List<LatLng> _pathHistory = [];
  static const int   _maxPath     = 50;

  // ── Layer toggle ──────────────────────────
  bool _showPath     = true;
  bool _showGeofence = true;

  // ── Pulse animation ───────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  // ═══════════════════════════════════════════
  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync  : this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _init();
  }

  Future<void> _init() async {
    final pairedWalkers = await DatabaseHelper.instance.getPairedWalkers();
    if (!mounted) return;

    final walkerId = pairedWalkers.isNotEmpty
        ? pairedWalkers.first['walker_id']?.toString()
        : null;

    setState(() => _walkerId = walkerId);
    if (walkerId == null || walkerId.isEmpty) return;

    _locationSub = LocationService.instance
        .watchLocation(walkerId)
        .listen((data) {
      if (!mounted) return;
      setState(() {
        _locationData = data;

        // Tambah ke path history
        _pathHistory.add(data.lansiaPos);
        if (_pathHistory.length > _maxPath) _pathHistory.removeAt(0);
      });

      // Auto-center saat pertama kali data masuk
      if (_pathHistory.length == 1) {
        _mapController.move(data.lansiaPos, 16);
      }
    });
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Shortcut getter ───────────────────────
  LatLng get _lansiaPos       => _locationData.lansiaPos;
  LatLng get _geofenceCenter  => _locationData.geofenceCenter;
  double get _geofenceRadius  => _locationData.geofenceRadius;
  bool   get _isInSafeZone    => _locationData.isInSafeZone;
  bool   get _isConnected     => _locationData.connected;
  String get _lastUpdate      => _locationData.lastUpdate;

  // ── Format waktu singkat ──────────────────
  String get _timeStr {
    // Coba parse dari string RTD "2026-06-02 21:30:00"
    try {
      final dt = DateTime.parse(_lastUpdate.replaceAll(' ', 'T'));
      final h  = dt.hour.toString().padLeft(2, '0');
      final m  = dt.minute.toString().padLeft(2, '0');
      return '$h.$m WIB';
    } catch (_) {
      return _lastUpdate;
    }
  }

  String get _updateStr {
    try {
      final dt = DateTime.parse(_lastUpdate.replaceAll(' ', 'T'));
      final h  = dt.hour.toString().padLeft(2, '0');
      final m  = dt.minute.toString().padLeft(2, '0');
      return 'Update Terakhir : $h:$m';
    } catch (_) {
      return 'Update: $_lastUpdate';
    }
  }

  void _centerToLansia() => _mapController.move(_lansiaPos, 16);

  // ═══════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bgPage,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: Stack(
                children: [
                  _buildMap(),
                  _buildLegendCard(),
                  _buildMapControls(),
                  _buildBottomInfo(),
                  // Loading overlay jika belum ada walker
                  if (_walkerId == null) _buildNoWalkerOverlay(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top Bar ───────────────────────────────
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: _C.bgPage,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pushReplacementNamed(
                context, AppRoutes.monitoring),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: _C.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.chevron_left,
                  color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Lokasi Lansia',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _C.textDark)),
                Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: 7, height: 7,
                      margin: const EdgeInsets.only(right: 5),
                      decoration: BoxDecoration(
                        color: _isConnected ? _C.amanText : _C.bahayaText,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text(
                      'Live Tracking',
                      style: TextStyle(
                          fontSize: 11,
                          color: _isConnected ? _C.amanText : _C.bahayaText,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Status koneksi + update
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _isConnected ? _C.amanBg : _C.bahayaBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6, height: 6,
                      margin: const EdgeInsets.only(right: 5),
                      decoration: BoxDecoration(
                        color: _isConnected ? _C.amanText : _C.bahayaText,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text(
                      _isConnected ? 'Terhubung' : 'Terputus',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _isConnected
                              ? _C.amanText
                              : _C.bahayaText),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              Text(_updateStr,
                  style: const TextStyle(
                      fontSize: 9, color: _C.textMid)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Map ───────────────────────────────────
  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _geofenceCenter,
        initialZoom  : 16,
        minZoom      : 10,
        maxZoom      : 18,
      ),
      children: [
        TileLayer(
          urlTemplate         : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.guardianwalk.app',
        ),

        // Geofence circle — radius dari RTD
        if (_showGeofence)
          CircleLayer(circles: [
            CircleMarker(
              point            : _geofenceCenter,
              radius           : _geofenceRadius,
              color            : _C.amanText.withOpacity(0.12),
              borderColor      : _C.amanText.withOpacity(0.6),
              borderStrokeWidth: 2,
              useRadiusInMeter : true,
            ),
          ]),

        // Path history polyline
        if (_showPath && _pathHistory.length > 1)
          PolylineLayer(polylines: [
            Polyline(
              points     : _pathHistory,
              color      : _C.secondary.withOpacity(0.6),
              strokeWidth: 3,
              isDotted   : true,
            ),
          ]),

        // Marker pusat geofence (rumah)
        MarkerLayer(markers: [
          Marker(
            point : _geofenceCenter,
            width : 36, height: 36,
            child : Container(
              decoration: BoxDecoration(
                color : _C.amanText,
                shape : BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color    : _C.amanText.withOpacity(0.4),
                    blurRadius: 8,
                  )
                ],
              ),
              child: const Icon(Icons.home_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
        ]),

        // Marker lansia — posisi dari RTD
        MarkerLayer(markers: [
          Marker(
            point : _lansiaPos,
            width : 54, height: 54,
            child : AnimatedBuilder(
              animation: _pulseAnim,
              builder  : (_, __) => Stack(
                alignment: Alignment.center,
                children: [
                  Transform.scale(
                    scale: _pulseAnim.value,
                    child: Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isInSafeZone
                            ? _C.primary.withOpacity(0.18)
                            : _C.bahayaText.withOpacity(0.18),
                      ),
                    ),
                  ),
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color : _isInSafeZone ? _C.primary : _C.bahayaText,
                      shape : BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: (_isInSafeZone
                                  ? _C.primary
                                  : _C.bahayaText)
                              .withOpacity(0.4),
                          blurRadius: 8,
                        )
                      ],
                    ),
                    child: const Icon(Icons.person_pin_rounded,
                        color: Colors.white, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ]),
      ],
    );
  }

  // ── Legend Card ───────────────────────────
  Widget _buildLegendCard() {
    return Positioned(
      top: 12, left: 12,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.08),
                blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _legendItem(
              color: _C.primary,
              icon : Icons.person_pin_rounded,
              label: 'Posisi Lansia',
              sub  : 'Lokasi saat ini',
            ),
            const SizedBox(height: 8),
            _legendItem(
              color: _C.amanText,
              icon : Icons.home_rounded,
              label: 'Area Aman (Geofence)',
              sub  : 'Radius ${_geofenceRadius.toInt()} m',
            ),
            const SizedBox(height: 8),
            _legendItem(
              color: _C.bahayaText,
              icon : Icons.location_off_rounded,
              label: 'Area Tidak Aman',
              sub  : 'Di luar zona aman',
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem({
    required Color    color,
    required IconData icon,
    required String   label,
    required String   sub,
  }) {
    return Row(
      children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
              color: color.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _C.textDark)),
            Text(sub,
                style: const TextStyle(fontSize: 9, color: _C.textMid)),
          ],
        ),
      ],
    );
  }

  // ── Map Controls ──────────────────────────
  Widget _buildMapControls() {
    return Positioned(
      right: 12, bottom: 110,
      child: Column(
        children: [
          _mapBtn(
            icon   : Icons.my_location_rounded,
            onTap  : _centerToLansia,
            color  : _C.primary,
            tooltip: 'Ke posisi lansia',
          ),
          const SizedBox(height: 8),
          _mapBtn(
            icon   : Icons.add,
            onTap  : () => _mapController.move(
                _mapController.camera.center,
                _mapController.camera.zoom + 1),
            tooltip: 'Zoom in',
          ),
          const SizedBox(height: 4),
          _mapBtn(
            icon   : Icons.remove,
            onTap  : () => _mapController.move(
                _mapController.camera.center,
                _mapController.camera.zoom - 1),
            tooltip: 'Zoom out',
          ),
          const SizedBox(height: 8),
          _mapBtn(
            icon   : _showGeofence
                ? Icons.layers_rounded
                : Icons.layers_clear_rounded,
            onTap  : () => setState(() => _showGeofence = !_showGeofence),
            color  : _showGeofence ? _C.amanText : _C.textMid,
            tooltip: 'Toggle geofence',
          ),
          const SizedBox(height: 4),
          _mapBtn(
            icon   : _showPath
                ? Icons.timeline_rounded
                : Icons.remove_road_rounded,
            onTap  : () => setState(() => _showPath = !_showPath),
            color  : _showPath ? _C.secondary : _C.textMid,
            tooltip: 'Toggle path',
          ),
        ],
      ),
    );
  }

  Widget _mapBtn({
    required IconData      icon,
    required VoidCallback  onTap,
    Color?                 color,
    String?                tooltip,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip ?? '',
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1),
                  blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Icon(icon, size: 20, color: color ?? _C.textDark),
        ),
      ),
    );
  }

  // ── Bottom Info ───────────────────────────
  Widget _buildBottomInfo() {
    return Positioned(
      left: 12, right: 12, bottom: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.96),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.08),
                blurRadius: 12, offset: const Offset(0, -2)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Koordinat realtime dari RTD
            Row(
              children: [
                Icon(Icons.location_on_rounded,
                    size: 15,
                    color: _isInSafeZone ? _C.primary : _C.bahayaText),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Lat : ${_lansiaPos.latitude.toStringAsFixed(6)}'
                    '   Lng : ${_lansiaPos.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _C.textDark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.access_time_rounded,
                    size: 15, color: _C.textMid),
                const SizedBox(width: 6),
                Text(_timeStr,
                    style: const TextStyle(
                        fontSize: 11, color: _C.textMid)),
                const Spacer(),
                // Status geofence dari RTD
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isInSafeZone ? _C.amanBg : _C.bahayaBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isInSafeZone
                            ? Icons.shield_rounded
                            : Icons.warning_rounded,
                        size: 12,
                        color: _isInSafeZone
                            ? _C.amanText
                            : _C.bahayaText,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isInSafeZone
                            ? 'Dalam Area Aman'
                            : 'Di Luar Area Aman',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _isInSafeZone
                              ? _C.amanText
                              : _C.bahayaText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── No Walker Overlay ─────────────────────
  Widget _buildNoWalkerOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.4),
      child: Center(
        child: Container(
          margin : const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color        : Colors.white,
            borderRadius : BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.link_off_rounded,
                  size: 48, color: _C.bahayaText),
              const SizedBox(height: 12),
              const Text('Walker Belum Terhubung',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _C.textDark)),
              const SizedBox(height: 8),
              const Text(
                'Scan QR walker terlebih dahulu\nuntuk melihat lokasi.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: _C.textMid),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => Navigator.pushReplacementNamed(
                    context, AppRoutes.qrConnect),
                icon : const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Scan QR'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _C.primary,
                    foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}