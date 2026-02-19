import 'dart:math';
import 'dart:ui';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle, FontWeight;

import '../config/colors.dart';
import '../config/constants.dart';
import 'components/player.dart';
import 'components/segment.dart';
import 'components/obstacle.dart';
import 'systems/difficulty.dart';
import 'systems/collision.dart';
import 'systems/projection.dart';
import 'rendering/sky_renderer.dart';
import 'rendering/road_renderer.dart';
import 'rendering/obstacle_renderer.dart';
import 'rendering/skier_renderer.dart';
import 'rendering/particle_renderer.dart';
import 'rendering/hud_renderer.dart';
import '../services/storage_service.dart';

enum GameState { menu, playing, dead }

class SkiGame extends FlameGame with TapDetector, PanDetector {
  // State
  GameState state = GameState.menu;
  final Player player = Player();
  final DifficultyState difficulty = DifficultyState();
  double distance = 0;
  int score = 0;
  int highScore = 0;
  double curvature = 0;
  double curveTarget = 0;
  double curveTimer = 0;
  double nextObstacleZ = initialObstacleZ;
  final List<Segment> segments = [];
  final List<Obstacle> obstacles = [];
  final Random _rng = Random();

  // Renderers
  final SkyRenderer _sky = SkyRenderer();
  final RoadRenderer _road = RoadRenderer();
  final ObstacleRenderer _obstacleRenderer = ObstacleRenderer();
  final SkierRenderer _skier = SkierRenderer();
  final ParticleSystem _particles = ParticleSystem();
  final HudRenderer _hud = HudRenderer();

  bool _snowflakesInitialized = false;

  @override
  Future<void> onLoad() async {
    highScore = await StorageService.loadHighScore();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (!_snowflakesInitialized) {
      _particles.initSnowflakes(size.x, size.y);
      _snowflakesInitialized = true;
    }
  }

  // ── Input ──

  // Track active pointer for held touches
  int? _activePointer;

  @override
  void onTapDown(TapDownInfo info) {
    final x = info.eventPosition.global.x;
    final y = info.eventPosition.global.y;

    if (state == GameState.playing) {
      final mid = size.x / 2;
      player.touchSide = x < mid ? -1 : 1;
      player.turnDir = player.touchSide;
    } else if (state == GameState.menu) {
      _handleMenuTap(x, y);
    } else if (state == GameState.dead) {
      _handleDeathTap(x, y);
    }
  }

  @override
  void onTapUp(TapUpInfo info) {
    player.turnDir = 0;
    player.touchSide = 0;
  }

  @override
  void onTapCancel() {
    player.turnDir = 0;
    player.touchSide = 0;
  }

  @override
  void onPanStart(DragStartInfo info) {
    if (state == GameState.playing) {
      final mid = size.x / 2;
      player.touchSide = info.eventPosition.global.x < mid ? -1 : 1;
      player.turnDir = player.touchSide;
    }
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    if (state == GameState.playing) {
      final mid = size.x / 2;
      final newSide = info.eventPosition.global.x < mid ? -1 : 1;
      if (newSide != player.touchSide) {
        player.touchSide = newSide;
        player.turnDir = newSide;
      }
    }
  }

  @override
  void onPanEnd(DragEndInfo info) {
    player.turnDir = 0;
    player.touchSide = 0;
  }

  @override
  void onPanCancel() {
    player.turnDir = 0;
    player.touchSide = 0;
  }

  void _handleMenuTap(double tx, double ty) {
    final w = size.x;
    final h = size.y;
    final btnW = 200.0;
    final btnH = 58.0;
    final btnY = h * 0.48;

    if (tx > w / 2 - btnW / 2 &&
        tx < w / 2 + btnW / 2 &&
        ty > btnY &&
        ty < btnY + btnH) {
      startRun();
    }
  }

  void _handleDeathTap(double tx, double ty) {
    final w = size.x;
    final h = size.y;
    final btnW = 180.0;
    final btnH = 54.0;
    final btnY = h * 0.58;
    final btn2Y = btnY + 68;

    if (tx > w / 2 - btnW / 2 && tx < w / 2 + btnW / 2) {
      if (ty > btnY && ty < btnY + btnH) {
        startRun();
      } else if (ty > btn2Y && ty < btn2Y + btnH) {
        state = GameState.menu;
      }
    }
  }

  // ── Game logic ──

  void startRun() {
    player.reset();
    distance = 0;
    score = 0;
    curvature = 0;
    curveTarget = 0;
    curveTimer = 0;
    nextObstacleZ = initialObstacleZ;
    _particles.clearParticles();
    obstacles.clear();
    _resetSegments();
    state = GameState.playing;
  }

  void _resetSegments() {
    segments.clear();
    for (int i = 0; i < numSegments; i++) {
      segments.add(Segment(curve: 0, z: i * segLength));
    }
  }

  void _recycleSegments() {
    while (segments.isNotEmpty && segments.first.z < distance - segLength) {
      segments.removeAt(0);
    }
    while (segments.length < numSegments) {
      final lastZ = segments.isNotEmpty ? segments.last.z : distance;
      segments.add(Segment(curve: curvature, z: lastZ + segLength));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    final clampedDt = dt.clamp(0.0, 0.05);
    final w = size.x;
    final h = size.y;

    _particles.updateSnowflakes(clampedDt, w, h, curvature, player.speed);

    if (state != GameState.playing) return;

    // Difficulty ramp
    difficulty.update(distance);

    // Accelerate
    if (player.speed < difficulty.currentMaxSpeed) {
      player.speed += clampedDt * 12;
      if (player.speed > difficulty.currentMaxSpeed) {
        player.speed = difficulty.currentMaxSpeed;
      }
    }

    // Turning
    if (player.turnDir != 0) {
      player.x += player.turnDir * turnRate * clampedDt;
      player.speed *= (1 - 0.15 * clampedDt);
    }

    // Centrifugal effect from curvature
    player.x += curvature * player.speed * clampedDt * 0.012;

    // Trail curves
    curveTimer -= clampedDt;
    if (curveTimer <= 0) {
      curveTarget = (_rng.nextDouble() - 0.5) * (1.5 + difficulty.t * 2.5);
      curveTimer = 1.5 + _rng.nextDouble() * 3;
    }
    curvature += (curveTarget - curvature) * clampedDt * 1.2;

    // Move forward
    distance += player.speed * clampedDt;
    score = (distance / 3).floor();

    // Recycle segments
    _recycleSegments();

    // Spawn obstacles
    while (nextObstacleZ < distance + drawDist) {
      obstacles.add(Obstacle.spawn(nextObstacleZ));
      nextObstacleZ += difficulty.obstacleRate * (0.6 + _rng.nextDouble() * 0.8);
    }

    // Remove old obstacles
    obstacles.removeWhere((ob) => ob.z < distance - 10);

    // Collision detection
    final result = checkCollisions(obstacles, player.x, distance);
    if (result.hit) {
      if (result.isGate) {
        result.obstacle!.passed = true;
        score += 200;
        player.speed += 3;
      } else {
        // Crash!
        state = GameState.dead;
        player.speed = 0;
        _saveScore();
        _particles.spawnCrash(w / 2, h * 0.82);
        return;
      }
    }

    // Snow spray while turning
    if (player.turnDir != 0 && player.speed > 5) {
      _particles.spawnSpray(
        w / 2 - player.turnDir * 20,
        h * 0.88,
        -player.turnDir.toDouble(),
      );
    }

    _particles.updateParticles(clampedDt);
  }

  Future<void> _saveScore() async {
    if (score > highScore) {
      highScore = score;
    }
    await StorageService.saveHighScore(score);
  }

  // ── Render ──

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final w = size.x;
    final h = size.y;

    if (state == GameState.menu) {
      _renderMenu(canvas, w, h);
      return;
    }

    // Sky
    _sky.render(canvas, w, h);

    // Road
    _road.render(canvas, w, h, player.x, difficulty.trailWidth, segments);

    // Obstacles — sort back to front
    final visible = obstacles
        .where((ob) => ob.z > distance && ob.z < distance + drawDist)
        .toList()
      ..sort((a, b) => b.z.compareTo(a.z));

    // Camera X with accumulated curve offset
    double camX = player.x;
    double cumulativeCurve = 0;
    for (final seg in segments) {
      if (seg.z >= distance && seg.z < distance + drawDist * 0.3) {
        cumulativeCurve += seg.curve * 0.002;
      }
    }
    camX -= cumulativeCurve;

    for (final ob in visible) {
      final p = project(ob.lane, ob.z, distance, camX, w, h);
      if (p == null || p.y < 0 || p.y > h) continue;

      final s = p.w * 0.6;
      switch (ob.type) {
        case ObstacleType.tree:
          _obstacleRenderer.drawTree(canvas, p.x, p.y, s);
        case ObstacleType.rock:
          _obstacleRenderer.drawRock(canvas, p.x, p.y, s);
        case ObstacleType.snowman:
          _obstacleRenderer.drawSnowman(canvas, p.x, p.y, s);
        case ObstacleType.gate:
          _obstacleRenderer.drawGate(canvas, p.x, p.y, s, ob.passed);
      }
    }

    _particles.drawSnowflakes(canvas);
    _particles.drawParticles(canvas);

    // Skier POV
    _skier.render(canvas, w, h, player.turnDir);

    // HUD
    _hud.render(
      canvas, w, h,
      score, player.speed, highScore, difficulty,
      player.touchSide, distance, true,
    );

    // Death overlay
    if (state == GameState.dead) {
      _renderDeath(canvas, w, h);
    }
  }

  // ── Menu Screen ──

  void _renderMenu(Canvas canvas, double w, double h) {
    _sky.renderMenuSky(canvas, w, h);
    _particles.drawSnowflakes(canvas);

    final paint = Paint();

    // Title card background
    paint.color = const Color(0xA6000000); // rgba(0,0,0,0.65)
    canvas.drawPath(_roundedRect(w / 2 - 140, h * 0.13, 280, 100, 16), paint);

    // Title text
    _drawText(canvas, 'SKI RUN', w / 2, h * 0.13 + 50, 44, FontWeight.bold, const Color(0xFFFFFFFF));
    _drawText(canvas, 'Endless first-person skiing', w / 2, h * 0.13 + 78, 14, FontWeight.normal, const Color(0x99FFFFFF));

    // High score
    if (highScore > 0) {
      _drawText(canvas, 'Best: ${_formatNumber(highScore)}', w / 2, h * 0.38, 16, FontWeight.bold, GameColors.gold);
    }

    // Play button
    final btnW = 200.0, btnH = 58.0;
    final btnY = h * 0.48;
    paint.color = GameColors.buttonRed;
    canvas.drawPath(_roundedRect(w / 2 - btnW / 2, btnY, btnW, btnH, 29), paint);
    _drawText(canvas, 'START', w / 2, btnY + 37, 22, FontWeight.bold, const Color(0xFFFFFFFF));

    // Instructions box
    final instY = h * 0.68;
    paint.color = const Color(0x80000000);
    canvas.drawPath(_roundedRect(w / 2 - 140, instY, 280, 105, 12), paint);

    _drawText(canvas, 'HOW TO PLAY', w / 2, instY + 24, 14, FontWeight.bold, const Color(0xFFFFFFFF));
    _drawText(canvas, 'Hold LEFT side to turn left', w / 2, instY + 46, 12, FontWeight.normal, const Color(0xCCFFFFFF));
    _drawText(canvas, 'Hold RIGHT side to turn right', w / 2, instY + 64, 12, FontWeight.normal, const Color(0xCCFFFFFF));
    _drawText(canvas, 'Dodge obstacles, pass through gates', w / 2, instY + 82, 12, FontWeight.normal, const Color(0xCCFFFFFF));
    _drawText(canvas, 'It only gets faster...', w / 2, instY + 97, 12, FontWeight.normal, const Color(0xCCFFFFFF));
  }

  // ── Death Screen ──

  void _renderDeath(Canvas canvas, double w, double h) {
    final paint = Paint();

    // Dark overlay
    paint.color = const Color(0x8C000000); // rgba(0,0,0,0.55)
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), paint);

    _drawText(canvas, 'WIPEOUT!', w / 2, h * 0.3, 38, FontWeight.bold, GameColors.speedHot);
    _drawText(canvas, _formatNumber(score), w / 2, h * 0.39, 28, FontWeight.bold, const Color(0xFFFFFFFF));
    _drawText(canvas, 'SCORE', w / 2, h * 0.43, 14, FontWeight.normal, const Color(0x99FFFFFF));

    final isNewBest = highScore == score && score > 0;
    if (isNewBest) {
      _drawText(canvas, 'NEW BEST!', w / 2, h * 0.48, 16, FontWeight.bold, GameColors.gold);
    }

    _drawText(canvas, '${distance.floor()}m traveled', w / 2, h * 0.53, 13, FontWeight.normal, const Color(0x80FFFFFF));

    // Retry button
    final btnW = 180.0, btnH = 54.0;
    final btnY = h * 0.58;
    paint.color = GameColors.buttonRed;
    canvas.drawPath(_roundedRect(w / 2 - btnW / 2, btnY, btnW, btnH, 27), paint);
    _drawText(canvas, 'RETRY', w / 2, btnY + 34, 20, FontWeight.bold, const Color(0xFFFFFFFF));

    // Menu button
    final btn2Y = btnY + 68;
    paint.color = const Color(0x33FFFFFF);
    canvas.drawPath(_roundedRect(w / 2 - btnW / 2, btn2Y, btnW, btnH, 27), paint);
    _drawText(canvas, 'MENU', w / 2, btn2Y + 34, 20, FontWeight.bold, const Color(0xFFFFFFFF));
  }

  // ── Helpers ──

  Path _roundedRect(double x, double y, double w, double h, double r) {
    return Path()
      ..moveTo(x + r, y)
      ..lineTo(x + w - r, y)
      ..quadraticBezierTo(x + w, y, x + w, y + r)
      ..lineTo(x + w, y + h - r)
      ..quadraticBezierTo(x + w, y + h, x + w - r, y + h)
      ..lineTo(x + r, y + h)
      ..quadraticBezierTo(x, y + h, x, y + h - r)
      ..lineTo(x, y + r)
      ..quadraticBezierTo(x, y, x + r, y)
      ..close();
  }

  void _drawText(
    Canvas canvas, String text, double cx, double cy,
    double fontSize, FontWeight weight, Color color,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: weight,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  String _formatNumber(int n) {
    if (n < 1000) return n.toString();
    final s = n.toString();
    final result = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) result.write(',');
      result.write(s[i]);
    }
    return result.toString();
  }
}
