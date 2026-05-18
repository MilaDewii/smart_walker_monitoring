import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

// ============================================================
// COLORS
// ============================================================
class _C {
  static const Color primary      = AppColors.primary;
  static const Color secondary    = AppColors.secondary;
  static const Color primaryLight = Color(0xFFDBEAFE);
  static const Color bgPage       = Color(0xFFF0F4FA);
  static const Color white        = AppColors.white;
  static const Color textDark     = AppColors.textDark;
  static const Color textMid      = AppColors.textGrey;

  static const Color bahayaText     = AppColors.statusRed;
  static const Color bahayaBg       = Color(0xFFFEE2E2);
  static const Color bahayaBorder   = Color(0xFFFCA5A5);
  static const Color peringatanText = AppColors.statusYellow;
  static const Color peringatanBg   = Color(0xFFFFF8E1);
  static const Color peringatanBorder = Color(0xFFFFD54F);
  static const Color amanText       = AppColors.statusGreen;
  static const Color amanBg         = Color(0xFFDCFCE7);
  static const Color amanBorder     = Color(0xFF86EFAC);
}

// ============================================================
// MODEL
// ============================================================
enum HistoryCategory { jatuh, geofence, aktivitas, sensor, walker }
enum HistoryStatus   { bahaya, peringatan, aman }

class HistoryItem {
  final String id;
  final String title;
  final String subtitle;
  final String detail;
  final String time;
  final String date;
  final HistoryCategory category;
  final HistoryStatus status;
  final IconData icon;
  final Map<String, String> meta;

  const HistoryItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.time,
    required this.date,
    required this.category,
    required this.status,
    required this.icon,
    this.meta = const {},
  });
}

// ============================================================
// DUMMY DATA
// ============================================================
final List<HistoryItem> _dummyHistory = [
  HistoryItem(
    id: '1',
    title: 'Potensi Jatuh Terdeteksi',
    subtitle: 'Gerakan mendadak ke bawah terdeteksi sensor MPU6050',
    detail: 'Gerakan jatuh terdeteksi oleh sensor MPU6050. Lansia terdeteksi melakukan gerakan mendadak ke bawah dengan skor anomali tinggi.',
    time: '11:24 AM',
    date: '08 April 2025',
    category: HistoryCategory.jatuh,
    status: HistoryStatus.bahaya,
    icon: Icons.personal_injury_rounded,
    meta: {'Skor Anomali': '0.82 / 1.00', 'Durasi': '23 detik', 'Sensor': 'MPU6050'},
  ),
  HistoryItem(
    id: '2',
    title: 'Keluar Area Aman',
    subtitle: 'Lansia melewati batas radius geofence',
    detail: 'Posisi lansia terdeteksi berada di luar radius geofence yang telah ditentukan oleh keluarga.',
    time: '09:12 AM',
    date: '08 April 2025',
    category: HistoryCategory.geofence,
    status: HistoryStatus.peringatan,
    icon: Icons.location_off_rounded,
    meta: {'Lokasi': 'Jl. Veteran', 'Radius Keluar': '> 10 meter', 'Koordinat': '-7.250, 112.768'},
  ),
  HistoryItem(
    id: '3',
    title: 'Aktivitas Tidak Normal',
    subtitle: 'Akselerasi melebihi batas threshold sistem',
    detail: 'Nilai akselerasi terdeteksi sangat tinggi melebihi batas normal yang ditetapkan sistem pemantauan.',
    time: '14:21 PM',
    date: '08 April 2025',
    category: HistoryCategory.aktivitas,
    status: HistoryStatus.peringatan,
    icon: Icons.directions_run_rounded,
    meta: {'Nilai Akselerasi': '1.8g', 'Threshold': '1.2g', 'Sensor': 'MPU6050'},
  ),
  HistoryItem(
    id: '4',
    title: 'Semua Sensor Aktif',
    subtitle: 'Pengecekan rutin — semua sensor normal',
    detail: 'Seluruh sensor perangkat terdeteksi aktif dan berjalan normal pada pengecekan berkala.',
    time: '08:00 AM',
    date: '08 April 2025',
    category: HistoryCategory.sensor,
    status: HistoryStatus.aman,
    icon: Icons.sensors_rounded,
    meta: {'MPU6050': 'Aktif', 'GPS': 'Aktif', 'Ultrasonik': 'Aktif'},
  ),
  HistoryItem(
    id: '5',
    title: 'GPS Disconnect',
    subtitle: 'Sinyal GPS terputus secara tiba-tiba',
    detail: 'Koneksi GPS gagal selama beberapa menit. Harap periksa perangkat dan pastikan sinyal tersedia.',
    time: '08:20 AM',
    date: '08 April 2025',
    category: HistoryCategory.sensor,
    status: HistoryStatus.bahaya,
    icon: Icons.gps_off_rounded,
    meta: {'Sensor': 'GPS', 'Status': 'Disconnect', 'Durasi Off': '± 5 menit'},
  ),
  HistoryItem(
    id: '6',
    title: 'Walker Aman',
    subtitle: 'Sesi monitoring selesai tanpa anomali',
    detail: 'Semua parameter pemantauan dalam kondisi normal selama sesi monitoring pagi. Tidak ada aktivitas mencurigakan.',
    time: '07:00 AM',
    date: '08 April 2025',
    category: HistoryCategory.walker,
    status: HistoryStatus.aman,
    icon: Icons.elderly_rounded,
    meta: {'Durasi Monitoring': '60 menit', 'Langkah': '842 langkah', 'Status Sensor': 'Normal'},
  ),
  HistoryItem(
    id: '7',
    title: 'Potensi Jatuh Terdeteksi',
    subtitle: 'Deteksi saat posisi berbaring mendadak malam hari',
    detail: 'Deteksi jatuh terjadi saat posisi berbaring mendadak pada malam hari. Skor anomali sangat tinggi.',
    time: '22:45 PM',
    date: '07 April 2025',
    category: HistoryCategory.jatuh,
    status: HistoryStatus.bahaya,
    icon: Icons.personal_injury_rounded,
    meta: {'Skor Anomali': '0.91 / 1.00', 'Durasi': '17 detik', 'Sensor': 'MPU6050'},
  ),
  HistoryItem(
    id: '8',
    title: 'Aktivitas Normal',
    subtitle: 'Pola gerakan dalam batas aman threshold',
    detail: 'Akselerasi dan gyroscope berada dalam batas normal selama sesi pemantauan sore hari.',
    time: '15:30 PM',
    date: '07 April 2025',
    category: HistoryCategory.aktivitas,
    status: HistoryStatus.aman,
    icon: Icons.directions_walk_rounded,
    meta: {'Nilai Maks': '0.9g', 'Threshold': '1.2g', 'Gyroscope': 'Normal'},
  ),
];

// ============================================================
// HISTORY SCREEN
// ============================================================
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _selectedStatus   = 'Semua';
  String _selectedCategory = 'Semua';

  final List<String> _statusFilters = ['Semua', 'Bahaya', 'Peringatan', 'Aman'];

  final List<Map<String, dynamic>> _categoryTabs = [
    {'label': 'Semua',     'icon': Icons.history_rounded},
    {'label': 'Jatuh',     'icon': Icons.personal_injury_rounded},
    {'label': 'Geofence',  'icon': Icons.location_off_rounded},
    {'label': 'Aktivitas', 'icon': Icons.directions_run_rounded},
    {'label': 'Sensor',    'icon': Icons.sensors_rounded},
    {'label': 'Walker',    'icon': Icons.elderly_rounded},
  ];

  List<HistoryItem> get _filtered {
    var list = List<HistoryItem>.from(_dummyHistory);
    if (_selectedCategory != 'Semua') {
      final catMap = {
        'Jatuh'    : HistoryCategory.jatuh,
        'Geofence' : HistoryCategory.geofence,
        'Aktivitas': HistoryCategory.aktivitas,
        'Sensor'   : HistoryCategory.sensor,
        'Walker'   : HistoryCategory.walker,
      };
      list = list.where((h) => h.category == catMap[_selectedCategory]).toList();
    }
    if (_selectedStatus != 'Semua') {
      final stMap = {
        'Bahaya'    : HistoryStatus.bahaya,
        'Peringatan': HistoryStatus.peringatan,
        'Aman'      : HistoryStatus.aman,
      };
      list = list.where((h) => h.status == stMap[_selectedStatus]).toList();
    }
    return list;
  }

  Map<String, List<HistoryItem>> get _grouped {
    final Map<String, List<HistoryItem>> g = {};
    for (final item in _filtered) {
      g.putIfAbsent(item.date, () => []).add(item);
    }
    return g;
  }

  int get _totalBahaya     => _dummyHistory.where((h) => h.status == HistoryStatus.bahaya).length;
  int get _totalPeringatan => _dummyHistory.where((h) => h.status == HistoryStatus.peringatan).length;
  int get _totalAman       => _dummyHistory.where((h) => h.status == HistoryStatus.aman).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBar(),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F0FB),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                clipBehavior: Clip.hardEdge,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatCards(),
                      const SizedBox(height: 20),
                      _buildCategoryScroll(),
                      const SizedBox(height: 12),
                      _buildStatusChips(),
                      const SizedBox(height: 6),
                      _buildResultCount(),
                      const SizedBox(height: 10),
                      if (_filtered.isEmpty)
                        _buildEmpty()
                      else
                        ..._grouped.entries.map((e) =>
                            _buildDateSection(e.key, e.value)),
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

  // ── Top Bar ──────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      color: const Color(0xFFF0F4F8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _C.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 18, color: _C.textDark),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Riwayat Monitoring',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _C.textDark)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _C.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.history_rounded, size: 14, color: _C.primary),
                    const SizedBox(width: 4),
                    Text('${_dummyHistory.length} Log',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _C.primary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: _C.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                Icon(Icons.search_rounded,
                    color: _C.textMid.withOpacity(0.6), size: 20),
                const SizedBox(width: 8),
                Text('Cari riwayat kejadian...',
                    style: TextStyle(
                        color: _C.textMid.withOpacity(0.6), fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Stat Cards ───────────────────────────────────────────
  Widget _buildStatCards() {
    return Row(
      children: [
        _buildStatCard(
          count: _totalBahaya,
          label: 'Bahaya',
          icon: Icons.warning_amber_rounded,
          iconBg: _C.bahayaBg,
          iconColor: _C.bahayaText,
          accentColor: _C.bahayaText,
          borderColor: _C.bahayaBorder,
        ),
        const SizedBox(width: 10),
        _buildStatCard(
          count: _totalPeringatan,
          label: 'Peringatan',
          icon: Icons.error_outline_rounded,
          iconBg: _C.peringatanBg,
          iconColor: _C.peringatanText,
          accentColor: _C.peringatanText,
          borderColor: _C.peringatanBorder,
        ),
        const SizedBox(width: 10),
        _buildStatCard(
          count: _totalAman,
          label: 'Aman',
          icon: Icons.check_circle_outline_rounded,
          iconBg: _C.amanBg,
          iconColor: _C.amanText,
          accentColor: _C.amanText,
          borderColor: _C.amanBorder,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required int count,
    required String label,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required Color accentColor,
    required Color borderColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: _C.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: borderColor, width: 3)),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(height: 6),
            Text('$count',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: accentColor)),
            Text(label,
                style: const TextStyle(fontSize: 11, color: _C.textMid)),
          ],
        ),
      ),
    );
  }

  // ── Category Tabs ─────────────────────────────────────────
  Widget _buildCategoryScroll() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Filter Kategori',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: _C.textDark)),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _categoryTabs.map((tab) {
              final active = _selectedCategory == tab['label'];
              return GestureDetector(
                onTap: () => setState(
                    () => _selectedCategory = tab['label'] as String),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? _C.primary : _C.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: active ? _C.primary : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                    boxShadow: active
                        ? [BoxShadow(
                            color: _C.primary.withOpacity(0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3))]
                        : [],
                  ),
                  child: Row(
                    children: [
                      Icon(tab['icon'] as IconData,
                          size: 14,
                          color: active ? Colors.white : _C.textMid),
                      const SizedBox(width: 5),
                      Text(tab['label'] as String,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: active ? Colors.white : _C.textMid)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── Status Filter Chips ──────────────────────────────────
  Widget _buildStatusChips() {
    final colorMap = {
      'Semua'     : _C.primary,
      'Bahaya'    : _C.bahayaText,
      'Peringatan': _C.peringatanText,
      'Aman'      : _C.amanText,
    };
    final iconMap = {
      'Semua'     : Icons.all_inclusive_rounded,
      'Bahaya'    : Icons.warning_amber_rounded,
      'Peringatan': Icons.error_outline_rounded,
      'Aman'      : Icons.check_circle_outline_rounded,
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _statusFilters.map((f) {
          final active = _selectedStatus == f;
          final color  = colorMap[f]!;
          return GestureDetector(
            onTap: () => setState(() => _selectedStatus = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: active ? color.withOpacity(0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: active ? color : const Color(0xFFCBD5E1),
                    width: 1.2),
              ),
              child: Row(
                children: [
                  Icon(iconMap[f]!, size: 13, color: active ? color : _C.textMid),
                  const SizedBox(width: 5),
                  Text(f,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: active ? color : _C.textMid)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Result Count ─────────────────────────────────────────
  Widget _buildResultCount() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        'Menampilkan ${_filtered.length} dari ${_dummyHistory.length} riwayat',
        style: const TextStyle(fontSize: 11, color: _C.textMid),
      ),
    );
  }

  // ── Date Section ─────────────────────────────────────────
  Widget _buildDateSection(String date, List<HistoryItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 10),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 13, color: _C.primary),
              const SizedBox(width: 6),
              Text(date,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _C.textDark)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _C.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${items.length} kejadian',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _C.primary)),
              ),
            ],
          ),
        ),
        // Timeline list
        ...items.asMap().entries.map((entry) {
          final isLast = entry.key == items.length - 1;
          return _buildTimelineCard(entry.value, isLast);
        }),
      ],
    );
  }

  // ── Timeline Card ─────────────────────────────────────────
  Widget _buildTimelineCard(HistoryItem item, bool isLast) {
    final sd = _statusDesign(item.status);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline rail
          SizedBox(
            width: 32,
            child: Column(
              children: [
                const SizedBox(height: 14),
                Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    color: sd.text,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: sd.text.withOpacity(0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.only(top: 4),
                      color: const Color(0xFFE2E8F0),
                    ),
                  )
                else
                  const SizedBox(height: 8),
              ],
            ),
          ),
          // Card content
          Expanded(
            child: GestureDetector(
              onTap: () => _showDetail(item, sd),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: _C.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border(
                    left: BorderSide(color: sd.text, width: 3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: _buildCardBody(item, sd),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBody(HistoryItem item, _StatusDesign sd) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: sd.bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, size: 22, color: sd.text),
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
                            fontSize: 11, color: _C.textMid, height: 1.3)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: sd.bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(sd.label,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: sd.text)),
              ),
            ],
          ),

          // Meta chips (key info inline)
          if (item.meta.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),
            _buildMetaRow(item),
          ],

          // Timestamp footer
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.access_time_rounded,
                  size: 11, color: _C.textMid.withOpacity(0.6)),
              const SizedBox(width: 4),
              Text(item.time,
                  style: TextStyle(
                      fontSize: 11,
                      color: _C.textMid.withOpacity(0.7),
                      fontWeight: FontWeight.w500)),
              const Spacer(),
              Text('Lihat detail  →',
                  style: TextStyle(
                      fontSize: 11,
                      color: _C.primary.withOpacity(0.7),
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(HistoryItem item) {
    // Show first 3 meta entries as small inline chips
    final entries = item.meta.entries.take(3).toList();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: entries.map((e) {
        final isSensor = ['MPU6050', 'GPS', 'Ultrasonik'].contains(e.key);
        final isOff = e.value.toLowerCase().contains('disconnect') ||
            e.value.toLowerCase().contains('tidak') ||
            e.value.toLowerCase().contains('off');
        final dotColor = isSensor
            ? (isOff ? _C.bahayaText : _C.amanText)
            : null;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFB8D4F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dotColor != null) ...[
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Text('${e.key}: ',
                  style: const TextStyle(
                      fontSize: 10,
                      color: _C.textMid,
                      fontWeight: FontWeight.w500)),
              Text(e.value,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: dotColor ?? _C.textDark)),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Empty State ───────────────────────────────────────────
  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: _C.primaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.history_rounded, size: 38, color: _C.primary),
            ),
            const SizedBox(height: 14),
            const Text('Tidak ada riwayat',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _C.textDark)),
            const SizedBox(height: 4),
            const Text('Coba ubah filter atau kategori',
                style: TextStyle(fontSize: 12, color: _C.textMid)),
          ],
        ),
      ),
    );
  }

  // ── Detail Bottom Sheet ───────────────────────────────────
  void _showDetail(HistoryItem item, _StatusDesign sd) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Label atas
              Row(
                children: [
                  const Icon(Icons.history_rounded,
                      size: 13, color: _C.textMid),
                  const SizedBox(width: 5),
                  const Text('Detail Riwayat',
                      style: TextStyle(fontSize: 12, color: _C.textMid)),
                  const Spacer(),
                  Text('${item.date}  ·  ${item.time}',
                      style: const TextStyle(fontSize: 11, color: _C.textMid)),
                ],
              ),
              const SizedBox(height: 12),

              // Header
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: sd.bg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border(left: BorderSide(color: sd.text, width: 4)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(item.icon, size: 28, color: sd.text),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: sd.text)),
                          const SizedBox(height: 2),
                          Text(item.subtitle,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: sd.text.withOpacity(0.7))),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(sd.label,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: sd.text)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Keterangan detail
              const Text('Keterangan',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _C.textMid)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(item.detail,
                    style: const TextStyle(
                        fontSize: 13,
                        color: _C.textDark,
                        height: 1.6)),
              ),

              if (item.meta.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text('Data Terukur',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _C.textMid)),
                const SizedBox(height: 8),
                ...item.meta.entries.map((e) {
                  final isSensor =
                      ['MPU6050', 'GPS', 'Ultrasonik'].contains(e.key);
                  final isOff = e.value.toLowerCase().contains('tidak') ||
                      e.value.toLowerCase().contains('off') ||
                      e.value.toLowerCase().contains('disconnect');
                  final valColor = isSensor
                      ? (isOff ? _C.bahayaText : _C.amanText)
                      : _C.textDark;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: _C.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        if (isSensor)
                          Container(
                            width: 8, height: 8,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: valColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        Text(e.key,
                            style: const TextStyle(
                                fontSize: 13, color: _C.textMid)),
                        const Spacer(),
                        Text(e.value,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: valColor)),
                      ],
                    ),
                  );
                }),
              ],

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Tutup',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _StatusDesign _statusDesign(HistoryStatus s) {
    switch (s) {
      case HistoryStatus.bahaya:
        return _StatusDesign('Bahaya', _C.bahayaText, _C.bahayaBg);
      case HistoryStatus.peringatan:
        return _StatusDesign('Peringatan', _C.peringatanText, _C.peringatanBg);
      case HistoryStatus.aman:
        return _StatusDesign('Aman', _C.amanText, _C.amanBg);
    }
  }
}

class _StatusDesign {
  final String label;
  final Color text;
  final Color bg;
  const _StatusDesign(this.label, this.text, this.bg);
}