import '../database/database_helper.dart';
import 'firebase_service.dart';

/// Sinkron nomor kontak darurat (diisi user pas registrasi, tabel
/// emergency_contacts) ke Firebase "/Walkers/<walkerId>/config/caregiver_phone"
/// -- dibaca ESP32 buat SMS darurat kalau internet/GPRS mati.
class CaregiverSyncService {
  static Future<void> syncIfPossible() async {
    final walker = await DatabaseHelper.instance.getLastPairedWalker();
    if (walker == null) return; // belum pairing walker

    final contacts = await DatabaseHelper.instance.getEmergencyContacts();
    if (contacts.isEmpty) return; // belum isi kontak darurat

    // Ambil kontak paling baru (getEmergencyContacts() sudah orderBy id DESC)
    final noHp = contacts.first['contact_number'] as String?;
    if (noHp == null || noHp.trim().isEmpty) return;

    final walkerId = walker['walker_id'] as String;
    final normalized = _normalizePhone(noHp);

    try {
      await FirebaseService().setCaregiverPhone(walkerId, normalized);
      print('[CaregiverSync] Nomor $normalized -> $walkerId OK');
    } catch (e) {
      // Offline/error jaringan -- gak apa2, coba lagi di kesempatan berikutnya
      print('[CaregiverSync] Gagal sync: $e');
    }
  }

  // ESP32 (modem.sendSMS) butuh format internasional "+62...".
  static String _normalizePhone(String raw) {
    var p = raw.trim().replaceAll(RegExp(r'[\s-]'), '');
    if (p.startsWith('0')) {
      p = '+62${p.substring(1)}';
    } else if (p.startsWith('62')) {
      p = '+$p';
    } else if (!p.startsWith('+')) {
      p = '+62$p';
    }
    return p;
  }
}