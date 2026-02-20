import '../../config/constants.dart';
import '../components/segment.dart';

class ProjectedPoint {
  final double x;
  final double y;
  final double w;
  final double scale;

  const ProjectedPoint({
    required this.x,
    required this.y,
    required this.w,
    required this.scale,
  });
}

/// Project an obstacle at (laneX, worldZ) onto screen coordinates,
/// using the same perspective and curvature model as the road renderer
/// so obstacles appear fixed on the road surface.
ProjectedPoint? project(
  double laneX,
  double worldZ,
  double cameraZ,
  double playerX,
  double screenW,
  double screenH,
  List<Segment> segments,
) {
  final relZ = worldZ - cameraZ;
  if (relZ <= 0.1) return null;
  if (relZ > drawDist) return null;

  // t: 0 = near player, 1 = far away — matches road renderer
  final t = ((relZ - 0.5) / drawDist).clamp(0.0, 1.0);
  final depth = 0.5 + t * drawDist;
  final perspective = 1 / (depth * 0.04 + 0.2);

  // Compute cumulative curve from far to this depth, matching road renderer
  // The road renderer iterates from i=roadStrips down to i=0, accumulating
  // curve at each strip. We replicate that down to the obstacle's strip.
  double cumulativeCurve = 0;
  final obsStrip = (t * roadStrips).round();
  for (int i = roadStrips; i >= obsStrip; i--) {
    final stripT = i / roadStrips;
    final segIdx = (stripT * (segments.length - 1)).floor();
    final seg = segments[segIdx.clamp(0, segments.length - 1)];
    cumulativeCurve += seg.curve * stripT * 0.3;
  }

  // Road center at this depth (same formula as road renderer)
  final centerX = screenW / 2
      - playerX * perspective * screenW * 0.5
      + cumulativeCurve * perspective * 8;

  // Obstacle offset from road center
  final sx = centerX + laneX * perspective * screenW * 0.5;

  // Screen Y matching road renderer
  final horizY = screenH * horizon;
  final roadH = screenH - horizY;
  final sy = horizY + roadH * (1 - t);

  // Use original cameraDepth/relZ formula for SIZING so obstacles aren't giant.
  // Road perspective is only used for correct positioning on the road surface.
  final sw = cameraDepth / relZ * screenW * 0.5;

  return ProjectedPoint(x: sx, y: sy, w: sw, scale: cameraDepth / relZ);
}
