import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/tokens.dart';
import '../../core/components/neu_surface.dart';
import '../../core/components/section_card.dart';
import 'data/models/home_summary.dart';
import 'presentation/providers/home_provider.dart';

// ─── HomeScreen ──────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerStatefulWidget {
  /// Dipanggil saat user menekan "Mulai Scan Kumbung" untuk berpindah ke tab scan.
  final VoidCallback? onGoToScan;

  const HomeScreen({super.key, this.onGoToScan});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startAnimation() {
    if (_controller.status == AnimationStatus.dismissed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(homeSummaryProvider);

    return summaryAsync.when(
      loading: () => const _HomeShimmerLoading(),
      error: (error, stack) => _HomeErrorState(
        error: error.toString(),
        onRetry: () => ref.invalidate(homeSummaryProvider),
      ),
      data: (summary) {
        _startAnimation();
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pagePaddingX,
            AppSpacing.s2,
            AppSpacing.pagePaddingX,
            110,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _HomeGreetingHeader(),
              const SizedBox(height: AppSpacing.sectionGap),
              _IncomeCard(animation: _animation, summary: summary),
              const SizedBox(height: AppSpacing.sectionGap),
              _BaglogCard(animation: _animation, summary: summary),
              const SizedBox(height: AppSpacing.sectionGap),
              _SelfCheckCard(
                animation: _animation,
                summary: summary,
                onGoToScan: widget.onGoToScan,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Shimmer Loading State ───────────────────────────────────────────────────

class _HomeShimmerLoading extends StatefulWidget {
  const _HomeShimmerLoading();

  @override
  State<_HomeShimmerLoading> createState() => _HomeShimmerLoadingState();
}

class _HomeShimmerLoadingState extends State<_HomeShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, _) {
        final shimmerOpacity = (0.3 + 0.4 * (0.5 + 0.5 * math.cos(_shimmerController.value * 2 * math.pi))).clamp(0.0, 1.0);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pagePaddingX,
            AppSpacing.s2,
            AppSpacing.pagePaddingX,
            110,
          ),
          child: Opacity(
            opacity: shimmerOpacity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header skeleton
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 14,
                            width: 180,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5EAE4),
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 26,
                            width: 140,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5EAE4),
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5EAE4),
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sectionGap),
                // Income card skeleton
                _buildSkeletonCard(height: 200),
                const SizedBox(height: AppSpacing.sectionGap),
                // Baglog card skeleton
                _buildSkeletonCard(height: 300),
                const SizedBox(height: AppSpacing.sectionGap),
                // Self check card skeleton
                _buildSkeletonCard(height: 150),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkeletonCard({required double height}) {
    return NeuSurface(
      variant: NeuVariant.raised,
      radius: AppRadius.card,
      padding: const EdgeInsets.all(AppSpacing.s4),
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFE5EAE4).withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppRadius.tile),
        ),
      ),
    );
  }
}

// ─── Error State ─────────────────────────────────────────────────────────────

class _HomeErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _HomeErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.pagePaddingX),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            NeuSurface(
              variant: NeuVariant.raised,
              radius: 24,
              child: Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.cloud_off_rounded,
                  color: AppColors.danger600,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Gagal memuat data',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            NeuSurface(
              variant: NeuVariant.raised,
              radius: AppRadius.tile,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.tile),
                  onTap: onRetry,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.refresh_rounded,
                          color: AppColors.primary800,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Coba Lagi',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeGreetingHeader extends StatelessWidget {
  const _HomeGreetingHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selamat Pagi, Petani BUMDes',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Kumbung Blok A',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        NeuSurface(
          variant: NeuVariant.raised,
          radius: 18,
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            child: const Icon(
              Icons.yard_rounded,
              color: AppColors.primary800,
              size: 26,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Count-Up Helper ─────────────────────────────────────────────────────────

/// Teks yang beranimasi count-up dari 0 ke [target].
class _CountUpText extends AnimatedWidget {
  final double target;
  final TextStyle style;
  final String Function(double value) formatter;

  const _CountUpText({
    required Animation<double> animation,
    required this.target,
    required this.style,
    required this.formatter,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    final anim = listenable as Animation<double>;
    return Text(formatter(anim.value * target), style: style);
  }
}

// ─── Income Card ─────────────────────────────────────────────────────────────

class _IncomeCard extends StatelessWidget {
  final Animation<double> animation;
  final HomeSummary summary;
  const _IncomeCard({required this.animation, required this.summary});

  // Format ribuan sederhana tanpa library external
  static String _rupiah(double v) {
    final s = v.toInt().toString();
    final buf = StringBuffer('Rp ');
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  String _formatHarvestDate() {
    if (summary.recentHarvests.isNotEmpty) {
      final dt = summary.recentHarvests.first.harvestedAt.toLocal();
      const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      final day = days[dt.weekday - 1];
      final month = months[dt.month - 1];
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$day, ${dt.day} $month ${dt.year} - $hour:$minute WIB';
    }
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: Icons.payments_outlined,
      title: 'Estimasi Pendapatan Panen',
      children: Column(
        children: [
          NeuSurface(
            variant: NeuVariant.inset,
            radius: AppRadius.tile,
            padding: const EdgeInsets.all(AppSpacing.s4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'ESTIMASI PANEN HARI INI',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.04 * 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                          if (summary.deltaPct != 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: summary.deltaPct > 0
                                    ? const Color(0xFFDDEBDC)
                                    : const Color(0xFFF8DADA),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${summary.deltaPct > 0 ? '↑' : '↓'}${summary.deltaPct.abs().toStringAsFixed(0)}%',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: summary.deltaPct > 0
                                      ? AppColors.primary800
                                      : AppColors.danger600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: _CountUpText(
                          animation: animation,
                          target: summary.todayIncome.toDouble(),
                          formatter: _rupiah,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                NeuSurface(
                  variant: NeuVariant.raised,
                  radius: 16,
                  child: Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: AppColors.primary800,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          r'$',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          Row(
            children: [
              Expanded(
                child: NeuSurface(
                  variant: NeuVariant.raised,
                  radius: AppRadius.tile,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Berat Panen Terakhir',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            _CountUpText(
                              animation: animation,
                              target: summary.todayKg,
                              formatter: (v) => v.toStringAsFixed(1),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary800,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Kg',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: NeuSurface(
                  variant: NeuVariant.raised,
                  radius: AppRadius.tile,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Harga Jual Rata-rata',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            _CountUpText(
                              animation: animation,
                              target: summary.pricePerKg.toDouble(),
                              formatter: _rupiah,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary800,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '/Kg',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          NeuSurface(
            variant: NeuVariant.inset,
            radius: AppRadius.tile,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s4,
              vertical: AppSpacing.s3,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 20,
                  color: AppColors.primary800,
                ),
                const SizedBox(width: AppSpacing.s3),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hasil Panen Terakhir:',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatHarvestDate(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary800,
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

// ─── Baglog Card ─────────────────────────────────────────────────────────────

class _BaglogCard extends StatelessWidget {
  final Animation<double> animation;
  final HomeSummary summary;
  const _BaglogCard({required this.animation, required this.summary});

  static String _fmtInt(double v) {
    final s = v.toInt().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final total = summary.activeBaglogs;
    final healthy = summary.healthyBaglogs;
    final treatable = summary.treatableBaglogs;
    final discarded = summary.discardedBaglogs;
    final healthRatio = summary.healthRatio;

    return SectionCard(
      icon: Icons.inventory_2_outlined,
      title: 'Ringkasan Siklus Baglog',
      children: Column(
        children: [
          NeuSurface(
            variant: NeuVariant.inset,
            radius: AppRadius.tile,
            padding: const EdgeInsets.all(AppSpacing.s4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTAL BAGLOG AKTIF',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.04 * 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            _CountUpText(
                              animation: animation,
                              target: total.toDouble(),
                              formatter: _fmtInt,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary800,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'baglog',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                NeuSurface(
                  variant: NeuVariant.raised,
                  radius: 16,
                  child: Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.eco_rounded,
                      color: AppColors.primary800,
                      size: 26,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          Row(
            children: [
              Expanded(
                child: _CycleMetricTile(
                  animation: animation,
                  label: 'Sehat Produktif',
                  target: healthy.toDouble(),
                  unit: 'baglog',
                  valueColor: AppColors.primary800,
                  badgeIcon: Icons.check_circle_rounded,
                  badgeColor: const Color(0xFFDDEBDC),
                  iconColor: AppColors.primary800,
                  progress: total > 0 ? healthy / total : 0,
                  progressBarColor: AppColors.primary800,
                  formatter: _fmtInt,
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: _CycleMetricTile(
                  animation: animation,
                  label: 'Bisa Diobati',
                  target: treatable.toDouble(),
                  unit: 'baglog',
                  valueColor: AppColors.warning500,
                  badgeIcon: Icons.healing_rounded,
                  badgeColor: const Color(0xFFFCEBCB),
                  iconColor: AppColors.warning500,
                  progress: total > 0 ? treatable / total : 0,
                  progressBarColor: AppColors.warning500,
                  formatter: _fmtInt,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          Row(
            children: [
              Expanded(
                child: _CycleMetricTile(
                  animation: animation,
                  label: 'Afkir / Dibuang',
                  target: discarded.toDouble(),
                  unit: 'baglog',
                  valueColor: AppColors.danger600,
                  badgeIcon: Icons.delete_outline_rounded,
                  badgeColor: const Color(0xFFF8DADA),
                  iconColor: AppColors.danger600,
                  progress: total > 0 ? discarded / total : 0,
                  progressBarColor: AppColors.danger600,
                  formatter: _fmtInt,
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: _CycleMetricTile(
                  animation: animation,
                  label: 'Tingkat Sehat',
                  target: healthRatio * 100,
                  unit: 'rasio',
                  valueColor: AppColors.primary800,
                  badgeIcon: Icons.query_stats_rounded,
                  badgeColor: const Color(0xFFDDEBDC),
                  iconColor: AppColors.primary800,
                  progress: healthRatio,
                  progressBarColor: AppColors.primary800,
                  formatter: (v) => '${v.toStringAsFixed(1)}%',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Cycle Metric Tile ───────────────────────────────────────────────────────────

class _CycleMetricTile extends StatelessWidget {
  final Animation<double> animation;
  final String label;
  final double target;
  final String unit;
  final Color valueColor;
  final IconData badgeIcon;
  final Color badgeColor;
  final Color iconColor;
  final double progress;
  final Color progressBarColor;
  final String Function(double) formatter;

  const _CycleMetricTile({
    required this.animation,
    required this.label,
    required this.target,
    required this.unit,
    required this.valueColor,
    required this.badgeIcon,
    required this.badgeColor,
    required this.iconColor,
    required this.progress,
    required this.progressBarColor,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    return NeuSurface(
      variant: NeuVariant.raised,
      radius: AppRadius.tile,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(badgeIcon, size: 14, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                _CountUpText(
                  animation: animation,
                  target: target,
                  formatter: formatter,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: valueColor,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AnimatedBuilder(
            animation: animation,
            builder: (context, _) => ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: Container(
                height: 5,
                width: double.infinity,
                color: const Color(0xFFE5EAE4),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (progress * animation.value).clamp(0.04, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: progressBarColor,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Self Check Card ───────────────────────────────────────────────────────────

class _SelfCheckCard extends StatelessWidget {
  final Animation<double> animation;
  final HomeSummary summary;
  final VoidCallback? onGoToScan;

  const _SelfCheckCard({
    required this.animation,
    required this.summary,
    this.onGoToScan,
  });

  @override
  Widget build(BuildContext context) {
    final checked = summary.selfCheck.checked;
    final target = summary.selfCheck.target;
    final progress = target > 0 ? checked / target : 0.0;

    return SectionCard(
      icon: Icons.checklist_rounded,
      title: 'Pengecekan Mandiri Hari Ini',
      trailing: Text(
        'Target: $target',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.primary800,
        ),
      ),
      children: Column(
        children: [
          NeuSurface(
            variant: NeuVariant.inset,
            radius: AppRadius.tile,
            padding: const EdgeInsets.all(AppSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AnimatedBuilder(
                      animation: animation,
                      builder: (context, _) {
                        final cur = (animation.value * checked).toInt();
                        return Text(
                          '$cur dari $target baglog dicek',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        );
                      },
                    ),
                    AnimatedBuilder(
                      animation: animation,
                      builder: (context, _) {
                        final pct = (animation.value * progress * 100).round();
                        return Text(
                          '$pct% Selesai',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary800,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s3),
                AnimatedBuilder(
                  animation: animation,
                  builder: (context, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: Container(
                      height: 8,
                      width: double.infinity,
                      color: const Color(0xFFDCE2DB),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor:
                            (progress * animation.value).clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary400,
                            borderRadius:
                                BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          // ── Tombol Mulai Scan Kumbung ─────────────────────────────────────────
          NeuSurface(
            variant: NeuVariant.raised,
            radius: AppRadius.tile,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.tile),
                onTap: onGoToScan, // ←─ tersambung ke halaman scan
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s4,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.photo_camera_outlined,
                        color: AppColors.primary800,
                        size: 24,
                      ),
                      const SizedBox(width: AppSpacing.s3),
                      Expanded(
                        child: Text(
                          'Mulai Scan Kumbung',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary800,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
