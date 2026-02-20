import 'dart:math';

enum ObstacleType { tree, rock, snowman, gate }

enum GateSize { small, medium, large }

class Obstacle {
  final ObstacleType type;
  final double lane;
  final double z;
  final double hitRadius;
  final GateSize gateSize;
  final int gatePoints;
  bool passed;

  Obstacle({
    required this.type,
    required this.lane,
    required this.z,
    required this.hitRadius,
    this.gateSize = GateSize.medium,
    this.gatePoints = 0,
    this.passed = false,
  });

  static final _rng = Random();

  static Obstacle spawn(double z) {
    final r = _rng.nextDouble();
    ObstacleType type;
    double lane;
    double hitRadius;
    GateSize gateSize = GateSize.medium;
    int gatePoints = 0;

    if (r < 0.45) {
      type = ObstacleType.tree;
      final edgeBias = _rng.nextDouble();
      if (edgeBias < 0.35) {
        lane = (_rng.nextBool() ? -1.0 : 1.0) * (0.5 + _rng.nextDouble() * 0.8);
      } else {
        lane = (_rng.nextDouble() - 0.5) * 1.8;
      }
      hitRadius = 0.12;
    } else if (r < 0.7) {
      type = ObstacleType.rock;
      lane = (_rng.nextDouble() - 0.5) * 1.4;
      hitRadius = 0.12;
    } else if (r < 0.85) {
      type = ObstacleType.snowman;
      lane = (_rng.nextDouble() - 0.5) * 1.2;
      hitRadius = 0.12;
    } else {
      type = ObstacleType.gate;
      lane = (_rng.nextDouble() - 0.5) * 0.8;

      // Variable gate sizes with different point rewards
      final gr = _rng.nextDouble();
      if (gr < 0.3) {
        gateSize = GateSize.small;
        gatePoints = 500;
        hitRadius = 0.18;
      } else if (gr < 0.65) {
        gateSize = GateSize.medium;
        gatePoints = 300;
        hitRadius = 0.35;
      } else {
        gateSize = GateSize.large;
        gatePoints = 100;
        hitRadius = 0.55;
      }
    }

    return Obstacle(
      type: type,
      lane: lane,
      z: z,
      hitRadius: hitRadius,
      gateSize: gateSize,
      gatePoints: gatePoints,
    );
  }
}
