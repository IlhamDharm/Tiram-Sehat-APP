import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/format/format_helper.dart';
import '../../../harvest/domain/models/harvest_entry.dart';
import '../../presentation/providers/report_provider.dart';

class ReportPdfService {
  /// Warna tema dokumen PDF (selaras dengan identitas TiramSehat)
  static final _primaryColor = PdfColor.fromHex('#1B4332');
  static final _secondaryColor = PdfColor.fromHex('#2D6A4F');
  static final _accentColor = PdfColor.fromHex('#40916C');
  static final _lightBgColor = PdfColor.fromHex('#F4FBF7');
  static final _borderGrey = PdfColor.fromHex('#D8E2DC');

  /// Menghasilkan file PDF untuk Rekap Mingguan
  static Future<Uint8List> generateWeeklyReportPdf({
    required WeeklyReportSummary weekly,
    String farmerName = 'Budi Santoso',
    String kumbungName = 'Kumbung Blok A',
  }) async {
    final pdf = pw.Document();

    final fontRegular = await PdfGoogleFonts.plusJakartaSansRegular();
    final fontBold = await PdfGoogleFonts.plusJakartaSansBold();
    final fontSemiBold = await PdfGoogleFonts.plusJakartaSansSemiBold();

    final baseTheme = pw.ThemeData.withFont(
      base: fontRegular,
      bold: fontBold,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: baseTheme,
        build: (pw.Context context) {
          return [
            _buildHeader(fontBold, fontSemiBold, 'REKAPITULASI PANEN & KAS PEKANAN'),
            pw.SizedBox(height: 12),
            _buildMetaInfo(
              fontBold: fontBold,
              periode: weekly.periodLabel,
              farmerName: farmerName,
              kumbungName: kumbungName,
            ),
            pw.SizedBox(height: 16),
            _buildSummaryCards(
              fontBold: fontBold,
              totalKg: weekly.totalKg,
              totalIncome: weekly.totalIncome,
              avgPrice: weekly.avgPrice,
              deltaText: '${weekly.deltaKgText} (${weekly.deltaPctText}) vs pekan lalu',
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'RINCIAN TRANSAKSI PANEN & PENJUALAN',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: _primaryColor,
              ),
            ),
            pw.SizedBox(height: 6),
            _buildHarvestTable(
              fontBold: fontBold,
              entries: weekly.entries,
              totalKg: weekly.totalKg,
              totalIncome: weekly.totalIncome,
            ),
            pw.SizedBox(height: 30),
            _buildSignatureSection(fontBold, farmerName),
          ];
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'Halaman ${context.pageNumber} dari ${context.pagesCount} | Dicetak otomatis melalui Aplikasi TiramSehat',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Menghasilkan file PDF untuk Rekap Bulanan
  static Future<Uint8List> generateMonthlyReportPdf({
    required MonthlyReportSummary monthly,
    required List<HarvestEntry> entries,
    String farmerName = 'Budi Santoso',
    String kumbungName = 'Kumbung Blok A',
  }) async {
    final pdf = pw.Document();

    final fontRegular = await PdfGoogleFonts.plusJakartaSansRegular();
    final fontBold = await PdfGoogleFonts.plusJakartaSansBold();
    final fontSemiBold = await PdfGoogleFonts.plusJakartaSansSemiBold();

    final baseTheme = pw.ThemeData.withFont(
      base: fontRegular,
      bold: fontBold,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: baseTheme,
        build: (pw.Context context) {
          return [
            _buildHeader(fontBold, fontSemiBold, 'REKAPITULASI PANEN & KAS BULANAN'),
            pw.SizedBox(height: 12),
            _buildMetaInfo(
              fontBold: fontBold,
              periode: '${monthly.monthName} ${monthly.year}',
              farmerName: farmerName,
              kumbungName: kumbungName,
            ),
            pw.SizedBox(height: 16),
            _buildSummaryCards(
              fontBold: fontBold,
              totalKg: monthly.totalKg,
              totalIncome: monthly.totalIncome,
              avgPrice: monthly.avgPrice,
              deltaText: '${monthly.deltaKgText} (${monthly.deltaPctText}) vs bulan lalu',
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'RINCIAN HASIL PANEN BULAN INI',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: _primaryColor,
              ),
            ),
            pw.SizedBox(height: 6),
            _buildHarvestTable(
              fontBold: fontBold,
              entries: entries,
              totalKg: monthly.totalKg,
              totalIncome: monthly.totalIncome,
            ),
            pw.SizedBox(height: 30),
            _buildSignatureSection(fontBold, farmerName),
          ];
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'Halaman ${context.pageNumber} dari ${context.pagesCount} | Dicetak otomatis melalui Aplikasi TiramSehat',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Membagikan atau menyimpan dokumen PDF langsung ke penyimpanan perangkat / WhatsApp
  static Future<void> shareOrSavePdf({
    required Uint8List pdfBytes,
    required String filename,
  }) async {
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: filename,
    );
  }

  // --- KOMPONEN TATA LETAK PDF ---

  static pw.Widget _buildHeader(pw.Font fontBold, pw.Font fontSemiBold, String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'BUMDes MARGOMULYO',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 16,
                    color: _primaryColor,
                    letterSpacing: 0.5,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'UNIT USAHA BUDIDAYA JAMUR TIRAM SEHAT',
                  style: pw.TextStyle(
                    font: fontSemiBold,
                    fontSize: 10,
                    color: _secondaryColor,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Jl. Raya Margomulyo No. 45, Bojonegoro, Jawa Timur',
                  style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                ),
              ],
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: pw.BoxDecoration(
                color: _lightBgColor,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: _accentColor, width: 0.8),
              ),
              child: pw.Text(
                title,
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 9,
                  color: _primaryColor,
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Divider(thickness: 1.5, color: _primaryColor),
      ],
    );
  }

  static pw.Widget _buildMetaInfo({
    required pw.Font fontBold,
    required String periode,
    required String farmerName,
    required String kumbungName,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  pw.Text('Periode Laporan: ', style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700)),
                  pw.Text(periode, style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: PdfColors.black)),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Row(
                children: [
                  pw.Text('Kumbung: ', style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700)),
                  pw.Text(kumbungName, style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: PdfColors.black)),
                ],
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Row(
                children: [
                  pw.Text('Petani Pengelola: ', style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700)),
                  pw.Text(farmerName, style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: PdfColors.black)),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Row(
                children: [
                  pw.Text('Status Basis Data: ', style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700)),
                  pw.Text('Tervalidasi Cloud Neon', style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: _secondaryColor)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryCards({
    required pw.Font fontBold,
    required double totalKg,
    required int totalIncome,
    required double avgPrice,
    required String deltaText,
  }) {
    return pw.Row(
      children: [
        _buildStatCard(
          fontBold: fontBold,
          label: 'TOTAL PANEN',
          value: FormatHelper.kg(totalKg),
          subtext: deltaText,
        ),
        pw.SizedBox(width: 8),
        _buildStatCard(
          fontBold: fontBold,
          label: 'TOTAL OMZET KAS',
          value: FormatHelper.rupiah(totalIncome),
          subtext: 'Penerimaan Penjualan',
          valueColor: _primaryColor,
        ),
        pw.SizedBox(width: 8),
        _buildStatCard(
          fontBold: fontBold,
          label: 'RATA-RATA HARGA',
          value: '${FormatHelper.rupiah(avgPrice.round())} /Kg',
          subtext: 'Harga Rata-rata Pasar',
        ),
      ],
    );
  }

  static pw.Widget _buildStatCard({
    required pw.Font fontBold,
    required String label,
    required String value,
    required String subtext,
    PdfColor? valueColor,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: _lightBgColor,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: _borderGrey, width: 0.8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 14,
                color: valueColor ?? _primaryColor,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              subtext,
              style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildHarvestTable({
    required pw.Font fontBold,
    required List<HarvestEntry> entries,
    required double totalKg,
    required int totalIncome,
  }) {
    if (entries.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(20),
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _borderGrey),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Text(
          'Belum ada transaksi panen yang tercatat pada periode ini.',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
        ),
      );
    }

    final headers = ['No', 'Waktu Petik', 'Bobot (Kg)', 'Harga /Kg', 'Total Kas', 'Catatan'];

    return pw.Table(
      border: pw.TableBorder.all(color: _borderGrey, width: 0.6),
      columnWidths: {
        0: const pw.FixedColumnWidth(28),
        1: const pw.FlexColumnWidth(2.2),
        2: const pw.FlexColumnWidth(1.2),
        3: const pw.FlexColumnWidth(1.4),
        4: const pw.FlexColumnWidth(1.6),
        5: const pw.FlexColumnWidth(2.0),
      },
      children: [
        // Header
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _primaryColor),
          children: headers.map((h) {
            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: pw.Text(
                h,
                textAlign: (h == 'No' || h == 'Waktu Petik' || h == 'Catatan')
                    ? pw.TextAlign.left
                    : pw.TextAlign.right,
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 8.5,
                  color: PdfColors.white,
                ),
              ),
            );
          }).toList(),
        ),
        // Data Rows
        ...entries.asMap().entries.map((item) {
          final index = item.key + 1;
          final entry = item.value;
          final isEven = item.key % 2 == 0;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: isEven ? PdfColors.white : _lightBgColor,
            ),
            children: [
              _cell('${index}', align: pw.TextAlign.center),
              _cell(entry.date),
              _cell(FormatHelper.kg(entry.weightKg), align: pw.TextAlign.right),
              _cell(FormatHelper.rupiah(entry.pricePerKg), align: pw.TextAlign.right),
              _cell(FormatHelper.rupiah(entry.grossIncome), fontBold: fontBold, align: pw.TextAlign.right),
              _cell(entry.note ?? '-'),
            ],
          );
        }),
        // Total Footer Row
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _cell(''),
            _cell('TOTAL AKUMULASI', fontBold: fontBold),
            _cell(FormatHelper.kg(totalKg), fontBold: fontBold, align: pw.TextAlign.right),
            _cell(''),
            _cell(FormatHelper.rupiah(totalIncome), fontBold: fontBold, align: pw.TextAlign.right),
            _cell(''),
          ],
        ),
      ],
    );
  }

  static pw.Widget _cell(
    String text, {
    pw.Font? fontBold,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          font: fontBold,
          fontSize: 8.5,
          color: PdfColors.black,
        ),
      ),
    );
  }

  static pw.Widget _buildSignatureSection(pw.Font fontBold, String farmerName) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text('Petani Pengelola Kumbung,', style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 45),
            pw.Text('( $farmerName )', style: pw.TextStyle(font: fontBold, fontSize: 9.5)),
            pw.SizedBox(height: 2),
            pw.Text('ID: PETANI-001', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text('Mengetahui,\nKetua Unit BUMDes Margomulyo,', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 38),
            pw.Text('( Drs. H. Subagyo )', style: pw.TextStyle(font: fontBold, fontSize: 9.5)),
            pw.SizedBox(height: 2),
            pw.Text('NIP: 19750812.BUMD.01', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          ],
        ),
      ],
    );
  }
}
