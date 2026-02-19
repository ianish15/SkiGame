import 'dart:math';
import 'dart:ui';

class Snowflake {
  double x;
  double y;
  double r;
  double vx;
  double vy;
  double opacity;

  Snowflake({
    required this.x,
    required this.y,
    required this.r,
    required this.vx,
    required this.vy,
    required this.opacity,
  });
}

class Particle {
  double x;
  double y;
  double vx;
  double vy;
  double life;
  double maxLife;
  double r;

  Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.maxLife,
    required this.r,
  });

  bool get isDead => life <= 0;
}

class ParticleSystem {
  final List<Snowflake> snowflakes = [];
  final List<Particle> particles = [];
  final Paint _paint = Paint();
  final Random _rng = Random();

  void initSnowflakes(double w, double h) {
    snowflakes.clear();
    for (int i = 0; i < 80; i++) {
      snowflakes.add(Snowflake(
        x: _rng.nextDouble() * w,
        y: _rng.nextDouble() * h,
        r: _rng.nextDouble() * 2.5 + 0.5,
        vx: _rng.nextDouble() * 0.4 - 0.2,
        vy: _rng.nextDouble() * 1.2 + 0.4,
        opacity: _rng.nextDouble() * 0.5 + 0.2,
      ));
    }
  }

  void updateSnowflakes(double dt, double w, double h, double curvature, double speed) {
    for (final s in snowflakes) {
      s.x += (s.vx + curvature * speed * 0.3) * dt * 60;
      s.y += s.vy * dt * 60;
      if (s.y > h) {
        s.y = -2;
        s.x = _rng.nextDouble() * w;
      }
      if (s.x < 0) s.x = w;
      if (s.x > w) s.x = 0;
    }
  }

  void drawSnowflakes(Canvas canvas) {
    for (final s in snowflakes) {
      _paint.color = Color.fromRGBO(255, 255, 255, s.opacity);
      canvas.drawCircle(Offset(s.x, s.y), s.r, _paint);
    }
  }

  void spawnSpray(double screenX, double screenY, double dir) {
    for (int i = 0; i < 5; i++) {
      final life = 0.25 + _rng.nextDouble() * 0.35;
      final speed = 1.5 + _rng.nextDouble() * 3;
      final angle = (_rng.nextDouble() - 0.5) * 0.8;
      particles.add(Particle(
        x: screenX + (_rng.nextDouble() - 0.5) * 12,
        y: screenY + _rng.nextDouble() * 4,
        vx: cos(angle) * speed + dir * 2.5,
        vy: -(sin(angle).abs() * speed + 1),
        life: life,
        maxLife: life,
        r: _rng.nextDouble() * 3.5 + 1.5,
      ));
    }
  }

  void spawnCrash(double screenX, double screenY) {
    for (int i = 0; i < 35; i++) {
      final a = _rng.nextDouble() * pi * 2;
      final sp = _rng.nextDouble() * 6 + 2;
      final life = 0.6 + _rng.nextDouble() * 0.5;
      particles.add(Particle(
        x: screenX,
        y: screenY,
        vx: cos(a) * sp,
        vy: sin(a) * sp - 3,
        life: life,
        maxLife: life,
        r: _rng.nextDouble() * 3.5 + 1,
      ));
    }
  }

  void updateParticles(double dt) {
    for (int i = particles.length - 1; i >= 0; i--) {
      final p = particles[i];
      p.x += p.vx * dt * 60;
      p.y += p.vy * dt * 60;
      p.vy += 4 * dt * 60; // gravity
      p.life -= dt;
      if (p.isDead) {
        particles.removeAt(i);
      }
    }
  }

  void drawParticles(Canvas canvas) {
    for (final p in particles) {
      final a = max(0.0, p.life / p.maxLife);
      _paint.color = Color.fromRGBO(255, 255, 255, a * 0.9);
      canvas.drawCircle(Offset(p.x, p.y), p.r, _paint);
    }
  }

  /// Draw a translucent mist cloud at the spray origin for a richer spray look.
  void drawSprayMist(Canvas canvas, double x, double y, double dir, double speed) {
    if (speed <= 5) return;
    final intensity = ((speed - 5) / 60).clamp(0.0, 1.0);
    final a = intensity * 0.15;
    _paint.color = Color.fromRGBO(255, 255, 255, a);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x + dir * 8, y - 5),
        width: 35 + intensity * 25,
        height: 16 + intensity * 8,
      ),
      _paint,
    );
    // Smaller secondary puff
    _paint.color = Color.fromRGBO(255, 255, 255, a * 0.6);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x + dir * 20, y - 10),
        width: 20 + intensity * 15,
        height: 10 + intensity * 5,
      ),
      _paint,
    );
  }

  void clearParticles() {
    particles.clear();
  }
}
