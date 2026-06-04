import 'package:firebase_database/firebase_database.dart';
import 'firebase_service.dart';

class WalkerService {
  final DatabaseReference _db = FirebaseService().db;

  Future<DataSnapshot> getWalkerData(String walkerId) async {
    return await _db.child('Walkers/$walkerId').get();
  }

  // Future<DataSnapshot> getBattery(String walkerId) async {
  //   return await _db.child('Walkers/$walkerId/sensors/battery').get();
  // }

  Future<DataSnapshot> getLocation(String walkerId) async {
    return await _db.child('Walkers/$walkerId/location').get();
  }

  Future<DataSnapshot> getStatus(String walkerId) async {
    return await _db.child('Walkers/$walkerId/status').get();
  }

  Future<DataSnapshot> getSensors(String walkerId) async {
    return await _db.child('Walkers/$walkerId/sensors').get();
  }

  Future<DataSnapshot> getHistory(String walkerId) async {
    return await _db.child('Walkers/$walkerId/history').get();
  }

  Future<DataSnapshot> getNotifications(String walkerId) async {
    return await _db.child('Walkers/$walkerId/notification').get();
  }

  Future<DataSnapshot> getFallDetection(String walkerId) async {
    return await _db.child('Walkers/$walkerId/fall_detection').get();
  }

  Future<DataSnapshot> getGeofence(String walkerId) async {
    return await _db.child('Walkers/$walkerId/geofence').get();
  }
}
