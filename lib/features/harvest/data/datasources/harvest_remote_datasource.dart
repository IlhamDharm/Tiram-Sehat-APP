import '../../../../core/network/api_client.dart';
import '../../domain/models/harvest_entry.dart';

class HarvestRemoteDataSource {
  final ApiClient _api;

  HarvestRemoteDataSource(this._api);

  Future<void> createHarvest(HarvestEntry entry) async {
    final res = await _api.post('/api/v1/harvests', body: {
      'harvested_at': entry.dateTime.toIso8601String(),
      'weight_kg': entry.weightKg,
      'price_per_kg': entry.pricePerKg,
      'note': entry.note,
    });
    if (res.error != null) {
      throw Exception(res.error!.message);
    }
  }

  Future<List<HarvestEntry>> fetchHarvests() async {
    final res = await _api.get('/api/v1/harvests');
    if (res.error != null || res.data == null) {
      throw Exception(res.error?.message ?? 'Gagal memuat data panen');
    }

    final list = res.data as List<dynamic>;
    return list.map((item) {
      final map = item as Map<String, dynamic>;
      final dt = DateTime.tryParse(map['harvested_at'] as String? ?? '') ??
          DateTime.now();
      return HarvestEntry(
        id: map['id']?.toString(),
        dateTime: dt,
        weightKg: (map['weight_kg'] as num?)?.toDouble() ?? 0.0,
        pricePerKg: (map['price_per_kg'] as num?)?.toInt() ?? 0,
        grossIncome: (map['gross_income'] as num?)?.toInt(),
        note: map['note'] as String?,
        buyer: 'Tengkulak Margomulyo',
      );
    }).toList();
  }
}
