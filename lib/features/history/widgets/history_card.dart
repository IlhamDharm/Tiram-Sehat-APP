import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/components/neu_surface.dart';
import '../../../core/components/status_badge.dart';
import '../../../core/format/format_helper.dart';
import '../domain/models/history_item.dart';
import 'baglog_thumbnail.dart';

/// Kartu ringkas riwayat inspeksi baglog.
/// Mengetuk kartu akan membuka halaman detail riwayat baglog.
class HistoryCard extends StatelessWidget {
  final HistoryItem item;
  final VoidCallback onTap;

  const HistoryCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  NeuTone get _neuTone {
    if (item.tone == 'danger') return NeuTone.danger;
    if (item.tone == 'warning') return NeuTone.warning;
    return NeuTone.defaultTone;
  }

  ThumbnailIndicatorType get _indicatorType {
    if (item.tone == 'danger') return ThumbnailIndicatorType.dangerTriangle;
    if (item.tone == 'warning') return ThumbnailIndicatorType.warningDot;
    return ThumbnailIndicatorType.successDot;
  }

  StatusBadge _buildHeaderBadge() {
    switch (item.badge) {
      case 'Harus Dibuang':
        return const StatusBadge(
          label: 'Harus Dibuang',
          tone: StatusTone.danger,
          icon: Icons.delete_outline_rounded,
          solid: true,
        );
      case 'Bisa Diobati':
        return const StatusBadge(
          label: 'Bisa Diobati',
          tone: StatusTone.warning,
          icon: Icons.healing_rounded,
          solid: true,
        );
      case 'Sedang Diobati':
        return const StatusBadge(
          label: 'Sedang Diobati',
          tone: StatusTone.success,
          icon: Icons.healing_rounded,
          solid: true,
        );
      case 'Sehat':
        return const StatusBadge(
          label: 'Sehat',
          tone: StatusTone.success,
          icon: Icons.eco_rounded,
          solid: true,
        );
      case 'Selesai Diobati':
      default:
        return StatusBadge(
          label: item.badge,
          tone: StatusTone.success,
          icon: Icons.check_circle_outline_rounded,
          solid: true,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasMeta = item.isManual ||
        item.confidenceScore != null ||
        (item.status != null && item.status!.isNotEmpty);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: NeuSurface(
        variant: NeuVariant.raised,
        radius: AppRadius.card,
        tone: _neuTone,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            BaglogThumbnail(
              indicatorType: _indicatorType,
              imageUrl: item.imageUrl,
            ),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: _buildHeaderBadge(),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.when,
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.inventory_2_outlined,
                        size: 14,
                        color: AppColors.primary600,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.rackLocation,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (hasMeta) ...[
                    const SizedBox(height: 6),
                    _buildMetaSummary(),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                boxShadow: AppShadows.raisedSm,
              ),
              child: const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaSummary() {
    final chips = <Widget>[];

    if (item.isManual) {
      chips.add(
        const StatusBadge(
          label: 'Inspeksi Manual',
          tone: StatusTone.neutral,
          icon: Icons.edit_note_rounded,
        ),
      );
    } else if (item.confidenceScore != null) {
      chips.add(
        StatusBadge(
          label: 'Akurasi ${FormatHelper.persen(item.confidenceScore!)}',
          tone: StatusTone.neutral,
          icon: Icons.psychology_alt_rounded,
        ),
      );
    }

    if (chips.isNotEmpty) {
      return Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: chips,
      );
    }

    return Text(
      item.status!,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        color: AppColors.textMuted,
      ),
    );
  }
}
