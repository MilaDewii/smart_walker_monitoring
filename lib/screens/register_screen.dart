import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_routes.dart';
import '../database/database_helper.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Controller Step 1
  final _namaController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  // Controller Step 2
  final _namaLansiaController = TextEditingController();
  final _umurController = TextEditingController();
  final _namaKontakController = TextEditingController();
  final _nomorTelpController = TextEditingController();
  String? _jenisKelamin;
  String? _relasi;

  Future<void> register() async {
    // Validasi sederhana
    if (_namaController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lengkapi data akun terlebih dahulu'),
        ),
      );
      return;
    }

// =========================
    // VALIDASI EMAIL
    // =========================
    final email = _emailController.text.trim();

    final emailRegex = RegExp(
      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
    );

    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Format email tidak valid'),
        ),
      );
      return;
    }

    // =========================
    // VALIDASI PASSWORD
    // =========================
    final password = _passwordController.text;

    final passwordRegex = RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&]).{8,}$',
    );

    if (!passwordRegex.hasMatch(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password minimal 8 karakter dan harus mengandung huruf besar, huruf kecil, angka, dan simbol',
          ),
        ),
      );
      return;
    }

    // cek email sudah ada
    final isExist =
        await DatabaseHelper.instance.isEmailExist(_emailController.text);

    if (isExist) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email sudah terdaftar'),
        ),
      );
      return;
    }

    // simpan user
    final userId = await DatabaseHelper.instance.registerUser(
      nama: _namaController.text,
      email: _emailController.text,
      password: _passwordController.text,
      noHp: _nomorTelpController.text,
    );

    // simpan profile lansia
    await DatabaseHelper.instance.saveProfile(
      nama: _namaController.text,
      email: _emailController.text,
      noHp: _nomorTelpController.text,
      foto: '',
      namaLansia: _namaLansiaController.text,
      umurLansia: int.tryParse(_umurController.text) ?? 0,
      jenisKelaminLansia: _jenisKelamin ?? '',
    );

    // simpan kontak darurat
    await DatabaseHelper.instance.saveEmergencyContact(
      contactName: _namaKontakController.text,
      contactNumber: _nomorTelpController.text,
      relationship: _relasi ?? '',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Registrasi berhasil'),
      ),
    );

    // simpan session login
    await DatabaseHelper.instance.saveLoginSession(
        userId: userId.toString(), email: _emailController.text, rememberMe: 0);

    // CEK SESSION
    final session = await DatabaseHelper.instance.getLoginSession();

    print("SESSION REGISTER:");
    print(session);

    Navigator.pushReplacementNamed(
      context,
      AppRoutes.connectWalker,
    );
  }

  @override
  void dispose() {
    _namaController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _namaLansiaController.dispose();
    _umurController.dispose();
    _namaKontakController.dispose();
    _nomorTelpController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep = 1);
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.monitoring);
    }
  }

  void _prevStep() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _currentStep = 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed:
              _currentStep == 1 ? _prevStep : () => Navigator.pop(context),
        ),
        title: Text(
          'Daftar Akun',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Stepper indicator dengan lingkaran
          _buildStepIndicator(),

          // Konten halaman
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1(),
                _buildStep2(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── STEP INDICATOR ───────────────────────────────────
  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
      child: Row(
        children: [
          // Lingkaran step 1
          _buildStepCircle(1, true),
          // Garis
          Expanded(
            child: Container(
              height: 2,
              color: _currentStep == 1
                  ? AppColors.primary
                  : AppColors.primary.withOpacity(0.2),
            ),
          ),
          // Lingkaran step 2
          _buildStepCircle(2, _currentStep == 1),
        ],
      ),
    );
  }

  Widget _buildStepCircle(int step, bool isActive) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color:
            isActive ? AppColors.primary : AppColors.primary.withOpacity(0.2),
      ),
      child: Center(
        child: Text(
          '$step',
          style: TextStyle(
            color: isActive ? Colors.white : AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  // ── STEP 1 ──────────────────────────────────────────
  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header info
          _buildSectionHeader(
            icon: Icons.person_outline,
            title: 'Buat Akun',
            subtitle: 'Lengkapi data Akun anda terlebih dahulu',
          ),
          const SizedBox(height: 20),

          // Nama Lengkap
          _buildTextField(
            controller: _namaController,
            label: 'Nama Lengkap',
            hint: 'Masukkan nama lengkap',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 16),

          // Email
          _buildTextField(
            controller: _emailController,
            label: 'Email',
            hint: 'Masukkan email aktif',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),

          // Password
          _buildTextField(
            controller: _passwordController,
            label: 'Password',
            hint: 'Masukkan password',
            icon: Icons.lock_outline,
            isPassword: true,
            obscureText: _obscurePassword,
            onTogglePassword: () {
              setState(() => _obscurePassword = !_obscurePassword);
            },
          ),
          const SizedBox(height: 6),

          Text(
            'Minimal 8 karakter, terdiri dari huruf besar, huruf kecil, angka, dan simbol',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 32),

          // Tombol Lanjut
          _buildButton('Lanjut', _nextStep),
          const SizedBox(height: 16),

          // Link sudah punya akun
          Center(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Sudah Punya Akun? ',
                      style: TextStyle(color: AppColors.textGrey, fontSize: 13),
                    ),
                    TextSpan(
                      text: 'Masuk',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── STEP 2 ──────────────────────────────────────────
  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header info
          _buildSectionHeader(
            icon: Icons.directions_walk,
            title: 'Data Lansia',
            subtitle: 'Masukkan data lansia yang akan di pantau',
          ),
          const SizedBox(height: 20),

          // Nama Lansia
          _buildTextField(
            controller: _namaLansiaController,
            label: 'Nama Lansia',
            hint: 'Masukkan Nama Lengkap Lansia',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 16),

          // Umur + Jenis Kelamin (sejajar)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _umurController,
                    label: 'Umur',
                    hint: 'Contoh : 74',
                    icon: Icons.calendar_today_outlined,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdown(
                    value: _jenisKelamin,
                    hint: 'Jenis Kelamin',
                    icon: Icons.person_outline,
                    items: ['Laki-laki', 'Perempuan'],
                    onChanged: (val) => setState(() => _jenisKelamin = val),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Divider kontak darurat
          _buildSectionHeader(
            icon: Icons.phone_outlined,
            title: 'Kontak Darurat',
            subtitle: 'Kontak ini akan dihubungi saat kondisi darurat.',
          ),
          const SizedBox(height: 16),

          // Nama Kontak
          _buildTextField(
            controller: _namaKontakController,
            label: 'Nama Kontak',
            hint: 'Masukkan Nama Kontak Darurat',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 16),

          // Nomor Telp
          _buildTextField(
            controller: _nomorTelpController,
            label: 'Nomor Telp',
            hint: 'Contoh : 081229129479',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),

          // Relasi
          _buildLabel('Relasi'),
          _buildDropdown(
            value: _relasi,
            hint: 'Pilih',
            icon: Icons.people_outline,
            items: ['Anak', 'Cucu', 'Pasangan', 'Saudara', 'Lainnya'],
            onChanged: (val) => setState(() => _relasi = val),
          ),
          const SizedBox(height: 32),

          // Tombol Daftar
          _buildButton('Daftar', register),
          const SizedBox(height: 12),

          // Teks kebijakan privasi
          Center(
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Dengan mendaftar , anda menyetujui\n',
                    style: TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 12,
                    ),
                  ),
                  TextSpan(
                    text: 'KebijakanPrivasi ',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: 'dan ',
                    style: TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 12,
                    ),
                  ),
                  TextSpan(
                    text: 'Ketentuan Layanan',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── WIDGET HELPERS ───────────────────────────────────
  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textGrey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textDark,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onTogglePassword,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: AppColors.textGrey, fontSize: 13),
        floatingLabelStyle: TextStyle(
          // ← label saat diklik
          color: AppColors.primary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        hintStyle:
            TextStyle(color: AppColors.textGrey.withOpacity(0.6), fontSize: 13),
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.textGrey,
                  size: 20,
                ),
                onPressed: onTogglePassword,
              )
            : null,
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          // ← border normal
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          // ← border saat diklik biru
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required IconData icon,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return PopupMenuButton<String>(
      onSelected: onChanged,
      offset: const Offset(-20, 0),
      itemBuilder: (context) => items.map((item) {
        return PopupMenuItem<String>(
          value: item,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Text(item, style: const TextStyle(fontSize: 13)),
            ],
          ),
        );
      }).toList(),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value ?? hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: TextStyle(
                  fontSize: 13,
                  color:
                      value != null ? AppColors.textDark : AppColors.textGrey,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down, color: AppColors.textGrey),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
