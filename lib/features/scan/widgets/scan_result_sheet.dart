import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/components/neu_surface.dart';
import '../../../core/components/section_card.dart';
import '../../../core/components/status_badge.dart';
import '../../../core/components/step_list.dart';
import '../../../core/components/action_button.dart';
import '../../../core/format/format_helper.dart';
import '../domain/models/scan_result.dart';

class ScanResultSheetContent extends StatefulWidget {
  final ScanResult result;
  final Uint8List? capturedBytes;
  final ScrollController? scrollController;
  final void Function(String rack, int column) onSaveToHistory;
  final VoidCallback onScanAgain;

  const ScanResultSheetContent({
    super.key,
    required this.result,
    this.capturedBytes,
    this.scrollController,
    required this.onSaveToHistory,
    required this.onScanAgain,
  });

  @override
  State<ScanResultSheetContent> createState() =>
      _ScanResultSheetContentState();
}

class _ScanResultSheetContentState extends State<ScanResultSheetContent> {
  final TextEditingController _rackController = TextEditingController();
  int _column = 1;
  bool _showError = false;
  bool _isSaved = false;

  @override
  void dispose() {
    _rackController.dispose();
    super.dispose();
  }

  bool get _isRackValid => RegExp(r'^[A-Z]$').hasMatch(_rackController.text);

  void _handleSave() {
    if (_isSaved) return;
    if (!_isRackValid) {
      setState(() => _showError = true);
      return;
    }
    setState(() => _isSaved = true);
    widget.onSaveToHistory(_rackController.text, _column);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: widget.scrollController,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePaddingX,
        0,
        AppSpacing.pagePaddingX,
        AppSpacing.s6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DiagnosisHeader(result: widget.result),
          const SizedBox(height: AppSpacing.s4),
          _ConfidenceCard(result: widget.result),
          const SizedBox(height: AppSpacing.sectionGap),
          _FieldDecisionSection(
            result: widget.result,
            capturedBytes: widget.capturedBytes,
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          _MitigationCard(result: widget.result),
          const SizedBox(height: AppSpacing.sectionGap),
          _LocationForm(
            rackController: _rackController,
            column: _column,
            showError: _showError,
            onRackChanged: () {
              if (_showError) setState(() => _showError = false);
            },
            onColumnChanged: (value) => setState(() => _column = value),
          ),
          const SizedBox(height: AppSpacing.s4),
          ActionButton(
            label: _isSaved ? 'Sudah Disimpan ke Riwayat' : 'Simpan ke Riwayat Scan',
            icon: _isSaved ? Icons.check_circle_rounded : Icons.bookmark_add_rounded,
            variant: _isSaved ? ActionVariant.secondary : ActionVariant.primary,
            fullWidth: true,
            onPress: _isSaved ? null : _handleSave,
          ),
          const SizedBox(height: AppSpacing.s3),
          ActionButton(
            label: 'Scan Baglog Lainnya',
            icon: Icons.photo_camera_rounded,
            variant: ActionVariant.secondary,
            fullWidth: true,
            onPress: widget.onScanAgain,
          ),
        ],
      ),
    );
  }
}

class _LocationForm extends StatelessWidget {
  final TextEditingController rackController;
  final int column;
  final bool showError;
  final VoidCallback onRackChanged;
  final ValueChanged<int> onColumnChanged;

  const _LocationForm({
    required this.rackController,
    required this.column,
    required this.showError,
    required this.onRackChanged,
    required this.onColumnChanged,
  });

  void _changeColumn(int delta) {
    final next = (column + delta).clamp(1, 999);
    if (next == column) return;
    onColumnChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return NeuSurface(
      variant: NeuVariant.raised,
      radius: AppRadius.tile,
      padding: const EdgeInsets.all(AppSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.my_location_rounded,
                  size: 20,
                  color: AppColors.primary800,
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
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tentukan rak dan kolom sebelum menyimpan.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const _RequiredBadge(),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 84,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Rak'),
                    const SizedBox(height: AppSpacing.s2),
                    TextField(
                      controller: rackController,
                      onChanged: (_) => onRackChanged(),
                      textAlign: TextAlign.center,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]')),
                        LengthLimitingTextInputFormatter(1),
                        _UpperCaseTextFormatter(),
                      ],
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'A',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                        filled: true,
                        fillColor: showError
                            ? AppColors.danger100
                            : AppColors.surfaceInset,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.tile),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Kolom'),
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
                              '$column',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 22,
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
                  ],
                ),
              ),
            ],
          ),
          if (showError) ...[
            const SizedBox(height: AppSpacing.s2),
            Text(
              'Rak wajib diisi (huruf A-Z).',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.danger600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RequiredBadge extends StatelessWidget {
  const _RequiredBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.warning100,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        'Wajib',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
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
        width: AppSpacing.tapTargetMin,
        height: AppSpacing.tapTargetMin,
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

class _DiagnosisHeader extends StatelessWidget {
  final ScanResult result;

  const _DiagnosisHeader({required this.result});

  String get _badgeLabel => switch (result.severity) {
        ScanSeverity.healthy => 'Sehat Produktif',
        ScanSeverity.mustDiscard => 'Harus Dibuang',
        ScanSeverity.treatable => 'Bisa Diobati',
      };

  StatusTone get _badgeTone => switch (result.severity) {
        ScanSeverity.healthy => StatusTone.success,
        ScanSeverity.mustDiscard => StatusTone.danger,
        ScanSeverity.treatable => StatusTone.warning,
      };

  @override
  Widget build(BuildContext context) {
    final description = result.description?.trim();
    final mlLabel = result.mlLabel?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'HASIL DIAGNOSA VISUAL',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.48,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s2),
            StatusBadge(
              label: _badgeLabel,
              tone: _badgeTone,
              solid: true,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s2),
        Text(
          result.diagnosisName,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            height: 1.25,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        if (result.scientificName.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            '(${result.scientificName})',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        if (description != null && description.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s2),
          Text(
            description,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.s3),
        Wrap(
          spacing: AppSpacing.s2,
          runSpacing: AppSpacing.s2,
          children: [
            _MetadataChip(
              icon: Icons.schedule_rounded,
              label: 'Waktu Scan',
              value: result.scannedAt,
            ),
            if (mlLabel != null && mlLabel.isNotEmpty)
              _MetadataChip(
                icon: Icons.label_outline_rounded,
                label: 'Kelas ML',
                value: mlLabel,
              ),
          ],
        ),
      ],
    );
  }
}

class _MetadataChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetadataChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceInset,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary800),
          const SizedBox(width: 6),
          Flexible(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                children: [
                  TextSpan(text: '$label: '),
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfidenceCard extends StatelessWidget {
  final ScanResult result;

  const _ConfidenceCard({required this.result});

  String get _confidenceTierLabel {
    if (result.confidence >= 0.85) return 'Sangat Yakin';
    if (result.confidence >= 0.65) return 'Cukup Yakin';
    return 'Perlu Verifikasi';
  }

  Color get _confidenceTierColor {
    if (result.confidence >= 0.85) return AppColors.success600;
    if (result.confidence >= 0.65) return AppColors.warning500;
    return AppColors.danger600;
  }

  static ({String label, Color color}) _classPresentation(String key) {
    return switch (key.trim().toLowerCase()) {
      'healthy' => (
        label: 'Healthy (Baglog Sehat)',
        color: AppColors.success600,
      ),
      'greenmold' || 'green_mold' => (
        label: 'Green Mold',
        color: AppColors.warning500,
      ),
      'blackmold' || 'black_mold' || 'black_bread_mold' => (
        label: 'Black Mold',
        color: AppColors.danger600,
      ),
      _ => (label: key, color: AppColors.primary600),
    };
  }

  @override
  Widget build(BuildContext context) {
    final percent = FormatHelper.persen(result.confidence * 100);
    final sortedProbs = result.probabilities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final modelVersion = result.modelVersion?.trim();

    return NeuSurface(
      variant: NeuVariant.raised,
      radius: AppRadius.tile,
      padding: const EdgeInsets.all(AppSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary100,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.psychology_alt_rounded,
                  size: 24,
                  color: AppColors.primary800,
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Text(
                  'Tingkat Keyakinan $percent',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              Text(
                _confidenceTierLabel,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _confidenceTierColor,
                ),
              ),
            ],
          ),
          if (sortedProbs.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.s3),
              child: Divider(height: 1, color: AppColors.surfaceInset),
            ),
            Text(
              'Distribusi Probabilitas Kelas',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.s2),
            ...sortedProbs.asMap().entries.map((indexed) {
              final idx = indexed.key;
              final entry = indexed.value;
              final meta = _classPresentation(entry.key);
              final isPredicted =
                  entry.key.toLowerCase() == result.mlLabel?.toLowerCase() ||
                      (result.mlLabel == null && idx == 0);
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s2),
                child: _ProbabilityBreakdownRow(
                  label: meta.label,
                  probability: entry.value,
                  color: meta.color,
                  isHighlighted: isPredicted,
                ),
              );
            }),
          ],
          if (modelVersion != null && modelVersion.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s1),
            Text(
              'Model: $modelVersion',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProbabilityBreakdownRow extends StatelessWidget {
  final String label;
  final double probability;
  final Color color;
  final bool isHighlighted;

  const _ProbabilityBreakdownRow({
    required this.label,
    required this.probability,
    required this.color,
    required this.isHighlighted,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = probability.clamp(0.0, 1.0);
    final pctText = FormatHelper.persen(clamped * 100);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w500,
                  color: isHighlighted
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
            Text(
              pctText,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w600,
                color: isHighlighted ? color : AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: clamped,
            minHeight: 7,
            backgroundColor: AppColors.surfaceInset,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _FieldGuidance {
  final String badgeLabel;
  final String decision;
  final String risk;
  final String thresholdLabel;
  final String threshold;
  final String toolsLabel;
  final String tools;
  final String recheck;
  final Color accentColor;
  final Color tintBg;
  final IconData decisionIcon;

  const _FieldGuidance({
    required this.badgeLabel,
    required this.decision,
    required this.risk,
    required this.thresholdLabel,
    required this.threshold,
    required this.toolsLabel,
    required this.tools,
    required this.recheck,
    required this.accentColor,
    required this.tintBg,
    required this.decisionIcon,
  });

  factory _FieldGuidance.fromResult(ScanResult result) {
    final normalizedLabel = (result.mlLabel ?? '').trim().toLowerCase();
    if (result.severity == ScanSeverity.healthy || normalizedLabel == 'healthy') {
      return const _FieldGuidance(
        badgeLabel: 'Healthy',
        decision: 'Aman — pertahankan di rak produksi',
        risk: 'Rendah (tidak ada kontaminasi terdeteksi)',
        thresholdLabel: 'Kondisi Ideal',
        threshold:
            'Miselium putih padat merata tanpa bercak hijau/hitam atau lendir bau asam.',
        toolsLabel: 'Kebutuhan Rawat',
        tools: 'Semprotan kabut air bersih & sirkulasi udara kumbung teratur',
        recheck: 'Pantau rutin saat jadwal inspeksi harian berikutnya',
        accentColor: AppColors.success600,
        tintBg: AppColors.success100,
        decisionIcon: Icons.verified_rounded,
      );
    }
    if (result.severity == ScanSeverity.mustDiscard ||
        normalizedLabel == 'blackmold' ||
        normalizedLabel == 'black_bread_mold') {
      return const _FieldGuidance(
        badgeLabel: 'Black Mold',
        decision: 'Bungkus rapat & musnahkan hari ini',
        risk: 'Sangat Tinggi (spora hitam mudah terbang menulari seisi kumbung)',
        thresholdLabel: 'Batas Penyelamatan',
        threshold:
            'Tidak disarankan diobati. Jangan buka baglog di dalam kumbung agar spora tidak menyebar.',
        toolsLabel: 'Alat & Bahan',
        tools: 'Kantong plastik rapat, sarung tangan, alkohol 70% / disinfektan',
        recheck: 'Periksa 4–6 baglog di kiri, kanan, dan rak bawahnya hari ini',
        accentColor: AppColors.danger600,
        tintBg: AppColors.danger100,
        decisionIcon: Icons.warning_amber_rounded,
      );
    }
    return const _FieldGuidance(
      badgeLabel: 'Green Mold',
      decision: 'Karantina & obati segera',
      risk: 'Sedang–Tinggi (menular lewat percikan air & aliran udara lembap)',
      thresholdLabel: 'Batas Obati vs Buang',
      threshold:
          'Masih bisa diobati bila bercak < 30% permukaan luar. Jika > 50% atau menembus dalam, langsung afkir.',
      toolsLabel: 'Alat & Bahan',
      tools:
          'Sendok bersih, alkohol 70%, pasta kapur tohor (CaCO₃) / sirih, rak karantina',
      recheck: 'Cek ulang 48 jam setelah pengerikan & pengolesan kapur',
      accentColor: AppColors.warning500,
      tintBg: AppColors.warning100,
      decisionIcon: Icons.medical_information_rounded,
    );
  }
}

class _FieldDecisionSection extends StatelessWidget {
  final ScanResult result;
  final Uint8List? capturedBytes;

  const _FieldDecisionSection({
    required this.result,
    this.capturedBytes,
  });

  bool get _hasCapturedPhoto =>
      (capturedBytes != null && capturedBytes!.isNotEmpty) ||
      (result.imageUrl != null && result.imageUrl!.isNotEmpty);

  void _openZoomDialog(BuildContext context) {
    if (!_hasCapturedPhoto) return;
    showDialog<void>(
      context: context,
      builder: (_) => _ImageZoomDialog(
        capturedBytes: capturedBytes,
        imageUrl: result.imageUrl,
        title: result.diagnosisName,
      ),
    );
  }

  Widget _buildPhoto() {
    if (capturedBytes != null && capturedBytes!.isNotEmpty) {
      return Image.memory(capturedBytes!, fit: BoxFit.cover);
    }
    return Image.network(
      result.imageUrl!,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: AppColors.surfaceInset,
        alignment: Alignment.center,
        child: const Icon(
          Icons.broken_image_outlined,
          color: AppColors.textMuted,
          size: 32,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final guidance = _FieldGuidance.fromResult(result);
    final confPct = FormatHelper.persen(result.confidence * 100);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Foto & Keputusan Lapangan',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  height: 24 / 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (_hasCapturedPhoto)
              Text(
                'Ketuk foto untuk zoom',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary800,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s3),
        NeuSurface(
          variant: NeuVariant.raised,
          radius: AppRadius.tile,
          padding: const EdgeInsets.all(AppSpacing.s3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_hasCapturedPhoto) ...[
                GestureDetector(
                  onTap: () => _openZoomDialog(context),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      height: 176,
                      width: double.infinity,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _buildPhoto(),
                          Positioned(
                            top: AppSpacing.s2,
                            right: AppSpacing.s2,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.52),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.zoom_in_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Positioned(
                            left: AppSpacing.s2,
                            bottom: AppSpacing.s2,
                            right: AppSpacing.s2,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: guidance.accentColor,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.pill),
                                ),
                                child: Text(
                                  '${guidance.badgeLabel} · $confPct',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textOnPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s3),
              ],
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s3,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: guidance.tintBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      guidance.decisionIcon,
                      size: 20,
                      color: guidance.accentColor,
                    ),
                    const SizedBox(width: AppSpacing.s2),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                          children: [
                            const TextSpan(
                              text: 'Keputusan: ',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            TextSpan(
                              text: guidance.decision,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: guidance.accentColor == AppColors.warning500
                                    ? const Color(0xFF92400E)
                                    : guidance.accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s3),
              _DecisionInfoRow(
                icon: Icons.coronavirus_outlined,
                label: 'Risiko Penularan',
                value: guidance.risk,
              ),
              const SizedBox(height: AppSpacing.s2),
              _DecisionInfoRow(
                icon: Icons.rule_rounded,
                label: guidance.thresholdLabel,
                value: guidance.threshold,
              ),
              const SizedBox(height: AppSpacing.s2),
              _DecisionInfoRow(
                icon: Icons.handyman_outlined,
                label: guidance.toolsLabel,
                value: guidance.tools,
              ),
              const SizedBox(height: AppSpacing.s2),
              _DecisionInfoRow(
                icon: Icons.event_repeat_rounded,
                label: 'Jadwal Cek Ulang',
                value: guidance.recheck,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DecisionInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DecisionInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: AppColors.primary800),
        ),
        const SizedBox(width: AppSpacing.s2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ImageZoomDialog extends StatelessWidget {
  final Uint8List? capturedBytes;
  final String? imageUrl;
  final String title;

  const _ImageZoomDialog({
    required this.capturedBytes,
    required this.imageUrl,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: AspectRatio(
                aspectRatio: 1,
                child: capturedBytes != null && capturedBytes!.isNotEmpty
                    ? Image.memory(capturedBytes!, fit: BoxFit.contain)
                    : Image.network(imageUrl!, fit: BoxFit.contain),
              ),
            ),
          ),
          Positioned(
            top: 8,
            left: 12,
            right: 52,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              tooltip: 'Tutup',
            ),
          ),
        ],
      ),
    );
  }
}

class _MitigationCard extends StatelessWidget {
  final ScanResult result;

  const _MitigationCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final title = result.severity == ScanSeverity.healthy
        ? 'Panduan Perawatan Baglog'
        : 'Panduan Tindakan Cepat Petani';

    return SectionCard(
      icon: Icons.medical_services_rounded,
      title: title,
      trailing: Text(
        '${result.steps.length} Langkah',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
        ),
      ),
      children: StepList(
        steps: result.steps
            .map((s) => StepItem(title: s.title, description: s.description))
            .toList(),
      ),
    );
  }
}
