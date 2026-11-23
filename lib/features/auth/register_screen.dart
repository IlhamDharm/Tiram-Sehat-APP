import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/components/neu_surface.dart';
import '../../core/network/api_providers.dart';
import '../../core/theme/tokens.dart';
import '../shell/app_shell.dart';

/// Halaman Registrasi Akun Petani TiramSehat.
class RegisterScreen extends StatefulWidget {
  final VoidCallback? onRegisterSuccess;

  const RegisterScreen({super.key, this.onRegisterSuccess});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _farmerIdController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();

  bool _isObscurePin = true;
  bool _isObscureConfirmPin = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _farmerIdController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
  }

  void _showError(String message, {bool isWarning = false}) {
    setState(() {
      _isLoading = false;
      _errorMessage = message;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isWarning ? const Color(0xFF5D2E14) : AppColors.danger600,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Row(
          children: [
            Icon(
              isWarning
                  ? Icons.cloud_off_rounded
                  : Icons.error_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final farmerId = _farmerIdController.text.trim();
    final pin = _pinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (name.length < 2) {
      _showError('Nama lengkap minimal 2 karakter.');
      return;
    }

    if (phone.length < 8) {
      _showError('Masukkan Nomor WhatsApp yang valid (minimal 8 digit).');
      return;
    }

    if (pin.length < 4 || pin.length > 8 || !RegExp(r'^\d+$').hasMatch(pin)) {
      _showError('PIN masuk harus terdiri dari 4–8 digit angka.');
      return;
    }

    if (pin != confirmPin) {
      _showError('Konfirmasi PIN tidak cocok dengan PIN masuk.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    ProviderContainer? container;
    try {
      container = ProviderScope.containerOf(context, listen: false);
    } catch (_) {
      container = null;
    }

    if (container != null) {
      try {
        final api = container.read(apiClientProvider);
        final res = await api.post(
          '/api/v1/auth/register',
          body: {
            'name': name,
            'phone': phone,
            'pin': pin,
            if (farmerId.isNotEmpty) 'farmer_id': farmerId,
          },
        );
        if (!mounted) return;

        if (res.error == null && res.data is Map<String, dynamic>) {
          final accessToken = res.data['access_token']?.toString();
          final refreshToken = res.data['refresh_token']?.toString();
          if (accessToken != null && accessToken.isNotEmpty) {
            container.read(authTokenProvider.notifier).state = accessToken;
          }
          if (refreshToken != null && refreshToken.isNotEmpty) {
            container.read(refreshTokenProvider.notifier).state = refreshToken;
          }
          setState(() => _isLoading = false);
          _completeRegistration(name);
          return;
        }

        _showError(
          res.error?.message ?? 'Registrasi gagal. Silakan periksa data Anda.',
        );
        return;
      } catch (_) {
        if (!mounted) return;
        _showError(
          'Tidak dapat terhubung ke server. Pastikan backend berjalan untuk mendaftar akun baru.',
          isWarning: true,
        );
        return;
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
    _completeRegistration(name);
  }

  void _completeRegistration(String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary800,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Text(
          'Registrasi berhasil! Selamat datang, $name.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );

    if (widget.onRegisterSuccess != null) {
      widget.onRegisterSuccess!();
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppShell()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pagePaddingX,
                      AppSpacing.s2,
                      AppSpacing.pagePaddingX,
                      AppSpacing.s6,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: AppSpacing.s5),
                          _buildFormCard(),
                          const SizedBox(height: AppSpacing.s5),
                          _buildFooterLink(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePaddingX,
        vertical: AppSpacing.s3,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppShadows.raisedSm,
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.textPrimary,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          Text(
            'Registrasi Akun',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 68,
          height: 68,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppShadows.raised,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              'assets/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                color: AppColors.primary100,
                child: const Icon(
                  Icons.eco_rounded,
                  color: AppColors.primary800,
                  size: 32,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s3),
        Text(
          'Daftar Akun Petani',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: AppSpacing.s1),
        Text(
          'Lengkapi data diri untuk mulai mencatat panen dan memantau baglog kumbung.',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            color: AppColors.textSecondary,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    final hasError = _errorMessage != null;

    return NeuSurface(
      variant: NeuVariant.raised,
      radius: AppRadius.card,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldLabel(
            icon: Icons.person_outline_rounded,
            label: 'Nama Lengkap',
          ),
          const SizedBox(height: AppSpacing.s2),
          _buildInputField(
            controller: _nameController,
            prefixIcon: Icons.person_outline_rounded,
            hintText: 'Contoh: Budi Santoso',
            textInputAction: TextInputAction.next,
            onChanged: (_) => _clearError(),
          ),
          const SizedBox(height: AppSpacing.s4),

          _buildFieldLabel(
            icon: Icons.phone_outlined,
            label: 'Nomor WhatsApp',
          ),
          const SizedBox(height: AppSpacing.s2),
          _buildInputField(
            controller: _phoneController,
            prefixIcon: Icons.phone_outlined,
            hintText: 'Contoh: 081234567890',
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            onChanged: (_) => _clearError(),
          ),
          const SizedBox(height: AppSpacing.s4),

          _buildFieldLabel(
            icon: Icons.badge_outlined,
            label: 'ID Petani (Opsional)',
          ),
          const SizedBox(height: AppSpacing.s2),
          _buildInputField(
            controller: _farmerIdController,
            prefixIcon: Icons.badge_outlined,
            hintText: 'Contoh: PETANI-002',
            textInputAction: TextInputAction.next,
            onChanged: (_) => _clearError(),
          ),
          const SizedBox(height: AppSpacing.s4),

          _buildFieldLabel(
            icon: Icons.pin_outlined,
            label: 'Buat PIN Masuk',
          ),
          const SizedBox(height: AppSpacing.s2),
          _buildInputField(
            controller: _pinController,
            prefixIcon: Icons.lock_outline_rounded,
            hintText: '4–6 angka PIN',
            obscureText: _isObscurePin,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
            ],
            onChanged: (_) => _clearError(),
            suffixWidget: _buildEyeToggle(
              obscure: _isObscurePin,
              onTap: () => setState(() => _isObscurePin = !_isObscurePin),
            ),
          ),
          const SizedBox(height: AppSpacing.s4),

          _buildFieldLabel(
            icon: Icons.lock_reset_rounded,
            label: 'Konfirmasi PIN Masuk',
          ),
          const SizedBox(height: AppSpacing.s2),
          _buildInputField(
            controller: _confirmPinController,
            prefixIcon: Icons.lock_outline_rounded,
            hintText: 'Ulangi PIN masuk',
            obscureText: _isObscureConfirmPin,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
            ],
            onChanged: (_) => _clearError(),
            onSubmitted: (_) => _handleRegister(),
            suffixWidget: _buildEyeToggle(
              obscure: _isObscureConfirmPin,
              onTap: () =>
                  setState(() => _isObscureConfirmPin = !_isObscureConfirmPin),
            ),
          ),

          if (hasError) ...[
            const SizedBox(height: AppSpacing.s3),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.danger100,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.dangerBorder, width: 1),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 18,
                    color: AppColors.danger600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.danger600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.s5),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildFieldLabel({required IconData icon, required String label}) {
    return Row(
      children: [
        Icon(icon, size: 17, color: AppColors.primary600),
        const SizedBox(width: AppSpacing.s2),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required IconData prefixIcon,
    required String hintText,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    Widget? suffixWidget,
  }) {
    return NeuSurface(
      variant: NeuVariant.inset,
      radius: AppRadius.button,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        child: Row(
          children: [
            Icon(prefixIcon, size: 20, color: AppColors.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controller,
                obscureText: obscureText,
                keyboardType: keyboardType,
                textInputAction: textInputAction,
                inputFormatters: inputFormatters,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textMuted,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            ?suffixWidget,
          ],
        ),
      ),
    );
  }

  Widget _buildEyeToggle({required bool obscure, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(
          obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: AppColors.textMuted,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _handleRegister,
      child: Container(
        width: double.infinity,
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
        decoration: BoxDecoration(
          color: AppColors.primary800,
          borderRadius: BorderRadius.circular(AppRadius.button),
          boxShadow: AppShadows.buttonPrimary,
        ),
        child: Center(
          child: _isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.person_add_alt_1_rounded,
                      color: AppColors.textOnPrimary,
                      size: 19,
                    ),
                    const SizedBox(width: AppSpacing.s2),
                    Text(
                      'Daftar Sekarang',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textOnPrimary,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildFooterLink() {
    return Text.rich(
      TextSpan(
        text: 'Sudah punya akun? ',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12.5,
          color: AppColors.textSecondary,
        ),
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Text(
                'Masuk di sini',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary800,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
