import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../mock/mock_data.dart';

List<HarvestEntry> _buildInitialHarvests() {
  final list = <HarvestEntry>[
    // --- Pekan Acuan: Minggu 20 Okt - Sabtu 26 Okt 2024 (1 Pekan Penuh) ---
    HarvestEntry(
      id: 'h-20241026',
      dateTime: DateTime(2024, 10, 26, 8, 0),
      weightKg: 25.5,
      pricePerKg: 15000,
      grossIncome: 382500,
      note: 'Puncak panen akhir pekan, kualitas jamur mekar segar.',
    ),
    HarvestEntry(
      id: 'h-20241025',
      dateTime: DateTime(2024, 10, 25, 7, 15),
      weightKg: 22.0,
      pricePerKg: 15000,
      grossIncome: 330000,
      note: 'Penyortiran borongan pedagang pasar induk.',
    ),
    HarvestEntry(
      id: 'h-20241024',
      dateTime: DateTime(2024, 10, 24, 7, 30),
      weightKg: 24.5,
      pricePerKg: 15000,
      grossIncome: 367500,
      note: 'Panen petik ke-3 kumbung selatan, kualitas baglog prima tanpa bercak.',
    ),
    HarvestEntry(
      id: 'h-20241023',
      dateTime: DateTime(2024, 10, 23, 7, 45),
      weightKg: 20.3,
      pricePerKg: 15000,
      grossIncome: 304500,
      note: 'Kelembapan kumbung stabil 88%, hasil petik bersih.',
    ),
    HarvestEntry(
      id: 'h-20241022',
      dateTime: DateTime(2024, 10, 22, 7, 0),
      weightKg: 19.0,
      pricePerKg: 15000,
      grossIncome: 285000,
      note: 'Sortasi grade A 95%, tidak ada tudung rusak.',
    ),
    HarvestEntry(
      id: 'h-20241021',
      dateTime: DateTime(2024, 10, 21, 7, 30),
      weightKg: 17.5,
      pricePerKg: 15000,
      grossIncome: 262500,
      note: 'Panen kumbung timur rak 1-4.',
    ),
    HarvestEntry(
      id: 'h-20241020',
      dateTime: DateTime(2024, 10, 20, 7, 15),
      weightKg: 16.0,
      pricePerKg: 15000,
      grossIncome: 240000,
      note: 'Petik perdana awal pekan hari Minggu.',
    ),

    // --- Pekan Sebelumnya: Minggu 13 Okt - Sabtu 19 Okt 2024 ---
    HarvestEntry(
      id: 'h-20241019',
      dateTime: DateTime(2024, 10, 19, 7, 30),
      weightKg: 20.6,
      pricePerKg: 15000,
      grossIncome: 309000,
      note: 'Penutupan pekan kedua.',
    ),
    HarvestEntry(
      id: 'h-20241018',
      dateTime: DateTime(2024, 10, 18, 7, 0),
      weightKg: 20.0,
      pricePerKg: 15000,
      grossIncome: 300000,
    ),
    HarvestEntry(
      id: 'h-20241017',
      dateTime: DateTime(2024, 10, 17, 7, 30),
      weightKg: 19.5,
      pricePerKg: 15000,
      grossIncome: 292500,
    ),
    HarvestEntry(
      id: 'h-20241016',
      dateTime: DateTime(2024, 10, 16, 7, 15),
      weightKg: 17.0,
      pricePerKg: 15000,
      grossIncome: 255000,
    ),
    HarvestEntry(
      id: 'h-20241015',
      dateTime: DateTime(2024, 10, 15, 7, 30),
      weightKg: 18.0,
      pricePerKg: 15000,
      grossIncome: 270000,
    ),
    HarvestEntry(
      id: 'h-20241014',
      dateTime: DateTime(2024, 10, 14, 7, 0),
      weightKg: 16.5,
      pricePerKg: 15000,
      grossIncome: 247500,
    ),
    HarvestEntry(
      id: 'h-20241013',
      dateTime: DateTime(2024, 10, 13, 7, 15),
      weightKg: 15.0,
      pricePerKg: 15000,
      grossIncome: 225000,
    ),

    // --- Sisa Bulan Oktober 2024 agar total bulanan sesuai mock data ---
    HarvestEntry(
      id: 'h-20241030',
      dateTime: DateTime(2024, 10, 30, 8, 0),
      weightKg: 18.2,
      pricePerKg: 15000,
      grossIncome: 273000,
    ),
    HarvestEntry(
      id: 'h-20241028',
      dateTime: DateTime(2024, 10, 28, 7, 30),
      weightKg: 18.2,
      pricePerKg: 15000,
      grossIncome: 273000,
    ),
    HarvestEntry(
      id: 'h-20241010',
      dateTime: DateTime(2024, 10, 10, 7, 0),
      weightKg: 67.5,
      pricePerKg: 15000,
      grossIncome: 1012500,
    ),
    HarvestEntry(
      id: 'h-20241007',
      dateTime: DateTime(2024, 10, 7, 7, 0),
      weightKg: 67.5,
      pricePerKg: 15000,
      grossIncome: 1012500,
    ),
    HarvestEntry(
      id: 'h-20241003',
      dateTime: DateTime(2024, 10, 3, 7, 0),
      weightKg: 60.0,
      pricePerKg: 15000,
      grossIncome: 900000,
    ),
    HarvestEntry(
      id: 'h-20241001',
      dateTime: DateTime(2024, 10, 1, 7, 0),
      weightKg: 58.5,
      pricePerKg: 15000,
      grossIncome: 877500,
    ),
  ];

  // Jika perangkat berjalan pada waktu saat ini (bukan 2024), tambahkan sampel untuk pekan berjalan
  final now = DateTime.now();
  if (now.year != 2024) {
    final d = DateTime(now.year, now.month, now.day);
    final daysSinceSun = d.weekday == DateTime.sunday ? 0 : d.weekday;
    final sun = d.subtract(Duration(days: daysSinceSun));

    final sampleWeights = [16.0, 17.5, 19.0, 20.3, 24.5, 22.0, 25.5];
    for (int i = 0; i < 7; i++) {
      final currentDay = sun.add(Duration(days: i, hours: 7, minutes: 30));
      if (!currentDay.isAfter(now.add(const Duration(hours: 1)))) {
        final w = sampleWeights[i % sampleWeights.length];
        list.add(HarvestEntry(
          id: 'now-${currentDay.millisecondsSinceEpoch}',
          dateTime: currentDay,
          weightKg: w,
          pricePerKg: 15000,
          grossIncome: (w * 15000).round(),
          note: 'Panen pekan berjalan hari ke-${i + 1}',
        ));
      }
    }
  }

  list.sort((a, b) => b.dateTime.compareTo(a.dateTime));
  return list;
}

class HarvestNotifier extends StateNotifier<List<HarvestEntry>> {
  HarvestNotifier() : super(_buildInitialHarvests());

  void addHarvest(HarvestEntry entry) {
    state = [entry, ...state]..sort((a, b) => b.dateTime.compareTo(a.dateTime));
  }

  void removeHarvest(String id) {
    state = state.where((e) => e.id != id).toList();
  }
}

final harvestListProvider = StateNotifierProvider<HarvestNotifier, List<HarvestEntry>>((ref) {
  return HarvestNotifier();
});

final latestHarvestProvider = Provider<HarvestEntry>((ref) {
  final harvests = ref.watch(harvestListProvider);
  if (harvests.isEmpty) {
    return MockData.harvestLast;
  }
  return harvests.first;
});

