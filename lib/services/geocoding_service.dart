// lib/services/geocoding_service.dart
//
// Reverse geocoding (lat/lng -> nama jalan/tempat) pakai Nominatim
// (OpenStreetMap). Gratis, tanpa API key.
//
// Dipakai dari history_screen.dart untuk mengisi "lokasiNama" yang
// sebelumnya selalu "Unknown" dari firmware ESP32 (lihat pushHistory()
// di GuardianWalk.ino -- field itu memang hardcoded "Unknown", belum
// pernah diisi beneran).
//
// PENTING:
// - Nominatim WAJIB diberi header User-Agent, kalau tidak bisa di-block.
// - Rate limit resmi Nominatim: MAKSIMAL 1 request/detik. Karena geocoding
//   di sini hanya dipanggil saat user membuka detail satu history item
//   (bukan looping banyak item sekaligus), ini aman dipakai apa adanya.
// - Ada cache in-memory sederhana per sesi app supaya kalau user buka-tutup
//   detail yang sama gak query ulang ke Nominatim.

import 'dart:convert';
import 'package:http/http.dart' as http;

class GeocodingService {
  static const String _userAgent =
      'GuardianWalk-App/1.0 (Tugas Akhir Polines - Sistem Monitoring Lansia)';

  static const String _baseUrl = 'https://nominatim.openstreetmap.org/reverse';

  // "Sentinel" -- nilai yang dianggap BUKAN nama lokasi asli, jadi widget
  // tahu kapan perlu geocoding ulang.
  static const String placeholderUnknown = 'Unknown';
  static const String placeholderKoordinat = 'Koordinat GPS';
  static const String fallbackNotFound = 'Lokasi tidak diketahui';
  static const String fallbackNoGps = 'Lokasi belum tersedia';

  static final Map<String, String> _cache = {};

  /// True kalau nilai lokasiNama yang datang dari Firebase/model masih
  /// berupa placeholder dan perlu di-resolve lewat geocoding.
  static bool needsGeocoding(String? lokasiNama) {
    return lokasiNama == null ||
        lokasiNama.isEmpty ||
        lokasiNama == placeholderUnknown ||
        lokasiNama == placeholderKoordinat;
  }

  /// Ambil nama lokasi dari koordinat lat/lng.
  static Future<String> getLocationName(double lat, double lng) async {
    if (lat == 0.0 && lng == 0.0) {
      return fallbackNoGps;
    }

    final cacheKey = '${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      final url = Uri.parse(
        '$_baseUrl?lat=$lat&lon=$lng&format=json&addressdetails=1&accept-language=id',
      );

      final response = await http
          .get(url, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        return fallbackNotFound;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data.containsKey('error')) {
        return fallbackNotFound;
      }

      final namaLokasi = _formatAddress(data);
      _cache[cacheKey] = namaLokasi;
      return namaLokasi;
    } catch (_) {
      return fallbackNotFound;
    }
  }

  /// Parse koordinat dari string format "lat,lng" (format yang dipakai
  /// field lokasiKoordinat di Firebase/history_model.dart).
  static ({double lat, double lng})? parseCoordString(String? koordStr) {
    if (koordStr == null || koordStr.isEmpty) return null;
    try {
      final parts = koordStr.split(',');
      if (parts.length < 2) return null;
      final lat = double.parse(parts[0].trim());
      final lng = double.parse(parts[1].trim());
      return (lat: lat, lng: lng);
    } catch (_) {
      return null;
    }
  }

  static String _formatAddress(Map<String, dynamic> data) {
    final address = data['address'] as Map<String, dynamic>?;
    if (address == null) {
      return (data['display_name'] as String?) ?? fallbackNotFound;
    }

    final jalan = address['road'] ??
        address['pedestrian'] ??
        address['neighbourhood'] ??
        address['suburb'];

    final kecamatan = address['city_district'] ?? address['suburb'];
    final kota = address['city'] ??
        address['town'] ??
        address['county'] ??
        address['state'];

    final parts = <String>[];
    if (jalan != null) parts.add(jalan.toString());
    if (kecamatan != null && kecamatan != jalan) parts.add(kecamatan.toString());
    if (kota != null) parts.add(kota.toString());

    if (parts.isEmpty) {
      return (data['display_name'] as String?) ?? fallbackNotFound;
    }

    return parts.join(', ');
  }
}