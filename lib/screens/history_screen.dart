// lib/screens/history_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../database/database_helper.dart';
import 'dart:ui' as ui;
import '../utils/app_colors.dart';
import 'package:latlong2/latlong.dart';
import '../utils/app_routes.dart';
import '../models/history_model.dart';
import '../services/history_service.dart';
import '../services/notification_service.dart';
import '../services/geocoding_service.dart';
import '../services/background_geocode_service.dart'; 
import 'package:firebase_database/firebase_database.dart';
import 'dart:io';
import 'dart:async';

// ── Colors ────────────────────────────────────────────────────
class _C {
  static const Color primary = AppColors.primary;
  static const Color primaryLight = Color(0xFFDBEAFE);
  static const Color white = AppColors.white;
  static const Color textDark = AppColors.textDark;
  static const Color textMid = AppColors.textGrey;

  static const Color bahayaText = AppColors.statusRed;
  static const Color bahayaBg = Color(0xFFFEE2E2);
  static const Color bahayaBorder = Color(0xFFFCA5A5);

  static const Color warnText = AppColors.statusYellow;
  static const Color warnBg = Color(0xFFFFF8E1);
  static const Color warnBorder = Color(0xFFFFD54F);

  static const Color amanText = AppColors.statusGreen;
  static const Color amanBg = Color(0xFFDCFCE7);
  static const Color amanBorder = Color(0xFF86EFAC);

  static const Color infoText = Color(0xFF3B82F6);
  static const Color infoBg = Color(0xFFEFF6FF);
  static const Color infoBorder = Color(0xFFBFDBFE);

  // Warna khusus "mendekati batas" — oranye lebih gelap dari warning biasa
  static const Color nearText = Color(0xFFEA580C);
  static const Color nearBg = Color(0xFFFFF7ED);
  static const Color nearBorder = Color(0xFFFDBA74);

  static const Color offlineText = Color(0xFF92400E);
  static const Color offlineBg = Color(0xFFFEF3C7);
  static const Color offlineBorder = Color(0xFFFBBF24);
}

// ── Screen ────────────────────────────────────────────────────
class HistoryScreen extends StatefulWidget {
  final String? openHistoryId;
  const HistoryScreen({super.key, this.openHistoryId});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _hasOpenedDetail = false;
  String _namaLansia = 'Nama Lansia';
  String _namaUser = 'User';
  File? _fotoFile;
  String? _walkerId;
  NotificationService? _notifService;

  late final HistoryService _service;
  late Stream<List<HistoryItem>> _historyStream;

  String _selectedCategory = 'Semua';
  String _sortOption = 'Terbaru';
  String _searchQuery = '';

  // ── Konektivitas ────────────────────────────────────────────
  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  StreamSubscription<List<HistoryItem>>? _geocodeSub;

  List<HistoryItem> _cachedItems = [];
  bool _loadingCache = false;

  // ── Tab filter (Geofence sekarang cover keluar + mendekati) ─
  final List<Map<String, dynamic>> _tabs = [
    {'label': 'Semua', 'icon': Icons.history_rounded},
    {'label': 'Jatuh', 'icon': Icons.personal_injury_rounded},
    {'label': 'Warning', 'icon': Icons.warning_amber_rounded},
    // "Geofence" sekarang menampilkan KEDUANYA: keluar & mendekati batas
    {'label': 'Geofence', 'icon': Icons.location_off_rounded},
    {'label': 'Sensor', 'icon': Icons.sensors_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _initConnectivity();
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _geocodeSub?.cancel();   
    super.dispose();
  }

  Future<void> _initConnectivity() async {
    final initial = await Connectivity().checkConnectivity();
    _updateOfflineState(initial);
    _connSub = Connectivity().onConnectivityChanged.listen(_updateOfflineState);
  }

  void _updateOfflineState(List<ConnectivityResult> results) {
    final offline =
        results.isEmpty || results.every((r) => r == ConnectivityResult.none);
    if (!mounted) return;
    setState(() => _isOffline = offline);
    if (offline) _loadCache();
  }

  Future<void> _loadCache() async {
    if (_walkerId == null) return;
    setState(() => _loadingCache = true);
    try {
      final items = await _service.getCachedHistory();
      if (!mounted) return;
      setState(() {
        _cachedItems = items;
        _loadingCache = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingCache = false);
    }
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await DatabaseHelper.instance.getProfile();
      final pairedWalkers = await DatabaseHelper.instance.getPairedWalkers();
      final walkerId = pairedWalkers.isNotEmpty
          ? pairedWalkers.first['walker_id']?.toString()
          : null;

      if (!mounted) return;
      setState(() {
        _namaLansia = profile?['nama_lansia']?.toString() ?? _namaLansia;
        _namaUser = profile?['nama']?.toString() ?? 'User';
        _walkerId = walkerId;
        final fotoPath = profile?['foto']?.toString() ?? '';
        if (fotoPath.isNotEmpty && File(fotoPath).existsSync()) {
          _fotoFile = File(fotoPath);
        } else {
          _fotoFile = null;
        }
      });

      if (_walkerId == null) return;
      _service = HistoryService(walkerId: _walkerId!);
      _historyStream = _service.historyStream().asBroadcastStream();
      _notifService = NotificationService(walkerId: _walkerId!);
      _geocodeSub = _historyStream.listen((items) {
        if (!_isOffline && _walkerId != null) {
          BackgroundGeocodeService.instance.scanAndQueue(items, _walkerId!);
        }
      });
      if (_isOffline) _loadCache();
    } catch (e) {
      if (!mounted) return;
      _service = HistoryService(walkerId: 'walker_001');
    }
  }

  List<HistoryItem> _applyFilter(List<HistoryItem> all) {
    List<HistoryItem> list;

    if (_selectedCategory == 'Semua') {
      list = List.from(all);
    } else {
      final catMap = {
        'Jatuh': [
          HistoryCategory.jatuh,
          HistoryCategory.hambatanBelakang,
        ],
        'Warning': [
          HistoryCategory.aktivitas,
          HistoryCategory.hambatanDepan,
        ],
        // Geofence = keluar area (geofence) + mendekati batas (geofenceMendekati)
        'Geofence': [
          HistoryCategory.geofence,
          HistoryCategory.geofenceMendekati,
        ],
        'Sensor': [
          HistoryCategory.sensor,
          HistoryCategory.walker,
        ],
      };
      list = all
          .where((h) => (catMap[_selectedCategory] ?? []).contains(h.category))
          .toList();
    }

    if (_sortOption == 'Bahaya') {
      list = list.where((h) => h.status == HistoryStatus.bahaya).toList();
    } else if (_sortOption == 'Peringatan') {
      list = list.where((h) => h.status == HistoryStatus.peringatan).toList();
    } else if (_sortOption == 'Normal') {
      list = list
          .where((h) =>
              h.status == HistoryStatus.aman || h.status == HistoryStatus.info)
          .toList();
    }

    if (_sortOption == 'Terbaru' || _sortOption == 'Terlama') {
      final asc = _sortOption == 'Terlama';
      list.sort((a, b) {
        final ta = a.rawTimestamp;
        final tb = b.rawTimestamp;
        if (ta != null && tb != null) {
          final cmp = ta.compareTo(tb);
          return asc ? cmp : -cmp;
        }
        if (ta == null && tb == null) return 0;
        return ta == null ? 1 : -1;
      });
    }

    if (_searchQuery.isNotEmpty) {
      list = list.where((item) {
        return item.title.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    return list;
  }

  Map<String, List<HistoryItem>> _grouped(List<HistoryItem> filtered) {
    final Map<String, List<HistoryItem>> g = {};
    for (final item in filtered) {
      g.putIfAbsent(item.date, () => []).add(item);
    }
    return g;
  }

  @override
  Widget build(BuildContext context) {
    if (_walkerId == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF0F4F8),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFB8D4F0),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child:
                    _isOffline ? _buildOfflineBody() : _buildOnlineBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnlineBody() {
    return StreamBuilder<List<HistoryItem>>(
      stream: _historyStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _C.primary));
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_rounded,
                    size: 40, color: _C.textMid),
                const SizedBox(height: 8),
                Text(
                  'Gagal memuat data\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(fontSize: 12, color: _C.textMid),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          );
        }
        final allItems = snapshot.data ?? [];
        return _buildList(allItems, fromCache: false);
      },
    );
  }

  Widget _buildOfflineBody() {
    if (_loadingCache) {
      return const Center(
          child: CircularProgressIndicator(color: _C.primary));
    }
    return _buildList(_cachedItems, fromCache: true);
  }

  Widget _buildList(List<HistoryItem> allItems, {required bool fromCache}) {
    if (!_hasOpenedDetail &&
        widget.openHistoryId != null &&
        allItems.isNotEmpty) {
      final matched =
          allItems.where((item) => item.id == widget.openHistoryId);
      if (matched.isNotEmpty) {
        _hasOpenedDetail = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) =>
                _DetailSheet(item: matched.first, walkerId: _walkerId!),
          );
        });
      }
    }
    final filtered = _applyFilter(allItems);
    final groupedItems = _grouped(filtered);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (fromCache) _offlineBanner(),
          if (fromCache) const SizedBox(height: 12),
          _summaryRow(allItems.length),
          const SizedBox(height: 12),
          _searchBar(),
          const SizedBox(height: 12),
          _categoryTabs(),
          const SizedBox(height: 14),
          if (filtered.isEmpty)
            _emptyState(fromCache: fromCache)
          else
            ...groupedItems.entries.map((e) => _dateSection(e.key, e.value)),
        ],
      ),
    );
  }

  Widget _offlineBanner() => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _C.offlineBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.offlineBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 16, color: _C.offlineText),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sedang offline. Menampilkan riwayat yang tersimpan di perangkat '
                '— data terbaru akan muncul saat koneksi kembali.',
                style: TextStyle(
                    fontSize: 11.5,
                    color: _C.offlineText,
                    height: 1.4),
              ),
            ),
          ],
        ),
      );

  Widget _topBar() => Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        color: const Color(0xFFF0F4F8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary.withOpacity(0.15),
              backgroundImage:
                  _fotoFile != null ? FileImage(_fotoFile!) : null,
              child: _fotoFile == null
                  ? Text(
                      _namaUser.isNotEmpty
                          ? _namaUser[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Hallo, $_namaUser',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textGrey)),
                      if (_isOffline) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.wifi_off_rounded,
                            size: 12, color: _C.offlineText),
                      ],
                    ],
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

  Widget _summaryRow(int total) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _C.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.history_rounded, size: 16, color: _C.primary),
            const SizedBox(width: 8),
            const Text('Total Riwayat',
                style: TextStyle(fontSize: 13, color: _C.textDark)),
            const SizedBox(width: 6),
            Text('$total kejadian',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _C.primary)),
            const Spacer(),
            PopupMenuButton<String>(
              onSelected: (val) async {
                if (val == 'Clear All') {
                  if (_isOffline) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Tidak bisa menghapus riwayat saat offline'),
                      ),
                    );
                    return;
                  }
                  await _service.clearAllHistory();
                  return;
                }
                setState(() => _sortOption = val);
              },
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              offset: const Offset(0, 36),
              itemBuilder: (_) => [
                _sortMenuItem('Terbaru', Icons.arrow_downward_rounded),
                _sortMenuItem('Terlama', Icons.arrow_upward_rounded),
                const PopupMenuDivider(),
                _sortMenuItem('Bahaya', Icons.dangerous_outlined),
                _sortMenuItem('Peringatan', Icons.warning_amber_rounded),
                _sortMenuItem('Normal', Icons.check_circle_outline),
                const PopupMenuDivider(),
                _sortMenuItem('Clear All', Icons.delete_forever),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  Text(_sortOption,
                      style: const TextStyle(
                          fontSize: 11, color: _C.textMid)),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 14, color: _C.textMid),
                ]),
              ),
            ),
          ],
        ),
      );

  Widget _searchBar() {
    return TextField(
      onChanged: (value) => setState(() => _searchQuery = value),
      decoration: InputDecoration(
        hintText: 'Cari riwayat...',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  PopupMenuItem<String> _sortMenuItem(String label, IconData icon) {
    final isActive = _sortOption == label;
    final Color iconColor;
    switch (label) {
      case 'Bahaya':
        iconColor = _C.bahayaText;
        break;
      case 'Peringatan':
        iconColor = _C.warnText;
        break;
      case 'Normal':
        iconColor = _C.amanText;
        break;
      default:
        iconColor = _C.primary;
    }
    return PopupMenuItem<String>(
      value: label,
      child: Row(children: [
        Icon(icon, size: 15, color: isActive ? iconColor : _C.textMid),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight:
                    isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? iconColor : _C.textDark)),
        if (isActive) ...[
          const Spacer(),
          Icon(Icons.check_rounded, size: 14, color: iconColor),
        ],
      ]),
    );
  }

  Widget _categoryTabs() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _tabs.map((tab) {
            final active = _selectedCategory == tab['label'];
            return GestureDetector(
              onTap: () => setState(
                  () => _selectedCategory = tab['label'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? _C.primary : _C.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                      color: active
                          ? _C.primary
                          : const Color(0xFFE2E8F0)),
                  boxShadow: active
                      ? [
                          BoxShadow(
                              color: _C.primary.withOpacity(0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2))
                        ]
                      : [],
                ),
                child: Row(children: [
                  Icon(tab['icon'] as IconData,
                      size: 13,
                      color: active ? Colors.white : _C.textMid),
                  const SizedBox(width: 5),
                  Text(tab['label'] as String,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                              active ? Colors.white : _C.textMid)),
                ]),
              ),
            );
          }).toList(),
        ),
      );

  Widget _dateSection(String date, List<HistoryItem> items) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 8),
            child: Text(date,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _C.textMid)),
          ),
          ...items.map(_historyCard),
        ],
      );

  Widget _historyCard(HistoryItem item) {
    final sd = _sdOf(item.status, item.category);
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _DetailSheet(item: item, walkerId: _walkerId!),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: _C.white,
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: sd.text, width: 3)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: sd.bg,
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(item.icon, size: 20, color: sd.text),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _C.textDark)),
                        const SizedBox(height: 2),
                        Text(item.subtitle,
                            style: const TextStyle(
                                fontSize: 11,
                                color: _C.textMid,
                                height: 1.3)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(item.time,
                          style: const TextStyle(
                              fontSize: 11, color: _C.textMid)),
                      PopupMenuButton(
                        icon: const Icon(Icons.more_vert, size: 16),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'delete',
                            enabled: !_isOffline,
                            child: Text(_isOffline
                                ? 'Hapus (perlu online)'
                                : 'Hapus'),
                          )
                        ],
                        onSelected: (value) async {
                          if (value == 'delete' && !_isOffline) {
                            await _service.deleteHistory(item.id);
                          }
                        },
                      )
                    ],
                  ),
                ],
              ),
              if (item.meta.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: item.meta.entries
                      .take(3)
                      .map((e) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${e.key}: ',
                                  style: const TextStyle(
                                      fontSize: 11, color: _C.textMid)),
                              Text(e.value,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _C.textDark)),
                            ],
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: sd.bg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: sd.border),
                  ),
                  child: Text(sd.label,
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: sd.text)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState({bool fromCache = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Column(children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                  color: _C.primaryLight,
                  borderRadius: BorderRadius.circular(18)),
              child: const Icon(Icons.history_rounded,
                  size: 32, color: _C.primary),
            ),
            const SizedBox(height: 12),
            Text(
              fromCache
                  ? 'Belum ada riwayat tersimpan di perangkat'
                  : 'Tidak ada riwayat',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _C.textDark),
            ),
          ]),
        ),
      );

  // ── _sdOf sekarang menerima category untuk membedakan mendekati vs keluar ─
  static _StatusDesign _sdOf(HistoryStatus s, [HistoryCategory? cat]) {
    // Khusus mendekati batas: gunakan warna oranye meski status "peringatan"
    if (cat == HistoryCategory.geofenceMendekati) {
      return _StatusDesign(
          'MENDEKATI', _C.nearText, _C.nearBg, _C.nearBorder);
    }
    switch (s) {
      case HistoryStatus.bahaya:
        return _StatusDesign(
            'BAHAYA', _C.bahayaText, _C.bahayaBg, _C.bahayaBorder);
      case HistoryStatus.peringatan:
        return _StatusDesign(
            'PERINGATAN', _C.warnText, _C.warnBg, _C.warnBorder);
      case HistoryStatus.aman:
        return _StatusDesign(
            'NORMAL', _C.amanText, _C.amanBg, _C.amanBorder);
      case HistoryStatus.info:
        return _StatusDesign(
            'INFO', _C.infoText, _C.infoBg, _C.infoBorder);
    }
  }
}

// ============================================================
// WIDGET NAMA LOKASI -- resolve otomatis via reverse geocoding
// kalau lokasiNama dari Firebase masih placeholder ("Unknown" /
// "Koordinat GPS" / kosong). Hasil geocoding disimpan balik ke
// Firebase supaya kunjungan berikutnya tidak perlu geocode ulang.
// ============================================================
class _ResolvedLocationName extends StatefulWidget {
  final String? initialLokasiNama;
  final String? lokasiKoordinat;
  final String historyId;
  final String walkerId;

  const _ResolvedLocationName({
    required this.initialLokasiNama,
    required this.lokasiKoordinat,
    required this.historyId,
    required this.walkerId,
  });

  @override
  State<_ResolvedLocationName> createState() => _ResolvedLocationNameState();
}

class _ResolvedLocationNameState extends State<_ResolvedLocationName> {
  String? _resolvedName;
  bool _loading = false;

  bool get _needsGeocoding =>
      GeocodingService.needsGeocoding(widget.initialLokasiNama);

  @override
  void initState() {
    super.initState();
    if (_needsGeocoding && widget.lokasiKoordinat != null) {
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final coord = GeocodingService.parseCoordString(widget.lokasiKoordinat);
    if (coord == null) return;

    setState(() => _loading = true);

    final nama = await GeocodingService.getLocationName(coord.lat, coord.lng);

    if (!mounted) return;
    setState(() {
      _resolvedName = nama;
      _loading = false;
    });

    // Simpan balik ke Firebase supaya history ini permanen punya nama
    // lokasi asli, tidak perlu geocode ulang tiap kali dibuka lagi.
    final berhasil = nama != GeocodingService.fallbackNotFound &&
        nama != GeocodingService.fallbackNoGps;
    if (berhasil) {
      FirebaseDatabase.instance
          .ref('Walkers/${widget.walkerId}/history/${widget.historyId}/lokasiNama')
          .set(nama)
          .catchError((_) {
        // Gagal simpan balik tidak masalah -- nama tetap tampil di layar,
        // cuma next time bakal geocode ulang.
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String display;
    if (!_needsGeocoding) {
      display = widget.initialLokasiNama!;
    } else if (_loading) {
      display = 'Memuat nama lokasi...';
    } else if (_resolvedName != null) {
      display = _resolvedName!;
    } else {
      display = widget.initialLokasiNama ?? '-';
    }

    return Expanded(
      child: Text(
        display,
        textAlign: TextAlign.right,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _C.textDark,
        ),
      ),
    );
  }
}

// ============================================================
// DETAIL SHEET
// ============================================================
class _DetailSheet extends StatelessWidget {
  final HistoryItem item;
  final String walkerId;
  const _DetailSheet({required this.item, required this.walkerId});

  _StatusDesign get sd =>
      _HistoryScreenState._sdOf(item.status, item.category);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.97,
      minChildSize: 0.6,
      maxChildSize: 0.97,
      expand: false,
      snap: false,
      builder: (_, controller) => Container(
        height: MediaQuery.of(context).size.height * 0.96,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(24),
            bottom: Radius.circular(22),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2)),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
                children: [
                  _hero(),
                  // Banner khusus "mendekati batas"
                  if (item.category ==
                      HistoryCategory.geofenceMendekati) ...[
                    const SizedBox(height: 12),
                    _nearBoundaryBanner(),
                  ],
                  if (item.category == HistoryCategory.hambatanBelakang &&
                      item.status == HistoryStatus.bahaya) ...[
                    const SizedBox(height: 12),
                    _warningBanner(),
                  ],
                  const SizedBox(height: 12),
                  _infoKejadian(),
                  const SizedBox(height: 12),
                  if (item.extra.hcsrJarak != null) ...[
                    _hcsrSection(),
                    const SizedBox(height: 12),
                  ],
                  if (item.extra.distanceData.isNotEmpty) ...[
                    _distanceChart(),
                    const SizedBox(height: 12),
                  ],
                  if (item.extra.sensorData.isNotEmpty) ...[
                    _imuChart(),
                    const SizedBox(height: 12),
                    if (item.extra.dataTerukur.isNotEmpty) ...[
                      _nilaiTerukur(),
                      const SizedBox(height: 12),
                    ],
                  ],
                  if (item.extra.ringkasanSensor != null) ...[
                    _ringkasanSensor(),
                    const SizedBox(height: 12),
                  ],
                  if (item.extra.lokasiNama != null) ...[
                    _lokasiSection(context),
                    const SizedBox(height: 12),
                  ],
                  if (item.extra.statusSistem != null) ...[
                    _statusSistem(),
                    const SizedBox(height: 12),
                  ],
                  if (item.extra.tindakanSistem.isNotEmpty) ...[
                    _tindakanSistem(),
                    const SizedBox(height: 20),
                  ],
                  _closeBtn(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: sd.bg, borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: sd.text.withOpacity(0.13),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(item.icon, size: 34, color: sd.text),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: sd.text)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                        color: sd.text,
                        borderRadius: BorderRadius.circular(16)),
                    child: Text(sd.label,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ),
                  const SizedBox(height: 4),
                  Text('${item.date}  ·  ${item.time}',
                      style: TextStyle(
                          fontSize: 11,
                          color: sd.text.withOpacity(0.7))),
                ],
              ),
            ),
          ],
        ),
      );

  // ── Banner khusus mendekati batas ──────────────────────────
  Widget _nearBoundaryBanner() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _C.nearBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.nearBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.location_searching_rounded,
                size: 16, color: _C.nearText),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: const TextSpan(
                  style: TextStyle(
                      fontSize: 12,
                      color: _C.nearText,
                      height: 1.5),
                  children: [
                    TextSpan(
                        text: 'Peringatan dini: ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(
                        text: 'Lansia mendekati batas area aman. '
                            'Pantau posisi lebih sering dan pastikan '
                            'lansia tidak melanjutkan keluar area.'),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _warningBanner() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFBBF24)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded,
                size: 16, color: Color(0xFFF59E0B)),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: const TextSpan(
                  style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF92400E),
                      height: 1.5),
                  children: [
                    TextSpan(
                        text: 'Sensor belakang ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: 'TIDAK'),
                    TextSpan(
                        text: ' mendeteksi adanya lansia. '
                            'Ini dapat mengindikasikan potensi jatuh.'),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _infoKejadian() {
    final e = item.extra;
    return _card(
      title: 'Informasi Kejadian',
      child: Column(
        children: [
          _kvRow('Jenis Kejadian', e.jenisKejadian),
          if (e.skorAnomali != null)
            _kvRow('Skor Anomali', e.skorAnomali!.toStringAsFixed(2),
                highlight: true),
          _kvRow('Status Deteksi Lansia', e.statusDeteksiLansia,
              highlight: e.statusDeteksiLansia.contains('Tidak')),
          _kvRow('Jarak Terukur', e.jarakTerukur),
          _kvRow('Waktu Kejadian', '${item.date}  ${item.time}'),
          _kvRow('Sensor', e.sensor),
          _kvRow('Status Bahaya', e.statusBahaya, highlight: true),
        ],
      ),
    );
  }

  Widget _hcsrSection() {
    final e = item.extra;
    final jarak = e.hcsrJarak!;
    final threshold = e.hcsrThreshold ?? 60.0;
    final isBelakang = item.category == HistoryCategory.hambatanBelakang;

    final Color statusColor = isBelakang
        ? (jarak > threshold ? _C.bahayaText : _C.amanText)
        : (jarak < threshold ? _C.warnText : _C.amanText);

    final String statusLower = (e.hcsrStatus ?? '').toLowerCase();
    final Color finalStatusColor = statusLower.contains('tidak terdeteksi')
        ? (item.status == HistoryStatus.bahaya
            ? _C.bahayaText
            : _C.warnText)
        : statusLower.contains('terdeteksi') &&
                !statusLower.contains('tidak')
            ? _C.amanText
            : statusLower.contains('hambatan')
                ? _C.warnText
                : statusColor;

    final String statusText = e.hcsrStatus ??
        (isBelakang
            ? (jarak > threshold ? 'Tidak Terdeteksi' : 'Terdeteksi')
            : (jarak < threshold ? 'Ada Hambatan' : 'Aman'));

    final String sensorName =
        isBelakang ? 'HC-SR04 Belakang' : 'HC-SR04 Depan';

    return _card(
      title: 'Beat Sonar Pelacak ($sensorName)',
      child: Column(
        children: [
          Row(children: [
            _sonarCol('Jarak Terukur',
                '${jarak.toStringAsFixed(0)} cm', _C.textDark),
            _sonarCol(
                'Batas Aman',
                '≤ ${threshold.toStringAsFixed(0)} cm',
                _C.warnText),
            _sonarCol('Status', statusText, finalStatusColor),
          ]),
          if (isBelakang) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:
                    jarak > threshold ? _C.bahayaBg : _C.amanBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 14,
                      color: jarak > threshold
                          ? _C.bahayaText
                          : _C.amanText),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      jarak > threshold
                          ? 'Jika jarak > ${threshold.toStringAsFixed(0)} cm dan tidak terdeteksi lansia selama lebih dari 5 detik, sistem akan mengindikasikan potensi jatuh.'
                          : 'Lansia terdeteksi dalam jangkauan aman.',
                      style: TextStyle(
                          fontSize: 11,
                          height: 1.4,
                          color: jarak > threshold
                              ? _C.bahayaText
                              : _C.amanText),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sonarCol(String label, String value, Color color) => Expanded(
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 10, color: _C.textMid),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ]),
      );

  Widget _distanceChart() {
    final isBelakang =
        item.category == HistoryCategory.hambatanBelakang;
    return _card(
      title: 'Jarak Sensor (Belakang & Depan)',
      child: ClipRect(
        child: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: SizedBox(
            height: 160,
            child: CustomPaint(
              painter: _DistanceChartPainter(
                data: item.extra.distanceData,
                lineColor: isBelakang
                    ? (item.status == HistoryStatus.bahaya
                        ? _C.bahayaText
                        : _C.amanText)
                    : _C.warnText,
                threshold: item.extra.hcsrThreshold ?? 60,
              ),
              size: Size.infinite,
            ),
          ),
        ),
      ),
    );
  }

  Widget _imuChart() => _card(
        title: 'Data Sensor IMU Saat Kejadian',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              _legendLine(
                  const Color(0xFF3B82F6), 'Akselerometer (g)'),
              const SizedBox(width: 16),
              _legendLine(
                  const Color(0xFF10B981), 'Gyroscope (°/s)'),
            ]),
            const SizedBox(height: 10),
            SizedBox(
              height: 150,
              child: CustomPaint(
                painter:
                    _SensorChartPainter(item.extra.sensorData),
                size: Size.infinite,
              ),
            ),
          ],
        ),
      );

  Widget _legendLine(Color c, String label) => Row(children: [
        Container(
            width: 18,
            height: 3,
            decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 5),
        Text(label,
            style:
                const TextStyle(fontSize: 11, color: _C.textMid)),
      ]);

  Widget _nilaiTerukur() {
    final entries = item.extra.dataTerukur.entries.toList();
    final rows = <List<MapEntry<String, String>>>[];
    for (var i = 0; i < entries.length; i += 3) {
      rows.add(entries.sublist(
          i, (i + 3 > entries.length) ? entries.length : i + 3));
    }
    return _card(
      title: 'Nilai Terukur IMU',
      child: Column(
        children: rows
            .map((row) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: row
                        .map((e) => Expanded(
                              child: Column(children: [
                                Text(e.value,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: _C.textDark)),
                                Text(e.key,
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: _C.textMid)),
                              ]),
                            ))
                        .toList(),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _ringkasanSensor() {
    final r = item.extra.ringkasanSensor!;
    return _card(
      title: 'Ringkasan Sensor Terkait',
      child: Column(children: [
        _sensorRow('HC-SR04 Depan', r.hcsr04Depan, r.statusDepan),
        _sensorRow(
            'HC-SR04 Belakang', r.hcsr04Belakang, r.statusBelakang),
        _sensorRow('IMU (MPU6050)', r.mpu6050, r.statusMpu),
        _sensorRow('Lokasi GPS', r.gpsJarak, r.statusGps),
      ]),
    );
  }

  Widget _sensorRow(String name, String value, String status) {
    final Color c = (status.toLowerCase().contains('tidak') ||
            status.toLowerCase().contains('hambatan') ||
            status.toLowerCase().contains('anomali'))
        ? _C.bahayaText
        : _C.amanText;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(
            child: Text(name,
                style: const TextStyle(
                    fontSize: 12, color: _C.textMid))),
        Text(value,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _C.textDark)),
        const SizedBox(width: 10),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: c.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(status,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: c)),
        ),
      ]),
    );
  }
Widget _lokasiSection(BuildContext context) {
    final e = item.extra;
    final coord = () {
      try {
        final parts =
            (e.lokasiKoordinat ?? '-7.9711,112.6328').split(',');
        return LatLng(
          double.parse(parts[0].trim()),
          double.parse(parts[1].trim()),
        );
      } catch (_) {
        return const LatLng(-7.9711, 112.6328);
      }
    }();

    // ── Warna PIN lokasi -- boleh ikut tingkat keparahan event
    // (jatuh/tidak terdeteksi tetap merah, sebagai penanda "ini kejadian
    // penting", terlepas dari status geofence-nya).
    final Color pinColor;
    switch (item.status) {
      case HistoryStatus.bahaya:
        pinColor = _C.bahayaText;
        break;
      case HistoryStatus.peringatan:
        pinColor = item.category == HistoryCategory.geofenceMendekati
            ? _C.nearText
            : _C.warnText;
        break;
      case HistoryStatus.aman:
        pinColor = _C.amanText;
        break;
      case HistoryStatus.info:
        pinColor = _C.infoText;
        break;
    }

    // ── Warna LINGKARAN geofence -- HARUS berdasarkan status geofence
    // sebenarnya (di dalam/luar area aman), BUKAN ikut tingkat keparahan
    // event. Jatuh/tidak terdeteksi saat lansia masih di dalam geofence
    // tetap harus tampil HIJAU di lingkaran ini.
    final String geoStatus = (e.kondisiGeofence).toLowerCase();
    final Color geofenceColor;
    if (geoStatus.contains('luar') || geoStatus.contains('keluar')) {
      geofenceColor = _C.bahayaText;
    } else if (geoStatus.contains('dekat') || geoStatus.contains('mendekati')) {
      geofenceColor = _C.nearText;
    } else {
      // "dalam", "aman", "inside", atau status tidak dikenali -> anggap aman
      geofenceColor = _C.amanText;
    }

    return _card(
      title: 'Informasi Lokasi',
      icon: Icons.location_on_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 160,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: coord,
                  initialZoom: 15,
                  interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.guardianwalk.app',
                  ),
                  CircleLayer(circles: [
                    CircleMarker(
                      point: coord,
                      radius: 80,
                      color: geofenceColor.withOpacity(0.12),
                      borderColor: geofenceColor,
                      borderStrokeWidth: 2,
                      useRadiusInMeter: true,
                    ),
                  ]),
                  MarkerLayer(markers: [
                    Marker(
                      point: coord,
                      width: 40,
                      height: 40,
                      child: Icon(Icons.location_pin,
                          color: pinColor, size: 40),
                    ),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Text('Lat: ${coord.latitude.toStringAsFixed(4)}',
                  style: const TextStyle(
                      fontSize: 11, color: _C.textMid)),
              Text('Lng: ${coord.longitude.toStringAsFixed(4)}',
                  style: const TextStyle(
                      fontSize: 11, color: _C.textMid)),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              const Text('Lokasi',
                  style: TextStyle(fontSize: 13, color: _C.textMid)),
              const SizedBox(width: 8),
              _ResolvedLocationName(
                initialLokasiNama: e.lokasiNama,
                lokasiKoordinat: e.lokasiKoordinat,
                historyId: item.id,
                walkerId: walkerId,
              ),
            ]),
          ),
          _kvRow('Status Geofence', e.kondisiGeofence),
          if (e.lokasiJarakPusat != null)
            _kvRow('Jarak dari Pusat', e.lokasiJarakPusat!),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.location),
              icon: const Icon(Icons.map_outlined,
                  size: 16, color: _C.primary),
              label: const Text('Lihat Lokasi',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _C.primary)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: _C.primary.withOpacity(0.9)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: Colors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusSistem() {
    final ss = item.extra.statusSistem!;
    return _card(
      title: 'Status Sistem Saat Kejadian',
      child: Row(children: [
        Expanded(
          child: _systemStatusCard(
            title: 'GSM Network',
            value: ss.gsmConnected ? 'Aktif' : 'Nonaktif',
            icon: Icons.signal_cellular_alt_rounded,
            isActive: ss.gsmConnected,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _systemStatusCard(
            title: 'GPS',
            value: ss.gpsConnected ? 'Aktif' : 'Nonaktif',
            icon: Icons.gps_fixed_rounded,
            isActive: ss.gpsConnected,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _systemStatusCard(
            title: 'IMU Sensor',
            value: ss.imuNormal ? 'Normal' : 'Anomali',
            icon: Icons.sensors_rounded,
            isActive: ss.imuNormal,
          ),
        ),
      ]),
    );
  }

  Widget _systemStatusCard({
    required String title,
    required String value,
    required IconData icon,
    required bool isActive,
  }) {
    final Color color = isActive ? _C.amanText : _C.bahayaText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 6),
        Text(title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _C.textMid)),
      ]),
    );
  }

  Widget _tindakanSistem() => _card(
        title: 'Tindakan Sistem',
        child: Column(
          children: item.extra.tindakanSistem
              .map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      const Icon(Icons.check_circle_rounded,
                          size: 16, color: _C.amanText),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(t,
                              style: const TextStyle(
                                  fontSize: 13, color: _C.textDark))),
                    ]),
                  ))
              .toList(),
        ),
      );

  Widget _closeBtn(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: _C.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('Kembali ke History',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      );

  Widget _kvRow(String k, String v, {bool highlight = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Expanded(
              child: Text(k,
                  style: const TextStyle(
                      fontSize: 13, color: _C.textMid))),
          Text(v,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: highlight ? sd.text : _C.textDark)),
        ]),
      );

  Widget _card({
    required String title,
    IconData? icon,
    required Widget child,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _C.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: _C.primary),
                const SizedBox(width: 6),
              ],
              Text(title,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _C.textDark)),
            ]),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
}

// ============================================================
// CHART PAINTERS (tidak berubah)
// ============================================================
class _DistanceChartPainter extends CustomPainter {
  final List<DistanceDataPoint> data;
  final Color lineColor;
  final double threshold;
  const _DistanceChartPainter({
    required this.data,
    required this.lineColor,
    required this.threshold,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    const double padL = 44, padB = 22, padT = 20, padR = 10;
    final w = size.width - padL - padR;
    final h = size.height - padT - padB;
    const double minVal = 0, maxVal = 120;

    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;
    final threshPaint = Paint()
      ..color = const Color(0xFFFBBF24).withOpacity(0.9)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final tp = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i <= 4; i++) {
      final y = padT + h * i / 4;
      canvas.drawLine(
          Offset(padL, y), Offset(padL + w, y), gridPaint);
      final val = maxVal - (maxVal - minVal) * i / 4;
      tp.text = TextSpan(
          text: '${val.toStringAsFixed(0)} cm',
          style: const TextStyle(
              fontSize: 8, color: Color(0xFFCBD5E1)));
      tp.layout();
      tp.paint(canvas, Offset(0, y - 5));
    }

    final ty = padT +
        h * (1 - (threshold - minVal) / (maxVal - minVal));
    canvas.drawLine(
        Offset(padL, ty), Offset(padL + w, ty), threshPaint);

    if (data.length < 2) {
      final barW = w / (data.length * 2);
      for (int i = 0; i < data.length; i++) {
        final x = padL + (i * 2 + 0.5) * barW;
        final yTop = padT +
            h * (1 - (data[i].distance - minVal) / (maxVal - minVal));
        final barPaint = Paint()
          ..color = lineColor.withOpacity(0.7)
          ..style = PaintingStyle.fill;
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(x, yTop, barW, padT + h - yTop),
                const Radius.circular(3)),
            barPaint);
        tp.text = TextSpan(
            text: data[i].label,
            style: const TextStyle(
                fontSize: 8, color: Color(0xFFCBD5E1)));
        tp.layout();
        tp.paint(canvas,
            Offset(x + barW / 2 - tp.width / 2, size.height - padB + 4));
      }
      return;
    }

    final stepX = w / (data.length - 1);
    for (int i = 0; i < data.length; i++) {
      tp.text = TextSpan(
          text: data[i].label,
          style: const TextStyle(
              fontSize: 8, color: Color(0xFFCBD5E1)));
      tp.layout();
      tp.paint(canvas,
          Offset(padL + stepX * i - tp.width / 2, size.height - padB + 4));
    }

    double yFor(double val) =>
        padT + h * (1 - (val - minVal) / (maxVal - minVal));

    final ui.Path fillPath = ui.Path();
    for (int i = 0; i < data.length; i++) {
      final x = padL + stepX * i;
      final y = yFor(data[i].distance);
      if (i == 0) {
        fillPath.moveTo(x, y);
      } else {
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(padL + stepX * (data.length - 1), padT + h);
    fillPath.lineTo(padL, padT + h);
    fillPath.close();
    canvas.drawPath(
        fillPath,
        Paint()
          ..color = lineColor.withOpacity(0.08)
          ..style = PaintingStyle.fill);

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final ui.Path linePath = ui.Path();
    for (int i = 0; i < data.length; i++) {
      final x = padL + stepX * i;
      final y = yFor(data[i].distance);
      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
    }
    canvas.drawPath(linePath, linePaint);

    final dotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;
    for (int i = 0; i < data.length; i++) {
      canvas.drawCircle(
          Offset(padL + stepX * i, yFor(data[i].distance)),
          3.5,
          dotPaint);
    }
  }

  @override
  bool shouldRepaint(_DistanceChartPainter old) => false;
}

class _SensorChartPainter extends CustomPainter {
  final List<SensorDataPoint> data;
  const _SensorChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    double minVal = double.infinity, maxVal = double.negativeInfinity;
    for (final d in data) {
      if (d.accel < minVal) minVal = d.accel;
      if (d.gyro < minVal) minVal = d.gyro;
      if (d.accel > maxVal) maxVal = d.accel;
      if (d.gyro > maxVal) maxVal = d.gyro;
    }
    minVal = (minVal - 0.5).floorToDouble();
    maxVal = (maxVal + 0.5).ceilToDouble();
    final range = maxVal - minVal;
    if (range == 0) return;

    final w = size.width;
    final h = size.height;

    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      canvas.drawLine(
          Offset(0, h * i / 4), Offset(w, h * i / 4), gridPaint);
    }

    double yFor(double val) => h - ((val - minVal) / range) * h;

    void drawLine(List<double> vals, Color color) {
      if (vals.length < 2) {
        canvas.drawCircle(
            Offset(w / 2, yFor(vals.first)),
            5,
            Paint()
              ..color = color
              ..style = PaintingStyle.fill);
        return;
      }
      final stepX = w / (vals.length - 1);
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final ui.Path path = ui.Path();
      for (int i = 0; i < vals.length; i++) {
        final x = stepX * i;
        final y = yFor(vals[i]);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
      final dot = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      for (int i = 0; i < vals.length; i++) {
        canvas.drawCircle(Offset(stepX * i, yFor(vals[i])), 3, dot);
      }
    }

    drawLine(
        data.map((d) => d.accel).toList(), const Color(0xFF3B82F6));
    drawLine(
        data.map((d) => d.gyro).toList(), const Color(0xFF10B981));
  }

  @override
  bool shouldRepaint(_SensorChartPainter old) => false;
}

// ── Status Design ──────────────────────────────────────────────
class _StatusDesign {
  final String label;
  final Color text;
  final Color bg;
  final Color border;
  const _StatusDesign(this.label, this.text, this.bg, this.border);
}