import 'dart:ui';
import '../../config/colors.dart';

class SkierRenderer {
  final Paint _paint = Paint();
  final Paint _strokePaint = Paint()..style = PaintingStyle.stroke;

  void render(Canvas canvas, double w, double h, int turnDir) {
    final bx = w / 2;
    final by = h * 0.92;

    const skiSpread = 22.0;
    const skiLen = 55.0;
    final tilt = turnDir * 0.15;

    // Skis
    _strokePaint.color = const Color(0xFF222222);
    _strokePaint.strokeWidth = 3.5;
    _strokePaint.strokeCap = StrokeCap.round;

    // Left ski
    canvas.drawLine(
      Offset(bx - skiSpread, by + 10),
      Offset(bx - skiSpread - tilt * 20, by - skiLen),
      _strokePaint,
    );

    // Right ski
    canvas.drawLine(
      Offset(bx + skiSpread, by + 10),
      Offset(bx + skiSpread - tilt * 20, by - skiLen),
      _strokePaint,
    );

    // Ski tips
    _strokePaint.strokeWidth = 2.5;
    final leftTipX = bx - skiSpread - tilt * 20;
    final rightTipX = bx + skiSpread - tilt * 20;

    final leftTip = Path()
      ..moveTo(leftTipX, by - skiLen)
      ..quadraticBezierTo(leftTipX, by - skiLen - 10, leftTipX + 4, by - skiLen - 12);
    canvas.drawPath(leftTip, _strokePaint);

    final rightTip = Path()
      ..moveTo(rightTipX, by - skiLen)
      ..quadraticBezierTo(rightTipX, by - skiLen - 10, rightTipX + 4, by - skiLen - 12);
    canvas.drawPath(rightTip, _strokePaint);

    // Poles
    _strokePaint.color = const Color(0xFF555555);
    _strokePaint.strokeWidth = 2;

    if (turnDir == -1) {
      // Left pole dug in
      canvas.drawLine(
        Offset(bx - 40, by - 30),
        Offset(bx - 80, by - skiLen - 30),
        _strokePaint,
      );
      // Right pole up
      canvas.drawLine(
        Offset(bx + 40, by - 30),
        Offset(bx + 55, by - skiLen - 10),
        _strokePaint,
      );
    } else if (turnDir == 1) {
      // Right pole dug in
      canvas.drawLine(
        Offset(bx + 40, by - 30),
        Offset(bx + 80, by - skiLen - 30),
        _strokePaint,
      );
      // Left pole up
      canvas.drawLine(
        Offset(bx - 40, by - 30),
        Offset(bx - 55, by - skiLen - 10),
        _strokePaint,
      );
    } else {
      // Both poles neutral
      canvas.drawLine(
        Offset(bx - 40, by - 25),
        Offset(bx - 50, by - skiLen - 5),
        _strokePaint,
      );
      canvas.drawLine(
        Offset(bx + 40, by - 25),
        Offset(bx + 50, by - skiLen - 5),
        _strokePaint,
      );
    }

    // Pole baskets
    _paint.color = const Color(0xFF666666);
    if (turnDir == -1) {
      canvas.drawCircle(Offset(bx - 80, by - skiLen - 30), 3, _paint);
    } else if (turnDir == 1) {
      canvas.drawCircle(Offset(bx + 80, by - skiLen - 30), 3, _paint);
    }

    // Gloves
    _paint.color = GameColors.glove;
    canvas.save();
    canvas.translate(bx - 40, by - 25);
    canvas.rotate(-0.3);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 14, height: 10), _paint);
    canvas.restore();

    canvas.save();
    canvas.translate(bx + 40, by - 25);
    canvas.rotate(0.3);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 14, height: 10), _paint);
    canvas.restore();
  }
}
