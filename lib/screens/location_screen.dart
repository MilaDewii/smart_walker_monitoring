import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../utils/app_colors.dart';
import '../utils/app_routes.dart';

// ============================================================
// COLORS
// ============================================================
class _C {
  static const Color primary = AppColors.primary;
  static const Color secondary = AppColors.secondary;
  static const Color bgPage = Color(0xFFE8F0FB);
  // static const Color white = AppColors.white;
  static const Color textDark = AppColors.textDark;
  static const Color textMid = AppColors.textGrey;
  static const Color amanText = AppColors.statusGreen;
  static const Color amanBg = Color(0xFFDCFCE7);
  static const Color bahayaText = AppColors.statusRed;
  static const Color bahayaBg = Color(0xFFFEE2E2);
}

// ============================================================
// LOCATION SCREEN
// ============================================================
class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen>
    with TickerProviderStateMixin {
  // ── Map controller
  final MapController _mapController = MapController();

  // ── State
  bool _isConnected = true;
  bool _isInSafeZone = true;

  // ── Koordinat (simulasi lansia)
  LatLng _lansiaPos = const LatLng(-6.98212, 110.41850);
  bool _initialArgsApplied = false;

  // ── Pusat geofence & radius
  final LatLng _geofenceCenter = const LatLng(-6.98212, 110.41800);
  final double _geofenceRadius = 300; // meter

  // ── Waktu update
  DateTime _lastUpdate = DateTime.now();

  // ── Timer simulasi pergerakan
  Timer? _moveTimer;

  // ── Animation controller untuk marker pulse
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // ── Riwayat path
  final List<LatLng> _pathHistory = [];

  // ── Layer visibility
  bool _showPath = true;
  bool _showGeofence = true;

  @override
  void initState() {
    super.initState();

    _pathHistory.add(_lansiaPos);

    // Pulse animation untuk marker lansia
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.15)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Simulasi pergerakan setiap 3 detik
    _moveTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _simulateMove();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialArgsApplied) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is LatLng) {
        _lansiaPos = args;
        _pathHistory.clear();
        _pathHistory.add(_lansiaPos);
      }
      _initialArgsApplied = true;
    }
  }

  @override
  void dispose() {
    _moveTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Simulasi pergerakan kecil ─────────────────────────────
  void _simulateMove() {
    // Gerak random kecil
    final offsetLat = (DateTime.now().millisecond % 5 - 2) * 0.00005;
    final offsetLng = (DateTime.now().millisecond % 7 - 3) * 0.00005;

    final newPos = LatLng(
      _lansiaPos.latitude + offsetLat,
      _lansiaPos.longitude + offsetLng,
    );

    // Cek apakah masih dalam geofence
    final dist = const Distance().as(LengthUnit.Meter, newPos, _geofenceCenter);
    final inSafe = dist <= _geofenceRadius;

    setState(() {
      _lansiaPos = newPos;
      _lastUpdate = DateTime.now();
      _isInSafeZone = inSafe;
      _pathHistory.add(newPos);
      // Batasi history 30 titik
      if (_pathHistory.length > 30) _pathHistory.removeAt(0);
    });
  }

  // ── Center map ke posisi lansia ───────────────────────────
  void _centerToLansia() {
    _mapController.move(_lansiaPos, 15);
  }

  // ── Format waktu ─────────────────────────────────────────
  String get _timeStr {
    final h = _lastUpdate.hour.toString().padLeft(2, '0');
    final m = _lastUpdate.minute.toString().padLeft(2, '0');
    return '$h.$m WIB';
  }

  String get _updateStr {
    final h = _lastUpdate.hour.toString().padLeft(2, '0');
    final m = _lastUpdate.minute.toString().padLeft(2, '0');
    return 'Update Terakhir : $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bgPage,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: Stack(
                children: [
                  _buildMap(),
                  _buildLegendCard(),
                  _buildMapControls(),
                  _buildBottomInfo(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top Bar ──────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: _C.bgPage,
      child: Row(
        children: [
          GestureDetector(
            onTap: () =>
                Navigator.pushReplacementNamed(context, AppRoutes.monitoring),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _C.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  const Icon(Icons.chevron_left, color: Colors.white, size: 22),
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
                    Container(
                      width: 7,
                      height: 7,
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
          // Status + update
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _isConnected ? _C.amanBg : _C.bahayaBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
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
                          color: _isConnected ? _C.amanText : _C.bahayaText),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              Text(_updateStr,
                  style: const TextStyle(fontSize: 9, color: _C.textMid)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Map ──────────────────────────────────────────────────
  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _geofenceCenter,
        initialZoom: 15,
        minZoom: 10,
        maxZoom: 18,
      ),
      children: [
        // Tile layer
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.guardianwalk.app',
        ),

        // Geofence circle
        if (_showGeofence)
          CircleLayer(
            circles: [
              CircleMarker(
                point: _geofenceCenter,
                radius: _geofenceRadius,
                color: _C.amanText.withOpacity(0.12),
                borderColor: _C.amanText.withOpacity(0.6),
                borderStrokeWidth: 2,
                useRadiusInMeter: true,
              ),
            ],
          ),

        // Path history polyline
        if (_showPath && _pathHistory.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _pathHistory,
                color: _C.secondary.withOpacity(0.6),
                strokeWidth: 3,
                isDotted: true,
              ),
            ],
          ),

        // Geofence center marker (rumah)
        MarkerLayer(
          markers: [
            Marker(
              point: _geofenceCenter,
              width: 36,
              height: 36,
              child: Container(
                decoration: BoxDecoration(
                  color: _C.amanText,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: _C.amanText.withOpacity(0.4),
                      blurRadius: 8,
                    )
                  ],
                ),
                child: const Icon(Icons.home_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
          ],
        ),

        // Lansia marker (pulse)
        MarkerLayer(
          markers: [
            Marker(
              point: _lansiaPos,
              width: 54,
              height: 54,
              child: AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Pulse ring
                      Transform.scale(
                        scale: _pulseAnim.value,
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isInSafeZone
                                ? _C.primary.withOpacity(0.18)
                                : _C.bahayaText.withOpacity(0.18),
                          ),
                        ),
                      ),
                      // Inner marker
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _isInSafeZone ? _C.primary : _C.bahayaText,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (_isInSafeZone ? _C.primary : _C.bahayaText)
                                      .withOpacity(0.4),
                              blurRadius: 8,
                            )
                          ],
                        ),
                        child: const Icon(Icons.person_pin_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Legend Card (kiri atas) ──────────────────────────────
  Widget _buildLegendCard() {
    return Positioned(
      top: 12,
      left: 12,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLegendItem(
              color: _C.primary,
              icon: Icons.person_pin_rounded,
              label: 'Posisi Lansia',
              sub: 'Lokasi saat ini',
            ),
            const SizedBox(height: 8),
            _buildLegendItem(
              color: _C.amanText,
              icon: Icons.home_rounded,
              label: 'Area Aman (Geovence)',
              sub: 'Radius ${_geofenceRadius.toInt()} meter',
            ),
            const SizedBox(height: 8),
            _buildLegendItem(
              color: _C.bahayaText,
              icon: Icons.location_off_rounded,
              label: 'Area Tidak Aman',
              sub: 'Di luar zona aman',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required IconData icon,
    required String label,
    required String sub,
  }) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
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
            Text(sub, style: const TextStyle(fontSize: 9, color: _C.textMid)),
          ],
        ),
      ],
    );
  }

  // ── Map Controls (kanan) ─────────────────────────────────
  Widget _buildMapControls() {
    return Positioned(
      right: 12,
      bottom: 110,
      child: Column(
        children: [
          // Center to lansia
          _buildMapBtn(
            icon: Icons.my_location_rounded,
            tooltip: 'Ke posisi lansia',
            onTap: _centerToLansia,
            color: _C.primary,
          ),
          const SizedBox(height: 8),
          // Zoom in
          _buildMapBtn(
            icon: Icons.add,
            tooltip: 'Zoom in',
            onTap: () {
              _mapController.move(
                  _mapController.camera.center, _mapController.camera.zoom + 1);
            },
          ),
          const SizedBox(height: 4),
          // Zoom out
          _buildMapBtn(
            icon: Icons.remove,
            tooltip: 'Zoom out',
            onTap: () {
              _mapController.move(
                  _mapController.camera.center, _mapController.camera.zoom - 1);
            },
          ),
          const SizedBox(height: 8),
          // Toggle geofence
          _buildMapBtn(
            icon: _showGeofence
                ? Icons.layers_rounded
                : Icons.layers_clear_rounded,
            tooltip: 'Toggle geofence',
            onTap: () => setState(() => _showGeofence = !_showGeofence),
            color: _showGeofence ? _C.amanText : _C.textMid,
          ),
        ],
      ),
    );
  }

  Widget _buildMapBtn({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip ?? '',
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Icon(icon, size: 20, color: color ?? _C.textDark),
        ),
      ),
    );
  }

  // ── Bottom Info ──────────────────────────────────────────
  Widget _buildBottomInfo() {
    return Positioned(
      left: 12,
      right: 12,
      bottom: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.96),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, -2),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Koordinat
            Row(
              children: [
                Icon(Icons.location_on_rounded,
                    size: 15,
                    color: _isInSafeZone ? _C.primary : _C.bahayaText),
                const SizedBox(width: 6),
                Text(
                  'Lat : ${_lansiaPos.latitude.toStringAsFixed(5)}'
                  '    Long : ${_lansiaPos.longitude.toStringAsFixed(5)}',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _C.textDark),
                ),
              ],
            ),
            const SizedBox(height: 5),
            // Waktu + status zone
            Row(
              children: [
                const Icon(Icons.access_time_rounded,
                    size: 15, color: _C.textMid),
                const SizedBox(width: 6),
                Text(_timeStr,
                    style: const TextStyle(fontSize: 11, color: _C.textMid)),
                const Spacer(),
                // Status zona
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isInSafeZone ? _C.amanBg : _C.bahayaBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isInSafeZone
                            ? Icons.shield_rounded
                            : Icons.warning_rounded,
                        size: 12,
                        color: _isInSafeZone ? _C.amanText : _C.bahayaText,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isInSafeZone ? 'Dalam Area Aman' : 'Di Luar Area Aman',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _isInSafeZone ? _C.amanText : _C.bahayaText,
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
}
