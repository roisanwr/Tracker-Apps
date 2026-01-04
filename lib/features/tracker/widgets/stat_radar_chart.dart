import 'dart:math';
import 'package:flutter/material.dart';

class StatRadarChart extends StatelessWidget {
  final Map<String, double>
      data; // Key: Nama Stat, Value: 0.0 - 1.0 (Persentase)
  final Color baseColor;
  final Color activeColor;

  const StatRadarChart({
    super.key,
    required this.data,
    this.baseColor = Colors.grey,
    this.activeColor = const Color(0xFF00E676), // Cyberpunk Green
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(200, 200),
      painter: _RadarChartPainter(data, baseColor, activeColor),
    );
  }
}

class _RadarChartPainter extends CustomPainter {
  final Map<String, double> data;
  final Color baseColor;
  final Color activeColor;

  _RadarChartPainter(this.data, this.baseColor, this.activeColor);

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = min(centerX, centerY) * 0.8; // Padding dikit

    final paintLine = Paint()
      ..color = baseColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final paintFill = Paint()
      ..color = activeColor.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    final paintBorder = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final keys = data.keys.toList();
    final values = data.values.toList();
    final int sides = keys.length;
    final double angleStep = (2 * pi) / sides;

    // 1. GAMBAR JARING LABA-LABA (Background Grid)
    // Kita buat 4 layer jaring (25%, 50%, 75%, 100%)
    for (int i = 1; i <= 4; i++) {
      double currentRadius = radius * (i / 4);
      Path gridPath = Path();
      for (int j = 0; j < sides; j++) {
        double angle = (j * angleStep) - (pi / 2); // Mulai dari atas (jam 12)
        double x = centerX + currentRadius * cos(angle);
        double y = centerY + currentRadius * sin(angle);
        if (j == 0) {
          gridPath.moveTo(x, y);
        } else {
          gridPath.lineTo(x, y);
        }
      }
      gridPath.close();
      canvas.drawPath(gridPath, paintLine);
    }

    // 2. GAMBAR GARIS DARI TENGAH KE SUDUT
    for (int j = 0; j < sides; j++) {
      double angle = (j * angleStep) - (pi / 2);
      double x = centerX + radius * cos(angle);
      double y = centerY + radius * sin(angle);
      canvas.drawLine(Offset(centerX, centerY), Offset(x, y), paintLine);

      // Gambar Label Teks (STR, INT, dll)
      _drawText(canvas, keys[j], x, y, centerX, centerY);
    }

    // 3. GAMBAR DATA USER (Area Berwarna)
    Path dataPath = Path();
    for (int j = 0; j < sides; j++) {
      double value = values[j]; // 0.0 sampai 1.0
      double angle = (j * angleStep) - (pi / 2);
      double x = centerX + (radius * value) * cos(angle);
      double y = centerY + (radius * value) * sin(angle);

      if (j == 0) {
        dataPath.moveTo(x, y);
      } else {
        dataPath.lineTo(x, y);
      }
    }
    dataPath.close();

    canvas.drawPath(dataPath, paintFill);
    canvas.drawPath(dataPath, paintBorder);
  }

  void _drawText(
      Canvas canvas, String text, double x, double y, double cx, double cy) {
    final textSpan = TextSpan(
      text: text,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(minWidth: 0, maxWidth: 100);

    // Offset sedikit biar gak nempel garis
    double offsetX = 0;
    double offsetY = 0;
    if (x < cx) offsetX = -20; // Kiri
    if (x > cx) offsetX = 5; // Kanan
    if (y < cy) offsetY = -15; // Atas
    if (y > cy) offsetY = 5; // Bawah

    textPainter.paint(
        canvas, Offset(x + offsetX - (textPainter.width / 2), y + offsetY));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
