import 'dart:math';
import 'dart:ui';
import 'package:flutter/painting.dart' show Alignment, LinearGradient;
import '../../config/colors.dart';
import '../../config/constants.dart';

class SkyRenderer {
  final Paint _paint = Paint();

  /// Interpolate colors across three distance zones:
  ///   0–5000  morning
  ///   5000–10000  afternoon
  ///   10000–15000  sunset
  Color _lerpZone(double distance, Color morning, Color afternoon, Color sunset) {
    if (distance < 5000) {
      return morning;
    } else if (distance < 10000) {
      final t = (distance - 5000) / 5000;
      return Color.lerp(morning, afternoon, t)!;
    } else {
      final t = ((distance - 10000) / 5000).clamp(0.0, 1.0);
      return Color.lerp(afternoon, sunset, t)!;
    }
  }

  // ── In-game sky ──

  void render(Canvas canvas, double w, double h, {double distance = 0}) {
    final horizY = h * horizon;

    // Progressive sky gradient
    final skyTopColor = _lerpZone(
      distance,
      const Color(0xFF6BB3D9),
      const Color(0xFF5A9EC4),
      const Color(0xFF2D1B4E),
    );
    final skyMidColor = _lerpZone(
      distance,
      const Color(0xFF9DCCEA),
      const Color(0xFFB8A080),
      const Color(0xFFD4624A),
    );
    final skyBottomColor = _lerpZone(
      distance,
      const Color(0xFFD4E8F5),
      const Color(0xFFE8D0B0),
      const Color(0xFFF0A060),
    );

    final skyRect = Rect.fromLTWH(0, 0, w, horizY + 1);
    _paint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [skyTopColor, skyMidColor, skyBottomColor],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(skyRect);
    canvas.drawRect(skyRect, _paint);
    _paint.shader = null;

    _drawSun(canvas, w, horizY, distance);
    _drawClouds(canvas, w, horizY, distance);
    _drawBackMountains(canvas, w, horizY, distance);
    _drawFrontMountains(canvas, w, horizY, distance);
    _drawTreeLine(canvas, w, horizY, distance);
  }

  // ── Menu sky ──

  void renderMenuSky(Canvas canvas, double w, double h) {
    final horizY = h * horizon;

    final skyRect = Rect.fromLTWH(0, 0, w, h);
    _paint.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [GameColors.skyTop, GameColors.skyMid, GameColors.skyMenuBottom],
      stops: [0.0, 0.4, 1.0],
    ).createShader(skyRect);
    canvas.drawRect(skyRect, _paint);
    _paint.shader = null;

    // Sun
    _paint.color = const Color(0x30FFEB3B);
    canvas.drawCircle(Offset(w * 0.75, horizY * 0.3), 60, _paint);
    _paint.color = const Color(0xCCFFF9C4);
    canvas.drawCircle(Offset(w * 0.75, horizY * 0.3), 20, _paint);
    _paint.color = const Color(0x80FFFFFF);
    canvas.drawCircle(Offset(w * 0.75, horizY * 0.3), 12, _paint);

    // Clouds
    _paint.color = const Color(0x4DFFFFFF);
    _drawCloud(canvas, w * 0.2, horizY * 0.25, 45, 15);
    _drawCloud(canvas, w * 0.6, horizY * 0.15, 55, 18);

    _drawBackMountains(canvas, w, horizY, 0);
    _drawFrontMountains(canvas, w, horizY, 0);
    _drawTreeLine(canvas, w, horizY, 0);

    // Snow ground
    _paint.color = GameColors.skyMenuBottom;
    canvas.drawRect(Rect.fromLTWH(0, horizY, w, h - horizY), _paint);
  }

  // ── Sun ──

  void _drawSun(Canvas canvas, double w, double horizY, double distance) {
    final progress = (distance / 15000).clamp(0.0, 1.0);
    final sunX = w * (0.75 - progress * 0.5);
    final sunY = horizY * (0.2 + progress * 0.5);
    final sunR = 20.0 + progress * 10;

    // Outer glow
    _paint.color = _lerpZone(
      distance,
      const Color(0x30FFEB3B),
      const Color(0x40FF9800),
      const Color(0x50FF5722),
    );
    canvas.drawCircle(Offset(sunX, sunY), sunR * 3, _paint);

    // Body
    _paint.color = _lerpZone(
      distance,
      const Color(0xCCFFF9C4),
      const Color(0xCCFFE082),
      const Color(0xCCFF8A65),
    );
    canvas.drawCircle(Offset(sunX, sunY), sunR, _paint);

    // Core
    _paint.color = const Color(0x80FFFFFF);
    canvas.drawCircle(Offset(sunX, sunY), sunR * 0.6, _paint);
  }

  // ── Clouds ──

  void _drawClouds(Canvas canvas, double w, double horizY, double distance) {
    final opacity = (0.3 + (distance / 15000) * 0.3).clamp(0.0, 0.6);
    _paint.color = Color.fromRGBO(255, 255, 255, opacity);

    _drawCloud(canvas, w * 0.15, horizY * 0.25, 40, 15);
    _drawCloud(canvas, w * 0.55, horizY * 0.15, 55, 18);
    _drawCloud(canvas, w * 0.85, horizY * 0.35, 35, 12);

    if (distance > 3000) {
      _drawCloud(canvas, w * 0.35, horizY * 0.3, 45, 14);
    }
    if (distance > 8000) {
      _drawCloud(canvas, w * 0.7, horizY * 0.2, 50, 16);
    }
  }

  void _drawCloud(Canvas canvas, double x, double y, double cw, double ch) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, y), width: cw, height: ch),
      _paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x - cw * 0.3, y + 2),
        width: cw * 0.6,
        height: ch * 0.8,
      ),
      _paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x + cw * 0.3, y + 1),
        width: cw * 0.7,
        height: ch * 0.7,
      ),
      _paint,
    );
  }

  // ── Back mountain range ──

  void _drawBackMountains(Canvas canvas, double w, double horizY, double distance) {
    _paint.color = _lerpZone(
      distance,
      const Color(0xFFBFD0DD),
      const Color(0xFFC8B8A0),
      const Color(0xFF7A6080),
    );

    final path = Path()
      ..moveTo(0, horizY)
      ..lineTo(w * 0.05, horizY - 80)
      ..lineTo(w * 0.15, horizY - 45)
      ..lineTo(w * 0.25, horizY - 95)
      ..lineTo(w * 0.4, horizY - 55)
      ..lineTo(w * 0.55, horizY - 100)
      ..lineTo(w * 0.7, horizY - 50)
      ..lineTo(w * 0.8, horizY - 85)
      ..lineTo(w * 0.95, horizY - 40)
      ..lineTo(w, horizY - 60)
      ..lineTo(w, horizY)
      ..close();
    canvas.drawPath(path, _paint);

    // Snow caps
    _paint.color = _lerpZone(
      distance,
      const Color(0xFFE8F0F8),
      const Color(0xFFE0D8C8),
      const Color(0xFFA090A0),
    );
    _drawSnowCap(canvas, w * 0.25, horizY - 95, 18);
    _drawSnowCap(canvas, w * 0.55, horizY - 100, 20);
    _drawSnowCap(canvas, w * 0.8, horizY - 85, 16);
  }

  void _drawSnowCap(Canvas canvas, double px, double py, double sz) {
    final cap = Path()
      ..moveTo(px, py)
      ..lineTo(px - sz * 0.7, py + sz)
      ..lineTo(px + sz * 0.7, py + sz)
      ..close();
    canvas.drawPath(cap, _paint);
  }

  // ── Front mountain range ──

  void _drawFrontMountains(Canvas canvas, double w, double horizY, double distance) {
    _paint.color = _lerpZone(
      distance,
      GameColors.mountain,
      const Color(0xFF90A898),
      const Color(0xFF605070),
    );

    final path = Path()
      ..moveTo(0, horizY)
      ..lineTo(w * 0.1, horizY - 40)
      ..lineTo(w * 0.2, horizY - 15)
      ..lineTo(w * 0.35, horizY - 65)
      ..lineTo(w * 0.5, horizY - 25)
      ..lineTo(w * 0.65, horizY - 70)
      ..lineTo(w * 0.8, horizY - 30)
      ..lineTo(w * 0.9, horizY - 50)
      ..lineTo(w, horizY - 20)
      ..lineTo(w, horizY)
      ..close();
    canvas.drawPath(path, _paint);

    // Snow caps
    _paint.color = _lerpZone(
      distance,
      GameColors.snowCap,
      const Color(0xFFD8D0C0),
      const Color(0xFF908090),
    );

    final cap1 = Path()
      ..moveTo(w * 0.35, horizY - 65)
      ..lineTo(w * 0.30, horizY - 40)
      ..lineTo(w * 0.40, horizY - 40)
      ..close();
    canvas.drawPath(cap1, _paint);

    final cap2 = Path()
      ..moveTo(w * 0.65, horizY - 70)
      ..lineTo(w * 0.60, horizY - 42)
      ..lineTo(w * 0.70, horizY - 42)
      ..close();
    canvas.drawPath(cap2, _paint);
  }

  // ── Distant tree line silhouette ──

  void _drawTreeLine(Canvas canvas, double w, double horizY, double distance) {
    _paint.color = _lerpZone(
      distance,
      const Color(0xFF4A6A50),
      const Color(0xFF506040),
      const Color(0xFF2A3030),
    );

    const treeH = 12.0;
    final path = Path()..moveTo(0, horizY);

    for (double x = 0; x <= w; x += 8) {
      final h = treeH * (0.5 + 0.5 * sin(x * 0.05 + 1.5));
      path.lineTo(x, horizY - h);
      path.lineTo(x + 4, horizY - h * 0.6);
    }

    path.lineTo(w, horizY);
    path.close();
    canvas.drawPath(path, _paint);
  }
}
