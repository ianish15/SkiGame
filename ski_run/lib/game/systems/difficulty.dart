import '../../config/constants.dart';

class DifficultyState {
  double currentMaxSpeed = initialBaseSpeed;
  double trailWidth = initialTrailWidth;
  double obstacleRate = initialObstacleRate;
  double t = 0.0; // 0..1 difficulty progress

  void update(double distance) {
    t = (distance / difficultyDistance).clamp(0.0, 1.0);
    currentMaxSpeed = initialBaseSpeed + t * maxSpeedGain; // 18 -> 73
    trailWidth = initialTrailWidth - t * 0.45; // 1.0 -> 0.55
    obstacleRate = initialObstacleRate - t * (initialObstacleRate - minObstacleRate); // 35 -> 6
  }

  String get label {
    final pct = (t * 100).floor();
    if (pct < 20) return 'GREEN';
    if (pct < 45) return 'BLUE';
    if (pct < 70) return 'BLACK';
    return 'DOUBLE BLACK';
  }
}
