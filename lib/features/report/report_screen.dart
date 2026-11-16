import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/tokens.dart';
import '../../core/components/neu_surface.dart';
import '../../core/components/section_card.dart';
import '../../core/components/segmented_tabs.dart';
import '../../core/components/action_button.dart';
import '../../core/format/format_helper.dart';
import '../../mock/mock_data.dart';
import '../harvest/harvest_provider.dart';
import 'report_provider.dart';
import 'widgets/trend_chart.dart';

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

  void _downloadReport(String periodName, double kg, int income) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Rekap laporan $periodName (${FormatHelper.kg(kg)} / ${FormatHelper.rupiahSingkat(income)}) berhasil disiapkan!',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
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
    final weekly = ref.watch(weeklyHarvestReportProvider);
    final monthly = ref.watch(monthlyHarvestReportProvider);
    final yearly = ref.watch(yearlyHarvestReportProvider);
    final latestHarvest = ref.watch(latestHarvestProvider);
    const cycle = MockData.cycle;

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
          ],
          _buildMetricsRow(weekly, monthly, yearly),
          const SizedBox(height: AppSpacing.sectionGap),
          _buildEfficiencySection(weekly, monthly, yearly, cycle),
          const SizedBox(height: AppSpacing.sectionGap),
          _buildAccumulationSection(weekly, monthly, yearly),
          const SizedBox(height: AppSpacing.sectionGap),
          _buildBatchCard(latestHarvest),
          const SizedBox(height: AppSpacing.sectionGap),
          ActionButton(
            label: 'Unduh Rekap Laporan (CSV / PDF)',
            icon: Icons.download_rounded,
            variant: ActionVariant.secondary,
            fullWidth: true,
            onPress: () => _downloadReport(activePeriodName, activeKg, activeIncome),
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

  Widget _buildMetricsRow(
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
      incomeValue = FormatHelper.rupiahSingkat(weekly.totalIncome);
      incomeAvgText = 'Rata-rata ${FormatHelper.rupiahSingkat(weekly.avgPrice.round())} / Kg';
    } else if (_selectedTabIndex == 1) {
      harvestTitle = 'Total Panen Bulan Ini';
      harvestValue = monthly.totalKg.toStringAsFixed(1).replaceAll('.', ',');
      harvestDeltaText = '${monthly.deltaKgText} dr bulan lalu';
      harvestDeltaBadge = monthly.deltaPctText;
      isPositive = monthly.deltaPct >= 0;

      incomeTitle = 'Penghasilan Bulan Ini';
      incomeValue = FormatHelper.rupiahSingkat(monthly.totalIncome);
      incomeAvgText = 'Rata-rata ${FormatHelper.rupiahSingkat(monthly.avgPrice.round())} / Kg';
    } else {
      harvestTitle = 'Total Panen Tahun Ini';
      harvestValue = yearly.totalKg.toStringAsFixed(1).replaceAll('.', ',');
      harvestDeltaText = 'Akumulasi tahunan';
      harvestDeltaBadge = '+12,0%';
      isPositive = true;

      incomeTitle = 'Penghasilan Tahun Ini';
      incomeValue = FormatHelper.rupiahSingkat(yearly.totalIncome);
      incomeAvgText = 'Rata-rata ${FormatHelper.rupiahSingkat(yearly.avgPrice.round())} / Kg';
    }

    return Row(
      children: [
        // Kartu Kiri: Total Panen
        Expanded(
          child: NeuSurface(
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
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.hourglass_empty_rounded,
                        color: AppColors.primary800,
                        size: 18,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPositive ? AppColors.primary100 : AppColors.danger100,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                            size: 11,
                            color: isPositive ? AppColors.primary600 : AppColors.danger600,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            harvestDeltaBadge,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
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
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      harvestValue,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Kg',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
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
                      size: 13,
                      color: isPositive ? AppColors.primary600 : AppColors.danger600,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        harvestDeltaText,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: isPositive ? AppColors.primary600 : AppColors.danger600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s3),
        // Kartu Kanan: Penghasilan
        Expanded(
          child: NeuSurface(
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
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.payments_outlined,
                        color: AppColors.primary800,
                        size: 20,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  incomeValue,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.s2),
                Row(
                  children: [
                    const Icon(
                      Icons.sell_outlined,
                      size: 13,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        incomeAvgText,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
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

    final healthyCount = MockData.report.healthy;
    final infectedCount = MockData.report.contaminated;
    final totalCount = MockData.report.totalBaglog;
    final healthRatioPct = (MockData.report.success * 100).toStringAsFixed(1).replaceAll('.', ',');

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
                    '$infectedCount Terkontaminasi',
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
                    widthFactor: (healthyCount / totalCount).clamp(0.0, 1.0),
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
                        FormatHelper.rupiahSingkat(income),
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
                        FormatHelper.rupiah(MockData.report.monthLoss),
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
                              Icons.shield_outlined,
                              size: 13,
                              color: AppColors.danger600,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Ditekan ${MockData.report.lossReducedPct}% via deteksi dini',
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
          const SizedBox(height: AppSpacing.s4),
          // Tip Lampu
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.primary100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lightbulb_outline_rounded,
                  color: AppColors.primary800,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      height: 1.45,
                      color: AppColors.textSecondary,
                    ),
                    children: const [
                      TextSpan(
                        text: 'Tindakan isolasi cepat pada ',
                      ),
                      TextSpan(
                        text: 'Rak Kumbung B',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      TextSpan(
                        text:
                            ' berhasil menyelamatkan sekitar 120 baglog terdekat dari spora jamur hijau (*Trichoderma*).',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBatchCard(HarvestEntry latest) {
    final batch = MockData.report.batch;

    return NeuSurface(
      variant: NeuVariant.raised,
      radius: AppRadius.card,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.surfaceInset,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF8D735C),
                          Color(0xFF5A4433),
                        ],
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.grass_rounded,
                    color: Color(0xFFE8DACD),
                    size: 32,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  batch.code,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Varietas ${batch.variety} • Hari ke-${batch.day}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary100,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        batch.grade,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Petik ${latest.date}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
