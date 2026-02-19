import '../../config/constants.dart';

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

ProjectedPoint? project(
  double laneX,
  double worldZ,
  double cameraZ,
  double camX,
  double screenW,
  double screenH,
) {
  final relZ = worldZ - cameraZ;
  if (relZ <= 0.1) return null;

  final scale = cameraDepth / relZ;
  final sx = screenW / 2 + (laneX - camX) * scale * screenW * 0.5;
  final sy = screenH * horizon - (cameraHeight * scale * screenH * 0.3);
  final sw = scale * screenW * 0.5;

  return ProjectedPoint(x: sx, y: sy, w: sw, scale: scale);
}
