import 'package:firebase_database/firebase_database.dart';
import '../database/database_helper.dart';

class WalkerConnectResult {
  final bool success;
  final String? walkerId;
  final String? errorMessage;

  WalkerConnectResult({
    required this.success,
    this.walkerId,
    this.errorMessage,
  });
}

class WalkerConnectService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  /// Validasi walker ke Firebase, lalu simpan ke SQLite jika valid.
  Future<WalkerConnectResult> connectWalker(String walkerId) async {
    try {
      // 1. Cek apakah walker_id exist di Firebase
      final ref = _db.ref('walkers/$walkerId');
      final snapshot = await ref.get();

      if (!snapshot.exists) {
        return WalkerConnectResult(
          success: false,
          errorMessage: 'Walker "$walkerId" tidak ditemukan.',
        );
      }

      // 2. (Opsional) cek status connected
      final statusSnap = await _db.ref('walkers/$walkerId/status/connected').get();
      final isConnected = statusSnap.value == true;
      if (!isConnected) {
        return WalkerConnectResult(
          success: false,
          errorMessage: 'Walker ditemukan tapi sedang offline.',
        );
      }

      // 3. Cek apakah sudah pernah dipasangkan
      final existing = await DatabaseHelper.instance.getPairedWalkers();
      final alreadyPaired = existing.any((w) => w['walker_id'] == walkerId);

      if (!alreadyPaired) {
        // 4. Simpan ke SQLite
        await DatabaseHelper.instance.savePairedWalker(
          walkerId: walkerId,
          pairedDate: DateTime.now().toIso8601String(),
        );
      }

      return WalkerConnectResult(success: true, walkerId: walkerId);
    } catch (e) {
      return WalkerConnectResult(
        success: false,
        errorMessage: 'Terjadi kesalahan: ${e.toString()}',
      );
    }
  }
}