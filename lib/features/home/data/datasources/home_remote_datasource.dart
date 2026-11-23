import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../models/home_summary.dart';

class HomeRemoteDataSource {
  final ApiClient _api;

  HomeRemoteDataSource(this._api);

  Future<HomeSummary> getSummary({DateTime? date}) async {
    final res = await _api.get('/api/v1/home/summary', query: {
      if (date != null) 'date': date.toIso8601String().split('T').first,
    });
    if (res.error != null || res.data == null) {
      throw ApiException.from(res.error);
    }
    return HomeSummary.fromJson(res.data as Map<String, dynamic>);
  }
}
