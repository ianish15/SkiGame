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

    // ── Skis ──
    final leftBaseX = bx - skiSpread;
    final rightBaseX = bx + skiSpread;
    final leftTipX = bx - skiSpread - tilt * 20;
    final rightTipX = bx + skiSpread - tilt * 20;

    // Ski base (dark underside edge)
    _strokePaint.color = const Color(0xFF1A1A1A);
    _strokePaint.strokeWidth = 5.5;
    _strokePaint.strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(leftBaseX, by + 10),
      Offset(leftTipX, by - skiLen),
      _strokePaint,
    );
    canvas.drawLine(
      Offset(rightBaseX, by + 10),
      Offset(rightTipX, by - skiLen),
      _strokePaint,
    );

    // Ski top surface — racing red with gradient look
    _strokePaint.color = const Color(0xFFE53935);
    _strokePaint.strokeWidth = 4.0;
    _strokePaint.strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(leftBaseX, by + 10),
      Offset(leftTipX, by - skiLen),
      _strokePaint,
    );
    canvas.drawLine(
      Offset(rightBaseX, by + 10),
      Offset(rightTipX, by - skiLen),
      _strokePaint,
    );

    // Ski highlight stripe (center line)
    _strokePaint.color = const Color(0xFFFF8A80);
    _strokePaint.strokeWidth = 1.5;
    canvas.drawLine(
      Offset(leftBaseX, by + 8),
      Offset(leftTipX, by - skiLen + 2),
      _strokePaint,
    );
    canvas.drawLine(
      Offset(rightBaseX, by + 8),
      Offset(rightTipX, by - skiLen + 2),
      _strokePaint,
    );

    // Ski edge highlight (metallic edge)
    _strokePaint.color = const Color(0xFFBDBDBD);
    _strokePaint.strokeWidth = 0.8;
    canvas.drawLine(
      Offset(leftBaseX - 2.2, by + 10),
      Offset(leftTipX - 2.2, by - skiLen),
      _strokePaint,
    );
    canvas.drawLine(
      Offset(rightBaseX + 2.2, by + 10),
      Offset(rightTipX + 2.2, by - skiLen),
      _strokePaint,
    );

    // Curved ski tips
    _strokePaint.color = const Color(0xFFE53935);
    _strokePaint.strokeWidth = 4.0;
    final leftTip = Path()
      ..moveTo(leftTipX, by - skiLen)
      ..quadraticBezierTo(
          leftTipX - 1, by - skiLen - 12, leftTipX + 5, by - skiLen - 16);
    canvas.drawPath(leftTip, _strokePaint);
    final rightTip = Path()
      ..moveTo(rightTipX, by - skiLen)
      ..quadraticBezierTo(
          rightTipX - 1, by - skiLen - 12, rightTipX + 5, by - skiLen - 16);
    canvas.drawPath(rightTip, _strokePaint);

    // Tip highlight
    _strokePaint.color = const Color(0xFFFF8A80);
    _strokePaint.strokeWidth = 1.2;
    canvas.drawPath(leftTip, _strokePaint);
    canvas.drawPath(rightTip, _strokePaint);

    // Bindings (small rectangles on each ski)
    _paint.color = const Color(0xFF333333);
    final bindY = by - skiLen * 0.35;
    // Left binding
    canvas.save();
    canvas.translate(leftBaseX + (leftTipX - leftBaseX) * 0.35, bindY);
    canvas.rotate(tilt * -0.15);
    canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: 8, height: 5), _paint);
    _paint.color = const Color(0xFF666666);
    canvas.drawRect(
        Rect.fromCenter(center: Offset(0, -1), width: 6, height: 2), _paint);
    canvas.restore();
    // Right binding
    _paint.color = const Color(0xFF333333);
    canvas.save();
    canvas.translate(rightBaseX + (rightTipX - rightBaseX) * 0.35, bindY);
    canvas.rotate(tilt * -0.15);
    canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: 8, height: 5), _paint);
    _paint.color = const Color(0xFF666666);
    canvas.drawRect(
        Rect.fromCenter(center: Offset(0, -1), width: 6, height: 2), _paint);
    canvas.restore();

    // Ski tails (flat end caps)
    _paint.color = const Color(0xFF1A1A1A);
    canvas.drawRect(
        Rect.fromCenter(
            center: Offset(leftBaseX, by + 11), width: 5.5, height: 3),
        _paint);
    canvas.drawRect(
        Rect.fromCenter(
            center: Offset(rightBaseX, by + 11), width: 5.5, height: 3),
        _paint);

    // ── Poles ──
    // Carbon fiber look: dark shaft with subtle metallic sheen
    final poleShaftColor = const Color(0xFF2C2C2C);
    final poleSheenColor = const Color(0xFF555555);

    if (turnDir == -1) {
      // Left pole planted
      _drawPole(canvas, bx - 40, by - 30, bx - 80, by - skiLen - 30,
          poleShaftColor, poleSheenColor, planted: true);
      // Right pole up
      _drawPole(canvas, bx + 40, by - 30, bx + 55, by - skiLen - 10,
          poleShaftColor, poleSheenColor, planted: false);
    } else if (turnDir == 1) {
      // Right pole planted
      _drawPole(canvas, bx + 40, by - 30, bx + 80, by - skiLen - 30,
          poleShaftColor, poleSheenColor, planted: true);
      // Left pole up
      _drawPole(canvas, bx - 40, by - 30, bx - 55, by - skiLen - 10,
          poleShaftColor, poleSheenColor, planted: false);
    } else {
      // Both poles neutral
      _drawPole(canvas, bx - 40, by - 25, bx - 50, by - skiLen - 5,
          poleShaftColor, poleSheenColor, planted: false);
      _drawPole(canvas, bx + 40, by - 25, bx + 50, by - skiLen - 5,
          poleShaftColor, poleSheenColor, planted: false);
    }

    // Gloves
    _paint.color = GameColors.glove;
    canvas.save();
    canvas.translate(bx - 40, by - 25);
    canvas.rotate(-0.3);
    canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 14, height: 10), _paint);
    // Glove cuff
    _paint.color = const Color(0xFF1A1A1A);
    canvas.drawRect(
        Rect.fromCenter(center: Offset(0, 5), width: 12, height: 3), _paint);
    canvas.restore();

    canvas.save();
    canvas.translate(bx + 40, by - 25);
    canvas.rotate(0.3);
    canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 14, height: 10), _paint);
    _paint.color = const Color(0xFF1A1A1A);
    canvas.drawRect(
        Rect.fromCenter(center: Offset(0, 5), width: 12, height: 3), _paint);
    canvas.restore();
  }

  void _drawPole(
    Canvas canvas,
    double gripX,
    double gripY,
    double tipX,
    double tipY,
    Color shaftColor,
    Color sheenColor, {
    required bool planted,
  }) {
    // Pole shaft — dark carbon
    _strokePaint.color = shaftColor;
    _strokePaint.strokeWidth = 2.5;
    _strokePaint.strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(gripX, gripY), Offset(tipX, tipY), _strokePaint);

    // Metallic sheen (highlight line offset slightly)
    _strokePaint.color = sheenColor;
    _strokePaint.strokeWidth = 0.8;
    canvas.drawLine(
        Offset(gripX + 0.8, gripY), Offset(tipX + 0.8, tipY), _strokePaint);

    // Basket (ring near tip)
    final basketX = tipX + (gripX - tipX) * 0.08;
    final basketY = tipY + (gripY - tipY) * 0.08;
    _strokePaint.color = const Color(0xFF444444);
    _strokePaint.strokeWidth = 1.5;
    canvas.drawCircle(Offset(basketX, basketY), 5, _strokePaint);
    // Basket fill
    _paint.color = const Color(0x33FFFFFF);
    canvas.drawCircle(Offset(basketX, basketY), 4.5, _paint);

    // Pole tip (metallic point)
    _paint.color = const Color(0xFFAAAAAA);
    canvas.drawCircle(Offset(tipX, tipY), 1.8, _paint);

    // Grip (rubber handle at top)
    _paint.color = const Color(0xFF111111);
    canvas.save();
    final angle =
        (tipY - gripY) != 0 ? (tipX - gripX) / (tipY - gripY) * -0.5 : 0.0;
    canvas.translate(gripX, gripY);
    canvas.rotate(angle);
    canvas.drawRect(
        Rect.fromCenter(center: Offset(0, -6), width: 4, height: 12), _paint);
    // Grip strap loop
    _strokePaint.color = const Color(0xFF333333);
    _strokePaint.strokeWidth = 1.0;
    canvas.drawOval(
        Rect.fromCenter(center: Offset(0, -12), width: 8, height: 5),
        _strokePaint);
    canvas.restore();

    // Snow spray when planted
    if (planted) {
      _paint.color = const Color(0x40FFFFFF);
      canvas.drawCircle(Offset(tipX, tipY + 2), 4, _paint);
      _paint.color = const Color(0x20FFFFFF);
      canvas.drawCircle(Offset(tipX, tipY + 1), 7, _paint);
    }
  }
}
