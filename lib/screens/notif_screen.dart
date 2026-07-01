import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';
import '../database/database_helper.dart';
import '../models/alert_model.dart';
import '../services/notification_service.dart';
import '../services/history_service.dart';
import '../models/history_model.dart';
import '../utils/app_colors.dart';
import '../utils/app_routes.dart';

// ============================================================
// COLORS
// ============================================================
class _C {
  static const Color primary      = AppColors.primary;
  static const Color primaryLight = Color(0xFFDBEAFE);
  static const Color bgPage       = Color(0xFFE8F0FB);
  static const Color white        = AppColors.white;
  static const Color textDark     = AppColors.textDark;
  static const Color textMid      = AppColors.textGrey;

  static const Color tinggiText  = AppColors.statusRed;
  static const Color tinggiBg    = Color(0xFFFEE2E2);
  static const Color daruratText = Color.fromARGB(255, 222, 3, 3);
  static const Color daruratBg   = Color(0xFFFEE2E2);
  static const Color waspadaText = Color(0xFFD97706);
  static const Color waspadaBg   = Color(0xFFFFF3CD);
  static const Color amanText    = Color(0xFF16A34A);
  static const Color amanBg      = Color(0xFFDCFCE7);
  static const Color unreadDot   = AppColors.statusRed;
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
  String _namaUser    = 'User';
  String _namaLansia  = 'Nama Lansia';
  String _namaLengkap = 'User';
  File?  _fotoFile;
  String? _walkerId;
  NotificationService? _service;

  StreamSubscription<List<AlertItem>>? _walkerSub;
  List<AlertItem> _alerts = [];

  bool   _isLoading        = true;
  String _errorMsg         = '';
  String _selectedFilter   = 'Semua';
  final List<String> _filters = ['Semua', 'Darurat', 'Waspada'];

  String _selectedDateFilter = 'Hari ini';
  final List<String> _dateFilters = ['Hari ini', 'Semua Tanggal'];
  final GlobalKey _dateDropdownKey = GlobalKey();

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

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

  Future<void> _loadProfileAndSubscribe() async {
    try {
      final profile = await DatabaseHelper.instance.getProfile();
      final paired  = await DatabaseHelper.instance.getLastPairedWalker();
      final walkerId = paired?['walker_id']?.toString();

      if (!mounted) return;

      File? fotoFile;
      final fotoPath = profile?['foto']?.toString() ?? '';
      if (fotoPath.isNotEmpty && File(fotoPath).existsSync()) {
        fotoFile = File(fotoPath);
      }

      setState(() {
        _namaUser    = profile?['nama']?.toString() ?? 'User';
        _namaLengkap = profile?['nama']?.toString() ?? 'User';
        _namaLansia  = profile?['nama_lansia']?.toString() ?? _namaLansia;
        _fotoFile    = fotoFile;
        _walkerId    = walkerId;
      });

      if (walkerId == null || walkerId.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMsg  = 'Belum ada walker yang dipasangkan.';
        });
        return;
      }

      _service = NotificationService(walkerId: walkerId);
      await _service!.saveOneSignalId();

      _walkerSub = _service!.watchNotifications().listen(
        (items) {
          if (mounted) {
            setState(() {
              _alerts = items;
              _isLoading = false;
            });
          }
        },
        onError: (e) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMsg = 'Gagal memuat notifikasi: $e';
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMsg = 'Terjadi kesalahan: $e';
        });
      }
    }
  }

  List<AlertItem> get _filtered {
    Iterable<AlertItem> list = _alerts;

    if (_selectedFilter == 'Tinggi') {
      list = list.where((a) => a.level == AlertLevel.tinggi);
    } else if (_selectedFilter == 'Darurat') {
      list = list.where((a) => a.level == AlertLevel.darurat);
    } else if (_selectedFilter == 'Waspada') {
      list = list.where((a) => a.level == AlertLevel.waspada);
    }

    if (_selectedDateFilter == 'Hari ini') {
      final now      = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      list = list.where((a) => a.rawDate == todayStr);
    }

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

  Future<void> _markAllRead() async {
    if (_service == null) return;
    await _service!.markAllAsRead(_alerts);
  }

  // ── Buka detail: hanya tandai sudahDibaca (titik merah hilang)
  //    TIDAK otomatis tandai aman — user harus klik sendiri
  Future<void> _openDetail(AlertItem item) async {
    await _service?.markAsRead(item.id);
    if (!mounted) return;

    // Cari history yang relevan berdasarkan timestamp notifikasi
    HistoryItem? historyItem;
    if (_walkerId != null) {
      try {
        final historyService = HistoryService(walkerId: _walkerId!);
        historyItem = await historyService.findByNotification(
          timestamp: item.timestamp,
          title: item.title,
        );
        debugPrint('[NotifScreen] historyItem id: ${historyItem?.id}');
      } catch (e) {
        debugPrint('[NotifScreen] gagal cari historyItem: $e');
      }
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationDetailScreen(
          // Kirim item dengan sudahDibaca=true tapi sudahAman tetap aslinya
          item: item.copyWith(sudahDibaca: true),
          namaLansia:  _namaLansia,
          namaLengkap: _namaLengkap,
          fotoFile:    _fotoFile,
          service:     _service!,
          historyItem: historyItem,
        ),
      ),
    );
  }

  int get _totalToday {
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return _alerts.where((a) => a.rawDate == today).length;
  }

  int get _daruratToday =>
      _alerts.where((a) => a.level == AlertLevel.darurat).length;
  int get _belumDibacaToday => _alerts.where((a) => !a.sudahDibaca).length;

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

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
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

  Widget _buildHeader() {
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
                  Text('Halo, $_namaLengkap',
                      style: const TextStyle(fontSize: 12, color: _C.textMid)),
                  Text('Monitoring $_namaLansia',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _C.textDark)),
                ],
              ),
              const Spacer(),
              if (_walkerId != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: _C.primaryLight,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(_walkerId!,
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _C.primary)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 44,
            decoration: BoxDecoration(
                color: _C.white, borderRadius: BorderRadius.circular(12)),
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
              offset: const Offset(0, 4))
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
                      style: TextStyle(color: _C.textMid, fontSize: 13))),
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
                  borderRadius: BorderRadius.circular(8)),
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
                borderRadius: BorderRadius.circular(6)),
            child: Row(
              children: [
                Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                        color: Color(0xFF4ADE80), shape: BoxShape.circle)),
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
              bg: const Color(0xFFFFF3CD),
              iconColor: _C.waspadaText,
              icon: Icons.warning_amber_rounded),
          const SizedBox(width: 8),
          _buildSummaryChip(
              count: _daruratToday,
              label: 'Darurat',
              sub: 'Perlu tindakan',
              bg: const Color(0xFFFEE2E2),
              iconColor: _C.daruratText,
              icon: Icons.local_fire_department_rounded),
          const SizedBox(width: 8),
          _buildSummaryChip(
              count: _belumDibacaToday,
              label: 'Belum Dibaca',
              sub: 'Butuh respon',
              bg: const Color(0xFFE0F2FE),
              iconColor: _C.primary,
              icon: Icons.mark_email_unread_rounded),
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

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
                children: _filters.map((f) => _buildFilterChip(f)).toList()),
          ),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerRight, child: _buildDateDropdown()),
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
    return GestureDetector(
      onTap: () async {
        final RenderBox box =
            _dateDropdownKey.currentContext!.findRenderObject() as RenderBox;
        final Offset offset = box.localToGlobal(Offset.zero);
        final Size size = box.size;
        final result = await showMenu<String>(
          context: context,
          position: RelativeRect.fromLTRB(offset.dx, offset.dy + size.height + 4,
              offset.dx + size.width, 0),
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
        if (result != null) setState(() => _selectedDateFilter = result);
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
            Icon(Icons.calendar_today_rounded,
                size: 12,
                color:
                    _selectedDateFilter == 'Hari ini' ? _C.primary : _C.textMid),
            const SizedBox(width: 4),
            Text(_selectedDateFilter,
                style: TextStyle(
                    fontSize: 11,
                    color: _selectedDateFilter == 'Hari ini'
                        ? _C.primary
                        : _C.textMid,
                    fontWeight: _selectedDateFilter == 'Hari ini'
                        ? FontWeight.w600
                        : FontWeight.normal)),
            const SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 14,
                color:
                    _selectedDateFilter == 'Hari ini' ? _C.primary : _C.textMid),
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
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(item.icon, size: 18, color: ld['text'] as Color),
                ),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(item.title,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _C.textDark))),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: ld['badgeBg'] as Color,
                      borderRadius: BorderRadius.circular(6)),
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
                // Titik merah = belum dibaca
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                      color: item.sudahDibaca
                          ? Colors.transparent
                          : _C.unreadDot,
                      shape: BoxShape.circle),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(item.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: _C.textDark)),
            const SizedBox(height: 10),
            _buildTileActionButtons(item),
          ],
        ),
      ),
    );
  }

  // ── Tombol aksi di tile
  Widget _buildTileActionButtons(AlertItem item) {
    // ── FIX: tombol "Tandai Aman" pakai sudahAman, BUKAN sudahDibaca
    final bool sudahAman = item.sudahAman;
    return Row(
      children: [
        _actionBtn(
          icon: Icons.phone_rounded,
          label: 'Hubungi',
          color: _C.tinggiText,
          bg: _C.tinggiBg,
          onTap: () => _showContactPicker(context),
        ),
        const SizedBox(width: 6),
        _actionBtn(
          icon: sudahAman
              ? Icons.check_circle_rounded
              : Icons.check_circle_outline_rounded,
          label: sudahAman ? 'Aman' : 'Tandai Aman',
          color: _C.amanText,
          bg: _C.amanBg,
          onTap: () async {
            // ── FIX: panggil markAsSafe, bukan markAsRead
            if (!sudahAman) await _service?.markAsSafe(item.id);
          },
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => _openDetail(item),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: _C.primary, borderRadius: BorderRadius.circular(8)),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Lihat Detail',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.white)),
                SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 14, color: AppColors.white),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required Color bg,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3))),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  void _showContactPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ContactPickerSheet(),
    );
  }

  Map<String, dynamic> _levelData(AlertLevel level) {
    switch (level) {
      case AlertLevel.tinggi:
        return {
          'label':   'Darurat',
          'text':    _C.daruratText,
          'bg':      _C.daruratBg,
          'badgeBg': _C.daruratText.withOpacity(0.12),
        };
      case AlertLevel.darurat:
        return {
          'label':   'Darurat',
          'text':    _C.daruratText,
          'bg':      _C.daruratBg,
          'badgeBg': _C.daruratText.withOpacity(0.12),
        };
      case AlertLevel.waspada:
        return {
          'label':   'Waspada',
          'text':    _C.waspadaText,
          'bg':      _C.waspadaBg,
          'badgeBg': _C.waspadaText.withOpacity(0.12),
        };
    }
  }
}

// ============================================================
// CONTACT PICKER SHEET
// ============================================================
class _ContactPickerSheet extends StatefulWidget {
  @override
  State<_ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends State<_ContactPickerSheet> {
  List<Map<String, dynamic>> _contacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final contacts = await DatabaseHelper.instance.getEmergencyContacts();
    if (mounted) {
      setState(() {
        _contacts = contacts;
        _loading = false;
      });
    }
  }

  Future<void> _call(String number) async {
    Navigator.pop(context);
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Tidak bisa menghubungi $number'),
              backgroundColor: _C.tinggiText),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2))),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: _C.tinggiBg, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.phone_rounded,
                    size: 18, color: _C.tinggiText),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hubungi Kontak Darurat',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _C.textDark)),
                  Text('Pilih kontak yang akan dihubungi',
                      style: TextStyle(fontSize: 11, color: _C.textMid)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()))
          else if (_contacts.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.contacts_outlined,
                      size: 40, color: _C.textMid),
                  const SizedBox(height: 8),
                  const Text('Belum ada kontak darurat',
                      style: TextStyle(fontSize: 13, color: _C.textMid)),
                  const SizedBox(height: 4),
                  const Text('Tambahkan di menu Profil → Kontak Darurat',
                      style: TextStyle(fontSize: 11, color: _C.textMid),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 16, color: _C.primary),
                    label: const Text('Tutup',
                        style: TextStyle(color: _C.primary, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _C.primary),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _contacts.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (_, i) {
                final c       = _contacts[i];
                final name    = c['contact_name']?.toString() ?? '-';
                final number  = c['contact_number']?.toString() ?? '';
                final rel     = c['relationship']?.toString() ?? '';
                final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  leading: CircleAvatar(
                    radius: 22,
                    backgroundColor: _C.primaryLight,
                    child: Text(initial,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _C.primary)),
                  ),
                  title: Text(name,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _C.textDark)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(number,
                          style:
                              const TextStyle(fontSize: 12, color: _C.textMid)),
                      if (rel.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 3),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: _C.primaryLight,
                              borderRadius: BorderRadius.circular(4)),
                          child: Text(rel,
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: _C.primary,
                                  fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                  trailing: GestureDetector(
                    onTap: () => _call(number),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color: _C.tinggiText,
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.phone_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

// ============================================================
// NOTIFICATION DETAIL SCREEN
// ============================================================
class NotificationDetailScreen extends StatefulWidget {
  final AlertItem item;
  final String namaLansia;
  final String namaLengkap;
  final File? fotoFile;
  final NotificationService service;
  final HistoryItem? historyItem;

  const NotificationDetailScreen({
    super.key,
    required this.item,
    required this.namaLansia,
    required this.namaLengkap,
    required this.fotoFile,
    required this.service,
    this.historyItem,
  });

  @override
  State<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  late bool _sudahAman;

  @override
  void initState() {
    super.initState();
    // ── FIX: init dari sudahAman, BUKAN sudahDibaca
    _sudahAman = widget.item.sudahAman;
  }

  Map<String, dynamic> get _levelData {
    switch (widget.item.level) {
      case AlertLevel.tinggi:
        return {
          'label':   'Tinggi',
          'text':    _C.tinggiText,
          'bg':      _C.tinggiBg,
          'badgeBg': _C.tinggiText.withOpacity(0.12),
        };
      case AlertLevel.darurat:
        return {
          'label':   'Darurat',
          'text':    _C.daruratText,
          'bg':      _C.daruratBg,
          'badgeBg': _C.daruratText.withOpacity(0.12),
        };
      case AlertLevel.waspada:
        return {
          'label':   'Waspada',
          'text':    _C.waspadaText,
          'bg':      _C.waspadaBg,
          'badgeBg': _C.waspadaText.withOpacity(0.12),
        };
    }
  }

  // ── FIX: panggil markAsSafe, bukan markAsRead
  Future<void> _tandaiAman() async {
    if (_sudahAman) return;
    await widget.service.markAsSafe(widget.item.id);
    if (mounted) setState(() => _sudahAman = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text('Kejadian ditandai aman', style: TextStyle(fontSize: 13)),
            ],
          ),
          backgroundColor: _C.amanText,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showContactPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ContactPickerSheet(),
    );
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
                    _buildSectionTitle('Lokasi Sekarang'),
                    const SizedBox(height: 8),
                    _buildMapCard(context),
                    const SizedBox(height: 14),
                    _buildSectionTitle('Tindakan'),
                    const SizedBox(height: 8),
                    _buildActionPanel(context),
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
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: _C.primary.withOpacity(0.12),
            backgroundImage:
                widget.fotoFile != null ? FileImage(widget.fotoFile!) : null,
            child: widget.fotoFile == null
                ? Text(
                    widget.namaLengkap.isNotEmpty
                        ? widget.namaLengkap[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _C.primary))
                : null,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Halo, ${widget.namaLengkap}',
                  style: const TextStyle(fontSize: 12, color: _C.textMid)),
              Text('Monitoring ${widget.namaLansia}',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _C.textDark)),
            ],
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
                borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.maybePop(context),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                        color: AppColors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8)),
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
                const Spacer(),
                // Badge "Aman / Aktif" — berdasarkan sudahAman
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _sudahAman
                        ? _C.amanText.withOpacity(0.9)
                        : AppColors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                          _sudahAman
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 12,
                          color: Colors.white),
                      const SizedBox(width: 4),
                      Text(_sudahAman ? 'Aman' : 'Aktif',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(14),
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
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          color: ld['bg'] as Color,
                          borderRadius: BorderRadius.circular(12)),
                      child: Icon(widget.item.icon,
                          size: 22, color: ld['text'] as Color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(widget.item.title,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: _C.textDark))),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: ld['text'] as Color,
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(ld['label'] as String,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.white)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(widget.item.description,
                    style: const TextStyle(
                        fontSize: 13, color: _C.textDark, height: 1.4)),
                const SizedBox(height: 10),
                // Di detail: tampilkan jam + tanggal lengkap
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded,
                        size: 13, color: _C.textMid),
                    const SizedBox(width: 4),
                    Text('${widget.item.time}  ·  ${widget.item.date}',
                        style: const TextStyle(fontSize: 11, color: _C.textMid)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapCard(BuildContext context) {
    final bool hasValidLocation = widget.item.location.latitude != 0.0 ||
        widget.item.location.longitude != 0.0;
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
            borderRadius: hasValidLocation
                ? const BorderRadius.vertical(top: Radius.circular(16))
                : BorderRadius.circular(16),
            child: SizedBox(
              height: 220,
              child: hasValidLocation
                  ? Stack(
                      children: [
                        FlutterMap(
                          options: MapOptions(
                              initialCenter: widget.item.location,
                              initialZoom: 15),
                          children: [
                            TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.guardianwalk.app'),
                            CircleLayer(circles: [
                              CircleMarker(
                                  point: widget.item.location,
                                  radius: 80,
                                  color: _C.waspadaText.withOpacity(0.15),
                                  borderColor: _C.waspadaText,
                                  borderStrokeWidth: 2,
                                  useRadiusInMeter: true)
                            ]),
                            MarkerLayer(markers: [
                              Marker(
                                point: widget.item.location,
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
                                            spreadRadius: 2)
                                      ]),
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
                                  border: Border.all(
                                      color: _C.waspadaText, width: 1)),
                              child: const Text('Posisi Terakhir Lansia',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _C.waspadaText)),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      color: const Color(0xFFF1F5F9),
                      child: const Center(
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                            Icon(Icons.location_off_rounded,
                                size: 36, color: _C.textMid),
                            SizedBox(height: 8),
                            Text('Lokasi tidak tersedia',
                                style:
                                    TextStyle(fontSize: 12, color: _C.textMid)),
                          ])),
                    ),
            ),
          ),
          if (hasValidLocation)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(
                      context, AppRoutes.location,
                      arguments: widget.item.location),
                  icon: const Icon(Icons.navigation_rounded, size: 18),
                  label: const Text('Buka Navigasi ke Lokasi',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _C.primary,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionPanel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          const Text('Apa yang ingin kamu lakukan?',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: _C.textDark)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _showContactPicker,
              icon: const Icon(Icons.phone_rounded, size: 18),
              label: const Text('Hubungi Sekarang',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.tinggiText,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      color: _sudahAman ? _C.amanBg : Colors.transparent,
                      border: Border.all(color: _C.amanText),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _tandaiAman,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _sudahAman
                                  ? Icons.check_circle_rounded
                                  : Icons.check_circle_outline_rounded,
                              size: 16,
                              color: _C.amanText,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _sudahAman ? 'Sudah Aman' : 'Tandai Aman',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _C.amanText),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      if (widget.historyItem != null) {
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst);
                        Navigator.pushNamed(
                          context,
                          AppRoutes.history,
                          arguments: {'openHistoryId': widget.historyItem!.id},
                        );
                      } else {
                        Navigator.pushNamed(context, AppRoutes.history);
                      }
                    },
                    icon: const Icon(Icons.history_rounded,
                        size: 16, color: _C.primary),
                    label: Text(
                      widget.historyItem != null
                          ? 'Lihat di Riwayat'
                          : 'Lihat Riwayat',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _C.primary),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _C.primary),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: _C.primaryLight,
                borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 13, color: _C.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Data sensor detail (IMU, HC-SR04, status sistem) tersedia di menu Riwayat.',
                    style: TextStyle(
                        fontSize: 11,
                        color: _C.primary.withOpacity(0.85),
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}