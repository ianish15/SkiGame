import 'dart:ui';
import '../../config/colors.dart';
import '../../config/constants.dart';
import '../components/segment.dart';

class RoadRenderer {
  final Paint _paint = Paint();

  void render(
    Canvas canvas,
    double w,
    double h,
    double playerX,
    double trailWidth,
    List<Segment> segments,
  ) {
    final horizY = h * horizon;
    final roadH = h - horizY;
    double cumulativeCurve = 0;

    for (int i = roadStrips; i >= 0; i--) {
      final t = i / roadStrips; // 0 = bottom (near), 1 = top (far)
      final screenY = horizY + roadH * (1 - t);
      final depth = 0.5 + t * drawDist;
      final perspective = 1 / (depth * 0.04 + 0.2);

      // Curvature offset at this depth
      final segIdx = (t * (segments.length - 1)).floor();
      final seg = segments[segIdx.clamp(0, segments.length - 1)];
      cumulativeCurve += seg.curve * t * 0.3;

      final centerX =
          w / 2 - playerX * perspective * w * 0.5 + cumulativeCurve * perspective * 8;
      final halfTrail = trailWidth * perspective * w * 0.45;
      final stripH = roadH / roadStrips + 1;

      // Off-piste snow
      final offPisteColor =
          (depth ~/ 4) % 2 == 0 ? GameColors.offPisteLight : GameColors.offPisteDark;
      _paint.color = offPisteColor;
      canvas.drawRect(Rect.fromLTWH(0, screenY, w, stripH), _paint);

      // Trail surface
      final trailColor =
          (depth ~/ 4) % 2 == 0 ? GameColors.trailLight : GameColors.trailDark;
      _paint.color = trailColor;
      canvas.drawRect(
        Rect.fromLTWH(centerX - halfTrail, screenY, halfTrail * 2, stripH),
        _paint,
      );

      // Trail edge markers
      _paint.color = GameColors.edgeMarker;
      canvas.drawRect(
        Rect.fromLTWH(centerX - halfTrail - 2, screenY, 3 * perspective + 1, stripH),
        _paint,
      );
      canvas.drawRect(
        Rect.fromLTWH(centerX + halfTrail - 1, screenY, 3 * perspective + 1, stripH),
        _paint,
      );

      // Center dashes (periodic)
      if ((depth ~/ 6) % 3 == 0) {
        _paint.color = GameColors.centerDash;
        canvas.drawRect(
          Rect.fromLTWH(centerX - 1, screenY, 2, stripH),
          _paint,
        );
      }
    }
  }
}
