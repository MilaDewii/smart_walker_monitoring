import 'package:firebase_database/firebase_database.dart';
import 'firebase_service.dart';

class NotificationService {
  final DatabaseReference _db = FirebaseService().db;

  Future<DataSnapshot> getNotifications(
      String walkerId) async {
    return await _db
        .child('Walkers/$walkerId/notification')
        .get();
  }

  Future<void> markAsRead(
      String walkerId,
      String notifId) async {
    await _db
        .child(
            'Walkers/$walkerId/notification/$notifId/is_read')
        .set(true);
  }

  Future<void> clearNotifications(
      String walkerId) async {
    await _db
        .child('Walkers/$walkerId/notification')
        .remove();
  }
}