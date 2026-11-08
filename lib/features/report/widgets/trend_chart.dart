import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/tokens.dart';

class TrendChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final String? unit;
  final String Function(double)? valueFormatter;

  const TrendChart({
    super.key,
    required this.values,
    required this.labels,
    this.unit,
    this.valueFormatter,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 125,
      width: double.infinity,
      child: CustomPaint(
        painter: _TrendChartPainter(
          values: values,
          labels: labels,
          unit: unit,
          valueFormatter: valueFormatter,
        ),
      ),
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final String? unit;
  final String Function(double)? valueFormatter;

  _TrendChartPainter({
    required this.values,
    required this.labels,
    this.unit,
    this.valueFormatter,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    const leftPadding = 20.0;
    const rightPadding = 24.0;
    const topPadding = 22.0;
    const bottomPadding = 26.0;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    // Draw horizontal dashed grid lines
    final gridPaint = Paint()
      ..color = AppColors.textMuted.withValues(alpha: 0.15)
      ..strokeWidth = 1.0;

    for (int i = 0; i < 4; i++) {
      final y = topPadding + (chartHeight / 3) * i;
      _drawDashedLine(
        canvas,
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );
    }

    // Dynamic min and max for scaling
    double minVal = values.reduce((a, b) => a < b ? a : b);
    double maxVal = values.reduce((a, b) => a > b ? a : b);
    if (minVal == maxVal) {
      minVal = (minVal * 0.8).clamp(0.0, double.infinity);
      maxVal = maxVal > 0 ? maxVal * 1.2 : 10.0;
    }
    final range = maxVal - minVal;
    final minY = (minVal - range * 0.25).clamp(0.0, double.infinity);
    final maxY = maxVal + range * 0.25;

    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? leftPadding + chartWidth / 2
          : leftPadding + (chartWidth / (values.length - 1)) * i;
      final normalizedY = (maxY == minY) ? 0.5 : (values[i] - minY) / (maxY - minY);
      final y = topPadding + chartHeight * (1.0 - normalizedY);
      points.add(Offset(x, y));
    }

    // Fill gradient path under the curve
    final path = Path();
    path.moveTo(points.first.dx, size.height - bottomPadding);
    path.lineTo(points.first.dx, points.first.dy);

    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    path.lineTo(points.last.dx, size.height - bottomPadding);
    path.close();

    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.primary600.withValues(alpha: 0.28),
          AppColors.primary400.withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, topPadding, size.width, chartHeight));

    canvas.drawPath(path, gradientPaint);

    // Line stroke path
    final linePaint = Paint()
      ..color = AppColors.primary600
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final linePath = Path();
    linePath.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(linePath, linePaint);

    // Cari titik tertinggi
    int maxIndex = 0;
    for (int i = 1; i < values.length; i++) {
      if (values[i] >= values[maxIndex]) maxIndex = i;
    }

    // Gambar titik dan label
    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      final isLast = i == points.length - 1;
      final isMax = i == maxIndex;
      final isHighlighted = isLast || (isMax && values.length <= 7);

      // Gambar titik lingkaran
      final dotBgPaint = Paint()
        ..color = isHighlighted ? AppColors.primary800 : AppColors.surface
        ..style = PaintingStyle.fill;
      final dotBorderPaint = Paint()
        ..color = isHighlighted ? AppColors.primary400 : AppColors.primary600
        ..strokeWidth = isHighlighted ? 2.8 : 2.2
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(pt, isHighlighted ? 5.5 : 4.0, dotBgPaint);
      canvas.drawCircle(pt, isHighlighted ? 5.5 : 4.0, dotBorderPaint);

      // Label nilai di atas titik
      if (isHighlighted && values[i] > 0) {
        final valText = valueFormatter != null
            ? valueFormatter!(values[i])
            : (unit != null
                ? '${values[i].toStringAsFixed(1).replaceAll('.', ',')} $unit'
                : values[i].toStringAsFixed(1).replaceAll('.', ','));

        final valSpan = TextSpan(
          text: valText,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: AppColors.primary800,
          ),
        );
        final valPainter = TextPainter(
          text: valSpan,
          textDirection: TextDirection.ltr,
        )..layout();

        final labelX = (pt.dx - (valPainter.width / 2))
            .clamp(4.0, size.width - valPainter.width - 4.0);
        valPainter.paint(canvas, Offset(labelX, pt.dy - 17));
      }

      // Label sumbu X di bagian bawah
      if (i < labels.length) {
        final labelText = labels[i];
        final textSpan = TextSpan(
          text: labelText,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10.5,
            fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w500,
            color: isHighlighted ? AppColors.primary800 : AppColors.textSecondary,
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout();

        final labelX = (pt.dx - (textPainter.width / 2))
            .clamp(2.0, size.width - textPainter.width - 2.0);
        textPainter.paint(
          canvas,
          Offset(labelX, size.height - bottomPadding + 6),
        );
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    double startX = p1.dx;
    while (startX < p2.dx) {
      canvas.drawLine(
        Offset(startX, p1.dy),
        Offset((startX + dashWidth).clamp(p1.dx, p2.dx), p1.dy),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.labels != labels;
  }
}
