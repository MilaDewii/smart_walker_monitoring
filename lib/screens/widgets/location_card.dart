import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/walker_data.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_routes.dart';

class LocationCard extends StatefulWidget {
  final WalkerData walkerData;
  final String? walkerId;
  final BuildContext parentContext;

  const LocationCard({
    super.key,
    required this.walkerData,
    required this.walkerId,
    required this.parentContext,
  });

  @override
  State<LocationCard> createState() => _LocationCardState();
}

class _LocationCardState extends State<LocationCard> {
  final MapController _mapController = MapController();
  bool _mapReady = false;

  bool get _hasGeofence =>
      widget.walkerData.geofenceCenter.latitude != 0.0 ||
      widget.walkerData.geofenceCenter.longitude != 0.0;

  LatLng get _centerTarget {
    // Prioritas: posisi lansia → geofence center → default
    final pos = widget.walkerData.position;
    if (pos.latitude != 0.0 || pos.longitude != 0.0) return pos;
    return widget.walkerData.geofenceCenter;
  }

  // ── Level gabungan: aman / waspada / darurat ──────────────────────────────
  // Disamakan dengan logika _visualLevel di monitoring_screen.dart supaya
  // warna pin lansia di mini-map ini konsisten dengan layar monitoring.
  String get _visualLevel {
    final w = widget.walkerData;
    if (w.jatuh || w.geofenceStatus == 'outside' || !w.ultrasonicBack) {
      return 'darurat';
    }
    if (w.status == 'waspada' || w.mendekatiGeofence || w.ultrasonicFront) {
      return 'waspada';
    }
    return 'aman';
  }

  Color get _statusColor {
    switch (_visualLevel) {
      case 'darurat':
        return AppColors.statusRed;
      case 'waspada':
        return AppColors.statusYellow;
      default:
        return AppColors.statusGreen;
    }
  }

  // ── Badge geofence — 3 level: inside / mendekati / outside ──────────────
  Color get _geofenceBadgeColor {
    if (widget.walkerData.geofenceStatus == 'outside') {
      return AppColors.statusRed;
    }
    if (widget.walkerData.mendekatiGeofence) {
      return AppColors.statusYellow;
    }
    return AppColors.statusGreen;
  }

  String get _geofenceBadgeLabel {
    if (widget.walkerData.geofenceStatus == 'outside') {
      return 'Di Luar Area!';
    }
    if (widget.walkerData.mendekatiGeofence) {
      return 'Mendekati Batas';
    }
    return 'Area Aman';
  }

  @override
  void didUpdateWidget(LocationCard old) {
    super.didUpdateWidget(old);

    // Reset _mapReady kalau geofence baru saja hilang -- FlutterMap otomatis
    // dilepas dari tree oleh _buildEmptyState(), controller-nya jadi
    // disposed. Tanpa reset ini, didUpdateWidget berikutnya masih mengira
    // map aktif dan manggil _mapController.move() ke controller yang sudah
    // mati -> "FlutterMapInternalController was used after being disposed".
    if (!_hasGeofence) {
      _mapReady = false;
      return;
    }

    // Auto-center peta saat posisi lansia berubah
    if (_mapReady &&
        mounted &&
        widget.walkerData.position != old.walkerData.position) {
      final pos = widget.walkerData.position;
      if (pos.latitude != 0.0 || pos.longitude != 0.0) {
        try {
          _mapController.move(pos, 15);
        } catch (e) {
          debugPrint('[MAP] skip move, controller disposed: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: _hasGeofence ? _buildMapCard(context) : _buildEmptyState(context),
    );
  }

  // ── Empty State ───────────────────────────────────────────────────────────
  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Lokasi Lansia',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            width: 90,
            height: 90,
            decoration: const BoxDecoration(
              color: Color(0xFFF0F4F8),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.home_outlined,
              size: 44,
              color: AppColors.textGrey.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Belum Ada Area Aman',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tentukan lokasi rumah untuk memulai monitoring '
            'dan fitur geofence.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textGrey,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(
                context,
                AppRoutes.geofenceSetup,
                arguments: {'fromDashboard': true},
              ),
              icon: const Icon(Icons.add_location_alt_rounded, size: 18),
              label: const Text('Atur Lokasi Rumah'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Map Card ──────────────────────────────────────────────────────────────
  Widget _buildMapCard(BuildContext context) {
    final posisi = widget.walkerData.position;
    final geofenceCenter = widget.walkerData.geofenceCenter;
    final geofenceRadius = widget.walkerData.geofenceRadius;
    final hasLansiaPos = posisi.latitude != 0.0 || posisi.longitude != 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
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
                  color: _geofenceBadgeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _geofenceBadgeColor,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _geofenceBadgeLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: _geofenceBadgeColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Peta — auto-center ke posisi lansia/geofence
        ClipRRect(
          child: SizedBox(
            height: 180,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                // initialCenter ke posisi yang benar sejak awal
                initialCenter: _centerTarget,
                initialZoom: 15,
                onMapReady: () {
                  if (!mounted) return;
                  setState(() => _mapReady = true);
                  // Pastikan center sudah benar saat map siap
                  final target = _centerTarget;
                  if (target.latitude != 0.0 || target.longitude != 0.0) {
                    try {
                      _mapController.move(target, 15);
                    } catch (e) {
                      debugPrint(
                          '[MAP] skip initial move, controller disposed: $e');
                    }
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.guardianwalk.app',
                ),
                // Geofence lingkaran
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: geofenceCenter,
                      radius: geofenceRadius,
                      color: _geofenceBadgeColor.withOpacity(0.12),
                      borderColor: _geofenceBadgeColor,
                      borderStrokeWidth: 2,
                      useRadiusInMeter: true,
                    ),
                  ],
                ),
                // Marker rumah
                MarkerLayer(
                  markers: [
                    Marker(
                      point: geofenceCenter,
                      width: 32,
                      height: 32,
                      child: Icon(
                        Icons.home_rounded,
                        color: _geofenceBadgeColor,
                        size: 28,
                      ),
                    ),
                  ],
                ),
                // Marker lansia (hanya kalau GPS sudah ada)
                if (hasLansiaPos)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: posisi,
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

        // Koordinat
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  hasLansiaPos
                      ? 'Lat: ${posisi.latitude.toStringAsFixed(5)}'
                          '   Lng: ${posisi.longitude.toStringAsFixed(5)}'
                      : 'GPS Lansia belum tersedia',
                  style: TextStyle(fontSize: 11, color: AppColors.textGrey),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (widget.walkerId != null
                          ? AppColors.statusGreen
                          : AppColors.statusRed)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  widget.walkerId != null ? 'Terhubung' : 'Tidak Terhubung',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: widget.walkerId != null
                        ? AppColors.statusGreen
                        : AppColors.statusRed,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Last update
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                size: 12,
                color: AppColors.textGrey,
              ),
              const SizedBox(width: 4),
              Text(
                'Update: ${widget.walkerData.lastUpdate}',
                style: TextStyle(fontSize: 10, color: AppColors.textGrey),
              ),
            ],
          ),
        ),

        // Tombol
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    AppRoutes.geofenceSetup,
                    arguments: {'fromDashboard': true},
                  ),
                  icon: const Icon(Icons.edit_location_alt_rounded, size: 16),
                  label: const Text('Ubah'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pushReplacementNamed(
                    context,
                    AppRoutes.location,
                  ),
                  icon: const Icon(Icons.map_rounded, size: 16),
                  label: const Text('Lihat Lokasi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}