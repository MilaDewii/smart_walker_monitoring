import 'dart:io';
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../database/database_helper.dart';
import '../models/alert_model.dart';
import '../services/notification_service.dart';
import '../screens/notif_screen.dart' show NotificationDetailScreen;
import '../services/history_service.dart';
import '../utils/app_routes.dart';

void setupOneSignalClickHandler(GlobalKey<NavigatorState> navigatorKey) {
  OneSignal.Notifications.addClickListener((event) async {
    debugPrint('[OneSignal] Notif diklik!');
    debugPrint(
        '[OneSignal] additionalData: ${event.notification.additionalData}');

    final data = event.notification.additionalData;
    if (data == null) {
      debugPrint(
          '[OneSignal] additionalData NULL — payload tidak punya data{}');
      return;
    }

    final notifId = data['notifId']?.toString();
    final walkerId = data['walkerId']?.toString();
    debugPrint('[OneSignal] notifId=$notifId walkerId=$walkerId');

    if (notifId == null ||
        notifId.isEmpty ||
        walkerId == null ||
        walkerId.isEmpty) {
      debugPrint('[OneSignal] notifId/walkerId kosong, batal navigasi');
      return;
    }

    await _waitForNavigatorReady(navigatorKey);
    await Future.delayed(const Duration(milliseconds: 500)); //

    final service = NotificationService(walkerId: walkerId);
    final items = await service.fetchNotifications();
    debugPrint('[OneSignal] fetched ${items.length} notif dari RTDB');

    AlertItem? item;
    for (final a in items) {
      if (a.id == notifId) {
        item = a;
        break;
      }
    }

    if (item == null) {
      debugPrint('[OneSignal] notifId $notifId tidak ditemukan di RTDB');
      navigatorKey.currentState?.pushNamed('/notification');
      return;
    }

    await service.markAsRead(item.id);

    final profile = await DatabaseHelper.instance.getProfile();
    final namaLengkap = profile?['nama']?.toString() ?? 'User';
    final namaLansia = profile?['nama_lansia']?.toString() ?? 'Nama Lansia';
    final fotoPath = profile?['foto']?.toString() ?? '';
    File? fotoFile;
    if (fotoPath.isNotEmpty && File(fotoPath).existsSync()) {
      fotoFile = File(fotoPath);
    }

    // Tunggu navigator siap (penting untuk cold start)
    await _waitForNavigatorReady(navigatorKey);

    final historyService = HistoryService(walkerId: walkerId);
    final historyItem = await historyService.findByNotification(
      timestamp: item!.timestamp,
      title: item!.title,
    );
    debugPrint('[History] historyItem id: ${historyItem?.id}');

    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => NotificationDetailScreen(
          item: item!.copyWith(sudahDibaca: true),
          namaLansia: namaLansia,
          namaLengkap: namaLengkap,
          fotoFile: fotoFile,
          service: service,
          historyItem: historyItem, // ◄ TAMBAH INI
        ),
      ),
    );
    debugPrint('[OneSignal] Navigasi ke NotificationDetailScreen berhasil');
  });
}

Future<void> _waitForNavigatorReady(GlobalKey<NavigatorState> key) async {
  int attempts = 0;
  while (key.currentState == null && attempts < 50) {
    await Future.delayed(const Duration(milliseconds: 100));
    attempts++;
  }
}
