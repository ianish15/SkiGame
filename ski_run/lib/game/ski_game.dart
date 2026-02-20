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

class SkiGame extends FlameGame with TapCallbacks, DragCallbacks {
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
  String _deathMessage = 'WIPEOUT!';

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

  int? _activePointer;

  @override
  void onTapDown(TapDownEvent event) {
    final x = event.canvasPosition.x;
    final y = event.canvasPosition.y;

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
  void onTapUp(TapUpEvent event) {
    player.turnDir = 0;
    player.touchSide = 0;
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    player.turnDir = 0;
    player.touchSide = 0;
  }

  @override
  void onDragStart(DragStartEvent event) {
    if (state == GameState.playing) {
      final mid = size.x / 2;
      player.touchSide = event.canvasPosition.x < mid ? -1 : 1;
      player.turnDir = player.touchSide;
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (state == GameState.playing) {
      final mid = size.x / 2;
      final newSide = event.canvasEndPosition.x < mid ? -1 : 1;
      if (newSide != player.touchSide) {
        player.touchSide = newSide;
        player.turnDir = newSide;
      }
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    player.turnDir = 0;
    player.touchSide = 0;
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    player.turnDir = 0;
    player.touchSide = 0;
  }

  // ── Button constants (shared between render & tap) ──

  static const _menuBtnW = 220.0;
  static const _menuBtnH = 58.0;
  double get _menuBtnY => size.y * 0.46;

  static const _deathBtnW = 200.0;
  static const _deathBtnH = 54.0;
  double get _deathRetryY => size.y * 0.58;
  double get _deathMenuY => _deathRetryY + 68;

  void _handleMenuTap(double tx, double ty) {
    final w = size.x;
    if (tx > w / 2 - _menuBtnW / 2 &&
        tx < w / 2 + _menuBtnW / 2 &&
        ty > _menuBtnY &&
        ty < _menuBtnY + _menuBtnH) {
      startRun();
    }
  }

  void _handleDeathTap(double tx, double ty) {
    final w = size.x;
    if (tx > w / 2 - _deathBtnW / 2 && tx < w / 2 + _deathBtnW / 2) {
      if (ty > _deathRetryY && ty < _deathRetryY + _deathBtnH) {
        startRun();
      } else if (ty > _deathMenuY && ty < _deathMenuY + _deathBtnH) {
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
    _deathMessage = 'WIPEOUT!';
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

    // Out-of-bounds check — die if past trail edges
    final boundary = difficulty.trailWidth * 0.92;
    if (player.x.abs() > boundary) {
      state = GameState.dead;
      _deathMessage = 'OUT OF BOUNDS!';
      player.speed = 0;
      _saveScore();
      _particles.spawnCrash(w / 2, h * 0.82);
      return;
    }

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
        score += result.obstacle!.gatePoints;
        player.speed += 3;
      } else {
        // Crash!
        state = GameState.dead;
        _deathMessage = 'WIPEOUT!';
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
    _sky.render(canvas, w, h, distance: distance);

    // Road
    _road.render(canvas, w, h, player.x, difficulty.trailWidth, segments);

    // Obstacles — sort back to front
    final visible = obstacles
        .where((ob) => ob.z > distance && ob.z < distance + drawDist)
        .toList()
      ..sort((a, b) => b.z.compareTo(a.z));

    for (final ob in visible) {
      final p = project(ob.lane, ob.z, distance, player.x, w, h, segments);
      if (p == null || p.y < 0 || p.y > h) continue;

      final s = p.w * 2.0;
      switch (ob.type) {
        case ObstacleType.tree:
          _obstacleRenderer.drawTree(canvas, p.x, p.y, s);
        case ObstacleType.rock:
          _obstacleRenderer.drawRock(canvas, p.x, p.y, s);
        case ObstacleType.snowman:
          _obstacleRenderer.drawSnowman(canvas, p.x, p.y, s);
        case ObstacleType.gate:
          _obstacleRenderer.drawGate(
            canvas, p.x, p.y, s, ob.passed,
            gateSize: ob.gateSize,
            points: ob.gatePoints,
          );
      }
    }

    _particles.drawSnowflakes(canvas);
    _particles.drawParticles(canvas);

    // Spray mist cloud when turning
    if (state == GameState.playing && player.turnDir != 0 && player.speed > 5) {
      _particles.drawSprayMist(
        canvas,
        w / 2 - player.turnDir * 25,
        h * 0.89,
        -player.turnDir.toDouble(),
        player.speed,
      );
    }

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

    // Title card — frosted dark panel
    final cardX = w / 2 - 150;
    final cardY = h * 0.10;
    const cardW = 300.0;
    const cardH = 115.0;

    // Card shadow
    paint.color = const Color(0x30000000);
    canvas.drawPath(_roundedRect(cardX + 2, cardY + 3, cardW, cardH, 18), paint);
    // Card body
    paint.color = const Color(0xB3101828);
    canvas.drawPath(_roundedRect(cardX, cardY, cardW, cardH, 18), paint);
    // Card border
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0x20FFFFFF);
    canvas.drawPath(_roundedRect(cardX, cardY, cardW, cardH, 18), borderPaint);

    // Title
    _drawStyledText(canvas, 'SKI RUN', w / 2, cardY + 50, 46,
        FontWeight.bold, const Color(0xFFFFFFFF), letterSpacing: 4);
    _drawText(canvas, 'Endless first-person skiing', w / 2, cardY + 85, 13,
        FontWeight.normal, const Color(0x99FFFFFF));

    // High score
    if (highScore > 0) {
      paint.color = const Color(0x40000000);
      final hsW = 160.0;
      canvas.drawPath(
          _roundedRect(w / 2 - hsW / 2, h * 0.35, hsW, 30, 15), paint);
      _drawText(canvas, 'BEST  ${_formatNumber(highScore)}', w / 2,
          h * 0.35 + 15, 14, FontWeight.bold, GameColors.gold);
    }

    // Play button — gradient
    _drawGradientButton(
      canvas, w / 2, _menuBtnY, _menuBtnW, _menuBtnH,
      const Color(0xFF4FC3F7), const Color(0xFF0277BD),
      'PLAY', 22,
    );

    // Instructions card
    final instX = w / 2 - 150;
    final instY = h * 0.62;
    const instW = 300.0;
    const instH = 135.0;

    paint.color = const Color(0x80101828);
    canvas.drawPath(_roundedRect(instX, instY, instW, instH, 14), paint);
    canvas.drawPath(_roundedRect(instX, instY, instW, instH, 14), borderPaint);

    _drawStyledText(canvas, 'HOW TO PLAY', w / 2, instY + 24, 13,
        FontWeight.bold, const Color(0xCCFFFFFF), letterSpacing: 2);

    // Divider line
    paint.color = const Color(0x1AFFFFFF);
    canvas.drawRect(
        Rect.fromLTWH(instX + 30, instY + 38, instW - 60, 1), paint);

    _drawText(canvas, 'Hold LEFT side to turn left', w / 2, instY + 56, 12,
        FontWeight.normal, const Color(0xB3FFFFFF));
    _drawText(canvas, 'Hold RIGHT side to turn right', w / 2, instY + 74, 12,
        FontWeight.normal, const Color(0xB3FFFFFF));
    _drawText(canvas, 'Dodge obstacles  |  Stay on the trail', w / 2,
        instY + 92, 12, FontWeight.normal, const Color(0xB3FFFFFF));
    _drawText(canvas, 'Pass through gates for bonus points', w / 2,
        instY + 110, 12, FontWeight.normal, const Color(0xB3FFFFFF));
    _drawText(canvas, 'It only gets faster...', w / 2, instY + 126, 11,
        FontWeight.normal, const Color(0x66FFFFFF));
  }

  // ── Death Screen ──

  void _renderDeath(Canvas canvas, double w, double h) {
    final paint = Paint();

    // Dark gradient overlay
    paint.shader = Gradient.linear(
      Offset(0, 0),
      Offset(0, h),
      [const Color(0x60000000), const Color(0xB3000000)],
    );
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), paint);
    paint.shader = null;

    // Central card
    final cardW = min(w * 0.85, 320.0);
    final cardX = w / 2 - cardW / 2;
    final cardY = h * 0.18;
    final cardH = h * 0.68;

    // Card shadow
    paint.color = const Color(0x40000000);
    canvas.drawPath(
        _roundedRect(cardX + 2, cardY + 3, cardW, cardH, 22), paint);
    // Card body
    paint.color = const Color(0xCC0D1B2A);
    canvas.drawPath(_roundedRect(cardX, cardY, cardW, cardH, 22), paint);
    // Card border
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0x25FFFFFF);
    canvas.drawPath(_roundedRect(cardX, cardY, cardW, cardH, 22), borderPaint);

    // Death title
    final titleColor = _deathMessage == 'OUT OF BOUNDS!'
        ? const Color(0xFFFFB74D)
        : GameColors.speedHot;
    _drawStyledText(canvas, _deathMessage, w / 2, h * 0.27, 32,
        FontWeight.bold, titleColor, letterSpacing: 2);

    // Score
    _drawStyledText(canvas, _formatNumber(score), w / 2, h * 0.36, 48,
        FontWeight.bold, const Color(0xFFFFFFFF), letterSpacing: 1);
    _drawText(canvas, 'SCORE', w / 2, h * 0.42, 12, FontWeight.normal,
        const Color(0x80FFFFFF));

    // Divider
    paint.color = const Color(0x1AFFFFFF);
    canvas.drawRect(
        Rect.fromLTWH(cardX + 40, h * 0.45, cardW - 80, 1), paint);

    // Stats
    final isNewBest = highScore == score && score > 0;
    if (isNewBest) {
      // Glow behind NEW BEST
      paint.color = const Color(0x20FFC107);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(w / 2, h * 0.49), width: 150, height: 30),
          paint);
      _drawStyledText(canvas, 'NEW BEST!', w / 2, h * 0.49, 18,
          FontWeight.bold, GameColors.gold, letterSpacing: 2);
    }

    _drawText(canvas, '${distance.floor()}m traveled', w / 2, h * 0.535, 13,
        FontWeight.normal, const Color(0x80FFFFFF));

    // Retry button — gradient
    _drawGradientButton(
      canvas, w / 2, _deathRetryY, _deathBtnW, _deathBtnH,
      const Color(0xFF4FC3F7), const Color(0xFF0277BD),
      'RETRY', 20,
    );

    // Menu button — ghost
    _drawGhostButton(
        canvas, w / 2, _deathMenuY, _deathBtnW, _deathBtnH, 'MENU', 18);
  }

  // ── Drawing helpers ──

  void _drawGradientButton(
    Canvas canvas,
    double cx,
    double y,
    double bw,
    double bh,
    Color c1,
    Color c2,
    String text,
    double fontSize,
  ) {
    final paint = Paint();
    final left = cx - bw / 2;
    final radius = bh / 2;

    // Shadow
    paint.color = const Color(0x40000000);
    canvas.drawPath(_roundedRect(left + 2, y + 3, bw, bh, radius), paint);

    // Gradient fill
    paint.shader = Gradient.linear(
      Offset(left, y),
      Offset(left, y + bh),
      [c1, c2],
    );
    canvas.drawPath(_roundedRect(left, y, bw, bh, radius), paint);
    paint.shader = null;

    // Highlight (top half)
    paint.color = const Color(0x20FFFFFF);
    canvas.save();
    canvas.clipPath(_roundedRect(left, y, bw, bh, radius));
    canvas.drawRect(Rect.fromLTWH(left, y, bw, bh * 0.45), paint);
    canvas.restore();

    // Text
    _drawText(canvas, text, cx, y + bh / 2 + 1, fontSize, FontWeight.bold,
        const Color(0xFFFFFFFF));
  }

  void _drawGhostButton(
    Canvas canvas,
    double cx,
    double y,
    double bw,
    double bh,
    String text,
    double fontSize,
  ) {
    final left = cx - bw / 2;
    final radius = bh / 2;

    // Subtle fill
    final paint = Paint()..color = const Color(0x15FFFFFF);
    canvas.drawPath(_roundedRect(left, y, bw, bh, radius), paint);

    // Border
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0x55FFFFFF);
    canvas.drawPath(_roundedRect(left, y, bw, bh, radius), border);

    // Text
    _drawText(canvas, text, cx, y + bh / 2 + 1, fontSize, FontWeight.bold,
        const Color(0xCCFFFFFF));
  }

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

  void _drawStyledText(
    Canvas canvas, String text, double cx, double cy,
    double fontSize, FontWeight weight, Color color, {
    double letterSpacing = 0,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: weight,
          letterSpacing: letterSpacing,
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
