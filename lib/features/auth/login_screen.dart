import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/components/neu_surface.dart';
import '../shell/app_shell.dart';
import 'register_screen.dart';

/// Halaman Login TiramSehat
/// Mengikuti spesifikasi desain [docs/design/Login_Page.png]
/// dengan implementasi Soft UI / Neumorphism, animasi opening bertahap,
/// serta penanganan responsif dan keyboard-friendly.
class LoginScreen extends StatefulWidget {
  /// Callback ketika login berhasil (opsional, default: navigasi ke [AppShell])
  final VoidCallback? onLoginSuccess;

  const LoginScreen({super.key, this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _phoneOrIdController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  bool _isObscurePin = true;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isOfflineOffer = false;

  late final AnimationController _animController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _cardSlide;
  late final Animation<double> _cardFade;
  late final Animation<Offset> _actionsSlide;
  late final Animation<double> _actionsFade;
  late final Animation<double> _footerFade;

  @override
  void initState() {
    super.initState();

    // Controller animasi opening (durasi 950ms dengan kurva easeOut halus)
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    // Staggered animations:
    // 1. Logo pop & fade in
    _logoScale = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutBack),
      ),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
      ),
    );

    // 2. Teks header sapaan slide up & fade in
    _headerSlide = Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _animController,
            curve: const Interval(0.20, 0.60, curve: Curves.easeOutCubic),
          ),
        );
    _headerFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.20, 0.55, curve: Curves.easeOut),
      ),
    );

    // 3. Neumorphic Card form slide up & fade in
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _animController,
            curve: const Interval(0.35, 0.80, curve: Curves.easeOutCubic),
          ),
        );
    _cardFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.35, 0.75, curve: Curves.easeOut),
      ),
    );

    // 4. Action button & divider slide up & fade in
    _actionsSlide =
        Tween<Offset>(begin: const Offset(0, 0.20), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animController,
            curve: const Interval(0.55, 0.95, curve: Curves.easeOutCubic),
          ),
        );
    _actionsFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.55, 0.90, curve: Curves.easeOut),
      ),
    );

    // 5. Footer info fade in
    _footerFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.70, 1.0, curve: Curves.easeIn),
      ),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _phoneOrIdController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_errorMessage != null || _isOfflineOffer) {
      setState(() {
        _errorMessage = null;
        _isOfflineOffer = false;
      });
    }
  }

  void _showError(String message, {bool isWarning = false}) {
    setState(() {
      _isLoading = false;
      _errorMessage = message;
      _isOfflineOffer = isWarning;
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

  void _completeLogin() {
    if (widget.onLoginSuccess != null) {
      widget.onLoginSuccess!();
    } else {
      Navigator.of(context)
          .pushReplacement(MaterialPageRoute(builder: (_) => const AppShell()));
    }
  }

  void _handleLogin() async {
    FocusScope.of(context).unfocus();
    final identifier = _phoneOrIdController.text.trim();
    final pin = _pinController.text.trim();

    if (identifier.isEmpty || pin.isEmpty) {
      _showError('Masukkan Nomor WhatsApp/ID Petani dan PIN.');
      return;
    }

    if (pin.length < 4 || pin.length > 8) {
      _showError('PIN masuk harus terdiri dari 4–8 angka.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isOfflineOffer = false;
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
          '/api/v1/auth/login',
          body: {'identifier': identifier, 'pin': pin},
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
          _completeLogin();
          return;
        }

        final code = res.error?.code ?? 'AUTH_ERROR';
        final String message;
        if (code == 'UNAUTHENTICATED' || code == 'http_401') {
          message =
              'Nomor WhatsApp / ID Petani atau PIN salah. Silakan periksa kembali.';
        } else if (code == 'http_422' || code == 'VALIDATION_ERROR') {
          message =
              'Format Nomor WhatsApp / ID Petani atau PIN tidak valid (4–8 angka).';
        } else {
          message = res.error?.message ?? 'Login gagal. Silakan coba lagi.';
        }
        _showError(message);
        return;
      } catch (_) {
        if (!mounted) return;
        _showError(
          'Tidak dapat terhubung ke server. Pastikan backend berjalan atau lanjutkan mode offline.',
          isWarning: true,
        );
        return;
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 400));
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
    _completeLogin();
  }

  void _showForgotPasswordDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: const BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.card),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceInset,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.warning100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_reset_rounded,
                    color: AppColors.warning500,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lupa PIN Masuk?',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Bantuan Pemulihan Akun Petani',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s4),
            NeuSurface(
              variant: NeuVariant.inset,
              radius: AppRadius.tile,
              padding: const EdgeInsets.all(AppSpacing.s4),
              child: Text(
                'Demi keamanan data hasil panen kumbung, silakan hubungi Ketua Kelompok Tani atau Pengurus BUMDes Margomulyo untuk reset PIN akun Anda.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s5),
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primary800,
                  borderRadius: BorderRadius.circular(AppRadius.button),
                  boxShadow: AppShadows.buttonPrimary,
                ),
                alignment: Alignment.center,
                child: Text(
                  'Mengerti',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textOnPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s2),
          ],
        ),
      ),
    );
  }

  Future<void> _openRegisterScreen() async {
    final registered = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RegisterScreen(
          onRegisterSuccess: () => Navigator.of(context).pop(true),
        ),
      ),
    );
    if (registered == true && mounted) {
      _completeLogin();
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
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pagePaddingX,
                vertical: AppSpacing.s4,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ================= 1. LOGO & BRAND HEADER =================
                    ScaleTransition(
                      scale: _logoScale,
                      child: FadeTransition(
                        opacity: _logoFade,
                        child: _buildBrandLogo(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s4),

                    // ================= 2. WELCOME HEADLINE =================
                    SlideTransition(
                      position: _headerSlide,
                      child: FadeTransition(
                        opacity: _headerFade,
                        child: Column(
                          children: [
                            Text(
                              'Selamat Datang, Petani!',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s2),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                'Masuk untuk mencatat hasil panen dan memantau kesehatan baglog.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: AppColors.textSecondary,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s6),

                    // ================= 3. FORM CARD =================
                    SlideTransition(
                      position: _cardSlide,
                      child: FadeTransition(
                        opacity: _cardFade,
                        child: NeuSurface(
                          variant: NeuVariant.raised,
                          radius: AppRadius.card,
                          padding: const EdgeInsets.all(AppSpacing.cardPadding),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Field 1: Nomor WhatsApp / ID Petani
                              _buildFieldLabel(
                                icon: Icons.badge_outlined,
                                label: 'Nomor WhatsApp / ID Petani',
                              ),
                              const SizedBox(height: AppSpacing.s2 + 2),
                              _buildInputField(
                                controller: _phoneOrIdController,
                                prefixIcon: Icons.phone_outlined,
                                hintText: 'Contoh: 0812×xxx atau P-01',
                                keyboardType: TextInputType.text,
                                textInputAction: TextInputAction.next,
                                hasError: _errorMessage != null && !_isOfflineOffer,
                                onChanged: (_) => _clearError(),
                              ),
                              const SizedBox(height: AppSpacing.s4 + 2),

                              // Field 2: PIN Masuk
                              _buildFieldLabel(
                                icon: Icons.pin_outlined,
                                label: 'PIN Masuk',
                              ),
                              const SizedBox(height: AppSpacing.s2 + 2),
                              _buildInputField(
                                controller: _pinController,
                                prefixIcon: Icons.lock_outline_rounded,
                                hintText: 'Ketik 4–6 angka PIN',
                                obscureText: _isObscurePin,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                hasError: _errorMessage != null && !_isOfflineOffer,
                                onChanged: (_) => _clearError(),
                                onSubmitted: (_) => _handleLogin(),
                                suffixWidget: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _isObscurePin = !_isObscurePin;
                                    });
                                  },
                                  behavior: HitTestBehavior.opaque,
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Icon(
                                      _isObscurePin
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: AppColors.textMuted,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.s3),

                              // Helper: Lupa PIN?
                              Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                  onTap: _showForgotPasswordDialog,
                                  behavior: HitTestBehavior.opaque,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                      horizontal: 2,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.help_outline_rounded,
                                          size: 15,
                                          color: Color(0xFFE67E22),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Lupa PIN?',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              if (_errorMessage != null) ...[
                                const SizedBox(height: AppSpacing.s3),
                                _buildInlineErrorBanner(),
                              ],
                              const SizedBox(height: AppSpacing.s5),

                              // ================= 4. ACTION BUTTONS =================
                              SlideTransition(
                                position: _actionsSlide,
                                child: FadeTransition(
                                  opacity: _actionsFade,
                                  child: Column(
                                    children: [
                                      // Primary CTA: Masuk ke Kumbung
                                      _buildPrimaryButton(),
                                      if (_isOfflineOffer) ...[
                                        const SizedBox(height: AppSpacing.s3),
                                        _buildOfflineContinueButton(),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s5),

                    // ================= 5. FOOTER INFO =================
                    FadeTransition(
                      opacity: _footerFade,
                      child: _buildFooterSection(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Logo & Identitas Brand TiramSehat
  Widget _buildBrandLogo() {
    return Column(
      children: [
        Container(
          width: 82,
          height: 82,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            boxShadow: AppShadows.raised,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                color: AppColors.primary100,
                child: const Icon(
                  Icons.eco_rounded,
                  color: AppColors.primary800,
                  size: 40,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s3),
        Text(
          'TiramSehat',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.primary800,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  /// Label Field dengan Ikon Hijau Merek
  Widget _buildFieldLabel({required IconData icon, required String label}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary600),
        const SizedBox(width: AppSpacing.s2),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  /// Input Field dengan Nuansa Neumorphic Inset
  Widget _buildInputField({
    required TextEditingController controller,
    required IconData prefixIcon,
    required String hintText,
    bool obscureText = false,
    bool hasError = false,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    Widget? suffixWidget,
  }) {
    return NeuSurface(
      variant: NeuVariant.inset,
      radius: AppRadius.button,
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: hasError
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.button),
                border: Border.all(color: AppColors.danger600, width: 1.2),
              )
            : null,
        alignment: Alignment.center,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              prefixIcon,
              size: 20,
              color: hasError ? AppColors.danger600 : AppColors.textMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controller,
                obscureText: obscureText,
                keyboardType: keyboardType,
                textInputAction: textInputAction,
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
                    fontSize: 14,
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

  Widget _buildInlineErrorBanner() {
    final isWarning = _isOfflineOffer;
    final bgColor =
        isWarning ? const Color(0xFFFEF3DC) : AppColors.danger100;
    final borderColor =
        isWarning ? const Color(0xFFF7D59A) : AppColors.dangerBorder;
    final textColor =
        isWarning ? const Color(0xFF92530A) : AppColors.danger600;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isWarning
                ? Icons.cloud_off_rounded
                : Icons.error_outline_rounded,
            size: 18,
            color: textColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: textColor,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineContinueButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _completeLogin,
      child: NeuSurface(
        variant: NeuVariant.raised,
        radius: AppRadius.button,
        child: Container(
          width: double.infinity,
          height: 48,
          alignment: Alignment.center,
          child: Text(
            'Lanjutkan dalam Mode Offline',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.primary800,
            ),
          ),
        ),
      ),
    );
  }

  /// Tombol Primer "Masuk ke Kumbung"
  Widget _buildPrimaryButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _handleLogin,
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
                    Flexible(
                      child: Text(
                        'Masuk ke Kumbung',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textOnPrimary,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s2),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: AppColors.textOnPrimary,
                      size: 19,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// Footer Mode Offline & Informasi Tambahan
  Widget _buildFooterSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            text: 'Petani baru? ',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            children: [
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: GestureDetector(
                  onTap: _openRegisterScreen,
                  child: Text(
                    'Registrasi Akun',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
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
        ),
      ],
    );
  }
}