import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'dart:ui' as ui;
import '../utils/app_colors.dart';
import 'package:latlong2/latlong.dart';
import '../utils/app_routes.dart';

// ============================================================
// COLORS
// ============================================================
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
}

// ============================================================
// MODELS
// ============================================================
enum HistoryCategory {
  jatuh,
  geofence,
  aktivitas,
  sensor,
  walker,
  hambatanDepan,
  hambatanBelakang
}

enum HistoryStatus { bahaya, peringatan, aman, info }

class SensorDataPoint {
  final double accel;
  final double gyro;
  const SensorDataPoint(this.accel, this.gyro);
}

class DistanceDataPoint {
  final double distance;
  final String label;
  const DistanceDataPoint(this.distance, this.label);
}

class StatusSistem {
  final int batteryPercent;
  final bool gsmNetworkConnected;
  final bool gpsConnected;
  final bool firebaseRtdConnected;
  const StatusSistem({
    required this.batteryPercent,
    this.gsmNetworkConnected = true,
    this.gpsConnected = true,
    this.firebaseRtdConnected = true,
  });
}

class RingkasanSensor {
  final String hcsr04Depan;
  final String statusDepan;
  final String hcsr04Belakang;
  final String statusBelakang;
  final String mpu6050;
  final String statusMpu;
  final String gpsJarak;
  final String statusGps;
  const RingkasanSensor({
    required this.hcsr04Depan,
    required this.statusDepan,
    required this.hcsr04Belakang,
    required this.statusBelakang,
    required this.mpu6050,
    required this.statusMpu,
    required this.gpsJarak,
    required this.statusGps,
  });
}

class HistoryItemExtra {
  final String jenisKejadian;
  final String statusDeteksiLansia;
  final String jarakTerukur;
  final String sensor;
  final String statusBahaya;
  final String kondisiGeofence;
  final StatusSistem? statusSistem;
  final RingkasanSensor? ringkasanSensor;
  final List<String> tindakanSistem;
  final double? skorAnomali;
  final List<SensorDataPoint> sensorData;
  final List<DistanceDataPoint> distanceData;
  final Map<String, String> dataTerukur;
  final String? lokasiNama;
  final String? lokasiKoordinat;
  final String? lokasiJarakPusat;
  final double? hcsrJarak;
  final double? hcsrThreshold;
  final String? hcsrStatus;

  const HistoryItemExtra({
    required this.jenisKejadian,
    this.statusDeteksiLansia = '-',
    this.jarakTerukur = '-',
    this.sensor = '-',
    this.statusBahaya = '-',
    this.kondisiGeofence = '-',
    this.statusSistem,
    this.ringkasanSensor,
    this.tindakanSistem = const [],
    this.skorAnomali,
    this.sensorData = const [],
    this.distanceData = const [],
    this.dataTerukur = const {},
    this.lokasiNama,
    this.lokasiKoordinat,
    this.lokasiJarakPusat,
    this.hcsrJarak,
    this.hcsrThreshold,
    this.hcsrStatus,
  });
}

class HistoryItem {
  final String id;
  final String title;
  final String subtitle;
  final String time;
  final String date;
  final HistoryCategory category;
  final HistoryStatus status;
  final IconData icon;
  final Map<String, String> meta;
  final HistoryItemExtra extra;

  const HistoryItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.date,
    required this.category,
    required this.status,
    required this.icon,
    this.meta = const {},
    required this.extra,
  });
}

// ============================================================
// DUMMY DATA
// ============================================================
final List<HistoryItem> _dummyHistory = [
  // 1. Potensi Jatuh (MPU6050)
  HistoryItem(
    id: '1',
    title: 'Potensi Jatuh Terdeteksi',
    subtitle: 'Gerakan mendadak ke bawah terdeteksi sensor MPU6050',
    time: '11:24 AM',
    date: '11 Mei 2025',
    category: HistoryCategory.jatuh,
    status: HistoryStatus.bahaya,
    icon: Icons.personal_injury_rounded,
    meta: {'Skor Anomali': '0.82', 'Durasi': '23 detik', 'Sensor': 'MPU6050'},
    extra: HistoryItemExtra(
      jenisKejadian: 'Deteksi Jatuh',
      statusDeteksiLansia: 'Terdeteksi',
      jarakTerukur: '23 detik',
      sensor: 'MPU6050',
      statusBahaya: 'BAHAYA',
      kondisiGeofence: 'Di dalam Area Aman',
      skorAnomali: 0.82,
      sensorData: [
        SensorDataPoint(0.8, 0.2),
        SensorDataPoint(1.2, 0.5),
        SensorDataPoint(2.1, 1.8),
        SensorDataPoint(1.9, 2.2),
        SensorDataPoint(0.6, -0.3),
        SensorDataPoint(-0.4, -1.2),
        SensorDataPoint(-1.8, -2.0),
        SensorDataPoint(-0.9, -0.8),
        SensorDataPoint(0.3, 0.1),
        SensorDataPoint(0.2, -0.1),
      ],
      dataTerukur: {
        'Ax': '1.45 g',
        'Ay': '-0.32 g',
        'Az': '1.89 g',
        'Gx': '45.3°/s',
        'Gy': '-23.8°/s',
        'Gz': '12.6°/s',
      },
      statusSistem: const StatusSistem(
        batteryPercent: 78,
        // voltage: 3.92,
        gsmNetworkConnected: false,
        gpsConnected: true,
        firebaseRtdConnected: false,
        // wifiConnected: true,
        // mqttConnected: true,
        // motorStatus: 'Normal',
      ),
      ringkasanSensor: const RingkasanSensor(
        hcsr04Depan: '45 cm',
        statusDepan: 'Ada Hambatan',
        hcsr04Belakang: '30 cm',
        statusBelakang: 'Tidak Terdeteksi',
        mpu6050: 'Anomali',
        statusMpu: 'Terdeteksi',
        gpsJarak: '120 cm',
        statusGps: 'Tidak Terhubung',
      ),
      lokasiNama: 'Jl. Veteran, Malang',
      lokasiKoordinat: '-7.9711, 112.6328',
      lokasiJarakPusat: '15.6 meter',
      tindakanSistem: [
        'Data dikirim ke Firebase',
        'Notifikasi dikirim ke 2 pengguna',
        'Di-catat dalam riwayat kejadian',
      ],
    ),
  ),

  // 2. Geofence
  HistoryItem(
    id: '2',
    title: 'Keluar Area Aman (Geofence)',
    subtitle: 'Lansia melewati batas radius geofence',
    time: '09:12 AM',
    date: '11 Mei 2025',
    category: HistoryCategory.geofence,
    status: HistoryStatus.peringatan,
    icon: Icons.location_off_rounded,
    meta: {
      'Lokasi': 'Jl. Veteran, Malang',
      'Jarak': '> 10 meter',
      'Jauh': '15.6 meter'
    },
    extra: HistoryItemExtra(
      jenisKejadian: 'Geofence Breach',
      statusDeteksiLansia: 'Terdeteksi',
      jarakTerukur: '> 10 meter',
      sensor: 'GPS (SIM800)',
      statusBahaya: 'PERINGATAN',
      kondisiGeofence: 'Di luar Area Aman',
      lokasiNama: 'Jl. Veteran, Malang',
      lokasiKoordinat: '-7.9711, 112.6328',
      lokasiJarakPusat: '15.6 meter',
      statusSistem: const StatusSistem(
        batteryPercent: 85,
        // voltage: 4.10,
        // wifiConnected: true,
        // mqttConnected: true,
        // motorStatus: 'Normal',
      ),
      tindakanSistem: [
        'Data dikirim ke Firebase',
        'Notifikasi dikirim ke 3 pengguna',
        'Di-catat dalam riwayat kejadian',
      ],
    ),
  ),

  // 3. Aktivitas Tidak Normal
  HistoryItem(
    id: '3',
    title: 'Aktivitas Tidak Normal',
    subtitle: 'Akselerasi melebihi batas threshold sistem',
    time: '02:21 PM',
    date: '11 Mei 2025',
    category: HistoryCategory.aktivitas,
    status: HistoryStatus.peringatan,
    icon: Icons.directions_run_rounded,
    meta: {
      'Akselerasi': '1.8 g',
      'Nilai': 'Melebihi threshold',
      'Sensor': 'MPU6050'
    },
    extra: HistoryItemExtra(
      jenisKejadian: 'Aktivitas Abnormal',
      statusDeteksiLansia: 'Terdeteksi',
      jarakTerukur: '-',
      sensor: 'MPU6050',
      statusBahaya: 'PERINGATAN',
      kondisiGeofence: 'Di dalam Area Aman',
      sensorData: [
        SensorDataPoint(0.5, 0.1),
        SensorDataPoint(1.0, 0.8),
        SensorDataPoint(1.8, 1.5),
        SensorDataPoint(1.6, 1.2),
        SensorDataPoint(1.4, 1.0),
        SensorDataPoint(1.2, 0.9),
        SensorDataPoint(0.9, 0.6),
        SensorDataPoint(0.7, 0.3),
      ],
      dataTerukur: {
        'Ax': '1.8 g',
        'Threshold': '1.2 g',
        'Gyroscope': 'Normal',
        'Sensor': 'MPU6050'
      },
      statusSistem: const StatusSistem(
        batteryPercent: 62,
        // voltage: 3.75,
        // wifiConnected: true,
        // mqttConnected: true,
        // motorStatus: 'Normal',
      ),
      tindakanSistem: [
        'Data dikirim ke Firebase',
        'Notifikasi dikirim ke 2 pengguna',
      ],
    ),
  ),

  // 4. Hambatan Depan
  HistoryItem(
    id: '4',
    title: 'Hambatan Terdeteksi (Depan)',
    subtitle: 'Ada hambatan di depan walker — HC-SR04 Depan',
    time: '01:41 PM',
    date: '11 Mei 2025',
    category: HistoryCategory.hambatanDepan,
    status: HistoryStatus.info,
    icon: Icons.sensors_rounded,
    meta: {'Jarak': '45 cm', 'Sensor': 'HC-SR04 Depan'},
    extra: HistoryItemExtra(
      jenisKejadian: 'Deteksi Hambatan Depan',
      statusDeteksiLansia: 'Terdeteksi',
      jarakTerukur: '45 cm',
      sensor: 'HC-SR04 Depan',
      statusBahaya: 'INFO',
      kondisiGeofence: 'Di dalam Area Aman',
      hcsrJarak: 45,
      hcsrThreshold: 60,
      hcsrStatus: 'Ada Hambatan',
      distanceData: [
        DistanceDataPoint(90, '-10d'),
        DistanceDataPoint(82, '-8d'),
        DistanceDataPoint(75, '-6d'),
        DistanceDataPoint(62, '-4d'),
        DistanceDataPoint(52, '-2d'),
        DistanceDataPoint(47, '-1d'),
        DistanceDataPoint(45, 'Skrg'),
      ],
      statusSistem: const StatusSistem(
        batteryPercent: 78,
        // voltage: 3.92,
        // wifiConnected: true,
        // mqttConnected: true,
        // motorStatus: 'Normal',
      ),
      ringkasanSensor: const RingkasanSensor(
        hcsr04Depan: '45 cm',
        statusDepan: 'Ada Hambatan',
        hcsr04Belakang: '120 cm',
        statusBelakang: 'Aman',
        mpu6050: 'Normal',
        statusMpu: 'Tidak Terdeteksi',
        gpsJarak: '0 m',
        statusGps: 'Connected',
      ),
      lokasiNama: 'Jl. Veteran, Malang',
      lokasiKoordinat: '-7.9711, 112.6328',
      lokasiJarakPusat: '15.6 meter',
      tindakanSistem: [
        'Data dikirim ke Firebase',
        'Notifikasi dikirim ke 2 pengguna',
        'Di-catat dalam riwayat kejadian',
      ],
    ),
  ),

  // 5. Hambatan Belakang — bahaya
  HistoryItem(
    id: '5',
    title: 'Hambatan Terdeteksi (Belakang)',
    subtitle: 'Lansia TIDAK terdeteksi di belakang — indikasi potensi jatuh',
    time: '01:44 PM',
    date: '11 Mei 2025',
    category: HistoryCategory.hambatanBelakang,
    status: HistoryStatus.bahaya,
    icon: Icons.personal_injury_rounded,
    meta: {
      'Jarak': '38 cm',
      'Lansia': 'Tidak Terdeteksi',
      'Sensor': 'HC-SR04 Belakang'
    },
    extra: HistoryItemExtra(
      jenisKejadian: 'Indikasi Potensi Jatuh',
      statusDeteksiLansia: 'Tidak Terdeteksi',
      jarakTerukur: '38 cm',
      sensor: 'HC-SR04 Belakang (Ultrasonik)',
      statusBahaya: 'BAHAYA',
      kondisiGeofence: 'Di dalam Area Aman',
      hcsrJarak: 38,
      hcsrThreshold: 60,
      hcsrStatus: 'Tidak Terdeteksi',
      distanceData: [
        DistanceDataPoint(95, '-10d'),
        DistanceDataPoint(88, '-8d'),
        DistanceDataPoint(80, '-6d'),
        DistanceDataPoint(65, '-4d'),
        DistanceDataPoint(52, '-2d'),
        DistanceDataPoint(44, '-1d'),
        DistanceDataPoint(38, 'Skrg'),
      ],
      statusSistem: const StatusSistem(
        batteryPercent: 78,
        // voltage: 3.92,
        // wifiConnected: true,
        // mqttConnected: true,
        // motorStatus: 'Normal',
      ),
      ringkasanSensor: const RingkasanSensor(
        hcsr04Depan: '45 cm',
        statusDepan: 'Ada Hambatan',
        hcsr04Belakang: '38 cm',
        statusBelakang: 'Tidak Terdeteksi',
        mpu6050: 'Anomali',
        statusMpu: 'Terdeteksi',
        gpsJarak: '120 cm',
        statusGps: 'Tidak Terhubung',
      ),
      lokasiNama: 'Jl. Veteran, Malang',
      lokasiKoordinat: '-7.9711, 112.6328',
      lokasiJarakPusat: '15.6 meter',
      tindakanSistem: [
        'Data dikirim ke Firebase',
        'Notifikasi dikirim ke 2 pengguna',
        'Di-catat dalam riwayat kejadian',
      ],
    ),
  ),

  // 6. Hambatan Belakang — aman
  HistoryItem(
    id: '6',
    title: 'Hambatan Terdeteksi (Belakang)',
    subtitle: 'Lansia terdeteksi di belakang walker — kondisi aman',
    time: '12:30 PM',
    date: '11 Mei 2025',
    category: HistoryCategory.hambatanBelakang,
    status: HistoryStatus.aman,
    icon: Icons.elderly_rounded,
    meta: {
      'Jarak': '55 cm',
      'Lansia': 'Terdeteksi Lansia',
      'Sensor': 'HC-SR04 Belakang'
    },
    extra: HistoryItemExtra(
      jenisKejadian: 'Deteksi Lansia Belakang',
      statusDeteksiLansia: 'Terdeteksi Lansia',
      jarakTerukur: '55 cm',
      sensor: 'HC-SR04 Belakang',
      statusBahaya: 'AMAN',
      kondisiGeofence: 'Di dalam Area Aman',
      hcsrJarak: 55,
      hcsrThreshold: 60,
      hcsrStatus: 'Terdeteksi',
      distanceData: [
        DistanceDataPoint(70, '-10d'),
        DistanceDataPoint(67, '-8d'),
        DistanceDataPoint(64, '-6d'),
        DistanceDataPoint(61, '-4d'),
        DistanceDataPoint(58, '-2d'),
        DistanceDataPoint(56, '-1d'),
        DistanceDataPoint(55, 'Skrg'),
      ],
      tindakanSistem: [
        'Data dikirim ke Firebase',
        'Di-catat dalam riwayat kejadian',
      ],
    ),
  ),

  // 7. MPU6050 Aktif
  HistoryItem(
    id: '7',
    title: 'MPU6050 Aktif',
    subtitle: 'Sensor Normal — Berfungsi',
    time: '01:10 PM',
    date: '11 Mei 2025',
    category: HistoryCategory.sensor,
    status: HistoryStatus.aman,
    icon: Icons.sensors_rounded,
    meta: {'Status': 'Normal', 'Kondisi': 'Berfungsi', 'Sensor': 'MPU6050'},
    extra: HistoryItemExtra(
      jenisKejadian: 'Pengecekan Sensor',
      jarakTerukur: '-',
      sensor: 'MPU6050',
      statusBahaya: 'NORMAL',
      tindakanSistem: ['Log status dikirim ke Firebase'],
      statusSistem: const StatusSistem(
        batteryPercent: 90,
        // voltage: 4.05,
        // wifiConnected: true,
        // mqttConnected: true,
        // motorStatus: 'Normal',
      ),
    ),
  ),

  // 8. GPS Aktif
  HistoryItem(
    id: '8',
    title: 'GPS Aktif',
    subtitle: 'Sinyal Good HIG — SIM800 GPS',
    time: '11:20 AM',
    date: '11 Mei 2025',
    category: HistoryCategory.sensor,
    status: HistoryStatus.aman,
    icon: Icons.gps_fixed_rounded,
    meta: {'Sinyal': 'Good HIG', 'Sensor': 'SIM800 GPS'},
    extra: HistoryItemExtra(
      jenisKejadian: 'Pengecekan GPS',
      jarakTerukur: '-',
      sensor: 'SIM800 GPS',
      statusBahaya: 'NORMAL',
      tindakanSistem: ['Log status dikirim ke Firebase'],
    ),
  ),

  // 9. Baterai
  HistoryItem(
    id: '9',
    title: 'Status Baterai',
    subtitle: 'Tegangan 3.92 V — Sensor: BMS',
    time: '11:40 AM',
    date: '11 Mei 2025',
    category: HistoryCategory.sensor,
    status: HistoryStatus.peringatan,
    icon: Icons.battery_charging_full_rounded,
    meta: {'Kapasitas': '78%', 'Tegangan': '3.92 V', 'Sensor': 'BMS'},
    extra: HistoryItemExtra(
      jenisKejadian: 'Status Baterai',
      jarakTerukur: '-',
      sensor: 'BMS',
      statusBahaya: 'HRG',
      tindakanSistem: ['Log status dikirim ke Firebase'],
      statusSistem: const StatusSistem(
        batteryPercent: 78,
        // voltage: 3.92,
        // wifiConnected: true,
        // mqttConnected: true,
        // motorStatus: 'Normal',
      ),
    ),
  ),

  // 10. Walker Aman
  HistoryItem(
    id: '10',
    title: 'Walker Aman',
    subtitle: 'Tidak ada aktivitas abnormal',
    time: '10:36 AM',
    date: '10 Mei 2025',
    category: HistoryCategory.walker,
    status: HistoryStatus.aman,
    icon: Icons.elderly_rounded,
    meta: {'Kondisi': 'Aman', 'Sensor': 'Sensor Normal'},
    extra: HistoryItemExtra(
      jenisKejadian: 'Monitoring Rutin',
      statusDeteksiLansia: 'Terdeteksi',
      jarakTerukur: '-',
      sensor: 'Semua Sensor',
      statusBahaya: 'NORMAL',
      tindakanSistem: [
        'Data dikirim ke Firebase',
        'Di-catat dalam riwayat kejadian',
      ],
    ),
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
  String _selectedCategory = 'Semua';
  String _sortOption =
      'Terbaru'; // Terbaru | Terlama | Bahaya | Peringatan | Normal

  final List<Map<String, dynamic>> _tabs = [
    {'label': 'Semua', 'icon': Icons.history_rounded},
    {'label': 'Jatuh', 'icon': Icons.personal_injury_rounded},
    {'label': 'Warning', 'icon': Icons.warning_amber_rounded},
    {'label': 'Geofence', 'icon': Icons.location_off_rounded},
    {'label': 'Sensor', 'icon': Icons.sensors_rounded},
  ];

  // Parse "HH:MM AM/PM" → menit sejak tengah malam untuk perbandingan waktu
  int _parseTimeToMinutes(String time) {
    try {
      final parts = time.split(' ');
      final hm = parts[0].split(':');
      int h = int.parse(hm[0]);
      final m = int.parse(hm[1]);
      final isPm = parts[1].toUpperCase() == 'PM';
      if (isPm && h != 12) h += 12;
      if (!isPm && h == 12) h = 0;
      return h * 60 + m;
    } catch (_) {
      return 0;
    }
  }

  List<HistoryItem> get _filtered {
    List<HistoryItem> list;
    if (_selectedCategory == 'Semua') {
      list = List.from(_dummyHistory);
    } else {
      final catMap = {
        'Jatuh': [HistoryCategory.jatuh, HistoryCategory.hambatanBelakang],
        'Warning': [HistoryCategory.aktivitas, HistoryCategory.hambatanDepan],
        'Geofence': [HistoryCategory.geofence],
        'Sensor': [HistoryCategory.sensor, HistoryCategory.walker],
      };
      list = _dummyHistory
          .where((h) => (catMap[_selectedCategory] ?? []).contains(h.category))
          .toList();
    }

    // Filter berdasarkan status jika dipilih
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

    // Sort berdasarkan waktu untuk Terbaru / Terlama
    if (_sortOption == 'Terbaru' || _sortOption == 'Terlama') {
      final asc = _sortOption == 'Terlama';
      list.sort((a, b) {
        final cmpDate = a.date.compareTo(b.date);
        if (cmpDate != 0) return asc ? cmpDate : -cmpDate;
        final cmpTime =
            _parseTimeToMinutes(a.time).compareTo(_parseTimeToMinutes(b.time));
        return asc ? cmpTime : -cmpTime;
      });
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

  @override
  Widget build(BuildContext context) {
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
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _summaryRow(),
                      const SizedBox(height: 12),
                      _categoryTabs(),
                      const SizedBox(height: 14),
                      if (_filtered.isEmpty)
                        _emptyState()
                      else
                        ..._grouped.entries
                            .map((e) => _dateSection(e.key, e.value)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      // bottomNavigationBar: _bottomBar(),
    );
  }

// ── TOP BAR ────────────────────────────────────────────────
  Widget _topBar() => Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        color: const Color(0xFFF0F4F8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFE2E8F0),
              child: Text(
                'M',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hallo, Mila',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textGrey,
                    ),
                  ),
                  Text(
                    'Monitoring Lansia',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _summaryRow() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
            Text('${_dummyHistory.length} kejadian',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _C.primary)),
            const Spacer(),
            PopupMenuButton<String>(
              onSelected: (val) => setState(() => _sortOption = val),
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
              ],
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  Text(_sortOption,
                      style: const TextStyle(fontSize: 11, color: _C.textMid)),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 14, color: _C.textMid),
                ]),
              ),
            ),
          ],
        ),
      );

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
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? iconColor : _C.textDark,
            )),
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
              onTap: () =>
                  setState(() => _selectedCategory = tab['label'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? _C.primary : _C.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                      color: active ? _C.primary : const Color(0xFFE2E8F0)),
                  boxShadow: active
                      ? [
                          BoxShadow(
                              color: _C.primary.withOpacity(0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2))
                        ]
                      : [],
                ),
                child: Row(
                  children: [
                    Icon(tab['icon'] as IconData,
                        size: 13, color: active ? Colors.white : _C.textMid),
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
      );

  Widget _dateSection(String date, List<HistoryItem> items) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 8),
            child: Text('Hari ini — $date',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _C.textMid)),
          ),
          ...items.map(_historyCard),
        ],
      );

  Widget _historyCard(HistoryItem item) {
    final sd = _sdOf(item.status);
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _DetailSheet(item: item),
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
                        color: sd.bg, borderRadius: BorderRadius.circular(10)),
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
                                fontSize: 11, color: _C.textMid, height: 1.3)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(item.time,
                      style: const TextStyle(fontSize: 11, color: _C.textMid)),
                ],
              ),
              if (item.meta.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: item.meta.entries
                      .take(3)
                      .map((e) => RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                  fontSize: 11, color: _C.textMid),
                              children: [
                                TextSpan(text: '${e.key}  '),
                                TextSpan(
                                    text: e.value,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: _C.textDark)),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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

  Widget _emptyState() => Padding(
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
            const Text('Tidak ada riwayat',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _C.textDark)),
          ]),
        ),
      );

  // Widget _bottomBar() => Container(
  //   padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
  //   decoration: const BoxDecoration(
  //     color: _C.white,
  //     border: Border(top: BorderSide(color: Color(0xFFEDF2F7))),
  //   ),
  //   child: Row(
  //     children: [
  //       Expanded(
  //         child: OutlinedButton.icon(
  //           onPressed: () {},
  //           icon: const Icon(Icons.delete_sweep_outlined, size: 15, color: _C.bahayaText),
  //           label: const Text('Hapus Semua Riwayat',
  //               style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _C.bahayaText)),
  //           style: OutlinedButton.styleFrom(
  //             side: const BorderSide(color: _C.bahayaBorder),
  //             backgroundColor: _C.bahayaBg,
  //             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //             padding: const EdgeInsets.symmetric(vertical: 12),
  //           ),
  //         ),
  //       ),
  //       const SizedBox(width: 10),
  //       Expanded(
  //         child: ElevatedButton.icon(
  //           onPressed: () {},
  //           icon: const Icon(Icons.check_circle_outline, size: 15, color: Colors.white),
  //           label: const Text('Tandai Semua Sudah Dibaca',
  //               style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
  //           style: ElevatedButton.styleFrom(
  //             backgroundColor: _C.primary, elevation: 0,
  //             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //             padding: const EdgeInsets.symmetric(vertical: 12),
  //           ),
  //         ),
  //       ),
  //     ],
  //   ),
  // );

  static _StatusDesign _sdOf(HistoryStatus s) {
    switch (s) {
      case HistoryStatus.bahaya:
        return _StatusDesign(
            'BAHAYA', _C.bahayaText, _C.bahayaBg, _C.bahayaBorder);
      case HistoryStatus.peringatan:
        return _StatusDesign(
            'PERINGATAN', _C.warnText, _C.warnBg, _C.warnBorder);
      case HistoryStatus.aman:
        return _StatusDesign('NORMAL', _C.amanText, _C.amanBg, _C.amanBorder);
      case HistoryStatus.info:
        return _StatusDesign('INFO', _C.infoText, _C.infoBg, _C.infoBorder);
    }
  }
}

// ============================================================
// DETAIL SHEET
// ============================================================
class _DetailSheet extends StatelessWidget {
  final HistoryItem item;
  const _DetailSheet({required this.item});

  _StatusDesign get sd => _HistoryScreenState._sdOf(item.status);

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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
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
                          fontSize: 11, color: sd.text.withOpacity(0.7))),
                ],
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
                      fontSize: 12, color: Color(0xFF92400E), height: 1.5),
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
    final threshold = e.hcsrThreshold!;
    final isBelakang = item.category == HistoryCategory.hambatanBelakang;

    final Color statusColor = isBelakang
        ? (jarak < threshold ? _C.bahayaText : _C.amanText)
        : (jarak < threshold ? _C.warnText : _C.amanText);

    final String statusText = e.hcsrStatus ??
        (isBelakang
            ? (jarak < threshold ? 'Tidak Terdeteksi' : 'Terdeteksi')
            : (jarak < threshold ? 'Ada Hambatan' : 'Aman'));

    final String sensorName = isBelakang ? 'HC-SR04 Belakang' : 'HC-SR04 Depan';

    return _card(
      title: 'Beat Sonar Pelacak ($sensorName)',
      child: Column(
        children: [
          Row(
            children: [
              _sonarCol('Jarak Terukur', '${jarak.toStringAsFixed(0)} cm',
                  _C.textDark),
              _sonarCol('Batas Aman', '≤ ${threshold.toStringAsFixed(0)} cm',
                  _C.warnText),
              _sonarCol('Status', statusText, statusColor),
            ],
          ),
          if (isBelakang) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: jarak < threshold ? _C.bahayaBg : _C.amanBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 14,
                      color: jarak < threshold ? _C.bahayaText : _C.amanText),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      jarak < threshold
                          ? 'Jika jarak > 60 cm dan tidak terdeteksi lansia selama lebih dari 5 detik, sistem akan mengindikasikan potensi jatuh.'
                          : 'Lansia terdeteksi dalam jangkauan aman. Jarak ≤ 60 cm menunjukkan lansia berada di belakang walker.',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: jarak < threshold ? _C.bahayaText : _C.amanText,
                      ),
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
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 10, color: _C.textMid),
                textAlign: TextAlign.center),
          ],
        ),
      );

  Widget _distanceChart() {
    final isBelakang = item.category == HistoryCategory.hambatanBelakang;
    return _card(
      title: 'Grafik Jarak (10 detik terakhir)',
      child: SizedBox(
        height: 150,
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
    );
  }

  Widget _imuChart() => _card(
        title: 'Data Sensor Saat Kejadian',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _legendLine(const Color(0xFF3B82F6), 'Akselerometer (g)'),
                const SizedBox(width: 16),
                _legendLine(const Color(0xFF10B981), 'Gyroscope (°/s)'),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 150,
              child: CustomPaint(
                painter: _SensorChartPainter(item.extra.sensorData),
                size: Size.infinite,
              ),
            ),
          ],
        ),
      );

  Widget _legendLine(Color c, String label) => Row(
        children: [
          Container(
              width: 18,
              height: 3,
              decoration: BoxDecoration(
                  color: c, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 11, color: _C.textMid)),
        ],
      );

  Widget _nilaiTerukur() {
    final entries = item.extra.dataTerukur.entries.toList();
    final rows = <List<MapEntry<String, String>>>[];
    for (var i = 0; i < entries.length; i += 3) {
      rows.add(entries.sublist(
          i, (i + 3 > entries.length) ? entries.length : i + 3));
    }
    return _card(
      title: 'Nilai Terukur',
      child: Column(
        children: rows
            .map((row) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: row
                        .map((e) => Expanded(
                              child: Column(
                                children: [
                                  Text(e.value,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: _C.textDark)),
                                  Text(e.key,
                                      style: const TextStyle(
                                          fontSize: 10, color: _C.textMid)),
                                ],
                              ),
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
      child: Column(
        children: [
          _sensorRow('HC-SR04 Hambatan', r.hcsr04Depan, r.statusDepan),
          _sensorRow('HC-SR04 Belakang', r.hcsr04Belakang, r.statusBelakang),
          _sensorRow('MPU6050 (Deteksi)', r.mpu6050, r.statusMpu),
          _sensorRow('Dana Lansia (TR)/Ultrasonik', r.gpsJarak, r.statusGps),
        ],
      ),
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
      child: Row(
        children: [
          Expanded(
              child: Text(name,
                  style: const TextStyle(fontSize: 12, color: _C.textMid))),
          Text(value,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _C.textDark)),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: c.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(status,
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.bold, color: c)),
          ),
        ],
      ),
    );
  }

  Widget _lokasiSection(BuildContext context) {
    final e = item.extra;

    // Parse koordinat dari string "-7.9711, 112.6328"
    final coord = () {
      try {
        final parts = (e.lokasiKoordinat ?? '-7.9711, 112.6328').split(',');
        return LatLng(
          double.parse(parts[0].trim()),
          double.parse(parts[1].trim()),
        );
      } catch (_) {
        return const LatLng(-7.9711, 112.6328);
      }
    }();

    final Color markerColor;
    switch (item.status) {
      case HistoryStatus.bahaya:
        markerColor = _C.bahayaText;
        break;
      case HistoryStatus.peringatan:
        markerColor = _C.warnText;
        break;
      case HistoryStatus.aman:
        markerColor = _C.amanText;
        break;
      case HistoryStatus.info:
        markerColor = _C.infoText;
        break;
    }

    return _card(
      title: 'Informasi Lokasi',
      icon: Icons.location_on_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── MAP ──────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 160,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: coord,
                  initialZoom: 15,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all, // allow interaction in preview
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.guardianwalk.app',
                  ),
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: coord,
                        radius: 80,
                        color: markerColor.withOpacity(0.12),
                        borderColor: markerColor,
                        borderStrokeWidth: 2,
                        useRadiusInMeter: true,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: coord,
                        width: 40,
                        height: 40,
                        child: Icon(
                          Icons.location_pin,
                          color: markerColor,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ── KOORDINAT ────────────────────────────────────────
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'Lat: ${coord.latitude.toStringAsFixed(4)}',
                style: const TextStyle(fontSize: 11, color: _C.textMid),
              ),
              Text(
                'Lng: ${coord.longitude.toStringAsFixed(4)}',
                style: const TextStyle(fontSize: 11, color: _C.textMid),
              ),
            ],
          ),

          const SizedBox(height: 6),
          _kvRow('Lokasi', e.lokasiNama ?? '-'),
          _kvRow('Status Geofence', e.kondisiGeofence),
          if (e.lokasiJarakPusat != null)
            _kvRow('Jarak dari Pusat Area', e.lokasiJarakPusat!),

          const SizedBox(height: 10),

          // ── TOMBOL ───────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.location);
              },
              icon: Icon(Icons.map_outlined, size: 16, color: _C.primary),
              label: Text(
                'Lihat di Google Maps',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _C.primary,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: _C.primary.withOpacity(0.9)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _systemStatusCard(
                  title: 'Baterai',
                  value: '${ss.batteryPercent}%',
                  icon: Icons.battery_charging_full_rounded,
                  isActive: ss.batteryPercent > 20,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _systemStatusCard(
                  title: 'GSM Network',
                  value: ss.gsmNetworkConnected ? 'Aktif' : 'Nonaktif',
                  icon: Icons.signal_cellular_alt_rounded,
                  isActive: ss.gsmNetworkConnected,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
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
                  title: 'Firebase RTD',
                  value: ss.firebaseRtdConnected ? 'Aktif' : 'Nonaktif',
                  icon: Icons.cloud_done_rounded,
                  isActive: ss.firebaseRtdConnected,
                ),
              ),
            ],
          ),
        ],
      ),
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
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _C.textMid,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tindakanSistem() => _card(
        title: 'Tindakan Sistem',
        child: Column(
          children: item.extra.tindakanSistem
              .map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            size: 16, color: _C.amanText),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(t,
                                style: const TextStyle(
                                    fontSize: 13, color: _C.textDark))),
                      ],
                    ),
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('Kembali ke History',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      );

  Widget _kvRow(String k, String v, {bool highlight = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
                child: Text(k,
                    style: const TextStyle(fontSize: 13, color: _C.textMid))),
            Text(v,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: highlight ? sd.text : _C.textDark)),
          ],
        ),
      );

  Widget _card(
          {required String title, IconData? icon, required Widget child}) =>
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
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: _C.primary),
                  const SizedBox(width: 6),
                ],
                Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _C.textDark)),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
}

// ============================================================
// DISTANCE CHART PAINTER
// ============================================================
class _DistanceChartPainter extends CustomPainter {
  final List<DistanceDataPoint> data;
  final Color lineColor;
  final double threshold;
  const _DistanceChartPainter(
      {required this.data, required this.lineColor, required this.threshold});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    const double padL = 44, padB = 22, padT = 10, padR = 10;
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
      canvas.drawLine(Offset(padL, y), Offset(padL + w, y), gridPaint);
      final val = maxVal - (maxVal - minVal) * i / 4;
      tp.text = TextSpan(
          text: '${val.toStringAsFixed(0)} cm',
          style: const TextStyle(fontSize: 8, color: Color(0xFFCBD5E1)));
      tp.layout();
      tp.paint(canvas, Offset(0, y - 5));
    }

    final ty = padT + h * (1 - (threshold - minVal) / (maxVal - minVal));
    canvas.drawLine(Offset(padL, ty), Offset(padL + w, ty), threshPaint);

    final stepX = w / (data.length - 1);
    for (int i = 0; i < data.length; i++) {
      tp.text = TextSpan(
          text: data[i].label,
          style: const TextStyle(fontSize: 8, color: Color(0xFFCBD5E1)));
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
      if (i == 0)
        fillPath.moveTo(x, y);
      else
        fillPath.lineTo(x, y);
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
      if (i == 0)
        linePath.moveTo(x, y);
      else
        linePath.lineTo(x, y);
    }
    canvas.drawPath(linePath, linePaint);

    final dotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;
    for (int i = 0; i < data.length; i++) {
      canvas.drawCircle(
          Offset(padL + stepX * i, yFor(data[i].distance)), 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_DistanceChartPainter old) => false;
}

// ============================================================
// IMU SENSOR CHART PAINTER
// ============================================================
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

    final w = size.width;
    final h = size.height;
    final stepX = w / (data.length - 1);

    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      canvas.drawLine(Offset(0, h * i / 4), Offset(w, h * i / 4), gridPaint);
    }

    double yFor(double val) => h - ((val - minVal) / range) * h;

    void drawLine(List<double> vals, Color color) {
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
        if (i == 0)
          path.moveTo(x, y);
        else
          path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);
      final dot = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      for (int i = 0; i < vals.length; i++) {
        canvas.drawCircle(Offset(stepX * i, yFor(vals[i])), 3, dot);
      }
    }

    drawLine(data.map((d) => d.accel).toList(), const Color(0xFF3B82F6));
    drawLine(data.map((d) => d.gyro).toList(), const Color(0xFF10B981));
  }

  @override
  bool shouldRepaint(_SensorChartPainter old) => false;
}

// ============================================================
// MAP GRID PAINTER
// ============================================================
// ignore: unused_element
// ignore: unused_element
class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFBFDBFE).withOpacity(0.5)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 20) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 20) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_MapGridPainter old) => false;
}

// ============================================================
// STATUS DESIGN
// ============================================================
class _StatusDesign {
  final String label;
  final Color text;
  final Color bg;
  final Color border;
  const _StatusDesign(this.label, this.text, this.bg, this.border);
}
