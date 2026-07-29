import 'package:flutter/material.dart';
import '../utils/app_routes.dart';
import '../database/database_helper.dart';

class WalkerConnectScreen extends StatefulWidget {
  const WalkerConnectScreen({super.key});

  @override
  State<WalkerConnectScreen> createState() => _WalkerConnectScreenState();
}

class _WalkerConnectScreenState extends State<WalkerConnectScreen> {
  String? walkerId;
  String? connectedAt;

  @override
  void initState() {
    super.initState();
    loadWalker();
  }

  Future<void> loadWalker() async {
    final walkers = await DatabaseHelper.instance.getPairedWalkers();

    if (!mounted || walkers.isEmpty) return;

    final walker = walkers.first;
    setState(() {
      walkerId = walker['walker_id']?.toString();
      connectedAt = walker['paired_date']?.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isConnected = walkerId != null;

    return Scaffold(
      backgroundColor: const Color(0xFFE8F0FB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              if (isConnected) ...[
                Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 90,
                ),
                const SizedBox(height: 20),
                const Text(
                  "Walker Terhubung",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "ID : $walkerId",
                  style: const TextStyle(
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Terhubung pada:\n$connectedAt",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.grey,
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 40), // atur jaraknya
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(
                          context,
                          AppRoutes.monitoring,
                        );
                      },
                      child: const Text(
                        "Mulai Monitoring",
                      ),
                    ),
                  ),
                )
              ] else ...[
                const Spacer(),
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.wifi_off_rounded,
                    color: Colors.red,
                    size: 50,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Walker Belum Terhubung",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.qrConnect,
                      );
                    },
                    icon: const Icon(Icons.qr_code),
                    label: const Text(
                      "Hubungkan Walker",
                    ),
                  ),
                ),
                const Spacer(),
              ]
            ],
          ),
        ),
      ),
    );
  }
}