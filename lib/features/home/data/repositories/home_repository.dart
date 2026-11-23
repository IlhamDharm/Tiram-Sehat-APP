import '../datasources/home_remote_datasource.dart';
import '../models/home_summary.dart';

class HomeRepository {
  final HomeRemoteDataSource _remote;

  HomeRepository(this._remote);

  Future<HomeSummary> getSummary({DateTime? date}) async {
    return await _remote.getSummary(date: date);
  }
}
