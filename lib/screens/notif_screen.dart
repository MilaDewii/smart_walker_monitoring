import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart';
import '../utils/app_colors.dart';

// ============================================================
// MODEL
// ============================================================
enum AlertLevel { tinggi, darurat, waspada }

class AlertItem {
  final String id;
  final String title;
  final AlertLevel level;
  final String time;
  final String date;
  final String description;
  final double score;
  final int durasiDetik;
  bool sudahDibaca;
  final IconData icon;
  final LatLng location;

  AlertItem({
    required this.id,
    required this.title,
    required this.level,
    required this.time,
    required this.date,
    required this.description,
    required this.score,
    required this.durasiDetik,
    required this.sudahDibaca,
    required this.icon,
    required this.location,
  });
}

// ============================================================
// COLORS — semua bersumber dari AppColors
// ============================================================
class _C {
  static const Color primary      = AppColors.primary;    // #1E3A8A biru tua
  static const Color secondary    = AppColors.secondary;  // #3B82F6 biru muda
  static const Color primaryLight = Color(0xFFDBEAFE);
  static const Color bgPage       = Color(0xFFE8F0FB);    // latar biru sangat muda
  static const Color white        = AppColors.white;
  static const Color textDark     = AppColors.textDark;
  static const Color textMid      = AppColors.textGrey;

  static const Color tinggiText  = AppColors.statusRed;
  static const Color tinggiBg    = Color(0xFFFEE2E2);
  static const Color daruratText = AppColors.statusYellow;
  static const Color daruratBg   = Color(0xFFFFF3CD);
  static const Color waspadaText = AppColors.statusGreen;
  static const Color waspadaBg   = Color(0xFFDCFCE7);
  static const Color unreadDot   = AppColors.statusRed;
}

// ============================================================
// NOTIFICATION SCREEN (List)
// ============================================================
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  String _selectedFilter = 'Semua';
  final List<String> _filters = ['Semua', 'Darurat', 'Waspada'];

  final List<AlertItem> _alerts = [
    AlertItem(
      id: '1',
      title: 'Anomali Terdeteksi',
      level: AlertLevel.tinggi,
      time: '11.00 WIB',
      date: '08 April 2025',
      description: 'Pola gerakan tidak biasa terdeteksi oleh sistem',
      score: 0.82,
      durasiDetik: 23,
      sudahDibaca: false,
      icon: Icons.warning_amber_rounded,
      location: const LatLng(-8.4755, 115.2120),
    ),
    AlertItem(
      id: '2',
      title: 'Potensi Jatuh',
      level: AlertLevel.darurat,
      time: '10.24 WIB',
      date: '08 April 2025',
      description: 'Gerakan jatuh terdeteksi oleh sistem !',
      score: 0.95,
      durasiDetik: 12,
      sudahDibaca: true,
      icon: Icons.accessibility_new_rounded,
      location: const LatLng(-8.4760, 115.2130),
    ),
    AlertItem(
      id: '3',
      title: 'Gerakan Tidak Biasa',
      level: AlertLevel.waspada,
      time: '08.37 WIB',
      date: '08 April 2025',
      description: 'Perubahan pola aktivitas',
      score: 0.61,
      durasiDetik: 28,
      sudahDibaca: true,
      icon: Icons.directions_walk_rounded,
      location: const LatLng(-8.4750, 115.2110),
    ),
  ];

  List<AlertItem> get _filteredAlerts {
    if (_selectedFilter == 'Semua') return _alerts;
    if (_selectedFilter == 'Darurat') {
      return _alerts.where((a) => a.level == AlertLevel.darurat).toList();
    }
    if (_selectedFilter == 'Waspada') {
      return _alerts.where((a) => a.level == AlertLevel.waspada).toList();
    }
    return _alerts;
  }

  int get _totalToday => _alerts.length;
  int get _daruratToday =>
      _alerts.where((a) => a.level == AlertLevel.darurat).length;
  int get _sudahDibacaToday => _alerts.where((a) => a.sudahDibaca).length;

  void _markAllRead() {
    setState(() {
      for (final a in _alerts) {
        a.sudahDibaca = true;
      }
    });
  }

  void _openDetail(AlertItem item) {
    setState(() => item.sudahDibaca = true);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationDetailScreen(item: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bgPage,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    _buildNotificationCard(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: _C.bgPage,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: _C.primary.withOpacity(0.15),
                child: const Icon(Icons.person_rounded,
                    color: _C.primary, size: 26),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Haillo, Mila',
                      style: TextStyle(fontSize: 12, color: _C.textMid)),
                  Text('Monitoring Lansia',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _C.textDark)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: _C.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                SizedBox(width: 12),
                Icon(Icons.search, color: _C.textMid, size: 20),
                SizedBox(width: 8),
                Text('Search ...',
                    style: TextStyle(color: _C.textMid, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard() {
    return Container(
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(),
          _buildSummaryRow(),
          const SizedBox(height: 12),
          _buildFilterRow(),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          _buildListHeader(),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          if (_filteredAlerts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('Tidak ada peringatan',
                    style: TextStyle(color: _C.textMid, fontSize: 13)),
              ),
            )
          else
            ..._filteredAlerts.map((a) => _buildAlertTile(a)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildCardHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: _C.primary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.chevron_left,
                  color: AppColors.white, size: 22),
            ),
          ),
          const SizedBox(width: 10),
          const Text('Notifikasi',
              style: TextStyle(
                  color: AppColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSummaryRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
      child: Row(
        children: [
          _buildSummaryChip(
            count: _totalToday,
            label: 'Total Peringatan',
            sub: 'Hari ini',
            bg: const Color(0xFFFEE2E2),
            iconColor: _C.tinggiText,
            icon: Icons.warning_amber_rounded,
          ),
          const SizedBox(width: 8),
          _buildSummaryChip(
            count: _daruratToday,
            label: 'Darurat',
            sub: 'Hari ini',
            bg: const Color(0xFFFFF3CD),
            iconColor: _C.daruratText,
            icon: Icons.local_fire_department_rounded,
          ),
          const SizedBox(width: 8),
          _buildSummaryChip(
            count: _sudahDibacaToday,
            label: 'Sudah Dibaca',
            sub: 'Hari ini',
            bg: const Color(0xFFE0F2FE),
            iconColor: _C.primary,
            icon: Icons.check_circle_outline_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip({
    required int count,
    required String label,
    required String sub,
    required Color bg,
    required Color iconColor,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: iconColor),
                const SizedBox(width: 4),
                Text('$count',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: iconColor)),
              ],
            ),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 10, color: _C.textDark),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(sub,
                style: const TextStyle(fontSize: 9, color: _C.textMid)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          ..._filters.map((f) => _buildFilterChip(f)),
          const Spacer(),
          _buildDateDropdown(),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final bool active = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? _C.primary : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? AppColors.white : _C.textMid)),
      ),
    );
  }

  Widget _buildDateDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Icon(Icons.calendar_today_rounded, size: 12, color: _C.textMid),
          SizedBox(width: 4),
          Text('Hari ini',
              style: TextStyle(fontSize: 11, color: _C.textMid)),
          SizedBox(width: 2),
          Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: _C.textMid),
        ],
      ),
    );
  }

  Widget _buildListHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Daftar Peringatan',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: _C.textDark)),
              Text('Terbaru Di atas',
                  style: TextStyle(fontSize: 10, color: _C.textMid)),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: _markAllRead,
            child: const Text('Tandai Semua Dibaca',
                style: TextStyle(
                    fontSize: 10,
                    color: _C.primary,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertTile(AlertItem item) {
    final levelData = _levelData(item.level);
    return GestureDetector(
      onTap: () => _openDetail(item),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: (levelData['bg'] as Color).withOpacity(0.45),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: levelData['bg'] as Color, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: levelData['bg'] as Color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon,
                      size: 18, color: levelData['text'] as Color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(item.title,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _C.textDark)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: levelData['badgeBg'] as Color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(levelData['label'] as String,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: levelData['text'] as Color)),
                ),
                const SizedBox(width: 6),
                Text(item.time.split(' ').first,
                    style:
                        const TextStyle(fontSize: 10, color: _C.textMid)),
                const SizedBox(width: 4),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color:
                        item.sudahDibaca ? Colors.transparent : _C.unreadDot,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(item.description,
                style:
                    const TextStyle(fontSize: 12, color: _C.textDark)),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildMeta('Skor : ${item.score.toStringAsFixed(2)}'),
                const SizedBox(width: 8),
                _buildMeta('Durasi : ${item.durasiDetik} Detik'),
                const Spacer(),
                _buildReadBadge(item.sudahDibaca),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeta(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(text,
          style: const TextStyle(fontSize: 10, color: _C.textMid)),
    );
  }

  Widget _buildReadBadge(bool dibaca) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: dibaca ? _C.waspadaBg : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        dibaca ? 'Dibaca' : 'Belum dibaca',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: dibaca ? _C.waspadaText : _C.textMid,
        ),
      ),
    );
  }

  Map<String, dynamic> _levelData(AlertLevel level) {
    switch (level) {
      case AlertLevel.tinggi:
        return {
          'label': 'Tinggi',
          'text': _C.tinggiText,
          'bg': _C.tinggiBg,
          'badgeBg': _C.tinggiText.withOpacity(0.12),
        };
      case AlertLevel.darurat:
        return {
          'label': 'Darurat',
          'text': _C.daruratText,
          'bg': _C.daruratBg,
          'badgeBg': _C.daruratText.withOpacity(0.12),
        };
      case AlertLevel.waspada:
        return {
          'label': 'Waspada',
          'text': _C.waspadaText,
          'bg': _C.waspadaBg,
          'badgeBg': _C.waspadaText.withOpacity(0.12),
        };
    }
  }
}

// ============================================================
// NOTIFICATION DETAIL SCREEN
// ============================================================
class NotificationDetailScreen extends StatelessWidget {
  final AlertItem item;

  const NotificationDetailScreen({super.key, required this.item});

  Map<String, dynamic> get _levelData {
    switch (item.level) {
      case AlertLevel.tinggi:
        return {
          'label': 'Tinggi',
          'text': _C.tinggiText,
          'bg': _C.tinggiBg,
          'badgeBg': _C.tinggiText.withOpacity(0.12),
        };
      case AlertLevel.darurat:
        return {
          'label': 'Darurat',
          'text': _C.daruratText,
          'bg': _C.daruratBg,
          'badgeBg': _C.daruratText.withOpacity(0.12),
        };
      case AlertLevel.waspada:
        return {
          'label': 'Waspada',
          'text': _C.waspadaText,
          'bg': _C.waspadaBg,
          'badgeBg': _C.waspadaText.withOpacity(0.12),
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final ld = _levelData;
    return Scaffold(
      backgroundColor: _C.bgPage,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    // ── Alert Card ──
                    _buildAlertCard(ld),
                    const SizedBox(height: 14),
                    // ── Ringkasan Kejadian ──
                    _buildSectionTitle('Ringkasan Kejadian'),
                    const SizedBox(height: 8),
                    _buildRingkasan(),
                    const SizedBox(height: 14),
                    // ── Lokasi Lansia ──
                    _buildSectionTitle('Lokasi Lansia'),
                    const SizedBox(height: 8),
                    _buildMapCard(context),
                    const SizedBox(height: 14),
                    // ── Grafik Aktivitas ──
                    _buildSectionTitle('Grafik Aktivitas'),
                    const SizedBox(height: 8),
                    _buildChartCard(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      color: _C.bgPage,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: _C.primary.withOpacity(0.12),
                child: const Icon(Icons.person_rounded, color: _C.primary, size: 26),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Haillo, Mila',
                      style: TextStyle(fontSize: 12, color: _C.textMid)),
                  Text('Monitoring Lansia',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _C.textDark)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: _C.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                SizedBox(width: 12),
                Icon(Icons.search, color: _C.textMid, size: 20),
                SizedBox(width: 8),
                Text('Search ...',
                    style: TextStyle(color: _C.textMid, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Section Title ────────────────────────────────────────
  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: _C.textDark));
  }

  // ── Alert Card ───────────────────────────────────────────
  Widget _buildAlertCard(Map<String, dynamic> ld) {
    return Container(
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          // Blue header bar
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: _C.primary,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Builder(builder: (ctx) {
              return Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.maybePop(ctx),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.chevron_left,
                          color: AppColors.white, size: 22),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text('Detail Peringatan',
                      style: TextStyle(
                          color: AppColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                ],
              );
            }),
          ),
          // Alert body
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (ld['bg'] as Color).withOpacity(0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ld['bg'] as Color),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: ld['bg'] as Color,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item.icon,
                          size: 20, color: ld['text'] as Color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(item.title,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _C.textDark)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: ld['badgeBg'] as Color,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(ld['label'] as String,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: ld['text'] as Color)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(item.description,
                    style: const TextStyle(
                        fontSize: 12, color: _C.textDark)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text('${item.time}   ${item.date}',
                        style: const TextStyle(
                            fontSize: 10, color: _C.textMid)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: item.sudahDibaca
                            ? _C.waspadaBg
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.sudahDibaca ? 'Dibaca' : 'Belum dibaca',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: item.sudahDibaca
                              ? _C.waspadaText
                              : _C.textMid,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Ringkasan Kejadian ───────────────────────────────────
  Widget _buildRingkasan() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          _buildRingkasanItem(
            icon: Icons.speed_rounded,
            iconColor: _C.tinggiText,
            iconBg: _C.tinggiBg,
            label: 'Skor Anomali',
            value: '${item.score.toStringAsFixed(2)}/1.00',
          ),
          _buildDividerV(),
          _buildRingkasanItem(
            icon: Icons.timer_rounded,
            iconColor: _C.primary,
            iconBg: _C.primaryLight,
            label: 'Durasi',
            value: '${item.durasiDetik} Detik',
          ),
          _buildDividerV(),
          _buildRingkasanItem(
            icon: Icons.access_time_rounded,
            iconColor: _C.waspadaText,
            iconBg: _C.waspadaBg,
            label: 'Waktu',
            value: item.time,
          ),
        ],
      ),
    );
  }

  Widget _buildRingkasanItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(height: 6),
          Text(label,
              style:
                  const TextStyle(fontSize: 10, color: _C.textMid)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _C.textDark),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildDividerV() {
    return Container(
      width: 1,
      height: 56,
      color: const Color(0xFFE2E8F0),
    );
  }

  // ── Map Card ─────────────────────────────────────────────
  Widget _buildMapCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          // Map
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
            child: SizedBox(
              height: 200,
              child: Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: item.location,
                      initialZoom: 15,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.guardianwalk.app',
                      ),
                      // Safe zone circle
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: item.location,
                            radius: 80,
                            color: _C.waspadaText.withOpacity(0.15),
                            borderColor: _C.waspadaText,
                            borderStrokeWidth: 2,
                            useRadiusInMeter: true,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: item.location,
                            width: 40,
                            height: 40,
                            child: Container(
                              decoration: BoxDecoration(
                                color: _C.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppColors.white, width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: _C.primary.withOpacity(0.4),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  )
                                ],
                              ),
                              child: const Icon(Icons.person_pin_rounded,
                                  color: AppColors.white, size: 22),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Area Aman label
                  Positioned(
                    top: 10,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: _C.waspadaText, width: 1),
                        ),
                        child: const Text('Area Aman',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _C.waspadaText)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Coordinates + status
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _buildCoordChip(
                    'Latitude : ${item.location.latitude.toStringAsFixed(4)}'),
                const SizedBox(width: 8),
                _buildCoordChip(
                    'Longitude : ${item.location.longitude.toStringAsFixed(4)}'),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _C.waspadaBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Terhubung',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _C.waspadaText)),
                ),
              ],
            ),
          ),
          // Lihat Lokasi button
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.location_on_rounded, size: 18),
                label: const Text('Lihat Lokasi',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.primary,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoordChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: const TextStyle(fontSize: 9, color: _C.textMid)),
    );
  }

  // ── Activity Chart ───────────────────────────────────────
  Widget _buildChartCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Legend
          Row(
            children: [
              _buildLegendDot(AppColors.primary, 'Akselerasi'),
              const SizedBox(width: 12),
              _buildLegendDot(const Color(0xFF7C3AED), 'Gyroscope'),
              const SizedBox(width: 12),
              _buildLegendDot(const Color(0xFFF59E0B), 'Ambang Batas'),
            ],
          ),
          const SizedBox(height: 12),
          // Chart
          SizedBox(
            height: 140,
            child: CustomPaint(
              size: const Size(double.infinity, 140),
              painter: _ActivityChartPainter(score: item.score),
            ),
          ),
          // X-axis labels
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('10.47', style: TextStyle(fontSize: 8, color: _C.textMid)),
                Text('10.48', style: TextStyle(fontSize: 8, color: _C.textMid)),
                Text('10.50', style: TextStyle(fontSize: 8, color: _C.textMid)),
                Text('11.00', style: TextStyle(fontSize: 8, color: _C.textMid)),
                Text('11.02', style: TextStyle(fontSize: 8, color: _C.textMid)),
                Text('11.04', style: TextStyle(fontSize: 8, color: _C.textMid)),
                Text('11.07', style: TextStyle(fontSize: 8, color: _C.textMid)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Anomaly label
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _C.tinggiBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: const [
                Icon(Icons.info_outline_rounded,
                    size: 12, color: _C.tinggiText),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Grafik ini menampilkan data akselerasi dan gyroscope dari sensor IMU/MPU6050 selama kejadian anomali. Garis merah menandai titik anomali terdeteksi. Garis area menunjukkan ambang batas normal untuk membantu mengidentifikasi aktivitas fisik abnormal.',
                    style: TextStyle(fontSize: 9, color: _C.tinggiText),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 9, color: _C.textMid)),
      ],
    );
  }
}

// ============================================================
// CUSTOM PAINTER – Activity Chart
// ============================================================
class _ActivityChartPainter extends CustomPainter {
  final double score;
  _ActivityChartPainter({required this.score});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(42);
    final w = size.width;
    final h = size.height;
    const steps = 60;

    // Y-axis lines
    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 0.8;
    for (int i = 0; i <= 4; i++) {
      final y = h * i / 4;
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    // Generate sensor data
    List<double> accel = [];
    List<double> gyro = [];
    for (int i = 0; i < steps; i++) {
      // spike around 75% mark to simulate anomaly
      double spike = 0;
      if (i > steps * 0.65 && i < steps * 0.80) {
        spike = (score * 0.6) * sin((i - steps * 0.65) * pi / (steps * 0.15));
      }
      accel.add(0.3 + rng.nextDouble() * 0.25 + spike.abs());
      gyro.add(0.2 + rng.nextDouble() * 0.2 + spike.abs() * 0.6);
    }

    // Normalize helper
    double norm(double v) => h - (v.clamp(0.0, 1.2) / 1.2) * h;

    // Ambang batas (threshold) line
    final threshPaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final threshY = norm(0.75);
    canvas.drawDashedLine(
        Offset(0, threshY), Offset(w, threshY), threshPaint, 6, 4);

    // Anomaly region fill
    final anomalyStart = (steps * 0.65 / steps * w);
    final anomalyEnd = (steps * 0.80 / steps * w);
    final anomalyPaint = Paint()
      ..color = const Color(0xFFFEE2E2).withOpacity(0.6);
    canvas.drawRect(
        Rect.fromLTRB(anomalyStart, 0, anomalyEnd, h), anomalyPaint);

    // Anomaly vertical line
    final anomalyLinePaint = Paint()
      ..color = AppColors.statusRed
      ..strokeWidth = 1.5;
    final midAnomaly = (anomalyStart + anomalyEnd) / 2;
    canvas.drawLine(Offset(midAnomaly, 0), Offset(midAnomaly, h),
        anomalyLinePaint);

    // Draw path helper
    void drawPath(List<double> data, Color color) {
      final path = ui.Path();
      for (int i = 0; i < data.length; i++) {
        final x = i / (steps - 1) * w;
        final y = norm(data[i]);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          final prevX = (i - 1) / (steps - 1) * w;
          final prevY = norm(data[i - 1]);
          final cpX = (prevX + x) / 2;
          path.cubicTo(cpX, prevY, cpX, y, x, y);
        }
      }
      canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..strokeWidth = 1.8
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round);
    }

    drawPath(accel, AppColors.primary);
    drawPath(gyro, const Color(0xFF7C3AED));

    // Y-axis labels
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final label in ['1.2', '0.9', '0.6', '0.3', '0']) {
      final idx = ['1.2', '0.9', '0.6', '0.3', '0'].indexOf(label);
      tp.text = TextSpan(
          text: label,
          style: const TextStyle(fontSize: 8, color: _C.textMid));
      tp.layout();
      tp.paint(canvas, Offset(0, h * idx / 4 + 1));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Extension for dashed line
extension on Canvas {
  void drawDashedLine(
      Offset start, Offset end, Paint paint, double dashLen, double gapLen) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final dist = sqrt(dx * dx + dy * dy);
    final nx = dx / dist;
    final ny = dy / dist;
    double drawn = 0;
    bool drawing = true;
    while (drawn < dist) {
      final segLen = drawing ? dashLen : gapLen;
      final next = (drawn + segLen).clamp(0.0, dist);
      if (drawing) {
        drawLine(
          Offset(start.dx + nx * drawn, start.dy + ny * drawn),
          Offset(start.dx + nx * next, start.dy + ny * next),
          paint,
        );
      }
      drawn = next;
      drawing = !drawing;
    }
  }
}