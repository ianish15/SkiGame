import '../components/obstacle.dart';

class CollisionResult {
  final bool hit;
  final bool isGate;
  final Obstacle? obstacle;

  const CollisionResult({
    this.hit = false,
    this.isGate = false,
    this.obstacle,
  });
}

CollisionResult checkCollisions(
  List<Obstacle> obstacles,
  double playerX,
  double distance,
) {
  for (final ob in obstacles) {
    final relZ = ob.z - distance;
    if (relZ > 0 && relZ < 3) {
      final dx = (playerX - ob.lane).abs();
      if (ob.type == ObstacleType.gate) {
        if (!ob.passed && dx < ob.hitRadius) {
          return CollisionResult(hit: true, isGate: true, obstacle: ob);
        }
      } else {
        if (dx < ob.hitRadius) {
          return CollisionResult(hit: true, isGate: false, obstacle: ob);
        }
      }
    }
  }
  return const CollisionResult();
}
