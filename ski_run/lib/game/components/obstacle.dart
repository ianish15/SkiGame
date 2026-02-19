import 'dart:math';

enum ObstacleType { tree, rock, snowman, gate }

class Obstacle {
  final ObstacleType type;
  final double lane;
  final double z;
  final double hitRadius;
  bool passed;

  Obstacle({
    required this.type,
    required this.lane,
    required this.z,
    required this.hitRadius,
    this.passed = false,
  });

  static final _rng = Random();

  static Obstacle spawn(double z) {
    final r = _rng.nextDouble();
    ObstacleType type;
    double lane;

    if (r < 0.45) {
      type = ObstacleType.tree;
      final edgeBias = _rng.nextDouble();
      if (edgeBias < 0.35) {
        lane = (_rng.nextBool() ? -1.0 : 1.0) * (0.5 + _rng.nextDouble() * 0.8);
      } else {
        lane = (_rng.nextDouble() - 0.5) * 1.8;
      }
    } else if (r < 0.7) {
      type = ObstacleType.rock;
      lane = (_rng.nextDouble() - 0.5) * 1.4;
    } else if (r < 0.85) {
      type = ObstacleType.snowman;
      lane = (_rng.nextDouble() - 0.5) * 1.2;
    } else {
      type = ObstacleType.gate;
      lane = (_rng.nextDouble() - 0.5) * 0.8;
    }

    return Obstacle(
      type: type,
      lane: lane,
      z: z,
      hitRadius: type == ObstacleType.gate ? 0.35 : 0.12,
    );
  }
}
