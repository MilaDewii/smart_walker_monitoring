import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import 'reset_password_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends State<ForgotPasswordScreen> {

  final _emailController =
      TextEditingController();

  final _noHpController =
      TextEditingController();

  Future verifyUser() async {
    final user =
        await DatabaseHelper.instance.checkUserForReset(
      _emailController.text.trim(),
      _noHpController.text.trim(),
    );

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Email atau nomor HP tidak sesuai',
          ),
        ),
      );

      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResetPasswordScreen(
          userId: user['id'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lupa Password'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [

            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _noHpController,
              decoration: const InputDecoration(
                labelText: 'Nomor HP',
              ),
            ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: verifyUser,
              child: const Text(
                'Verifikasi',
              ),
            ),
          ],
        ),
      ),
    );
  }
}