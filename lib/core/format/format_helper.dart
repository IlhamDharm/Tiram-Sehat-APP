class FormatHelper {
  static String rupiah(int value) {
    final str = value.toString();
    final buffer = StringBuffer('Rp ');
    final len = str.length;
    for (int i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  static String rupiahPerKg(int value) => '${rupiah(value)} /Kg';

  /// Format nominal rupiah disingkat untuk tampilan kartu/ringkasan:
  /// - < 1.000: 'Rp 500'
  /// - 1.000 s/d 999.999: 'Rp 15 rb' atau 'Rp 367,5 rb'
  /// - 1.000.000 s/d 999.999.999: 'Rp 1,5 jt' atau 'Rp 2,17 jt' atau 'Rp 105 jt'
  /// - >= 1.000.000.000: 'Rp 1,2 M'
  static String rupiahSingkat(num value) {
    if (value.abs() >= 1000000000) {
      final v = value / 1000000000;
      return 'Rp ${_formatDecimals(v)} M';
    }
    if (value.abs() >= 1000000) {
      final v = value / 1000000;
      return 'Rp ${_formatDecimals(v)} jt';
    }
    if (value.abs() >= 1000) {
      final v = value / 1000;
      return 'Rp ${_formatDecimals(v)} rb';
    }
    return rupiah(value.toInt());
  }

  static String rupiahPerKgSingkat(num value) => '${rupiahSingkat(value)} /Kg';

  static String _formatDecimals(double v) {
    if (v == v.roundToDouble()) {
      return v.toInt().toString();
    }
    final oneDec = double.parse(v.toStringAsFixed(1));
    if (oneDec == double.parse(v.toStringAsFixed(2))) {
      return v.toStringAsFixed(1).replaceAll('.', ',');
    }
    if (v.abs() < 10) {
      return v.toStringAsFixed(2).replaceAll('.', ',');
    }
    return v.toStringAsFixed(1).replaceAll('.', ',');
  }

  static String kg(double value) {
    final formatted = value.toStringAsFixed(1).replaceAll('.', ',');
    return '$formatted Kg';
  }

  static String persen(double value) {
    final formatted = value.toStringAsFixed(1).replaceAll('.', ',');
    return '$formatted%';
  }

  static String deltaKg(double value) {
    final formatted = value.toStringAsFixed(1).replaceAll('.', ',');
    return '+$formatted Kg';
  }

  static String deltaPct(double value) {
    final formatted = value.toStringAsFixed(1).replaceAll('.', ',');
    return '+$formatted%';
  }

  static String baglog(int value) {
    final str = value.toString();
    final buffer = StringBuffer();
    final len = str.length;
    for (int i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    buffer.write(' baglog');
    return buffer.toString();
  }

  static const List<String> namaHari = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  static const List<String> namaBulan = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  static const List<String> namaBulanLengkap = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  static String dateLong(DateTime date) {
    final hari = namaHari[date.weekday - 1];
    final bulan = namaBulan[date.month - 1];
    return '$hari, ${date.day} $bulan ${date.year}';
  }

  static String dateTimeLong(DateTime date) {
    final hari = namaHari[date.weekday - 1];
    final bulan = namaBulan[date.month - 1];
    final jam = date.hour.toString().padLeft(2, '0');
    final menit = date.minute.toString().padLeft(2, '0');
    return '$hari, ${date.day} $bulan ${date.year} - $jam:$menit WIB';
  }

  static String dateRange(DateTime start, DateTime end) {
    if (start.year == end.year && start.month == end.month) {
      return '${start.day} - ${end.day} ${namaBulan[start.month - 1]} ${start.year}';
    } else if (start.year == end.year) {
      return '${start.day} ${namaBulan[start.month - 1]} - ${end.day} ${namaBulan[end.month - 1]} ${start.year}';
    }
    return '${start.day} ${namaBulan[start.month - 1]} ${start.year} - ${end.day} ${namaBulan[end.month - 1]} ${end.year}';
  }
}
