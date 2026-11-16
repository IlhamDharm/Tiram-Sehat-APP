import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/components/action_button.dart';
import '../../core/components/neu_surface.dart';
import '../../core/components/section_card.dart';
import '../../core/components/status_badge.dart';
import '../../core/components/step_list.dart';
import '../../core/format/format_helper.dart';
import '../../core/theme/tokens.dart';
import 'domain/models/history_item.dart';
import 'presentation/providers/history_provider.dart';

/// Halaman detail riwayat deteksi / inspeksi baglog.
/// Menampilkan foto Cloudinary, informasi diagnosis, lokasi rak/kolom,
/// catatan lapangan, langkah penanganan (SOP), dan tombol konfirmasi tindakan.
class HistoryDetailScreen extends ConsumerWidget {
  final String itemId;
  final HistoryItem? fallbackItem;

  const HistoryDetailScreen({
    super.key,
    required this.itemId,
    this.fallbackItem,
  });

  HistoryItem? _findItem(List<HistoryItem> items) {
    for (final item in items) {
      if (item.id == itemId) return item;
    }
    return fallbackItem;
  }

  StatusTone _statusTone(HistoryItem item) {
    if (item.tone == 'danger') return StatusTone.danger;
    if (item.tone == 'warning') return StatusTone.warning;
    if (item.tone == 'success') return StatusTone.success;
    return StatusTone.neutral;
  }

  IconData _badgeIcon(HistoryItem item) {
    switch (item.badge) {
      case 'Harus Dibuang':
      case 'Telah Dibuang':
        return Icons.delete_outline_rounded;
      case 'Bisa Diobati':
      case 'Sedang Diobati':
        return Icons.healing_rounded;
      case 'Sehat':
        return Icons.eco_rounded;
      default:
        return Icons.check_circle_outline_rounded;
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    HistoryItem item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        title: Text(
          'Hapus Riwayat Baglog?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Catatan "${item.name}" pada ${item.rackLocation} akan dihapus dari riwayat.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Batal',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Hapus',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await ref.read(historyControllerProvider.notifier).remove(item.id);
    if (!context.mounted) return;

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Riwayat "${item.name}" telah dihapus',
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

  void _handleAction(BuildContext context, WidgetRef ref, HistoryItem item) {
    ref.read(historyControllerProvider.notifier).markHandled(item);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          item.actionLabel != null
              ? '${item.actionLabel} berhasil dicatat'
              : 'Status berhasil diperbarui',
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

  void _openImageZoom(BuildContext context, String imageUrl) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const SizedBox(
                    height: 240,
                    child: Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white54,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: () => Navigator.of(ctx).pop(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(historyControllerProvider);
    final item = _findItem(items);

    if (item == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          elevation: 0,
          title: const Text('Detail Riwayat'),
        ),
        body: const Center(
          child: Text('Data riwayat tidak ditemukan.'),
        ),
      );
    }

    final displayTitle = (item.diagnosisName != null &&
            item.diagnosisName!.trim().isNotEmpty)
        ? item.diagnosisName!
        : item.name;
    final hasImage = item.imageUrl != null && item.imageUrl!.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context, ref, item),
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
                    _buildImageSection(context, item, hasImage),
                    const SizedBox(height: AppSpacing.sectionGap),
                    _buildHeaderSection(item, displayTitle),
                    const SizedBox(height: AppSpacing.s4),
                    _buildInfoGrid(item),
                    if (item.status != null || item.note != null) ...[
                      const SizedBox(height: AppSpacing.sectionGap),
                      _buildStatusBox(item),
                    ],
                    if (item.steps.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sectionGap),
                      SectionCard(
                        icon: Icons.medical_services_rounded,
                        title: 'Panduan Tindakan Penanganan',
                        trailing: Text(
                          '${item.steps.length} Langkah',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                        children: StepList(
                          steps: item.steps
                              .map(
                                (s) => StepItem(
                                  title: s.title,
                                  description: s.description,
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                    if (item.actionLabel != null) ...[
                      const SizedBox(height: AppSpacing.sectionGap),
                      _buildBottomAction(context, ref, item),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, WidgetRef ref, HistoryItem item) {
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
            child: Text(
              'Detail Riwayat Baglog',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _confirmDelete(context, ref, item),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppShadows.raisedSm,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.danger600,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection(
    BuildContext context,
    HistoryItem item,
    bool hasImage,
  ) {
    return NeuSurface(
      variant: NeuVariant.raised,
      radius: AppRadius.card,
      padding: const EdgeInsets.all(AppSpacing.s2),
      child: GestureDetector(
        onTap: hasImage ? () => _openImageZoom(context, item.imageUrl!) : null,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 210,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (hasImage)
                  Image.network(
                    item.imageUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: AppColors.surfaceInset,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary600,
                            strokeWidth: 2.5,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) =>
                        _ImagePlaceholder(
                      isManual: item.isManual,
                      caption: 'Gagal memuat foto baglog',
                    ),
                  )
                else
                  _ImagePlaceholder(
                    isManual: item.isManual,
                    caption: item.isManual
                        ? 'Pencatatan Inspeksi Manual (Tanpa Foto)'
                        : 'Dokumentasi foto belum tersedia',
                  ),
                if (hasImage)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.zoom_in_rounded,
                            color: Colors.white,
                            size: 15,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Ketuk perbesar',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection(HistoryItem item, String displayTitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                item.isManual
                    ? 'INSPEKSI MANUAL BAGLOG'
                    : 'HASIL DETEKSI BAGLOG',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            StatusBadge(
              label: item.badge,
              tone: _statusTone(item),
              icon: _badgeIcon(item),
              solid: true,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s2),
        Text(
          displayTitle,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 25,
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        if (item.scientificName != null &&
            item.scientificName!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            '(${item.scientificName})',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.s2),
        Row(
          children: [
            const Icon(
              Icons.schedule_rounded,
              size: 15,
              color: AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              item.when,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoGrid(HistoryItem item) {
    final accuracyText = item.confidenceScore != null
        ? FormatHelper.persen(item.confidenceScore!)
        : (item.isManual ? 'Manual' : '-');

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _InfoTile(
                icon: Icons.inventory_2_outlined,
                label: 'Lokasi Kumbung',
                value: item.rackLocation,
              ),
            ),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: _InfoTile(
                icon: item.isManual
                    ? Icons.edit_note_rounded
                    : Icons.psychology_alt_rounded,
                label: item.isManual ? 'Metode' : 'Tingkat Akurasi',
                value: accuracyText,
              ),
            ),
          ],
        ),
        if (item.infectionLocation != null &&
            item.infectionLocation!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s3),
          _InfoTile(
            icon: Icons.place_outlined,
            label: 'Area / Lokasi Gejala pada Baglog',
            value: item.infectionLocation!,
          ),
        ],
      ],
    );
  }

  Widget _buildStatusBox(HistoryItem item) {
    Color boxBg;
    Border boxBorder;
    Color titleColor;
    IconData titleIcon;

    if (item.tone == 'danger') {
      boxBg = const Color(0xFFFDE8E8);
      boxBorder = Border.all(color: AppColors.dangerBorder, width: 1);
      titleColor = AppColors.danger600;
      titleIcon = Icons.error_outline_rounded;
    } else if (item.tone == 'warning') {
      boxBg = const Color(0xFFFEF3DC);
      boxBorder = Border.all(color: const Color(0xFFF7D59A), width: 1);
      titleColor = AppColors.warning500;
      titleIcon = Icons.cleaning_services_rounded;
    } else {
      boxBg = const Color(0xFFEAF4E9);
      boxBorder = Border.all(color: const Color(0xFFC6E2C4), width: 1);
      titleColor = AppColors.primary800;
      titleIcon = Icons.check_circle_outline_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: boxBg,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: boxBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(titleIcon, size: 18, color: titleColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.status ?? 'Status: ${item.badge}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
              ),
              if (item.tag != null) ...[
                const SizedBox(width: 8),
                StatusBadge(
                  label: item.tag!,
                  tone: _statusTone(item),
                ),
              ],
            ],
          ),
          if (item.note != null && item.note!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s2),
            Text(
              item.note!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomAction(
    BuildContext context,
    WidgetRef ref,
    HistoryItem item,
  ) {
    ActionVariant variant;
    if (item.tone == 'danger') {
      variant = ActionVariant.danger;
    } else if (item.tone == 'warning') {
      variant = ActionVariant.warning;
    } else {
      variant = ActionVariant.primary;
    }

    return ActionButton(
      label: item.actionLabel!,
      icon: Icons.check_circle_outline_rounded,
      variant: variant,
      fullWidth: true,
      onPress: () => _handleAction(context, ref, item),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final bool isManual;
  final String caption;

  const _ImagePlaceholder({
    required this.isManual,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceInset,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              boxShadow: AppShadows.raisedSm,
            ),
            child: Icon(
              isManual
                  ? Icons.edit_note_rounded
                  : Icons.inventory_2_rounded,
              color: AppColors.primary600,
              size: 28,
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(
            caption,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return NeuSurface(
      variant: NeuVariant.raised,
      radius: AppRadius.tile,
      padding: const EdgeInsets.all(AppSpacing.s3),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 19,
              color: AppColors.primary800,
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
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
