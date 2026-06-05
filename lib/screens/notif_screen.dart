import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../database/database_helper.dart';
import '../models/alert_model.dart';
import '../services/notification_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_routes.dart';

// ============================================================
// COLORS
// ============================================================
class _C {
  static const Color primary = AppColors.primary;
  static const Color primaryLight = Color(0xFFDBEAFE);
  static const Color bgPage = Color(0xFFE8F0FB);
  static const Color white = AppColors.white;
  static const Color textDark = AppColors.textDark;
  static const Color textMid = AppColors.textGrey;

  static const Color tinggiText = AppColors.statusRed;
  static const Color tinggiBg = Color(0xFFFEE2E2);
  static const Color daruratText = AppColors.statusYellow;
  static const Color daruratBg = Color(0xFFFFF3CD);
  static const Color waspadaText = AppColors.statusGreen;
  static const Color waspadaBg = Color(0xFFDCFCE7);
  static const Color unreadDot = AppColors.statusRed;
}

// ============================================================
// NOTIFICATION SCREEN
// ============================================================
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  // ── Data ──────────────────────────────────────────────────
  String _namaUser = 'User';
  String _namaLansia = 'Nama Lansia';
  String _namaLengkap = 'User';
  File? _fotoFile;
  String? _walkerId;
  NotificationService? _service;

  StreamSubscription<List<AlertItem>>? _walkerSub;
  List<AlertItem> _alerts = [];

  // ── UI State ──────────────────────────────────────────────
  bool _isLoading = true;
  String _errorMsg = '';
  String _selectedFilter = 'Semua';
  // FIX: tambah 'Tinggi' supaya semua level tercakup
  final List<String> _filters = ['Semua', 'Tinggi', 'Darurat', 'Waspada'];

  // FIX: filter tanggal — default 'Hari ini'
  String _selectedDateFilter = 'Hari ini';
  final List<String> _dateFilters = ['Hari ini', 'Semua Tanggal'];

  // FIX: GlobalKey untuk baca posisi widget dropdown secara akurat
  final GlobalKey _dateDropdownKey = GlobalKey();

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // ── Lifecycle ─────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadProfileAndSubscribe();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _walkerSub?.cancel();
    super.dispose();
  }

  // ── Init: ambil SQLite lalu subscribe RTDB ────────────────
  Future<void> _loadProfileAndSubscribe() async {
    try {
      final profile = await DatabaseHelper.instance.getProfile();
      final paired = await DatabaseHelper.instance.getLastPairedWalker();
      final walkerId = paired?['walker_id']?.toString();

      if (!mounted) return;

      // ← ambil nama & foto dari SQLite
      File? fotoFile;
      final fotoPath = profile?['foto']?.toString() ?? '';
      if (fotoPath.isNotEmpty && File(fotoPath).existsSync()) {
        fotoFile = File(fotoPath);
      }

      setState(() {
        _namaUser = profile?['nama']?.toString() ?? 'User';
        _namaLengkap = profile?['nama']?.toString() ?? 'User';
        _namaLansia = profile?['nama_lansia']?.toString() ?? _namaLansia;
        _fotoFile = fotoFile;
        _walkerId = walkerId;
      });

      if (walkerId == null || walkerId.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMsg = 'Belum ada walker yang dipasangkan.';
        });
        return;
      }

      _service = NotificationService(walkerId: walkerId);
      _walkerSub = _service!.watchNotifications().listen(
        (items) {
          if (mounted)
            setState(() {
              _alerts = items;
              _isLoading = false;
            });
        },
        onError: (e) {
          if (mounted)
            setState(() {
              _isLoading = false;
              _errorMsg = 'Gagal memuat notifikasi: $e';
            });
        },
      );
    } catch (e) {
      if (mounted)
        setState(() {
          _isLoading = false;
          _errorMsg = 'Terjadi kesalahan: $e';
        });
    }
  }

  // ── Filter ────────────────────────────────────────────────
  /// FIX: logika filter tanggal "Hari ini" sekarang aktif
  List<AlertItem> get _filtered {
    Iterable<AlertItem> list = _alerts;

    // Filter level
    if (_selectedFilter == 'Tinggi') {
      list = list.where((a) => a.level == AlertLevel.tinggi);
    } else if (_selectedFilter == 'Darurat') {
      list = list.where((a) => a.level == AlertLevel.darurat);
    } else if (_selectedFilter == 'Waspada') {
      list = list.where((a) => a.level == AlertLevel.waspada);
    }

    // FIX: Filter tanggal "Hari ini"
    if (_selectedDateFilter == 'Hari ini') {
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // DEBUG — hapus setelah selesai
      debugPrint('=== TODAY: $todayStr');
      for (final a in _alerts) {
        debugPrint('rawDate: "${a.rawDate}" | cocok: ${a.rawDate == todayStr}');
      }

      list = list.where((a) => a.rawDate == todayStr);
    }

    // Filter search
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((a) =>
          a.title.toLowerCase().contains(q) ||
          a.description.toLowerCase().contains(q) ||
          a.date.toLowerCase().contains(q) ||
          a.time.toLowerCase().contains(q));
    }

    return list.toList();
  }

  // ── Actions ───────────────────────────────────────────────
  /// FIX: markAllAsRead sekarang menggunakan _alerts yang belum difilter
  /// agar semua notif yang belum dibaca ikut ditandai
  Future<void> _markAllRead() async {
    if (_service == null) return;
    // Kirim semua alert (bukan hanya yang terfilter) ke service
    await _service!.markAllAsRead(_alerts);
  }

  Future<void> _openDetail(AlertItem item) async {
    await _service?.markAsRead(item.id);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationDetailScreen(
          item: item.copyWith(sudahDibaca: true),
          namaLansia: _namaLansia,
          namaLengkap: _namaLengkap, // ← tambah
          fotoFile: _fotoFile, // ← tambah
          service: _service!,
        ),
      ),
    );
  }

  // ── Summary helpers ───────────────────────────────────────
  int get _totalToday => _alerts.length;
  int get _daruratToday =>
      _alerts.where((a) => a.level == AlertLevel.darurat).length;
  int get _dibacaToday => _alerts.where((a) => a.sudahDibaca).length;

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bgPage,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  // ── Body ──────────────────────────────────────────────────
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMsg.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_errorMsg,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _C.textMid, fontSize: 13)),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 12),
          _buildNotificationCard(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: _C.bgPage,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              // ← avatar dari foto SQLite, fallback ke inisial
              CircleAvatar(
                radius: 22,
                backgroundColor: _C.primary.withOpacity(0.15),
                backgroundImage:
                    _fotoFile != null ? FileImage(_fotoFile!) : null,
                child: _fotoFile == null
                    ? Text(
                        _namaLengkap.isNotEmpty
                            ? _namaLengkap[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _C.primary),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    // ← ganti 'Halo, Mila'
                    'Halo, $_namaLengkap',
                    style: const TextStyle(fontSize: 12, color: _C.textMid),
                  ),
                  Text(
                    'Monitoring $_namaLansia',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _C.textDark),
                  ),
                ],
              ),
              const Spacer(),
              if (_walkerId != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _C.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _walkerId!,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _C.primary),
                  ),
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
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Icon(Icons.search, size: 20, color: _C.textMid),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: const InputDecoration(
                      hintText: 'Cari notifikasi ...',
                      hintStyle: TextStyle(fontSize: 14, color: _C.textMid),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, color: _C.textMid),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Main Card ─────────────────────────────────────────────
  Widget _buildNotificationCard() {
    final filtered = _filtered;
    return Container(
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4)),
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
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('Tidak ada peringatan',
                    style: TextStyle(color: _C.textMid, fontSize: 13)),
              ),
            )
          else
            ...filtered.map((a) => _buildAlertTile(a)),
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
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                      color: Color(0xFF4ADE80), shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                const Text('Live',
                    style: TextStyle(
                        color: AppColors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
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
            sub: 'Semua',
            bg: const Color(0xFFFEE2E2),
            iconColor: _C.tinggiText,
            icon: Icons.warning_amber_rounded,
          ),
          const SizedBox(width: 8),
          _buildSummaryChip(
            count: _daruratToday,
            label: 'Darurat',
            sub: 'Semua',
            bg: const Color(0xFFFFF3CD),
            iconColor: _C.daruratText,
            icon: Icons.local_fire_department_rounded,
          ),
          const SizedBox(width: 8),
          _buildSummaryChip(
            count: _dibacaToday,
            label: 'Sudah Dibaca',
            sub: 'Semua',
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
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 4),
              Text('$count',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: iconColor)),
            ]),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 10, color: _C.textDark),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(sub, style: const TextStyle(fontSize: 9, color: _C.textMid)),
          ],
        ),
      ),
    );
  }

  // FIX: _buildFilterRow sekarang memanggil _buildDateDropdown yang fungsional
  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Baris 1: filter chip — scrollable horizontal
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filters.map((f) => _buildFilterChip(f)).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // Baris 2: date dropdown rata kanan
          Align(
            alignment: Alignment.centerRight,
            child: _buildDateDropdown(),
          ),
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

  /// FIX: dropdown pakai GlobalKey → posisi menu tepat di bawah tombol filter
  Widget _buildDateDropdown() {
    return GestureDetector(
      onTap: () async {
        // Baca posisi & ukuran widget secara akurat dari RenderBox
        final RenderBox box =
            _dateDropdownKey.currentContext!.findRenderObject() as RenderBox;
        final Offset offset = box.localToGlobal(Offset.zero);
        final Size size = box.size;

        final result = await showMenu<String>(
          context: context,
          // Posisi tepat di bawah tombol
          position: RelativeRect.fromLTRB(
            offset.dx,
            offset.dy + size.height + 4,
            offset.dx + size.width,
            0,
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 4,
          items: _dateFilters
              .map((d) => PopupMenuItem<String>(
                    value: d,
                    height: 36,
                    child: Text(d,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: d == _selectedDateFilter
                                ? FontWeight.w700
                                : FontWeight.normal,
                            color: d == _selectedDateFilter
                                ? _C.primary
                                : _C.textDark)),
                  ))
              .toList(),
        );
        if (result != null) {
          setState(() => _selectedDateFilter = result);
        }
      },
      child: Container(
        key: _dateDropdownKey,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(
              color: _selectedDateFilter == 'Hari ini'
                  ? _C.primary
                  : const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(8),
          color: _selectedDateFilter == 'Hari ini'
              ? _C.primaryLight
              : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 12,
              color:
                  _selectedDateFilter == 'Hari ini' ? _C.primary : _C.textMid,
            ),
            const SizedBox(width: 4),
            Text(
              _selectedDateFilter,
              style: TextStyle(
                  fontSize: 11,
                  color: _selectedDateFilter == 'Hari ini'
                      ? _C.primary
                      : _C.textMid,
                  fontWeight: _selectedDateFilter == 'Hari ini'
                      ? FontWeight.w600
                      : FontWeight.normal),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 14,
              color:
                  _selectedDateFilter == 'Hari ini' ? _C.primary : _C.textMid,
            ),
          ],
        ),
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
    final ld = _levelData(item.level);
    return GestureDetector(
      onTap: () => _openDetail(item),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: (ld['bg'] as Color).withOpacity(0.45),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ld['bg'] as Color),
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
                    color: ld['bg'] as Color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, size: 18, color: ld['text'] as Color),
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
                    color: ld['badgeBg'] as Color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(ld['label'] as String,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: ld['text'] as Color)),
                ),
                const SizedBox(width: 6),
                Text(item.time.split(' ').first,
                    style: const TextStyle(fontSize: 10, color: _C.textMid)),
                const SizedBox(width: 4),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: item.sudahDibaca ? Colors.transparent : _C.unreadDot,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(item.description,
                style: const TextStyle(fontSize: 12, color: _C.textDark)),
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
      child:
          Text(text, style: const TextStyle(fontSize: 10, color: _C.textMid)),
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
  final String namaLansia;
  final String namaLengkap; // ← tambah
  final File? fotoFile; // ← tambah
  final NotificationService service;

  const NotificationDetailScreen({
    super.key,
    required this.item,
    required this.namaLansia,
    required this.namaLengkap,
    required this.fotoFile,
    required this.service,
  });

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
                    _buildAlertCard(context, ld),
                    const SizedBox(height: 14),
                    _buildSectionTitle('Lokasi Lansia'),
                    const SizedBox(height: 8),
                    _buildMapCard(context),
                    const SizedBox(height: 14),
                    _buildSectionTitle('Ringkasan Kejadian'),
                    const SizedBox(height: 8),
                    _buildRingkasan(),
                    const SizedBox(height: 14),
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

  // FIX: Header detail screen — hapus _namaLansia yang tidak ada, pakai namaLansia (parameter)
  // FIX: hilangkan Text ketiga yang duplikat dan menyebabkan syntax error
  Widget _buildHeader(BuildContext context) {
    return Container(
      color: _C.bgPage,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              // ← sama seperti list screen
              CircleAvatar(
                radius: 22,
                backgroundColor: _C.primary.withOpacity(0.12),
                backgroundImage: fotoFile != null ? FileImage(fotoFile!) : null,
                child: fotoFile == null
                    ? Text(
                        namaLengkap.isNotEmpty
                            ? namaLengkap[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _C.primary),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    // ← ganti 'Halo, Mila'
                    'Halo, $namaLengkap',
                    style: const TextStyle(fontSize: 12, color: _C.textMid),
                  ),
                  Text(
                    'Monitoring $namaLansia',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _C.textDark),
                  ),
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
                Text('Cari notifikasi ...',
                    style: TextStyle(color: _C.textMid, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.bold, color: _C.textDark));
  }

  // ── Alert Card ────────────────────────────────────────────
  Widget _buildAlertCard(BuildContext context, Map<String, dynamic> ld) {
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
          Container(
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
                const Text('Detail Peringatan',
                    style: TextStyle(
                        color: AppColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
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
                      child:
                          Icon(item.icon, size: 20, color: ld['text'] as Color),
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
                    style: const TextStyle(fontSize: 12, color: _C.textDark)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text('${item.time}   ${item.date}',
                        style:
                            const TextStyle(fontSize: 10, color: _C.textMid)),
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
                          color: item.sudahDibaca ? _C.waspadaText : _C.textMid,
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

  // ── Ringkasan Kejadian ────────────────────────────────────
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
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 10, color: _C.textMid)),
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

  Widget _buildDividerV() =>
      Container(width: 1, height: 56, color: const Color(0xFFE2E8F0));

  // ── Map Card ──────────────────────────────────────────────
  // FIX: Koordinat sekarang benar karena _toDoubleStrict di model
  // menangani latitude: "" → null → 0.0 (dan idealnya Firebase sudah diisi)
  Widget _buildMapCard(BuildContext context) {
    // FIX: Tampilkan peringatan jika koordinat masih 0,0
    final bool hasValidLocation =
        item.location.latitude != 0.0 || item.location.longitude != 0.0;

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
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: SizedBox(
              height: 200,
              child: hasValidLocation
                  ? Stack(
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
                            CircleLayer(circles: [
                              CircleMarker(
                                point: item.location,
                                radius: 80,
                                color: _C.waspadaText.withOpacity(0.15),
                                borderColor: _C.waspadaText,
                                borderStrokeWidth: 2,
                                useRadiusInMeter: true,
                              ),
                            ]),
                            MarkerLayer(markers: [
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
                            ]),
                          ],
                        ),
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
                    )
                  // FIX: Tampilkan placeholder jika koordinat tidak valid
                  : Container(
                      color: const Color(0xFFF1F5F9),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.location_off_rounded,
                                size: 36, color: _C.textMid),
                            SizedBox(height: 8),
                            Text('Koordinat tidak tersedia',
                                style:
                                    TextStyle(fontSize: 12, color: _C.textMid)),
                            Text('Periksa data latitude/longitude di Firebase',
                                style:
                                    TextStyle(fontSize: 10, color: _C.textMid)),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _buildCoordChip(
                    'Lat : ${item.location.latitude.toStringAsFixed(4)}'),
                const SizedBox(width: 8),
                _buildCoordChip(
                    'Lng : ${item.location.longitude.toStringAsFixed(4)}'),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasValidLocation ? _C.waspadaBg : _C.tinggiBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    hasValidLocation ? 'Terhubung' : 'Tidak Ada Data',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color:
                            hasValidLocation ? _C.waspadaText : _C.tinggiText),
                  ),
                ),
              ],
            ),
          ),
          if (hasValidLocation)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(
                      context, AppRoutes.location,
                      arguments: item.location),
                  icon: const Icon(Icons.location_on_rounded, size: 18),
                  label: const Text('Lihat Lokasi',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
      child: Text(text, style: const TextStyle(fontSize: 9, color: _C.textMid)),
    );
  }

  // ── Chart Card ────────────────────────────────────────────
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
          SizedBox(
            height: 140,
            child: CustomPaint(
              size: const Size(double.infinity, 140),
              painter: _ActivityChartPainter(score: item.score),
            ),
          ),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _C.tinggiBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 12, color: _C.tinggiText),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Grafik ini menampilkan data akselerasi dan gyroscope dari sensor IMU/MPU6050 selama kejadian anomali. Garis merah menandai titik anomali terdeteksi.',
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

    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 0.8;
    for (int i = 0; i <= 4; i++) {
      canvas.drawLine(Offset(0, h * i / 4), Offset(w, h * i / 4), gridPaint);
    }

    List<double> accel = [];
    List<double> gyro = [];
    for (int i = 0; i < steps; i++) {
      double spike = 0;
      if (i > steps * 0.65 && i < steps * 0.80) {
        spike = (score * 0.6) * sin((i - steps * 0.65) * pi / (steps * 0.15));
      }
      accel.add(0.3 + rng.nextDouble() * 0.25 + spike.abs());
      gyro.add(0.2 + rng.nextDouble() * 0.2 + spike.abs() * 0.6);
    }

    double norm(double v) => h - (v.clamp(0.0, 1.2) / 1.2) * h;

    final threshPaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawDashedLine(
        Offset(0, norm(0.75)), Offset(w, norm(0.75)), threshPaint, 6, 4);

    final aStart = steps * 0.65 / steps * w;
    final aEnd = steps * 0.80 / steps * w;
    canvas.drawRect(Rect.fromLTRB(aStart, 0, aEnd, h),
        Paint()..color = const Color(0xFFFEE2E2).withOpacity(0.6));
    canvas.drawLine(
        Offset((aStart + aEnd) / 2, 0),
        Offset((aStart + aEnd) / 2, h),
        Paint()
          ..color = AppColors.statusRed
          ..strokeWidth = 1.5);

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

    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final label in ['1.2', '0.9', '0.6', '0.3', '0']) {
      final idx = ['1.2', '0.9', '0.6', '0.3', '0'].indexOf(label);
      tp.text = TextSpan(
          text: label, style: const TextStyle(fontSize: 8, color: _C.textMid));
      tp.layout();
      tp.paint(canvas, Offset(0, h * idx / 4 + 1));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Dashed line extension ──────────────────────────────────
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
