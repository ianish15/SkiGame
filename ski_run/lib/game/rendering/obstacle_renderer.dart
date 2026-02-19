import 'dart:math';
import 'dart:ui';
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle;
import '../../config/colors.dart';

class ObstacleRenderer {
  final Paint _paint = Paint();
  final Paint _strokePaint = Paint()..style = PaintingStyle.stroke;

  void drawTree(Canvas canvas, double x, double y, double s) {
    final size = max(s * 0.8, 2.0);

    // Shadow
    _paint.color = const Color(0x1A000000);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x + size * 0.1, y),
        width: size * 1.0,
        height: size * 0.3,
      ),
      _paint,
    );

    // Trunk
    _paint.color = GameColors.trunk;
    canvas.drawRect(
      Rect.fromLTWH(x - size * 0.06, y - size * 0.6, size * 0.12, size * 0.6),
      _paint,
    );

    // Foliage — 3 layers
    for (int i = 0; i < 3; i++) {
      _paint.color = GameColors.foliage[i];
      final ty = y - size * (1.3 - i * 0.3);
      final bw = size * (0.35 + i * 0.05);
      final path = Path()
        ..moveTo(x, ty)
        ..lineTo(x - bw, ty + size * 0.4)
        ..lineTo(x + bw, ty + size * 0.4)
        ..close();
      canvas.drawPath(path, _paint);
    }

    // Snow on top
    _paint.color = const Color(0xFFFFFFFF);
    final snowPath = Path()
      ..moveTo(x, y - size * 1.35)
      ..lineTo(x - size * 0.18, y - size * 1.1)
      ..lineTo(x + size * 0.18, y - size * 1.1)
      ..close();
    canvas.drawPath(snowPath, _paint);
  }

  void drawRock(Canvas canvas, double x, double y, double s) {
    final size = max(s * 0.5, 2.0);

    // Shadow
    _paint.color = const Color(0x1A000000);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x, y),
        width: size * 1.0,
        height: size * 0.3,
      ),
      _paint,
    );

    // Rock body
    _paint.color = GameColors.rockBody;
    final bodyPath = Path()
      ..moveTo(x - size * 0.4, y)
      ..lineTo(x - size * 0.2, y - size * 0.45)
      ..lineTo(x + size * 0.15, y - size * 0.5)
      ..lineTo(x + size * 0.4, y - size * 0.15)
      ..lineTo(x + size * 0.35, y)
      ..close();
    canvas.drawPath(bodyPath, _paint);

    // Highlight
    _paint.color = GameColors.rockHighlight;
    final hlPath = Path()
      ..moveTo(x - size * 0.15, y - size * 0.3)
      ..lineTo(x + size * 0.1, y - size * 0.48)
      ..lineTo(x + size * 0.3, y - size * 0.15)
      ..lineTo(x + size * 0.05, y - size * 0.15)
      ..close();
    canvas.drawPath(hlPath, _paint);
  }

  void drawSnowman(Canvas canvas, double x, double y, double s) {
    final size = max(s * 0.6, 2.0);

    // Shadow
    _paint.color = const Color(0x14000000);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x, y),
        width: size * 0.7,
        height: size * 0.2,
      ),
      _paint,
    );

    // Bottom ball
    _paint.color = GameColors.snowmanBottom;
    canvas.drawCircle(Offset(x, y - size * 0.2), size * 0.3, _paint);

    // Middle ball
    _paint.color = GameColors.snowmanMid;
    canvas.drawCircle(Offset(x, y - size * 0.55), size * 0.22, _paint);

    // Head
    _paint.color = GameColors.snowmanHead;
    canvas.drawCircle(Offset(x, y - size * 0.82), size * 0.15, _paint);

    // Hat
    _paint.color = GameColors.hat;
    canvas.drawRect(
      Rect.fromLTWH(x - size * 0.12, y - size * 1.05, size * 0.24, size * 0.15),
      _paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(x - size * 0.18, y - size * 0.93, size * 0.36, size * 0.04),
      _paint,
    );

    // Eyes
    _paint.color = const Color(0xFF000000);
    canvas.drawCircle(Offset(x - size * 0.05, y - size * 0.84), size * 0.02, _paint);
    canvas.drawCircle(Offset(x + size * 0.05, y - size * 0.84), size * 0.02, _paint);

    // Carrot nose
    _paint.color = GameColors.carrot;
    final nosePath = Path()
      ..moveTo(x, y - size * 0.8)
      ..lineTo(x + size * 0.12, y - size * 0.78)
      ..lineTo(x, y - size * 0.76)
      ..close();
    canvas.drawPath(nosePath, _paint);
  }

  void drawGate(Canvas canvas, double x, double y, double s, bool passed) {
    final size = max(s * 0.8, 2.0);
    final hw = size * 0.5;
    final poleColor = passed
        ? const Color(0x664CAF50) // rgba(76,175,80,0.4)
        : GameColors.gateRed;

    // Poles
    _paint.color = poleColor;
    canvas.drawRect(
      Rect.fromLTWH(x - hw - size * 0.03, y - size * 0.9, size * 0.06, size * 0.9),
      _paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(x + hw - size * 0.03, y - size * 0.9, size * 0.06, size * 0.9),
      _paint,
    );

    // Banner
    _paint.color = passed
        ? const Color(0x334CAF50) // rgba(76,175,80,0.2)
        : const Color(0x4DF44336); // rgba(244,67,54,0.3)
    canvas.drawRect(
      Rect.fromLTWH(x - hw, y - size * 0.8, hw * 2, size * 0.15),
      _paint,
    );

    if (!passed) {
      // White stripes on poles
      _paint.color = const Color(0xFFFFFFFF);
      for (int i = 0; i < 3; i++) {
        final sy = y - size * 0.85 + i * size * 0.25;
        canvas.drawRect(
          Rect.fromLTWH(x - hw - size * 0.03, sy, size * 0.06, size * 0.08),
          _paint,
        );
        canvas.drawRect(
          Rect.fromLTWH(x + hw - size * 0.03, sy, size * 0.06, size * 0.08),
          _paint,
        );
      }
    }

    if (passed) {
      // "+200" text
      final fontSize = max(size * 0.2, 8.0);
      final tp = TextPainter(
        text: TextSpan(
          text: '+200',
          style: TextStyle(
            color: const Color(0xCC4CAF50),
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y - size * 0.95 - tp.height / 2));
    }
  }
}
