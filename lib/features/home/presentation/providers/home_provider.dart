import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_providers.dart';
import '../../../harvest/presentation/providers/harvest_provider.dart';
import '../../data/datasources/home_remote_datasource.dart';
import '../../data/models/home_summary.dart';
import '../../data/repositories/home_repository.dart';

final homeRemoteDataSourceProvider = Provider<HomeRemoteDataSource>((ref) {
  return HomeRemoteDataSource(ref.watch(apiClientProvider));
});

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepository(ref.watch(homeRemoteDataSourceProvider));
});

final homeSummaryProvider = FutureProvider.autoDispose<HomeSummary>((ref) async {
  final harvests = ref.watch(harvestListProvider);
  try {
    return await ref.watch(homeRepositoryProvider).getSummary();
  } catch (_) {
    // Fallback offline: gunakan data panen lokal dan sinkronkan dengan harvestListProvider
    final latest = harvests.isNotEmpty ? harvests.first : null;
    final todayKg = latest?.weightKg ?? 18.5;
    final todayIncome = latest?.grossIncome ?? 277500;

    return HomeSummary(
      date: latest?.date ?? 'Kamis, 24 Okt 2024 - 07:30 WIB',
      todayKg: todayKg,
      todayIncome: todayIncome,
      deltaPct: 18.0,
      activeBaglogs: 2450,
      healthyBaglogs: 2210,
      contaminatedBaglogs: 240,
      baglogBreakdown: {
        'bisa_diobati': 165,
        'afkir': 75,
      },
      selfCheck: const SelfCheckSummary(checked: 80, target: 100),
      recentHarvests: harvests
          .map((h) => RecentHarvest(
                id: h.id,
                harvestedAt: h.dateTime,
                weightKg: h.weightKg,
                grossIncome: h.grossIncome,
              ))
          .toList(),
    );
  }
});
