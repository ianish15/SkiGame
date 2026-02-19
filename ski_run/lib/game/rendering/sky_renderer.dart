import 'dart:ui';
import 'package:flutter/painting.dart' show Alignment, LinearGradient;
import '../../config/colors.dart';
import '../../config/constants.dart';

class SkyRenderer {
  final Paint _paint = Paint();

  void render(Canvas canvas, double w, double h) {
    final horizY = h * horizon;

    // Sky gradient
    final skyRect = Rect.fromLTWH(0, 0, w, horizY + 1);
    _paint.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [GameColors.skyTop, GameColors.skyMid, GameColors.skyBottom],
      stops: [0.0, 0.5, 1.0],
    ).createShader(skyRect);
    canvas.drawRect(skyRect, _paint);
    _paint.shader = null;

    // Mountains
    _drawMountains(canvas, w, h);
  }

  void renderMenuSky(Canvas canvas, double w, double h) {
    final skyRect = Rect.fromLTWH(0, 0, w, h);
    _paint.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        GameColors.skyTop,
        GameColors.skyMid,
        GameColors.skyMenuBottom,
      ],
      stops: [0.0, 0.4, 1.0],
    ).createShader(skyRect);
    canvas.drawRect(skyRect, _paint);
    _paint.shader = null;

    _drawMountains(canvas, w, h);

    // Snow ground
    final horizY = h * horizon;
    _paint.color = GameColors.skyMenuBottom;
    canvas.drawRect(Rect.fromLTWH(0, horizY, w, h - horizY), _paint);
  }

  void _drawMountains(Canvas canvas, double w, double h) {
    final horizY = h * horizon;

    // Mountain silhouette
    final mountainPath = Path()
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
    _paint.color = GameColors.mountain;
    canvas.drawPath(mountainPath, _paint);

    // Snow caps
    _paint.color = GameColors.snowCap;

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
}
