import 'package:firebase_database/firebase_database.dart';
import 'package:latlong2/latlong.dart';
import '../models/location_data.dart';

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  Stream<LocationData> watchLocation(String walkerId) {
    return FirebaseDatabase.instance
        .ref('Walkers/$walkerId')
        .onValue
        .map((event) {
      if (event.snapshot.value == null) return LocationData.empty();
      final raw = event.snapshot.value;
      if (raw is! Map) return LocationData.empty();
      return _parse(Map<dynamic, dynamic>.from(raw));
    });
  }

  LocationData _parse(Map<dynamic, dynamic> data) {
    final loc        = _asMap(data['location']);
    final lat        = _toDouble(loc['latitude'],  -7.051234);
    final lng        = _toDouble(loc['longitude'], 110.442123);
    final lastUpdate = loc['last_update']?.toString() ?? '-';

    final geo        = _asMap(data['geofence']);
    final geoLat     = _toDouble(geo['center_latitude'],  -7.051);
    final geoLng     = _toDouble(geo['center_longitude'], 110.442);
    final radius     = _toDouble(geo['radius'], 100);
    final geoStatus  = geo['status']?.toString() ?? 'inside';

    final st         = _asMap(data['status']);
    final connected  = st['connected'] == true;

    return LocationData(
      lansiaPos      : LatLng(lat, lng),
      geofenceCenter : LatLng(geoLat, geoLng),
      geofenceRadius : radius,
      geofenceStatus : geoStatus,
      lastUpdate     : lastUpdate,
      connected      : connected,
    );
  }

  Map<dynamic, dynamic> _asMap(dynamic v) =>
      v is Map ? Map<dynamic, dynamic>.from(v) : {};

  double _toDouble(dynamic v, double fallback) {
    if (v is num)    return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }
}