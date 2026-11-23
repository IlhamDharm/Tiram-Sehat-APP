import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/tokens.dart';
import '../../core/components/neu_surface.dart';
import '../../core/components/section_card.dart';
import '../../core/components/segmented_tabs.dart';
import '../../core/components/action_button.dart';
import '../../core/format/format_helper.dart';
import '../harvest/presentation/providers/harvest_provider.dart';
import 'data/services/report_pdf_service.dart';
import 'domain/models/report_data.dart';
import 'presentation/providers/report_provider.dart';
import 'widgets/trend_chart.dart';
import '../home/data/models/home_summary.dart';
import '../home/presentation/providers/home_provider.dart';

/// Layar Evaluasi & Laporan (Anggota E)
/// Terhubung langsung dengan pencatatan buku panen (Harvest),
/// siklus kesehatan baglog (Scan & Diagnosa), dan riwayat perlakuan kumbung.
class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  int _selectedTabIndex = 0;
  static const _tabs = ['Minggu Ini', 'Bulan Ini', 'Tahun Ini'];

  /// Ringkasan statis (kartu efisiensi & kerugian) dari layer data laporan.
  ReportData get _report => ref.watch(reportProvider);

  Future<void> _handleExportPdf({
    required WeeklyReportSummary weekly,
    required MonthlyReportSummary monthly,
    required String activePeriodName,
    required double activeKg,
    required int activeIncome,
  }) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceInset,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: AppColors.primary800,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ekspor Laporan Resmi (PDF)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'BUMDes Margomulyo • Unit Jamur Tiram',
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
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.surfaceInset),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Periode', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textMuted)),
                        Text(activePeriodName, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Panen', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textMuted)),
                        Text(FormatHelper.kg(activeKg), style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary800)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Penerimaan Kas', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textMuted)),
                        Text(FormatHelper.rupiah(activeIncome), style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary800)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ActionButton(
                label: 'Simpan / Bagikan ke WhatsApp (PDF)',
                icon: Icons.share_rounded,
                variant: ActionVariant.primary,
                fullWidth: true,
                onPress: () async {
                  Navigator.pop(ctx);
                  _generateAndSharePdf(weekly: weekly, monthly: monthly);
                },
              ),
              const SizedBox(height: 10),
              ActionButton(
                label: 'Batal',
                variant: ActionVariant.secondary,
                fullWidth: true,
                onPress: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _generateAndSharePdf({
    required WeeklyReportSummary weekly,
    required MonthlyReportSummary monthly,
  }) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Menyusun dokumen PDF resmi...',
              style: GoogleFonts.plusJakartaSans(fontSize: 12.5),
            ),
          ],
        ),
        backgroundColor: AppColors.primary800,
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      final Uint8List pdfBytes;
      final String filename;
      final now = DateTime.now();
      final dateTag = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

      if (_selectedTabIndex == 0) {
        pdfBytes = await ReportPdfService.generateWeeklyReportPdf(weekly: weekly);
        filename = 'Laporan_Panen_Pekan_$dateTag.pdf';
      } else {
        final harvests = ref.read(harvestListProvider);
        pdfBytes = await ReportPdfService.generateMonthlyReportPdf(
          monthly: monthly,
          entries: harvests,
        );
        filename = 'Laporan_Panen_${monthly.monthName}_${monthly.year}.pdf';
      }

      await ReportPdfService.shareOrSavePdf(
        pdfBytes: pdfBytes,
        filename: filename,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengekspor PDF: $e'),
          backgroundColor: AppColors.danger600,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final weekly = ref.watch(weeklyHarvestReportProvider);
    final monthly = ref.watch(monthlyHarvestReportProvider);
    final yearly = ref.watch(yearlyHarvestReportProvider);
    final cycle = ref.watch(cycleProvider);
    final homeSummary = ref.watch(homeSummaryProvider).valueOrNull;

    final double activeKg;
    final int activeIncome;
    final String activePeriodName;

    if (_selectedTabIndex == 0) {
      activeKg = weekly.totalKg;
      activeIncome = weekly.totalIncome;
      activePeriodName = 'Pekan ${weekly.periodLabel}';
    } else if (_selectedTabIndex == 1) {
      activeKg = monthly.totalKg;
      activeIncome = monthly.totalIncome;
      activePeriodName = 'Bulan ${monthly.monthName}';
    } else {
      activeKg = yearly.totalKg;
      activeIncome = yearly.totalIncome;
      activePeriodName = 'Tahun ${yearly.year}';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePaddingX,
        AppSpacing.s4,
        AppSpacing.pagePaddingX,
        96,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: AppSpacing.s4),
          _buildSubtitle(),
          const SizedBox(height: AppSpacing.s5),
          SegmentedTabs(
            items: _tabs,
            value: _selectedTabIndex,
            onChange: (index) => setState(() => _selectedTabIndex = index),
          ),
          const SizedBox(height: AppSpacing.s4),
          if (_selectedTabIndex == 0) ...[
            _buildWeekNavigator(weekly),
            const SizedBox(height: AppSpacing.s4),
          ] else if (_selectedTabIndex == 1) ...[
            _buildMonthNavigator(monthly),
            const SizedBox(height: AppSpacing.s4),
          ] else ...[
            _buildYearNavigator(yearly),
            const SizedBox(height: AppSpacing.s4),
          ],
          _buildMetricsCards(weekly, monthly, yearly),
          const SizedBox(height: AppSpacing.sectionGap),
          _buildEfficiencySection(weekly, monthly, yearly, cycle, homeSummary),
          const SizedBox(height: AppSpacing.sectionGap),
          _buildAccumulationSection(weekly, monthly, yearly, homeSummary),
          const SizedBox(height: AppSpacing.sectionGap),
          ActionButton(
            label: 'Unduh Rekap Laporan Resmi (PDF)',
            icon: Icons.picture_as_pdf_rounded,
            variant: ActionVariant.secondary,
            fullWidth: true,
            onPress: () => _handleExportPdf(
              weekly: weekly,
              monthly: monthly,
              activePeriodName: activePeriodName,
              activeKg: activeKg,
              activeIncome: activeIncome,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            'Evaluasi & Laporan',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubtitle() {
    return Text(
      'Ikhtisar produksi jamur tiram dan performa finansial kumbung berbasis pencatatan mandiri dari fitur buku panen.',
      style: GoogleFonts.plusJakartaSans(
        fontSize: 13.5,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      ),
    );
  }

  /// Navigasi pekan khusus untuk tab "Minggu Ini" (Minggu s/d Sabtu)
  Widget _buildWeekNavigator(WeeklyReportSummary weekly) {
    return NeuSurface(
      variant: NeuVariant.raised,
      radius: AppRadius.card,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Material(
            color: AppColors.surfaceInset,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                final current = ref.read(selectedReportDateProvider);
                ref.read(selectedReportDateProvider.notifier).state =
                    current.subtract(const Duration(days: 7));
              },
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  Icons.chevron_left_rounded,
                  color: AppColors.primary800,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 13,
                      color: AppColors.primary600,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Pekan 7 Hari (Min - Sab)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  weekly.periodLabel,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: AppColors.surfaceInset,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                final current = ref.read(selectedReportDateProvider);
                ref.read(selectedReportDateProvider.notifier).state =
                    current.add(const Duration(days: 7));
              },
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.primary800,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Navigasi bulan khusus untuk tab "Bulan Ini"
  Widget _buildMonthNavigator(MonthlyReportSummary monthly) {
    return NeuSurface(
      variant: NeuVariant.raised,
      radius: AppRadius.card,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Material(
            color: AppColors.surfaceInset,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                final current = ref.read(selectedReportDateProvider);
                final prev = DateTime(current.year, current.month - 1, 1);
                ref.read(selectedReportDateProvider.notifier).state = prev;
              },
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  Icons.chevron_left_rounded,
                  color: AppColors.primary800,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.calendar_month_rounded,
                      size: 13,
                      color: AppColors.primary600,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Periode Bulanan',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  monthly.monthName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: AppColors.surfaceInset,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                final current = ref.read(selectedReportDateProvider);
                final next = DateTime(current.year, current.month + 1, 1);
                ref.read(selectedReportDateProvider.notifier).state = next;
              },
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.primary800,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Navigasi tahun khusus untuk tab "Tahun Ini"
  Widget _buildYearNavigator(YearlyReportSummary yearly) {
    return NeuSurface(
      variant: NeuVariant.raised,
      radius: AppRadius.card,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Material(
            color: AppColors.surfaceInset,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                final current = ref.read(selectedReportDateProvider);
                final prev = DateTime(current.year - 1, current.month, 1);
                ref.read(selectedReportDateProvider.notifier).state = prev;
              },
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  Icons.chevron_left_rounded,
                  color: AppColors.primary800,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 13,
                      color: AppColors.primary600,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Periode Tahunan',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Tahun ${yearly.year}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: AppColors.surfaceInset,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                final current = ref.read(selectedReportDateProvider);
                final next = DateTime(current.year + 1, current.month, 1);
                ref.read(selectedReportDateProvider.notifier).state = next;
              },
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.primary800,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Kotak Total Panen dan Penghasilan (Layout Vertikal Atas Bawah)
  Widget _buildMetricsCards(
    WeeklyReportSummary weekly,
    MonthlyReportSummary monthly,
    YearlyReportSummary yearly,
  ) {
    final String harvestTitle;
    final String harvestValue;
    final String harvestDeltaText;
    final String harvestDeltaBadge;
    final bool isPositive;

    final String incomeTitle;
    final String incomeValue;
    final String incomeAvgText;

    if (_selectedTabIndex == 0) {
      harvestTitle = 'Total Panen Minggu Ini';
      harvestValue = weekly.totalKg.toStringAsFixed(1).replaceAll('.', ',');
      harvestDeltaText = '${weekly.deltaKgText} dr pekan lalu';
      harvestDeltaBadge = weekly.deltaPctText;
      isPositive = weekly.deltaPct >= 0;

      incomeTitle = 'Penghasilan Minggu Ini';
      incomeValue = FormatHelper.rupiah(weekly.totalIncome);
      incomeAvgText = 'Rata-rata ${FormatHelper.rupiahPerKg(weekly.avgPrice.round())}';
    } else if (_selectedTabIndex == 1) {
      harvestTitle = 'Total Panen Bulan Ini';
      harvestValue = monthly.totalKg.toStringAsFixed(1).replaceAll('.', ',');
      harvestDeltaText = '${monthly.deltaKgText} dr bulan lalu';
      harvestDeltaBadge = monthly.deltaPctText;
      isPositive = monthly.deltaPct >= 0;

      incomeTitle = 'Penghasilan Bulan Ini';
      incomeValue = FormatHelper.rupiah(monthly.totalIncome);
      incomeAvgText = 'Rata-rata ${FormatHelper.rupiahPerKg(monthly.avgPrice.round())}';
    } else {
      harvestTitle = 'Total Panen Tahun Ini';
      harvestValue = yearly.totalKg.toStringAsFixed(1).replaceAll('.', ',');
      harvestDeltaText = 'Akumulasi tahunan';
      harvestDeltaBadge = '+12,0%';
      isPositive = true;

      incomeTitle = 'Penghasilan Tahun Ini';
      incomeValue = FormatHelper.rupiah(yearly.totalIncome);
      incomeAvgText = 'Rata-rata ${FormatHelper.rupiahPerKg(yearly.avgPrice.round())}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Kotak Atas: Total Panen
        NeuSurface(
          variant: NeuVariant.raised,
          radius: AppRadius.card,
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.hourglass_empty_rounded,
                      color: AppColors.primary800,
                      size: 20,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPositive ? AppColors.primary100 : AppColors.danger100,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                          size: 13,
                          color: isPositive ? AppColors.primary600 : AppColors.danger600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          harvestDeltaBadge,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isPositive ? AppColors.primary600 : AppColors.danger600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s3),
              Text(
                harvestTitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    harvestValue,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Kg',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s2),
              Row(
                children: [
                  Icon(
                    isPositive ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
                    size: 14,
                    color: isPositive ? AppColors.primary600 : AppColors.danger600,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      harvestDeltaText,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: isPositive ? AppColors.primary600 : AppColors.danger600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s3),
        // Kotak Bawah: Penghasilan
        NeuSurface(
          variant: NeuVariant.raised,
          radius: AppRadius.card,
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.payments_outlined,
                      color: AppColors.primary800,
                      size: 22,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary100,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      'Tunai',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s3),
              Text(
                incomeTitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                incomeValue,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary800,
                ),
              ),
              const SizedBox(height: AppSpacing.s2),
              Row(
                children: [
                  const Icon(
                    Icons.sell_outlined,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      incomeAvgText,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEfficiencySection(
    WeeklyReportSummary weekly,
    MonthlyReportSummary monthly,
    YearlyReportSummary yearly,
    BaglogCycle cycle,
    HomeSummary? homeSummary,
  ) {
    final String chartTitle;
    final String chartBadge;
    final List<double> chartValues;
    final List<String> chartLabels;

    if (_selectedTabIndex == 0) {
      chartTitle = 'Tren Panen Harian (Min - Sab)';
      chartBadge = 'Total ${FormatHelper.kg(weekly.totalKg)}';
      chartValues = weekly.dailyKg;
      chartLabels = weekly.dayLabels; // ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab']
    } else if (_selectedTabIndex == 1) {
      chartTitle = 'Tren Panen Mingguan (4 Pekan)';
      chartBadge = 'Total ${FormatHelper.kg(monthly.totalKg)}';
      chartValues = monthly.weeklyKg;
      chartLabels = monthly.weekLabels;
    } else {
      chartTitle = 'Tren Panen Kuartal (Tahun Ini)';
      chartBadge = 'Total ${FormatHelper.kg(yearly.totalKg)}';
      chartValues = yearly.quarterlyKg;
      chartLabels = yearly.quarterLabels;
    }

    // Data didapatkan dari Beranda (homeSummary)
    final totalCount = homeSummary?.activeBaglogs ?? _report.totalBaglog;
    final healthyCount = homeSummary?.healthyBaglogs ?? _report.healthy;
    final infectedCount = homeSummary?.contaminatedBaglogs ?? _report.contaminated;
    final healthRatio = (homeSummary != null && homeSummary.activeBaglogs > 0)
        ? (homeSummary.healthyBaglogs / homeSummary.activeBaglogs)
        : _report.success;
    final healthRatioPct = (healthRatio * 100).toStringAsFixed(1).replaceAll('.', ',');

    return SectionCard(
      icon: Icons.eco_rounded,
      title: 'Tingkat Keberhasilan Panen',
      trailing: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: AppColors.primary100,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.spa_rounded,
          color: AppColors.primary600,
          size: 20,
        ),
      ),
      children: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'EFISIENSI SIKLUS KUMBUNG',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.04 * 11,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          NeuSurface(
            variant: NeuVariant.inset,
            radius: AppRadius.tile,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Text(
                  '$healthRatioPct%',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary800,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'dari',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textMuted,
                      ),
                    ),
                    Text(
                      FormatHelper.baglog(totalCount),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  chartTitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                chartBadge,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          // Chart terhubung dengan data panen harian/mingguan
          TrendChart(
            values: chartValues,
            labels: chartLabels,
            unit: 'Kg',
          ),
          const SizedBox(height: AppSpacing.s3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.primary600,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '${FormatHelper.baglog(healthyCount)} Sehat & Berbuah',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.danger600,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${FormatHelper.baglog(infectedCount)} Terkontaminasi',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          // Progress Bar efisiensi
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Container(color: AppColors.danger100),
                  FractionallySizedBox(
                    widthFactor: (totalCount > 0 ? (healthyCount / totalCount) : 0.0).clamp(0.0, 1.0),
                    child: Container(color: AppColors.primary400),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccumulationSection(
    WeeklyReportSummary weekly,
    MonthlyReportSummary monthly,
    YearlyReportSummary yearly,
    HomeSummary? homeSummary,
  ) {
    final String sectionTitle;
    final String periodLabel;
    final int income;
    final double weight;

    if (_selectedTabIndex == 0) {
      sectionTitle = 'Akumulasi Pekan Ini';
      periodLabel = weekly.periodLabel;
      income = weekly.totalIncome;
      weight = weekly.totalKg;
    } else if (_selectedTabIndex == 1) {
      sectionTitle = 'Akumulasi Bulan Ini';
      periodLabel = monthly.monthName;
      income = monthly.totalIncome;
      weight = monthly.totalKg;
    } else {
      sectionTitle = 'Akumulasi Tahun Ini';
      periodLabel = '${yearly.year}';
      income = yearly.totalIncome;
      weight = yearly.totalKg;
    }

    // Estimasi Kerugian dari total baglog yang dibuang / harus dibuang (Beranda)
    final discardedBaglogs = homeSummary?.discardedBaglogs ?? 75;
    const int baglogUnitCost = 3000;
    final estimatedLoss = discardedBaglogs * baglogUnitCost;

    return SectionCard(
      icon: Icons.account_balance_wallet_outlined,
      title: sectionTitle,
      trailing: Text(
        periodLabel,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
      children: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total Pemasukan Panen Inset
          NeuSurface(
            variant: NeuVariant.inset,
            radius: AppRadius.tile,
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Pemasukan Panen',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        FormatHelper.rupiah(income),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Total bersih ${FormatHelper.kg(weight)} jamur segar',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: AppShadows.raisedSm,
                  ),
                  child: const Icon(
                    Icons.savings_rounded,
                    color: AppColors.primary600,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          // Estimasi Kerugian Baglog Inset
          NeuSurface(
            variant: NeuVariant.inset,
            radius: AppRadius.tile,
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Estimasi Kerugian Baglog',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.danger600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 14,
                            color: AppColors.warning500,
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        FormatHelper.rupiah(estimatedLoss),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: AppColors.danger600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.danger100,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.delete_outline_rounded,
                              size: 13,
                              color: AppColors.danger600,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '$discardedBaglogs baglog afkir & harus dibuang',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.danger600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: AppShadows.raisedSm,
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    color: AppColors.warning500,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}
