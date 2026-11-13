import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/components/action_button.dart';
import '../../../core/components/neu_surface.dart';

class ScanLocationInput extends StatefulWidget {
  final Widget cameraPreview;
  final void Function(String rack, int column) onConfirm;
  final VoidCallback onCancel;

  const ScanLocationInput({
    super.key,
    required this.cameraPreview,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<ScanLocationInput> createState() => _ScanLocationInputState();
}

class _ScanLocationInputState extends State<ScanLocationInput> {
  final TextEditingController _rackController = TextEditingController();
  int _column = 1;
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    _rackController.addListener(_onRackChanged);
  }

  void _onRackChanged() => setState(() => _showError = false);

  @override
  void dispose() {
    _rackController
      ..removeListener(_onRackChanged)
      ..dispose();
    super.dispose();
  }

  bool get _isValid => RegExp(r'^[A-Z]$').hasMatch(_rackController.text);

  void _submit() {
    if (!_isValid) {
      setState(() => _showError = true);
      HapticFeedback.mediumImpact();
      return;
    }
    widget.onConfirm(_rackController.text, _column);
  }

  void _changeColumn(int delta) {
    final next = (_column + delta).clamp(1, 999);
    if (next == _column) return;
    HapticFeedback.lightImpact();
    setState(() => _column = next);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.cameraPreview,
        Container(color: Colors.black.withValues(alpha: 0.55)),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.pagePaddingX),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: NeuSurface(
                  padding: const EdgeInsets.all(AppSpacing.cardPadding),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: AppColors.success100,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.my_location_rounded,
                              color: AppColors.primary800,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Lokasi Baglog',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Tentukan rak dan kolom baglog ini.',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s5),
                      _FieldLabel('Rak'),
                      const SizedBox(height: AppSpacing.s2),
                      TextField(
                        controller: _rackController,
                        textAlign: TextAlign.center,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]')),
                          LengthLimitingTextInputFormatter(1),
                          _UpperCaseTextFormatter(),
                        ],
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'A',
                          hintStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                          ),
                          errorText:
                              _showError ? 'Masukkan huruf rak (A-Z).' : null,
                          errorStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.danger600,
                          ),
                          filled: true,
                          fillColor: AppColors.surfaceInset,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.tile),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      _FieldLabel('Kolom'),
                      const SizedBox(height: AppSpacing.s2),
                      Row(
                        children: [
                          _StepButton(
                            icon: Icons.remove_rounded,
                            onTap: () => _changeColumn(-1),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                '$_column',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                          _StepButton(
                            icon: Icons.add_rounded,
                            onTap: () => _changeColumn(1),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s5),
                      Row(
                        children: [
                          Expanded(
                            child: ActionButton(
                              label: 'Batal',
                              variant: ActionVariant.secondary,
                              onPress: widget.onCancel,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s3),
                          Expanded(
                            child: ActionButton(
                              label: 'Analisis',
                              icon: Icons.search_rounded,
                              variant: ActionVariant.primary,
                              onPress: _submit,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _StepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.tile),
          boxShadow: AppShadows.raisedSm,
        ),
        child: Icon(icon, color: AppColors.primary800, size: 22),
      ),
    );
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
