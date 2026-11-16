import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/tokens.dart';
import '../../core/components/neu_surface.dart';
import '../../core/components/app_chip.dart';
import '../../core/components/status_badge.dart';
import '../../core/network/api_providers.dart';
import '../auth/login_screen.dart';
import 'domain/models/history_item.dart';
import 'history_detail_screen.dart';
import 'manual_inspection_screen.dart';
import 'presentation/providers/history_provider.dart';
import 'widgets/history_card.dart';
import 'widgets/history_archived_card.dart';

enum HistoryFilterType {
  all,
  actionRequired,
  mustDiscard,
}

/// Layar Riwayat Deteksi Baglog (Anggota D)
/// Mengimplementasikan arsip inspeksi kamera dari backend (Neon DB) & lokal,
/// pencarian, filter chips, navigasi ke halaman detail, dan form inspeksi manual.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  HistoryFilterType _selectedFilter = HistoryFilterType.all;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  DateTime? _selectedDate;
  bool _isArchivedOpen = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncRemoteHistory();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _syncRemoteHistory({bool showFeedback = false}) async {
    ref.read(historySyncStatusProvider.notifier).state =
        HistorySyncStatus.loading;
    final status =
        await ref.read(historyControllerProvider.notifier).refreshFromRemote();
    if (!mounted) return;

    ref.read(historySyncStatusProvider.notifier).state = status;

    if (showFeedback) {
      final isSynced = status == HistorySyncStatus.synced;
      final isUnauth = status == HistorySyncStatus.unauthenticated;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isSynced
                ? 'Riwayat scan berhasil disinkronkan dari server'
                : isUnauth
                    ? 'Masuk dengan akun petani untuk menyinkronkan riwayat server'
                    : 'Server belum terjangkau, menampilkan riwayat lokal',
            style: GoogleFonts.plusJakartaSans(fontSize: 13),
          ),
          action: isUnauth
              ? SnackBarAction(
                  label: 'Masuk',
                  textColor: AppColors.accentChip,
                  onPressed: _openLoginAndSync,
                )
              : null,
          backgroundColor:
              isSynced ? AppColors.primary800 : const Color(0xFF5D2E14),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _openLoginAndSync() async {
    final loggedIn = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          onLoginSuccess: () => Navigator.of(context).pop(true),
        ),
      ),
    );
    if (loggedIn == true && mounted) {
      await _syncRemoteHistory(showFeedback: true);
    }
  }

  void _openDetail(HistoryItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HistoryDetailScreen(
          itemId: item.id,
          fallbackItem: item,
        ),
      ),
    );
  }

  void _openManualInspectionForm() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ManualInspectionScreen(),
      ),
    );
  }

  Future<void> _pickFilterDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  bool _matchesSelectedDate(HistoryItem item) {
    final target = _selectedDate;
    if (target == null) return true;
    final dt = item.createdAt;
    if (dt == null) return false;
    return dt.year == target.year &&
        dt.month == target.month &&
        dt.day == target.day;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(authTokenProvider, (prev, next) {
      if (next != null && next.isNotEmpty && next != prev) {
        _syncRemoteHistory();
      }
    });

    final items = ref.watch(historyControllerProvider);
    final syncStatus = ref.watch(historySyncStatusProvider);

    // Saring data berdasarkan query pencarian dan tanggal (bila dipilih)
    final query = _searchQuery.toLowerCase().trim();
    final filtered = items.where((item) {
      if (!_matchesSelectedDate(item)) return false;
      if (query.isEmpty) return true;
      final matchName = item.name.toLowerCase().contains(query);
      final matchRack = item.rackLocation.toLowerCase().contains(query);
      final matchNote = item.note?.toLowerCase().contains(query) ?? false;
      final matchBadge = item.badge.toLowerCase().contains(query);
      return matchName || matchRack || matchNote || matchBadge;
    }).toList();

    // Saring per kategori dan filter aktif
    final actionItems = filtered.where((item) {
      if (item.category != HistorySectionCategory.actionRequired) return false;
      if (_selectedFilter == HistoryFilterType.mustDiscard) {
        return item.badge == 'Harus Dibuang';
      }
      return true;
    }).toList();

    final recoveredItems = filtered.where((item) {
      if (_selectedFilter == HistoryFilterType.mustDiscard) return false;
      return item.category == HistorySectionCategory.recovered;
    }).toList();

    final archivedItems = filtered.where((item) {
      if (_selectedFilter == HistoryFilterType.mustDiscard) {
        return item.badge == 'Telah Dibuang';
      }
      return item.category == HistorySectionCategory.archived;
    }).toList();

    // Hitung counter untuk chip filter dari seluruh riwayat.
    final countAll = items.length;
    final countAction = items
        .where((item) => item.category == HistorySectionCategory.actionRequired)
        .length;
    final countDiscard = items
        .where((item) =>
            item.badge == 'Harus Dibuang' || item.badge == 'Telah Dibuang')
        .length;

    return RefreshIndicator(
      color: AppColors.primary600,
      onRefresh: () => _syncRemoteHistory(showFeedback: true),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePaddingX,
          AppSpacing.s4,
          AppSpacing.pagePaddingX,
          96,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header Judul Layar
            _buildScreenHeader(syncStatus),
            if (syncStatus == HistorySyncStatus.loading) ...[
              const SizedBox(height: AppSpacing.s2),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor: AppColors.primary100,
                  color: AppColors.primary600,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.s4),

            // 2. Bar Pencarian Inset
            _buildSearchBar(),
            if (_selectedDate != null) ...[
              const SizedBox(height: AppSpacing.s2),
              _buildSelectedDateChip(),
            ],
            const SizedBox(height: AppSpacing.s4),

            // 3. Filter Chips Horizontal
            _buildFilterChips(countAll, countAction, countDiscard),
            const SizedBox(height: AppSpacing.sectionGap),

            // Empty search state
            if (actionItems.isEmpty &&
                recoveredItems.isEmpty &&
                archivedItems.isEmpty) ...[
              _buildEmptyState(),
              const SizedBox(height: AppSpacing.s4),
            ],

            // 4. Daftar Kartu Perlu Tindakan
            if (actionItems.isNotEmpty) ...[
              ...actionItems.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s4),
                  child: HistoryCard(
                    item: item,
                    onTap: () => _openDetail(item),
                  ),
                );
              }),
            ],

            // 5. Bagian Selesai Diobati & Pulih
            if (recoveredItems.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s2),
              _buildSectionHeader(
                icon: Icons.check_circle_outline_rounded,
                title:
                    'Selesai Diobati & Pulih (${recoveredItems.length} Baglog)',
                trailingBadge: StatusBadge(
                  label: '${recoveredItems.length} Sembuh',
                  tone: StatusTone.success,
                ),
              ),
              const SizedBox(height: AppSpacing.s3),
              ...recoveredItems.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s4),
                  child: HistoryCard(
                    item: item,
                    onTap: () => _openDetail(item),
                  ),
                );
              }),
            ],

            // 6. Bagian Riwayat Terarsip
            if (archivedItems.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s2),
              _buildArchivedHeader(),
              if (_isArchivedOpen) ...[
                const SizedBox(height: AppSpacing.s3),
                ...archivedItems.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                    child: HistoryArchivedCard(
                      item: item,
                      onTap: () => _openDetail(item),
                    ),
                  );
                }),
              ],
            ],

            const SizedBox(height: AppSpacing.s3),

            // 7. Kartu Aksi Inspeksi Manual Baglog
            _buildManualInspectionCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildScreenHeader(HistorySyncStatus syncStatus) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Riwayat Deteksi Baglog',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Arsip inspeksi kamera & diagnosis on-device',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        // Tombol refresh/sinkronisasi raised
        GestureDetector(
          onTap: syncStatus == HistorySyncStatus.loading
              ? null
              : () => _syncRemoteHistory(showFeedback: true),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: AppShadows.raisedSm,
            ),
            child: Icon(
              Icons.refresh_rounded,
              color: syncStatus == HistorySyncStatus.loading
                  ? AppColors.textMuted
                  : AppColors.primary600,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return NeuSurface(
      variant: NeuVariant.inset,
      radius: AppRadius.tile,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            color: AppColors.textMuted,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Cari rak, nomor baglog, atau diagnosis...',
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
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              child: const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.close_rounded,
                  color: AppColors.textMuted,
                  size: 18,
                ),
              ),
            ),
          GestureDetector(
            onTap: _pickFilterDate,
            child: Icon(
              Icons.calendar_today_rounded,
              color: _selectedDate != null
                  ? AppColors.primary600
                  : AppColors.textSecondary,
              size: 19,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedDateChip() {
    final d = _selectedDate!;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final label = '${d.day} ${months[d.month - 1]} ${d.year}';

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary100,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.event_rounded,
                size: 14,
                color: AppColors.primary800,
              ),
              const SizedBox(width: 6),
              Text(
                'Filter tanggal: $label',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary800,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => setState(() => _selectedDate = null),
                child: const Icon(
                  Icons.close_rounded,
                  size: 15,
                  color: AppColors.primary800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return NeuSurface(
      variant: NeuVariant.inset,
      radius: AppRadius.card,
      padding: const EdgeInsets.all(AppSpacing.s6),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 36,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.s2),
            Text(
              'Tidak ada riwayat yang cocok',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Coba ubah kata kunci pencarian atau filter status.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(int countAll, int countAction, int countDiscard) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          AppChip(
            label: 'Semua Temuan ($countAll)',
            selected: _selectedFilter == HistoryFilterType.all,
            dotColor: AppColors.primary600,
            onPress: () =>
                setState(() => _selectedFilter = HistoryFilterType.all),
          ),
          const SizedBox(width: AppSpacing.s2),
          AppChip(
            label: 'Perlu Tindakan ($countAction)',
            selected: _selectedFilter == HistoryFilterType.actionRequired,
            dotColor: AppColors.warning500,
            onPress: () => setState(
                () => _selectedFilter = HistoryFilterType.actionRequired),
          ),
          const SizedBox(width: AppSpacing.s2),
          AppChip(
            label: 'Harus Dibuang ($countDiscard)',
            selected: _selectedFilter == HistoryFilterType.mustDiscard,
            dotColor: AppColors.danger600,
            onPress: () =>
                setState(() => _selectedFilter = HistoryFilterType.mustDiscard),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Widget trailingBadge,
  }) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            color: AppColors.primary100,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: AppColors.primary600,
            size: 16,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        trailingBadge,
      ],
    );
  }

  Widget _buildArchivedHeader() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _isArchivedOpen = !_isArchivedOpen),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              color: AppColors.primary100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: AppColors.primary600,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Riwayat Terarsip',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _isArchivedOpen ? 'Tutup arsip' : 'Klik untuk buka',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualInspectionCard() {
    return GestureDetector(
      onTap: _openManualInspectionForm,
      child: NeuSurface(
        variant: NeuVariant.raised,
        radius: AppRadius.card,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.cardPadding,
          vertical: AppSpacing.s4,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppShadows.raisedSm,
              ),
              child: const Icon(
                Icons.add_photo_alternate_outlined,
                color: AppColors.primary600,
                size: 22,
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
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Input manual tanpa bantuan kamera',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppShadows.raisedSm,
              ),
              child: const Icon(
                Icons.add_rounded,
                color: AppColors.primary600,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
