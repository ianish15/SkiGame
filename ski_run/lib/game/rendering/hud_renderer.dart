import 'dart:ui';
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle, FontWeight, TextDirection;
import '../../config/colors.dart';
import '../systems/difficulty.dart';

class HudRenderer {
  final Paint _paint = Paint();

  // Cached text painters
  TextPainter? _scorePainter;
  TextPainter? _scoreLabelPainter;
  TextPainter? _bestPainter;
  TextPainter? _diffPainter;
  TextPainter? _tutorialPainter;
  int _lastScore = -1;
  int _lastBest = -1;
  String _lastDiffLabel = '';

  void render(
    Canvas canvas,
    double w,
    double h,
    int score,
    double speed,
    int highScore,
    DifficultyState difficulty,
    int touchSide,
    double distance,
    bool isPlaying,
  ) {
    // Score panel background
    _paint.color = const Color(0x8C000000); // rgba(0,0,0,0.55)
    final panelPath = _roundedRect(12, 12, 140, 62, 10);
    canvas.drawPath(panelPath, _paint);

    // Score text
    if (_lastScore != score) {
      _lastScore = score;
      _scorePainter = _makeText(
        _formatNumber(score),
        26,
        FontWeight.bold,
        const Color(0xFFFFFFFF),
      );
    }
    _scorePainter!.paint(canvas, const Offset(22, 20));

    // "SCORE" label
    _scoreLabelPainter ??= _makeText(
      'SCORE',
      11,
      FontWeight.normal,
      const Color(0x99FFFFFF), // rgba(255,255,255,0.6)
    );
    _scoreLabelPainter!.paint(canvas, const Offset(22, 48));

    // Speed bar
    final speedPct = speed / difficulty.currentMaxSpeed;
    _paint.color = const Color(0x33FFFFFF); // rgba(255,255,255,0.2)
    canvas.drawRect(const Rect.fromLTWH(22, 64, 110, 4), _paint);
    _paint.color = speedPct > 0.85 ? GameColors.speedHot : GameColors.speedNormal;
    canvas.drawRect(Rect.fromLTWH(22, 64, 110 * speedPct, 4), _paint);

    // High score badge
    if (highScore > 0) {
      _paint.color = const Color(0x66000000);
      canvas.drawPath(_roundedRect(w - 110, 12, 98, 30, 8), _paint);

      if (_lastBest != highScore) {
        _lastBest = highScore;
        _bestPainter = _makeText(
          'BEST ${_formatNumber(highScore)}',
          11,
          FontWeight.bold,
          GameColors.gold,
        );
      }
      _bestPainter!.paint(
        canvas,
        Offset(w - 110 + 98 - _bestPainter!.width - 6, 18),
      );
    }

    // Difficulty indicator
    _paint.color = const Color(0x66000000);
    canvas.drawPath(_roundedRect(w / 2 - 50, 12, 100, 22, 6), _paint);

    final label = difficulty.label;
    if (_lastDiffLabel != label) {
      _lastDiffLabel = label;
      Color diffColor;
      switch (label) {
        case 'GREEN':
          diffColor = GameColors.diffGreen;
        case 'BLUE':
          diffColor = GameColors.diffBlue;
        case 'BLACK':
          diffColor = GameColors.diffBlack;
        default:
          diffColor = GameColors.diffDouble;
      }
      _diffPainter = _makeText(label, 11, FontWeight.bold, diffColor);
    }
    _diffPainter!.paint(
      canvas,
      Offset(w / 2 - _diffPainter!.width / 2, 17),
    );

    // Turn hints
    if (isPlaying) {
      _drawTurnHints(canvas, w, h, touchSide, distance);
    }
  }

  void _drawTurnHints(Canvas canvas, double w, double h, int touchSide, double distance) {
    if (touchSide == -1) {
      _paint.shader = Gradient.linear(
        Offset.zero,
        const Offset(60, 0),
        [const Color(0x26FFFFFF), const Color(0x00FFFFFF)],
      );
      canvas.drawRect(Rect.fromLTWH(0, 0, 60, h), _paint);
      _paint.shader = null;
    } else if (touchSide == 1) {
      _paint.shader = Gradient.linear(
        Offset(w, 0),
        Offset(w - 60, 0),
        [const Color(0x26FFFFFF), const Color(0x00FFFFFF)],
      );
      canvas.drawRect(Rect.fromLTWH(w - 60, 0, 60, h), _paint);
      _paint.shader = null;
    }

    // Tutorial text at start
    if (distance < 200) {
      _tutorialPainter ??= _makeText(
        'HOLD LEFT / RIGHT TO TURN',
        13,
        FontWeight.normal,
        const Color(0x59000000), // rgba(0,0,0,0.35)
      );
      _tutorialPainter!.paint(
        canvas,
        Offset(w / 2 - _tutorialPainter!.width / 2, h * 0.7),
      );
    }
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

  TextPainter _makeText(String text, double size, FontWeight weight, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: weight,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return tp;
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
