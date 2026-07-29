import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../utils/app_routes.dart';

class ResetPasswordScreen extends StatefulWidget {
  final int userId;

  const ResetPasswordScreen({
    super.key,
    required this.userId,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState
    extends State<ResetPasswordScreen> {

  final _passwordController =
      TextEditingController();

  final _confirmPasswordController =
      TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
void dispose() {
  _passwordController.dispose();
  _confirmPasswordController.dispose();
  super.dispose();
}

Future resetPassword() async {
  if (_passwordController.text.isEmpty ||
      _confirmPasswordController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Semua field wajib diisi',
        ),
      ),
    );

    return;
  }

  final passwordRegex = RegExp(
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&]).{8,}$',
  );

  if (!passwordRegex.hasMatch(
    _passwordController.text,
  )) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Password minimal 8 karakter dan harus mengandung huruf besar, huruf kecil, angka, dan simbol',
        ),
      ),
    );

    return;
  }

  if (_passwordController.text != _confirmPasswordController.text) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Konfirmasi password tidak cocok',
        ),
      ),
    );

    return;
  }

  await DatabaseHelper.instance.updatePassword(
    widget.userId,
    _passwordController.text,
  );

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(
        'Password berhasil diperbarui',
      ),
    ),
  );

  Navigator.pushNamedAndRemoveUntil(
    context,
    AppRoutes.login,
    (route) => false,
  );
}

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Reset Password'),
    ),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [

          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password Baru',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword =
                        !_obscurePassword;
                  });
                },
              ),
            ),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              labelText: 'Konfirmasi Password',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _obscureConfirmPassword =
                        !_obscureConfirmPassword;
                  });
                },
              ),
            ),
          ),

          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: resetPassword,
            child: const Text(
              'Simpan Password',
              ),
            ),
          ],
        ),
      ),
    );
  }
}