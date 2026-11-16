import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/components/action_button.dart';
import '../../core/components/app_chip.dart';
import '../../core/components/neu_surface.dart';
import '../../core/network/api_providers.dart';
import '../../core/services/scan_api_service.dart';
import '../../core/theme/tokens.dart';
import '../scan/domain/models/scan_result.dart';
import 'domain/models/history_item.dart';
import 'presentation/providers/history_provider.dart';

class _DiseasePreset {
  final String key;
  final String diagnosisName;
  final String scientificName;
  final ScanSeverity severity;
  final String defaultLocation;
  final List<ScanStep> steps;

  const _DiseasePreset({
    required this.key,
    required this.diagnosisName,
    required this.scientificName,
    required this.severity,
    required this.defaultLocation,
    required this.steps,
  });
}

const List<_DiseasePreset> _diseasePresets = [
  _DiseasePreset(
    key: 'green_mold',
    diagnosisName: 'Green Mold',
    scientificName: 'Trichoderma sp.',
    severity: ScanSeverity.treatable,
    defaultLocation: 'Cincin & Leher Baglog',
    steps: [
      ScanStep(
        title: 'Pindahkan ke Rak Karantina',
        description:
            'Segera pisahkan baglog dari rak utama kumbung untuk mencegah penularan spora via sirkulasi udara lembap.',
      ),
      ScanStep(
        title: 'Kerik Lembut Spora Hijau',
        description:
            'Gunakan sendok makan bersih yang telah disterilkan alkohol 70%. Kerik hingga batas miselium putih yang masih segar.',
      ),
      ScanStep(
        title: 'Oles Larutan Kapur Tohor (CaCO3)',
        description:
            'Oleskan pasta kapur tohor pekat atau fungisida nabati rebusan daun sirih ke bekas kerokan untuk menaikkan pH lokal.',
      ),
      ScanStep(
        title: 'Observasi Pemulihan 48 Jam',
        description:
            'Jika miselium putih tumbuh menutupi bekas luka, baglog aman. Jika spora menghitam/meluas, segera buang dari kumbung.',
      ),
    ],
  ),
  _DiseasePreset(
    key: 'black_bread_mold',
    diagnosisName: 'Black Bread Mold',
    scientificName: 'Rhizopus sp.',
    severity: ScanSeverity.mustDiscard,
    defaultLocation: 'Permukaan Baglog',
    steps: [
      ScanStep(
        title: 'Isolasi Segera dengan Plastik',
        description:
            'Tutup baglog rapat dengan kantong plastik sebelum dipindahkan agar spora hitam tidak berterbangan di dalam kumbung.',
      ),
      ScanStep(
        title: 'Musnahkan Jauh dari Kumbung',
        description:
            'Segera bakar atau kubur jauh dari area kumbung; bersihkan rak bekas baglog dengan disinfektan atau alkohol 70%.',
      ),
    ],
  ),
  _DiseasePreset(
    key: 'bacterial_brown_blotch',
    diagnosisName: 'Bacterial Brown Blotch',
    scientificName: 'Pseudomonas sp.',
    severity: ScanSeverity.treatable,
    defaultLocation: 'Permukaan Baglog',
    steps: [
      ScanStep(
        title: 'Keringkan Permukaan Bercak',
        description:
            'Bersihkan permukaan bercak cokelat secara lembut memakai lap bersih kering sekali pakai.',
      ),
      ScanStep(
        title: 'Semprot Larutan Kalsium Hipoklorit Encer',
        description:
            'Semprotkan larutan desinfektan encer dan tingkatkan sirkulasi udara kumbung.',
      ),
    ],
  ),
  _DiseasePreset(
    key: 'cobweb_mold',
    diagnosisName: 'Cobweb Mold',
    scientificName: 'Dactylium dendroides',
    severity: ScanSeverity.treatable,
    defaultLocation: 'Permukaan Baglog',
    steps: [
      ScanStep(
        title: 'Pisahkan ke Area Karantina',
        description:
            'Jauhkan baglog dari rak produksi aktif agar hifa laba-laba tidak merambat ke baglog sebelah.',
      ),
      ScanStep(
        title: 'Semprot Rebusan Sirih & Kapur Tohor',
        description:
            'Semprotkan fungisida nabati rebusan daun sirih dan taburi kapur tohor tipis di area terdampak.',
      ),
    ],
  ),
  _DiseasePreset(
    key: 'bacterial_wet_spot',
    diagnosisName: 'Bacterial Wet Spot',
    scientificName: 'Bacillus sp.',
    severity: ScanSeverity.treatable,
    defaultLocation: 'Cincin & Leher Baglog',
    steps: [
      ScanStep(
        title: 'Sanitasi Area Berlendir',
        description:
            'Lap area berlendir dan lakukan sanitasi klorin encer untuk membendung bakteri anaerob.',
      ),
      ScanStep(
        title: 'Perbaiki Sirkulasi & Kelembapan',
        description:
            'Kurangi penyemprotan kabut sementara dan pastikan ventilasi kumbung lancar.',
      ),
    ],
  ),
  _DiseasePreset(
    key: 'yellow_mold',
    diagnosisName: 'Yellow Mold',
    scientificName: 'Mycelium spp.',
    severity: ScanSeverity.treatable,
    defaultLocation: 'Permukaan Baglog',
    steps: [
      ScanStep(
        title: 'Karantina & Kerik Area Kuning',
        description:
            'Pisahkan baglog dari rak utama, lalu kerik tipis bagian substrat yang menguning.',
      ),
      ScanStep(
        title: 'Oles Kapur & Pantau 48 Jam',
        description:
            'Oleskan larutan kapur tohor dan amati perkembangan miselium putih.',
      ),
    ],
  ),
  _DiseasePreset(
    key: 'neurospora',
    diagnosisName: 'Neurospora',
    scientificName: 'Neurospora crassa',
    severity: ScanSeverity.mustDiscard,
    defaultLocation: 'Seluruh Substrat',
    steps: [
      ScanStep(
        title: 'Tutup Mulut Baglog & Keluarkan',
        description:
            'Spora oranye menyebar sangat cepat melalui udara; bungkus baglog sebelum dikeluarkan dari kumbung.',
      ),
      ScanStep(
        title: 'Bakar/Musnahkan & Sterilisasi Rak',
        description:
            'Musnahkan baglog di luar area budidaya dan semprot rak dengan alkohol 70% atau disinfektan.',
      ),
    ],
  ),
  _DiseasePreset(
    key: 'healthy',
    diagnosisName: 'Baglog Sehat Produktif',
    scientificName: 'Pleurotus ostreatus',
    severity: ScanSeverity.healthy,
    defaultLocation: 'Seluruh Baglog',
    steps: [
      ScanStep(
        title: 'Jaga Kelembapan Optimal',
        description:
            'Pertahankan kelembapan relatif 80-90% dengan penyemprotan kabut halus 2-3 kali sehari.',
      ),
      ScanStep(
        title: 'Pastikan Sirkulasi Udara Lancar',
        description:
            'Buka ventilasi kumbung secara berkala agar sirkulasi oksigen optimal untuk pembentukan pinhead.',
      ),
    ],
  ),
];

/// Halaman Form Inspeksi Manual Baglog tanpa bantuan kamera.
class ManualInspectionScreen extends ConsumerStatefulWidget {
  const ManualInspectionScreen({super.key});

  @override
  ConsumerState<ManualInspectionScreen> createState() =>
      _ManualInspectionScreenState();
}

class _ManualInspectionScreenState
    extends ConsumerState<ManualInspectionScreen> {
  static const _quickRacks = ['A-01', 'B-04', 'C-01', 'D-02'];
  static const _quickLocations = [
    'Cincin & Leher Baglog',
    'Permukaan Baglog',
    'Bagian Dasar Baglog',
    'Seluruh Substrat',
  ];

  final TextEditingController _rackController = TextEditingController();
  final TextEditingController _customDiagnosisController =
      TextEditingController();
  final TextEditingController _customScientificController =
      TextEditingController();
  final TextEditingController _infectionLocationController =
      TextEditingController(text: 'Cincin & Leher Baglog');
  final TextEditingController _noteController = TextEditingController();

  int _column = 1;
  String _selectedPresetKey = 'green_mold';
  ScanSeverity _severity = ScanSeverity.treatable;
  DateTime _inspectionDate = DateTime.now();
  bool _showRackError = false;
  bool _showDiagnosisError = false;

  @override
  void dispose() {
    _rackController.dispose();
    _customDiagnosisController.dispose();
    _customScientificController.dispose();
    _infectionLocationController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  _DiseasePreset? get _activePreset {
    for (final preset in _diseasePresets) {
      if (preset.key == _selectedPresetKey) return preset;
    }
    return null;
  }

  void _selectPreset(String key) {
    setState(() {
      _selectedPresetKey = key;
      _showDiagnosisError = false;
      final preset = _activePreset;
      if (preset != null) {
        _severity = preset.severity;
        _infectionLocationController.text = preset.defaultLocation;
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _inspectionDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _inspectionDate = picked);
    }
  }

  String _formatRack(String raw) {
    final trimmed = raw.trim();
    if (trimmed.toLowerCase().startsWith('rak')) {
      return trimmed;
    }
    return 'Rak Kumbung ${trimmed.toUpperCase()}';
  }

  String _formatWhen(DateTime date) {
    final now = DateTime.now();
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');

    if (isToday) {
      return 'Hari ini, $hour:$minute WIB';
    }
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}, $hour:$minute WIB';
  }

  Future<void> _submit() async {
    final rackRaw = _rackController.text.trim();
    final isCustom = _selectedPresetKey == 'custom';
    final diagnosisName = isCustom
        ? _customDiagnosisController.text.trim()
        : _activePreset!.diagnosisName;

    setState(() {
      _showRackError = rackRaw.isEmpty;
      _showDiagnosisError = isCustom && diagnosisName.isEmpty;
    });

    if (_showRackError || _showDiagnosisError) {
      return;
    }

    final scientificName = isCustom
        ? _customScientificController.text.trim()
        : _activePreset!.scientificName;
    final formattedRack = _formatRack(rackRaw);
    final locationText = _severity == ScanSeverity.healthy
        ? 'Seluruh Baglog'
        : (_infectionLocationController.text.trim().isNotEmpty
            ? _infectionLocationController.text.trim()
            : 'Permukaan Baglog');
    final noteText = _noteController.text.trim();

    final isHealthy = _severity == ScanSeverity.healthy;
    final mustDiscard = _severity == ScanSeverity.mustDiscard;
    final severityStr = isHealthy
        ? 'healthy'
        : mustDiscard
            ? 'must_discard'
            : 'treatable';

    final String badge = isHealthy
        ? 'Sehat'
        : mustDiscard
            ? 'Harus Dibuang'
            : 'Bisa Diobati';
    final String tone = isHealthy
        ? 'success'
        : mustDiscard
            ? 'danger'
            : 'warning';
    final HistorySectionCategory category = isHealthy
        ? HistorySectionCategory.recovered
        : HistorySectionCategory.actionRequired;
    final String status = isHealthy
        ? 'Baglog dalam kondisi sehat produktif'
        : mustDiscard
            ? 'Status: Menunggu Pemusnahan'
            : 'Status: Menunggu Desinfeksi';
    final String? actionLabel = isHealthy
        ? null
        : mustDiscard
            ? 'Konfirmasi Buang Baglog'
            : 'Konfirmasi Selesai Diobati';

    final displayName = scientificName.isNotEmpty
        ? '$diagnosisName ($scientificName)'
        : diagnosisName;

    final combinedDate = DateTime(
      _inspectionDate.year,
      _inspectionDate.month,
      _inspectionDate.day,
      DateTime.now().hour,
      DateTime.now().minute,
    );

    final steps = isCustom ? const <ScanStep>[] : _activePreset!.steps;

    HistoryItem item = HistoryItem(
      id: 'manual-${DateTime.now().millisecondsSinceEpoch}',
      name: displayName,
      badge: badge,
      tone: tone,
      when: _formatWhen(_inspectionDate),
      rack: formattedRack,
      col: _column,
      category: category,
      status: status,
      tag: 'Inspeksi Manual',
      note: noteText.isNotEmpty
          ? noteText
          : 'Dicatat melalui form inspeksi manual kumbung ($locationText).',
      actionLabel: actionLabel,
      diagnosisName: diagnosisName,
      scientificName: scientificName.isNotEmpty ? scientificName : null,
      infectionLocation: locationText,
      steps: steps,
      createdAt: combinedDate,
      isManual: true,
    );

    final api = ref.read(apiClientProvider);
    if (api.hasToken) {
      try {
        item = await ScanApiService.instance.createManualScan(
          api: api,
          rack: rackRaw,
          column: _column,
          diagnosisName: diagnosisName,
          scientificName: scientificName.isNotEmpty ? scientificName : null,
          severity: severityStr,
          infectionLocation: locationText,
          note: noteText.isNotEmpty ? noteText : item.note,
          steps: steps,
          scannedAt: combinedDate,
        );
      } catch (_) {
        // Offline / server gagal: tetap simpan ke daftar lokal.
      }
    }

    if (!mounted) return;
    ref.read(historyControllerProvider.notifier).addManualInspection(item);

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Inspeksi manual "$diagnosisName" pada $formattedRack • Kolom $_column berhasil disimpan',
          style: GoogleFonts.plusJakartaSans(fontSize: 13),
        ),
        backgroundColor: AppColors.primary800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pagePaddingX,
                  AppSpacing.s2,
                  AppSpacing.pagePaddingX,
                  AppSpacing.s8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLocationSection(),
                    const SizedBox(height: AppSpacing.sectionGap),
                    _buildDiagnosisSection(),
                    const SizedBox(height: AppSpacing.sectionGap),
                    _buildSeveritySection(),
                    if (_severity != ScanSeverity.healthy) ...[
                      const SizedBox(height: AppSpacing.sectionGap),
                      _buildInfectionLocationSection(),
                    ],
                    const SizedBox(height: AppSpacing.sectionGap),
                    _buildDateSection(),
                    const SizedBox(height: AppSpacing.sectionGap),
                    _buildNotesSection(),
                    const SizedBox(height: AppSpacing.s6),
                    ActionButton(
                      label: 'Simpan Inspeksi Manual',
                      icon: Icons.save_rounded,
                      variant: ActionVariant.primary,
                      fullWidth: true,
                      onPress: _submit,
                    ),
                  ],
                ),
              ),
            ),
          ],
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inspeksi Manual Baglog',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Catat temuan langsung tanpa bantuan kamera',
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
    );
  }

  Widget _buildLocationSection() {
    return NeuSurface(
      variant: NeuVariant.raised,
      radius: AppRadius.card,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SectionIcon(icon: Icons.my_location_rounded),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lokasi Baglog',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Pilih kode rak dan nomor kolom baglog',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            'Kode Rak',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.s2),
          NeuSurface(
            variant: NeuVariant.inset,
            radius: AppRadius.tile,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: TextField(
              controller: _rackController,
              onChanged: (_) {
                if (_showRackError) {
                  setState(() => _showRackError = false);
                }
              },
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                LengthLimitingTextInputFormatter(24),
              ],
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Contoh: B-04 atau Rak Kumbung A-01',
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textMuted,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_showRackError) ...[
            const SizedBox(height: 6),
            Text(
              'Kode rak wajib diisi.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.danger600,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.s3),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: _quickRacks.map((code) {
                final selected =
                    _rackController.text.trim().toUpperCase() == code;
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.s2),
                  child: AppChip(
                    label: 'Rak $code',
                    selected: selected,
                    onPress: () {
                      setState(() {
                        _rackController.text = code;
                        _showRackError = false;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nomor Kolom',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Posisi kolom baglog pada rak',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              _ColumnStepButton(
                icon: Icons.remove_rounded,
                onTap: () {
                  if (_column > 1) {
                    setState(() => _column--);
                  }
                },
              ),
              SizedBox(
                width: 48,
                child: Center(
                  child: Text(
                    '$_column',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              _ColumnStepButton(
                icon: Icons.add_rounded,
                onTap: () {
                  if (_column < 999) {
                    setState(() => _column++);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosisSection() {
    return NeuSurface(
      variant: NeuVariant.raised,
      radius: AppRadius.card,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SectionIcon(icon: Icons.biotech_rounded),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kondisi / Diagnosis Baglog',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Pilih gejala yang terlihat pada baglog',
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
          Wrap(
            spacing: AppSpacing.s2,
            runSpacing: AppSpacing.s2,
            children: [
              for (final preset in _diseasePresets)
                AppChip(
                  label: preset.diagnosisName,
                  selected: _selectedPresetKey == preset.key,
                  dotColor: preset.severity == ScanSeverity.healthy
                      ? AppColors.primary600
                      : preset.severity == ScanSeverity.mustDiscard
                          ? AppColors.danger600
                          : AppColors.warning500,
                  onPress: () => _selectPreset(preset.key),
                ),
              AppChip(
                label: 'Lainnya (Isi Manual)',
                selected: _selectedPresetKey == 'custom',
                dotColor: AppColors.textSecondary,
                onPress: () => _selectPreset('custom'),
              ),
            ],
          ),
          if (_selectedPresetKey == 'custom') ...[
            const SizedBox(height: AppSpacing.s4),
            Text(
              'Nama Kondisi / Penyakit',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.s2),
            NeuSurface(
              variant: NeuVariant.inset,
              radius: AppRadius.tile,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: TextField(
                controller: _customDiagnosisController,
                onChanged: (_) {
                  if (_showDiagnosisError) {
                    setState(() => _showDiagnosisError = false);
                  }
                },
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Misal: Jamur Kontaminan Merah Muda',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    color: AppColors.textMuted,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (_showDiagnosisError) ...[
              const SizedBox(height: 6),
              Text(
                'Nama diagnosis wajib diisi.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.danger600,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.s3),
            Text(
              'Nama Ilmiah (Opsional)',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.s2),
            NeuSurface(
              variant: NeuVariant.inset,
              radius: AppRadius.tile,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: TextField(
                controller: _customScientificController,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Misal: Trichoderma viride',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontStyle: FontStyle.normal,
                    color: AppColors.textMuted,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ] else if (_activePreset != null) ...[
            const SizedBox(height: AppSpacing.s3),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceInset.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppColors.primary800,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_activePreset!.diagnosisName} (${_activePreset!.scientificName}) • ${_activePreset!.steps.length} langkah SOP otomatis disertakan.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSeveritySection() {
    return NeuSurface(
      variant: NeuVariant.raised,
      radius: AppRadius.card,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SectionIcon(icon: Icons.health_and_safety_outlined),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Text(
                  'Tingkat Keparahan & Status',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          Row(
            children: [
              Expanded(
                child: _SeverityOption(
                  label: 'Bisa Diobati',
                  icon: Icons.healing_rounded,
                  selected: _severity == ScanSeverity.treatable,
                  activeColor: AppColors.warning500,
                  onTap: () =>
                      setState(() => _severity = ScanSeverity.treatable),
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              Expanded(
                child: _SeverityOption(
                  label: 'Harus Dibuang',
                  icon: Icons.delete_outline_rounded,
                  selected: _severity == ScanSeverity.mustDiscard,
                  activeColor: AppColors.danger600,
                  onTap: () =>
                      setState(() => _severity = ScanSeverity.mustDiscard),
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              Expanded(
                child: _SeverityOption(
                  label: 'Sehat',
                  icon: Icons.eco_rounded,
                  selected: _severity == ScanSeverity.healthy,
                  activeColor: AppColors.primary600,
                  onTap: () => setState(() => _severity = ScanSeverity.healthy),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfectionLocationSection() {
    return NeuSurface(
      variant: NeuVariant.raised,
      radius: AppRadius.card,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SectionIcon(icon: Icons.place_outlined),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Text(
                  'Area Infeksi pada Baglog',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          Wrap(
            spacing: AppSpacing.s2,
            runSpacing: AppSpacing.s2,
            children: _quickLocations.map((loc) {
              return AppChip(
                label: loc,
                selected: _infectionLocationController.text.trim() == loc,
                onPress: () {
                  setState(() => _infectionLocationController.text = loc);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.s3),
          NeuSurface(
            variant: NeuVariant.inset,
            radius: AppRadius.tile,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: TextField(
              controller: _infectionLocationController,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Tulis area infeksi baglog...',
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  color: AppColors.textMuted,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSection() {
    const days = [
      'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'
    ];
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final dateLabel =
        '${days[_inspectionDate.weekday - 1]}, ${_inspectionDate.day} ${months[_inspectionDate.month - 1]} ${_inspectionDate.year}';

    return GestureDetector(
      onTap: _pickDate,
      child: NeuSurface(
        variant: NeuVariant.raised,
        radius: AppRadius.card,
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Row(
          children: [
            const _SectionIcon(icon: Icons.calendar_today_rounded),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tanggal Inspeksi',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateLabel,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.edit_calendar_rounded,
              color: AppColors.primary600,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return NeuSurface(
      variant: NeuVariant.raised,
      radius: AppRadius.card,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SectionIcon(icon: Icons.notes_rounded),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Catatan Pengamatan (Opsional)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Ukuran bercak, bau, atau tindakan awal yang dilakukan',
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
          const SizedBox(height: AppSpacing.s3),
          NeuSurface(
            variant: NeuVariant.inset,
            radius: AppRadius.tile,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: TextField(
              controller: _noteController,
              maxLines: 3,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText:
                    'Contoh: Bercak hijau berdiameter ±2 cm di leher baglog, sudah dipisah ke rak karantina...',
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionIcon extends StatelessWidget {
  final IconData icon;

  const _SectionIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.primary100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        size: 20,
        color: AppColors.primary800,
      ),
    );
  }
}

class _ColumnStepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ColumnStepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppShadows.raisedSm,
        ),
        child: Icon(icon, color: AppColors.primary800, size: 20),
      ),
    );
  }
}

class _SeverityOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color activeColor;
  final VoidCallback onTap;

  const _SeverityOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? activeColor : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.tile),
          boxShadow: selected ? null : AppShadows.raisedSm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? Colors.white : activeColor,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
