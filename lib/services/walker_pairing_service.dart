import 'package:shared_preferences/shared_preferences.dart';

enum PairingResult {
  success,
  walkerNotFound,
  error,
}

class QrService {
  static const String walkerKey = 'paired_walker';

  Future<(PairingResult, String?)> pairWalker(
    String walkerId,
  ) async {
    try {
      if (walkerId.isEmpty) {
        return (
          PairingResult.walkerNotFound,
          'QR Walker tidak valid'
        );
      }

      final prefs =
          await SharedPreferences.getInstance();

      await prefs.setString(
        walkerKey,
        walkerId,
      );

      return (
        PairingResult.success,
        null,
      );
    } catch (e) {
      return (
        PairingResult.error,
        e.toString(),
      );
    }
  }

  Future<String?> getWalkerId() async {
    final prefs =
        await SharedPreferences.getInstance();

    return prefs.getString(walkerKey);
  }

  Future<void> removeWalker() async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.remove(walkerKey);
  }
}