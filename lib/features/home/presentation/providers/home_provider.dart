import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_providers.dart';
import '../../data/datasources/home_remote_datasource.dart';
import '../../data/models/home_summary.dart';
import '../../data/repositories/home_repository.dart';

final homeRemoteDataSourceProvider = Provider<HomeRemoteDataSource>((ref) {
  return HomeRemoteDataSource(ref.watch(apiClientProvider));
});

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepository(ref.watch(homeRemoteDataSourceProvider));
});

final homeSummaryProvider = FutureProvider.autoDispose<HomeSummary>((ref) {
  return ref.watch(homeRepositoryProvider).getSummary();
});
