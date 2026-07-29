import 'package:firebase_database/firebase_database.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();

  factory FirebaseService() => _instance;

  FirebaseService._internal();

  final DatabaseReference db = FirebaseDatabase.instance.ref();

  /// Tulis nomor kontak darurat ke Firebase, path yang dibaca ESP32:
  /// Walkers/<walkerId>/config/caregiver_phone
  /// (lihat syncCaregiverPhoneFromFirebase() di firmware)
  Future<void> setCaregiverPhone(String walkerId, String phone) async {
    await db.child('Walkers/$walkerId/config/caregiver_phone').set(phone);
  }

  /// Baca balik nomor caregiver dari Firebase (opsional, buat ditampilkan
  /// di UI misalnya di halaman settings/profile).
  Future<String?> getCaregiverPhone(String walkerId) async {
    final snapshot =
        await db.child('Walkers/$walkerId/config/caregiver_phone').get();
    return snapshot.exists ? snapshot.value as String? : null;
  }
}