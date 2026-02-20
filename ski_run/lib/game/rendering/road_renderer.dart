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

      // Center dashes (periodic)
      if ((depth ~/ 6) % 3 == 0) {
        _paint.color = GameColors.centerDash;
        canvas.drawRect(
          Rect.fromLTWH(centerX - 1, screenY, 2, stripH),
          _paint,
        );
      }

      // Boundary trees at regular depth intervals
      final treeSpacing = 10.0;
      final depthMod = depth % treeSpacing;
      final stripDepthRange = drawDist / roadStrips;
      if (depthMod < stripDepthRange && perspective > 0.08) {
        final treeScale = perspective * 50;
        if (treeScale > 4.0) {
          _drawBoundaryTree(canvas, centerX - halfTrail - treeScale * 0.7, screenY, treeScale);
          _drawBoundaryTree(canvas, centerX + halfTrail + treeScale * 0.7, screenY, treeScale);
        }
      }
    }
  }

  void _drawBoundaryTree(Canvas canvas, double x, double y, double scale) {
    if (scale < 4.0) return;

    // Shadow
    _paint.color = const Color(0x14000000);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x, y),
        width: scale * 0.8,
        height: scale * 0.2,
      ),
      _paint,
    );

    // Trunk
    _paint.color = const Color(0xFF4A3728);
    canvas.drawRect(
      Rect.fromLTWH(x - scale * 0.06, y - scale * 0.5, scale * 0.12, scale * 0.5),
      _paint,
    );

    // Foliage — 3 layers
    const foliageColors = [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)];
    for (int i = 0; i < 3; i++) {
      _paint.color = foliageColors[i];
      final ty = y - scale * (1.1 - i * 0.25);
      final bw = scale * (0.28 + i * 0.04);
      final path = Path()
        ..moveTo(x, ty)
        ..lineTo(x - bw, ty + scale * 0.35)
        ..lineTo(x + bw, ty + scale * 0.35)
        ..close();
      canvas.drawPath(path, _paint);
    }

    // Snow cap
    _paint.color = const Color(0xCCFFFFFF);
    final snowPath = Path()
      ..moveTo(x, y - scale * 1.15)
      ..lineTo(x - scale * 0.14, y - scale * 0.95)
      ..lineTo(x + scale * 0.14, y - scale * 0.95)
      ..close();
    canvas.drawPath(snowPath, _paint);
  }
}
