import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/player.dart';
import '../models/ultraball.dart';
import '../models/creature.dart';
import '../models/damage_indicator.dart';
import '../models/game_settings.dart';
import 'game_state.dart';
import 'camera_3d.dart';

/// Long-lived CustomPainter — stored on _GameWidgetState and reused every
/// frame.  All Paint, Path, and TextPainter instances live here; nothing is
/// allocated inside paint().
class FieldPainter extends CustomPainter {
  final GameState gs;

  // Layout — mutated by game_widget before each rebuild
  double scale   = 1.0;
  double offsetX = 0;
  double offsetY = 0;

  // View mode
  ViewMode viewMode = ViewMode.flat;
  final Camera3D _camera3D = Camera3D();
  Size _last3DSize = Size.zero;

  FieldPainter({required this.gs, required Listenable repaint})
      : super(repaint: repaint);

  // ---- Screen-space helpers ----
  double sx(double x) => x * scale + offsetX;
  double sy(double y) => y * scale + offsetY;
  double sm(double m) => m * scale;
  Offset toScreen(double x, double y) => Offset(sx(x), sy(y));

  // ====================================================================
  // Static Paints — fixed colors, allocated once for the app lifetime
  // ====================================================================
  static final Paint _bgPaint          = Paint()..color = const Color(0xFF0A0A14);
  static final Paint _lEndPaint        = Paint()..color = const Color(0xFF3D0A0A);
  static final Paint _rEndPaint        = Paint()..color = const Color(0xFF0A0A3D);
  static final Paint _channelPaint     = Paint()..color = const Color(0xFF1A0A2A);
  static final Paint _mainFieldPaint   = Paint()..color = const Color(0xFF0A1A0A);
  static final Paint _stripePaint      = Paint()..color = const Color(0xFF0D200D);
  // Kill zone: 0x26 ≈ 0.15*255 alpha, 0x80 ≈ 0.5*255 alpha
  static final Paint _killZoneFillPaint = Paint()
      ..color = const Color(0x26FF0000)
      ..style = PaintingStyle.fill;
  static final Paint _killZoneBorderPaint = Paint()
      ..color = const Color(0x80FF0000)
      ..style = PaintingStyle.stroke;
  static final Paint _eyePaint    = Paint()..color = const Color(0xFFFF3300);
  static final Paint _hpBgPaint   = Paint()..color = const Color(0xFF333333);
  static final Paint _hpGoodPaint = Paint()..color = const Color(0xFF44FF44);
  static final Paint _hpMedPaint  = Paint()..color = const Color(0xFFFFAA00);
  static final Paint _hpBadPaint  = Paint()..color = const Color(0xFFFF2222);
  static final Paint _facingPaint = Paint()
      ..color = const Color(0xD9FFFFFF)   // white 0.85 alpha
      ..style = PaintingStyle.fill;
  static final Paint _targetTriPaint = Paint()
      ..color = const Color(0xE6FF3333)   // 0.9 alpha red
      ..style = PaintingStyle.fill;

  // ====================================================================
  // Instance Paints — scratch objects mutated before each draw call
  // ====================================================================
  // _sp: stroke operations — set color/strokeWidth before use
  final Paint _sp = Paint()..style = PaintingStyle.stroke;
  // _fp: fill operations — set color before use
  final Paint _fp = Paint()..style = PaintingStyle.fill;
  // _gp: glow/blur operations — always resets maskFilter after use
  final Paint _gp = Paint()..style = PaintingStyle.fill;

  // ====================================================================
  // Reusable Path — reset before each use via ..reset()
  // ====================================================================
  final Path _path = Path();

  // ====================================================================
  // Phase line dash-path cache (per screen layout)
  // ====================================================================
  final List<Path?> _dashPaths   = List.filled(5, null);
  double            _dashScale   = -1;
  double            _dashOffX    = -1;
  double            _dashOffY    = -1;

  // ====================================================================
  // TextPainter caches
  // ====================================================================

  // Zone labels (depend on scale × team name)
  TextPainter? _awayZoneTp, _homeZoneTp;
  String?      _cachedAwayName, _cachedHomeName;
  double       _cachedZoneSm = -1;

  void _ensureZoneLabels() {
    final fsm = sm(3.0).clamp(8.0, 28.0);
    if (_awayZoneTp == null ||
        _cachedZoneSm != fsm ||
        _cachedAwayName != gs.settings.awayTeamName) {
      _cachedAwayName = gs.settings.awayTeamName;
      _cachedZoneSm   = fsm;
      _awayZoneTp = TextPainter(
        text: TextSpan(
          text: _cachedAwayName!.toUpperCase(),
          style: TextStyle(
            color: const Color(0xFFFF4444).withValues(alpha: 0.3),
            fontSize: fsm,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }
    if (_homeZoneTp == null ||
        _cachedZoneSm != fsm ||
        _cachedHomeName != gs.settings.homeTeamName) {
      _cachedHomeName = gs.settings.homeTeamName;
      _homeZoneTp = TextPainter(
        text: TextSpan(
          text: _cachedHomeName!.toUpperCase(),
          style: TextStyle(
            color: const Color(0xFF4488FF).withValues(alpha: 0.3),
            fontSize: fsm,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }
  }

  // Creature name label
  TextPainter? _creatureNameTp;
  String?      _cachedCreatureName;
  double       _cachedCreatureSm = -1;

  TextPainter _getCreatureNameTp() {
    final fsm = sm(1.5).clamp(8.0, 14.0);
    final name = gs.creature.name;
    if (_creatureNameTp == null ||
        _cachedCreatureSm != fsm ||
        _cachedCreatureName != name) {
      _cachedCreatureName = name;
      _cachedCreatureSm   = fsm;
      _creatureNameTp = TextPainter(
        text: TextSpan(
          text: name,
          style: TextStyle(
            color: const Color(0xFFFFAAAA),
            fontSize: fsm,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }
    return _creatureNameTp!;
  }

  // Player number labels (keyed by rosterIndex 0–14)
  final Map<int, TextPainter> _playerNumTp = {};
  double _cachedNumSm = -1;

  TextPainter _getPlayerNumTp(int rosterIndex) {
    final fsm = sm(1.1).clamp(6.0, 12.0);
    if (_cachedNumSm != fsm) {
      _playerNumTp.clear();
      _cachedNumSm = fsm;
    }
    return _playerNumTp.putIfAbsent(rosterIndex, () {
      return TextPainter(
        text: TextSpan(
          text: '${rosterIndex + 1}',
          style: TextStyle(
            color: Colors.white,
            fontSize: fsm,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }

  // Throw-arc distance label (re-laid-out only when value changes by ≥0.5 m)
  TextPainter? _distTp;
  double       _cachedDistLabel = double.nan;

  TextPainter _getDistTp(double dist) {
    if (_distTp == null || (dist - _cachedDistLabel).abs() >= 0.5) {
      _cachedDistLabel = dist;
      _distTp = TextPainter(
        text: TextSpan(
          text: '${dist.toStringAsFixed(0)}m',
          style: TextStyle(
            color: const Color(0xFFFFDD00).withValues(alpha: 0.85),
            fontSize: sm(1.2).clamp(8.0, 13.0),
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }
    return _distTp!;
  }

  // ====================================================================
  // paint()
  // ====================================================================

  @override
  void paint(Canvas canvas, Size size) {
    if (viewMode == ViewMode.threeQuarter) { _paint3D(canvas, size); return; }
    if (viewMode == ViewMode.full3D) { _paintFull3D(canvas, size); return; }

    // 1. Background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), _bgPaint);

    // 2. Left endzone
    _drawRect(canvas, 0, 0, 20, 40, _lEndPaint);
    _drawZoneLabel(canvas, 10, 20, false);  // away label

    // 3. Right endzone
    _drawRect(canvas, 120, 0, 20, 40, _rEndPaint);
    _drawZoneLabel(canvas, 130, 20, true);  // home label

    // 4. Left channel
    _drawRect(canvas, 20, -5, 10, 50, _channelPaint);

    // 5. Right channel
    _drawRect(canvas, 110, -5, 10, 50, _channelPaint);

    // 6. Main field
    _drawRect(canvas, 30, 0, 80, 40, _mainFieldPaint);
    _drawFieldStripes(canvas);

    // 6b. Creature connecting strips
    _drawCreatureConnectingStrips(canvas);

    // 7. Phase lines
    _drawPhaseLines(canvas);

    // 8. Field markings
    _drawFieldMarkings(canvas);

    // 9. Creature
    _drawCreature(canvas);

    // 10. Players
    _drawPlayers(canvas);

    // 11. Throw arc preview
    _drawThrowArcPreview(canvas);

    // 12. Ball
    _drawBall(canvas);

    // 13. Damage indicators
    _drawDamageIndicators(canvas);
  }

  void _drawDamageIndicators(Canvas canvas) {
    if (gs.indicators.isEmpty) return;
    for (final ind in gs.indicators) {
      final screenX = ind.worldX * scale + offsetX + ind.xJitter * scale;
      final screenY = ind.worldY * scale + offsetY - ind.progress * 60;
      final opacity = (1.0 - ind.progress * ind.progress).clamp(0.0, 1.0);

      final (Color baseColor, double fontSize, bool hasShadow) = switch (ind.type) {
        IndicatorType.damage => (const Color(0xFFFFFF44), 14.0, false),
        IndicatorType.kill   => (const Color(0xFFFF2222), 18.0, true),
        IndicatorType.heal   => (const Color(0xFF44FF88), 14.0, false),
        IndicatorType.combo  => (const Color(0xFFFFAA00), 22.0, true),
        IndicatorType.event  => (const Color(0xFFFFFFFF), 15.0, true),
      };

      final tp = TextPainter(
        text: TextSpan(
          text: ind.text,
          style: TextStyle(
            color: baseColor.withValues(alpha: opacity),
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            shadows: hasShadow
                ? [
                    Shadow(
                      color: Colors.black.withValues(alpha: opacity * 0.8),
                      blurRadius: 4,
                      offset: const Offset(1, 1),
                    ),
                  ]
                : null,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(screenX - tp.width / 2, screenY - fontSize / 2));
    }
  }

  // ---- Drawing helpers ----

  void _drawRect(Canvas canvas, double x, double y, double w, double h, Paint paint) {
    canvas.drawRect(Rect.fromLTWH(sx(x), sy(y), sm(w), sm(h)), paint);
  }

  void _drawZoneLabel(Canvas canvas, double cx, double cy, bool isHome) {
    _ensureZoneLabels();
    final tp = isHome ? _homeZoneTp! : _awayZoneTp!;
    tp.paint(canvas, Offset(sx(cx) - tp.width / 2, sy(cy) - tp.height / 2));
  }

  void _drawFieldStripes(Canvas canvas) {
    for (int i = 0; i < 4; i++) {
      canvas.drawRect(
        Rect.fromLTWH(sx(30.0 + i * 20.0), sy(0), sm(10), sm(40)),
        _stripePaint,
      );
    }
  }

  void _drawCreatureConnectingStrips(Canvas canvas) {
    _drawRect(canvas, 30, -5, 80, 5, _channelPaint);
    _drawRect(canvas, 30, 40, 80, 5, _channelPaint);

    _sp
      ..color = const Color(0xFF991133).withValues(alpha: 0.55)
      ..strokeWidth = sm(0.2);
    canvas.drawLine(Offset(sx(20), sy(0)),  Offset(sx(120), sy(0)),  _sp);
    canvas.drawLine(Offset(sx(20), sy(40)), Offset(sx(120), sy(40)), _sp);
  }

  void _drawPhaseLines(Canvas canvas) {
    // Invalidate dash path cache when layout changes
    if (_dashScale != scale || _dashOffX != offsetX || _dashOffY != offsetY) {
      for (int i = 0; i < _dashPaths.length; i++) { _dashPaths[i] = null; }
      _dashScale = scale;
      _dashOffX  = offsetX;
      _dashOffY  = offsetY;
    }

    final positions = Ultraball.phaseLineXPositions;
    for (int i = 0; i < positions.length; i++) {
      final lineX    = positions[i];
      final isActive = gs.ball.phaseLineActive[i];

      if (isActive) {
        _sp
          ..color = const Color(0xFF00FFFF).withValues(alpha: 0.15)
          ..strokeWidth = sm(1.5);
        canvas.drawLine(Offset(sx(lineX), sy(0)), Offset(sx(lineX), sy(40)), _sp);
      }

      _sp
        ..color = isActive
            ? const Color(0xFF00FFFF).withValues(alpha: 0.8)
            : const Color(0xFF444444).withValues(alpha: 0.5)
        ..strokeWidth = isActive ? sm(0.2) : sm(0.1);

      if (!isActive) {
        _dashPaths[i] ??= _buildDashPath(lineX);
        canvas.drawPath(_dashPaths[i]!, _sp);
      } else {
        canvas.drawLine(Offset(sx(lineX), sy(0)), Offset(sx(lineX), sy(40)), _sp);
      }
    }
  }

  Path _buildDashPath(double lineX) {
    final p = Path();
    double y = 0;
    while (y < 40) {
      p.moveTo(sx(lineX), sy(y));
      p.lineTo(sx(lineX), sy(math.min(y + 2, 40)));
      y += 4;
    }
    return p;
  }

  void _drawFieldMarkings(Canvas canvas) {
    _sp
      ..color = const Color(0xFF888888).withValues(alpha: 0.7)
      ..strokeWidth = sm(0.3);
    canvas.drawRect(Rect.fromLTWH(sx(0), sy(0), sm(140), sm(40)), _sp);

    _sp
      ..color = const Color(0xFF888888).withValues(alpha: 0.4)
      ..strokeWidth = sm(0.15);
    canvas.drawLine(Offset(sx(70), sy(0)), Offset(sx(70), sy(40)), _sp);

    _sp
      ..color = const Color(0xFFAAAAAA).withValues(alpha: 0.5)
      ..strokeWidth = sm(0.2);
    for (final x in [20.0, 30.0, 110.0, 120.0]) {
      canvas.drawLine(Offset(sx(x), sy(0)), Offset(sx(x), sy(40)), _sp);
    }
  }

  void _drawCreature(Canvas canvas) {
    final creature = gs.creature;
    final pos = toScreen(creature.x, creature.y);
    final r = sm(creature.size);

    // Chaos telegraph
    if (creature.type == CreatureType.chaos && creature.isTelegraphing) {
      final telegraphColor = switch (creature.telegraphAction) {
        ChaosAction.stop     => const Color(0xFFFFCC00),
        ChaosAction.reverse  => const Color(0xFFFF6600),
        ChaosAction.burst    => const Color(0xFFFF2200),
        ChaosAction.teleport => const Color(0xFF00FFFF),
      };
      _gp
        ..color = telegraphColor.withValues(alpha: 0.06)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0);
      canvas.drawCircle(pos, r * 3.0, _gp);
      _gp.maskFilter = null;

      _sp.strokeWidth = sm(0.25);
      for (final ring in creature.chaosRings) {
        final ringR = sm(creature.size * (1.2 + ring * 4.0));
        _sp.color = telegraphColor.withValues(alpha: (1.0 - ring) * 0.65);
        canvas.drawCircle(pos, ringR, _sp);
      }
    }

    // Kill zone
    _killZoneBorderPaint.strokeWidth = sm(0.2);
    canvas.drawCircle(pos, r, _killZoneFillPaint);
    canvas.drawCircle(pos, r, _killZoneBorderPaint);

    // Creature body
    final bodyColor = switch (creature.type) {
      CreatureType.kraken => const Color(0xFF4B0082),
      CreatureType.dragon => const Color(0xFF8B0000),
      CreatureType.hydra  => const Color(0xFF006400),
      CreatureType.wraith => const Color(0xFF0D2744),
      CreatureType.chaos  => const Color(0xFF0A0010),
    };

    _fp.color = bodyColor;
    canvas.drawCircle(pos, r * 0.85, _fp);
    _fp.color = bodyColor.withValues(alpha: 0.6);
    canvas.drawCircle(pos, r * 0.6, _fp);

    // Eyes
    final eyeOffset = r * 0.3;
    final eyeR = r * 0.15;
    canvas.drawCircle(
        Offset(pos.dx - eyeOffset, pos.dy - eyeOffset * 0.5), eyeR, _eyePaint);
    canvas.drawCircle(
        Offset(pos.dx + eyeOffset, pos.dy - eyeOffset * 0.5), eyeR, _eyePaint);

    // Name label
    final nameTp = _getCreatureNameTp();
    nameTp.paint(canvas, Offset(pos.dx - nameTp.width / 2, pos.dy + r + sm(0.5)));
  }

  void _drawPlayers(Canvas canvas) {
    final alive = gs.fieldPlayers.where((p) => p.isAlive).toList();

    // Pass 1: ground shadows for airborne players
    for (final p in alive) {
      if (p.isAirborne) _drawJumpShadow(canvas, p);
    }

    // Pass 2: player bodies
    for (final p in alive) {
      _drawPlayer(canvas, p);
    }
  }

  void _drawJumpShadow(Canvas canvas, UltraballPlayer p) {
    final groundPos = toScreen(p.x, p.y);
    final heightFrac = (p.zHeight / 4.0).clamp(0.0, 1.0);
    final shadowR = sm(1.2) * (1.0 - heightFrac * 0.5);
    _fp.color = Colors.black.withValues(alpha: 0.45 - heightFrac * 0.2);
    canvas.drawOval(
      Rect.fromCenter(center: groundPos, width: shadowR * 2.2, height: shadowR * 0.8),
      _fp,
    );
  }

  void _drawPlayer(Canvas canvas, UltraballPlayer p) {
    final groundPos = toScreen(p.x, p.y);
    final liftPixels = p.zHeight * scale * 0.5;
    final pos = Offset(groundPos.dx, groundPos.dy - liftPixels);
    final r = sm(1.2);
    final isTarget = p.id == gs.currentTargetId;

    // Target ring
    if (isTarget) {
      _sp
        ..color = const Color(0xFFFF2222).withValues(alpha: 0.9)
        ..strokeWidth = sm(0.3);
      canvas.drawCircle(pos, r + sm(0.9), _sp);
      _sp
        ..color = const Color(0xFFFF4444).withValues(alpha: 0.4)
        ..strokeWidth = sm(0.12);
      canvas.drawCircle(pos, r + sm(1.4), _sp);
      _drawTargetTriangles(canvas, pos, r + sm(1.7));
    }

    // Selection ring
    if (p.isSelected) {
      _sp
        ..color = Colors.white.withValues(alpha: 0.9)
        ..strokeWidth = sm(0.25);
      canvas.drawCircle(pos, r + sm(0.6), _sp);
      _sp
        ..color = Colors.white.withValues(alpha: 0.3)
        ..strokeWidth = sm(0.1);
      canvas.drawCircle(pos, r + sm(1.0), _sp);
    }

    // Ball holder glow
    if (gs.ball.holderId == p.id) {
      _gp
        ..color = const Color(0xFFFFDD00).withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(pos, r + sm(0.8), _gp);
      _gp.maskFilter = null;
    }

    // Player body
    final teamColor = p.team == Team.player
        ? const Color(0xFF1E88E5)
        : const Color(0xFFE53935);

    _fp.color = teamColor;
    canvas.drawCircle(pos, r, _fp);
    _fp.color = teamColor.withValues(alpha: 0.6);
    canvas.drawCircle(pos, r * 0.7, _fp);

    // Facing wedge
    _drawFacingIndicator(canvas, p, pos, r);

    // Stunned indicator
    if (p.isStunned) {
      _sp
        ..color = Colors.yellow.withValues(alpha: 0.6)
        ..strokeWidth = sm(0.2);
      canvas.drawCircle(pos, r + sm(0.3), _sp);
    }

    // Player number
    final numTp = _getPlayerNumTp(p.rosterIndex);
    numTp.paint(canvas, Offset(pos.dx - numTp.width / 2, pos.dy - numTp.height / 2));

    // Health bar
    _drawHealthBar(canvas, p, pos, r);
  }

  void _drawFacingIndicator(Canvas canvas, UltraballPlayer p, Offset center, double r) {
    final f = p.facing;
    final tipDist = r * 1.1;
    final tip = Offset(
      center.dx + math.cos(f) * tipDist,
      center.dy + math.sin(f) * tipDist,
    );
    const halfAngle = 0.55;
    final baseR = r * 0.45;
    final left = Offset(
      center.dx + math.cos(f + math.pi - halfAngle) * baseR,
      center.dy + math.sin(f + math.pi - halfAngle) * baseR,
    );
    final right = Offset(
      center.dx + math.cos(f + math.pi + halfAngle) * baseR,
      center.dy + math.sin(f + math.pi + halfAngle) * baseR,
    );

    _path
      ..reset()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    canvas.drawPath(_path, _facingPaint);
  }

  void _drawTargetTriangles(Canvas canvas, Offset center, double radius) {
    const size = 5.0;
    for (int i = 0; i < 4; i++) {
      final angle  = i * math.pi / 2;
      final tx     = center.dx + math.cos(angle) * radius;
      final ty     = center.dy + math.sin(angle) * radius;
      final inward = angle + math.pi;
      final perpL  = angle + math.pi / 2;
      final perpR  = angle - math.pi / 2;
      _path
        ..reset()
        ..moveTo(tx + math.cos(inward) * size, ty + math.sin(inward) * size)
        ..lineTo(tx + math.cos(perpL) * size * 0.5, ty + math.sin(perpL) * size * 0.5)
        ..lineTo(tx + math.cos(perpR) * size * 0.5, ty + math.sin(perpR) * size * 0.5)
        ..close();
      canvas.drawPath(_path, _targetTriPaint);
    }
  }

  void _drawHealthBar(Canvas canvas, UltraballPlayer p, Offset pos, double r) {
    final barW = r * 2.5;
    final barH = sm(0.4);
    final barX = pos.dx - barW / 2;
    final barY = pos.dy - r - barH - sm(0.3);

    canvas.drawRect(Rect.fromLTWH(barX, barY, barW, barH), _hpBgPaint);

    final healthFrac = (p.health / p.maxHealth).clamp(0.0, 1.0);
    if (healthFrac > 0) {
      final fillPaint = healthFrac > 0.5
          ? _hpGoodPaint
          : healthFrac > 0.25 ? _hpMedPaint : _hpBadPaint;
      canvas.drawRect(
          Rect.fromLTWH(barX, barY, barW * healthFrac, barH), fillPaint);
    }
  }

  void _drawThrowArcPreview(Canvas canvas) {
    final player = gs.selectedPlayer;
    if (player == null || !player.isChargingThrow) return;
    if (gs.ball.holderId != player.id) return;

    const hSpeed  = 20.0;
    const gravity = 20.0;
    final dist       = player.throwDistance;
    final flightTime = dist / hSpeed;
    final initVZ     = 0.5 * gravity * flightTime;
    const steps      = 24;

    // Arc paint (reuse _sp; shadow needs its own local because both are
    // needed in the same loop iteration)
    _sp
      ..color     = const Color(0xFFFFDD00).withValues(alpha: 0.75)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final shadowPaint = Paint()
      ..style      = PaintingStyle.stroke
      ..color      = const Color(0xFFFFDD00).withValues(alpha: 0.22)
      ..strokeWidth = 1.5
      ..strokeCap  = StrokeCap.round;

    final dotPaint = Paint()
      ..color = const Color(0xFFFFDD00).withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    Offset? prevArc;
    Offset? prevGround;

    for (int i = 1; i <= steps; i++) {
      final t     = (i / steps) * flightTime;
      final tPrev = ((i - 1) / steps) * flightTime;

      final wx = player.x + math.cos(player.facing) * hSpeed * t;
      final wy = player.y + math.sin(player.facing) * hSpeed * t;
      final z  = initVZ * t - 0.5 * gravity * t * t;

      final wxPrev = player.x + math.cos(player.facing) * hSpeed * tPrev;
      final wyPrev = player.y + math.sin(player.facing) * hSpeed * tPrev;
      final zPrev  = initVZ * tPrev - 0.5 * gravity * tPrev * tPrev;

      final groundPos = toScreen(wx, wy);
      final arcPos    = Offset(groundPos.dx, groundPos.dy - z * scale * 0.5);

      final groundPosPrev = prevGround ?? toScreen(wxPrev, wyPrev);
      final arcPosPrev    = prevArc ?? Offset(
          groundPosPrev.dx, groundPosPrev.dy - zPrev * scale * 0.5);

      if (i % 2 == 0) {
        canvas.drawLine(arcPosPrev, arcPos, _sp);
        canvas.drawLine(groundPosPrev, groundPos, shadowPaint);
      }

      if (i % 6 == 0) {
        canvas.drawCircle(arcPos, 3.0, dotPaint);
      }

      prevArc    = arcPos;
      prevGround = groundPos;
    }

    // Landing X marker
    final landWx  = player.x + math.cos(player.facing) * dist;
    final landWy  = player.y + math.sin(player.facing) * dist;
    final landPos = toScreen(landWx, landWy);

    _sp
      ..color     = const Color(0xFFFFDD00).withValues(alpha: 0.9)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    const xs = 6.0;
    canvas.drawLine(
      Offset(landPos.dx - xs, landPos.dy - xs),
      Offset(landPos.dx + xs, landPos.dy + xs),
      _sp,
    );
    canvas.drawLine(
      Offset(landPos.dx + xs, landPos.dy - xs),
      Offset(landPos.dx - xs, landPos.dy + xs),
      _sp,
    );

    // Distance label
    final distTp = _getDistTp(dist);
    distTp.paint(
        canvas, Offset(landPos.dx - distTp.width / 2, landPos.dy + xs + 2));
  }

  void _drawBall(Canvas canvas) {
    final ball = gs.ball;
    final groundPos = toScreen(ball.x, ball.y);
    final liftPixels = ball.zHeight * scale * 0.5;
    final pos = Offset(groundPos.dx, groundPos.dy - liftPixels);
    final r = sm(0.9);

    // Shadow for airborne ball
    if (ball.zHeight > 0) {
      final shadowR = r * (1.0 - (ball.zHeight / 10.0).clamp(0.0, 0.5));
      _fp.color = Colors.black.withValues(alpha: 0.35);
      canvas.drawOval(
        Rect.fromCenter(center: groundPos, width: shadowR * 2.4, height: shadowR * 0.9),
        _fp,
      );
    }

    // Charge color
    final charge = ball.chargePercent;
    Color ballColor;
    if (charge < 0.5) {
      ballColor = Color.lerp(
          const Color(0xFF88FF88), const Color(0xFFFFFF00), charge * 2)!;
    } else if (charge < 0.75) {
      ballColor = Color.lerp(
          const Color(0xFFFFFF00), const Color(0xFFFF8800), (charge - 0.5) * 4)!;
    } else if (charge < 0.9) {
      ballColor = Color.lerp(
          const Color(0xFFFF8800), const Color(0xFFFF2200), (charge - 0.75) * 6.67)!;
    } else {
      ballColor = const Color(0xFFFF0000);
    }

    // Glow
    if (ball.isHeld || ball.isInFlight) {
      _gp
        ..color = ballColor.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(pos, r * 2, _gp);
      _gp.maskFilter = null;
    }

    // Ball body
    _fp.color = ballColor;
    canvas.drawCircle(pos, r, _fp);

    // White core
    _fp.color = Colors.white.withValues(alpha: 0.85);
    canvas.drawCircle(pos, r * 0.45, _fp);

    // Charge arc
    if (ball.isHeld && charge > 0) {
      _sp
        ..color     = ballColor.withValues(alpha: 0.9)
        ..strokeWidth = sm(0.25)
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: pos, radius: r + sm(0.5)),
        -math.pi / 2,
        charge * 2 * math.pi,
        false,
        _sp,
      );
    }

    // In-flight trail
    if (ball.isInFlight) {
      final speed = math.sqrt(ball.velX * ball.velX + ball.velY * ball.velY);
      if (speed > 0) {
        final trailLen = sm(3.0);
        final trailDx  = -(ball.velX / speed) * trailLen;
        final trailDy  = -(ball.velY / speed) * trailLen;
        _sp
          ..color     = ballColor.withValues(alpha: 0.5)
          ..strokeWidth = r
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(pos, Offset(pos.dx + trailDx, pos.dy + trailDy), _sp);
      }
    }
  }

  // ====================================================================
  // 3D rendering
  // ====================================================================

  // Full 3D mode — rendering to be implemented.
  // Currently falls through to the 3/4 view as a placeholder.
  void _paintFull3D(Canvas canvas, Size size) {
    _paint3D(canvas, size);
  }

  void _paint3D(Canvas canvas, Size size) {
    if (_last3DSize != size) {
      _camera3D.update(size);
      _last3DSize = size;
    }

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), _bgPaint);

    // Ground zones (drawn back-to-front isn't strictly needed for flat quads,
    // but ordering endzones → channels → field keeps stripes on top)
    _draw3DQuad(canvas, 0, 0, 20, 40, _lEndPaint);
    _draw3DQuad(canvas, 20, -5, 30, 45, _channelPaint);
    _draw3DQuad(canvas, 110, -5, 120, 45, _channelPaint);
    _draw3DQuad(canvas, 120, 0, 140, 40, _rEndPaint);
    _draw3DQuad(canvas, 30, 0, 110, 40, _mainFieldPaint);
    for (int i = 0; i < 4; i++) {
      _draw3DQuad(canvas, 30.0 + i * 20.0, 0, 40.0 + i * 20.0, 40, _stripePaint);
    }
    _draw3DQuad(canvas, 30, -5, 110, 0, _channelPaint);
    _draw3DQuad(canvas, 30, 40, 110, 45, _channelPaint);

    _draw3DFieldOutline(canvas);
    _draw3DPhaseLines(canvas);
    _draw3DEntities(canvas);
    _draw3DThrowArcPreview(canvas);
    _drawDamageIndicators(canvas);
  }

  void _draw3DThrowArcPreview(Canvas canvas) {
    final player = gs.selectedPlayer;
    if (player == null || !player.isChargingThrow) return;
    if (gs.ball.holderId != player.id) return;

    const hSpeed  = 20.0;
    const gravity = 20.0;
    const zScale  = 1.2; // matches _draw3DPlayer / _draw3DBall lift
    final dist       = player.throwDistance;
    final flightTime = dist / hSpeed;
    final initVZ     = 0.5 * gravity * flightTime;
    const steps      = 24;

    _sp
      ..color     = const Color(0xFFFFDD00).withValues(alpha: 0.75)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final shadowPaint = Paint()
      ..style      = PaintingStyle.stroke
      ..color      = const Color(0xFFFFDD00).withValues(alpha: 0.22)
      ..strokeWidth = 1.5
      ..strokeCap  = StrokeCap.round;

    final dotPaint = Paint()
      ..color = const Color(0xFFFFDD00).withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    Offset? prevArc;
    Offset? prevGround;

    for (int i = 1; i <= steps; i++) {
      final t     = (i / steps) * flightTime;
      final tPrev = ((i - 1) / steps) * flightTime;

      final wx = player.x + math.cos(player.facing) * hSpeed * t;
      final wy = player.y + math.sin(player.facing) * hSpeed * t;
      final wz = (initVZ * t - 0.5 * gravity * t * t).clamp(0.0, double.infinity);

      final wxPrev = player.x + math.cos(player.facing) * hSpeed * tPrev;
      final wyPrev = player.y + math.sin(player.facing) * hSpeed * tPrev;
      final wzPrev = (initVZ * tPrev - 0.5 * gravity * tPrev * tPrev).clamp(0.0, double.infinity);

      final arcPos     = _camera3D.project(wx, wy, wz * zScale);
      final groundPos  = _camera3D.project(wx, wy, 0);
      final arcPosPrev = prevArc    ?? _camera3D.project(wxPrev, wyPrev, wzPrev * zScale);
      final gndPosPrev = prevGround ?? _camera3D.project(wxPrev, wyPrev, 0);

      if (arcPos != null && arcPosPrev != null && i % 2 == 0) {
        canvas.drawLine(arcPosPrev, arcPos, _sp);
      }
      if (groundPos != null && gndPosPrev != null && i % 2 == 0) {
        canvas.drawLine(gndPosPrev, groundPos, shadowPaint);
      }
      if (arcPos != null && i % 6 == 0) {
        canvas.drawCircle(arcPos, 3.0, dotPaint);
      }

      prevArc    = arcPos;
      prevGround = groundPos;
    }

    // Landing X marker
    final landWx = player.x + math.cos(player.facing) * dist;
    final landWy = player.y + math.sin(player.facing) * dist;
    final landPos = _camera3D.project(landWx, landWy, 0);
    if (landPos != null) {
      _sp
        ..color     = const Color(0xFFFFDD00).withValues(alpha: 0.9)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      const xs = 6.0;
      canvas.drawLine(Offset(landPos.dx - xs, landPos.dy - xs),
                      Offset(landPos.dx + xs, landPos.dy + xs), _sp);
      canvas.drawLine(Offset(landPos.dx + xs, landPos.dy - xs),
                      Offset(landPos.dx - xs, landPos.dy + xs), _sp);

      final distTp = _getDistTp(dist);
      distTp.paint(canvas, Offset(landPos.dx - distTp.width / 2, landPos.dy + xs + 2));
    }
  }

  void _draw3DQuad(Canvas canvas, double x0, double y0, double x1, double y1, Paint paint) {
    final p0 = _camera3D.project(x0, y0, 0);
    final p1 = _camera3D.project(x1, y0, 0);
    final p2 = _camera3D.project(x1, y1, 0);
    final p3 = _camera3D.project(x0, y1, 0);
    if (p0 == null || p1 == null || p2 == null || p3 == null) return;
    _path
      ..reset()
      ..moveTo(p0.dx, p0.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..close();
    canvas.drawPath(_path, paint);
  }

  void _draw3DLine(Canvas canvas, double x0, double y0, double z0,
                                   double x1, double y1, double z1, Paint paint) {
    final p0 = _camera3D.project(x0, y0, z0);
    final p1 = _camera3D.project(x1, y1, z1);
    if (p0 == null || p1 == null) return;
    canvas.drawLine(p0, p1, paint);
  }

  void _draw3DFieldOutline(Canvas canvas) {
    _sp
      ..color = const Color(0xFF888888).withValues(alpha: 0.7)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.butt;
    _draw3DLine(canvas, 0, 0, 0, 140, 0, 0, _sp);
    _draw3DLine(canvas, 140, 0, 0, 140, 40, 0, _sp);
    _draw3DLine(canvas, 140, 40, 0, 0, 40, 0, _sp);
    _draw3DLine(canvas, 0, 40, 0, 0, 0, 0, _sp);

    _sp
      ..color = const Color(0xFFAAAAAA).withValues(alpha: 0.5)
      ..strokeWidth = 1.0;
    for (final x in [20.0, 30.0, 110.0, 120.0]) {
      _draw3DLine(canvas, x, 0, 0, x, 40, 0, _sp);
    }

    _sp
      ..color = const Color(0xFF888888).withValues(alpha: 0.4)
      ..strokeWidth = 0.8;
    _draw3DLine(canvas, 70, 0, 0, 70, 40, 0, _sp);

    // Kill-zone border lines
    _sp
      ..color = const Color(0xFF991133).withValues(alpha: 0.55)
      ..strokeWidth = 1.0;
    _draw3DLine(canvas, 20, 0, 0, 120, 0, 0, _sp);
    _draw3DLine(canvas, 20, 40, 0, 120, 40, 0, _sp);
  }

  void _draw3DPhaseLines(Canvas canvas) {
    final positions = Ultraball.phaseLineXPositions;
    for (int i = 0; i < positions.length; i++) {
      final lineX = positions[i];
      final isActive = gs.ball.phaseLineActive[i];

      if (isActive) {
        _sp
          ..color = const Color(0xFF00FFFF).withValues(alpha: 0.15)
          ..strokeWidth = 8.0;
        _draw3DLine(canvas, lineX, 0, 0, lineX, 40, 0, _sp);
      }

      _sp
        ..color = isActive
            ? const Color(0xFF00FFFF).withValues(alpha: 0.8)
            : const Color(0xFF444444).withValues(alpha: 0.5)
        ..strokeWidth = isActive ? 2.0 : 1.0;
      _draw3DLine(canvas, lineX, 0, 0, lineX, 40, 0, _sp);
    }
  }

  void _draw3DEntities(Canvas canvas) {
    final List<(double, void Function())> items = [];

    // Creature
    final cr = gs.creature;
    final depCr = _camera3D.projectWithDepth(cr.x, cr.y, 0);
    if (depCr != null) {
      final pos = depCr.$1; final cw = depCr.$2;
      items.add((cw, () => _draw3DCreature(canvas, cr, pos, cw)));
    }

    // Players
    for (final pl in gs.fieldPlayers) {
      if (!pl.isAlive) continue;
      final dep = _camera3D.projectWithDepth(pl.x, pl.y, pl.zHeight * 1.2);
      if (dep == null) continue;
      final pos = dep.$1; final cw = dep.$2;
      items.add((cw, () => _draw3DPlayer(canvas, pl, pos, cw)));
    }

    // Ball
    {
      final ball = gs.ball;
      final dep = _camera3D.projectWithDepth(ball.x, ball.y, ball.zHeight * 1.2);
      if (dep != null) {
        final pos = dep.$1; final cw = dep.$2;
        items.add((cw, () => _draw3DBall(canvas, pos, cw)));
      }
    }

    // Sort farthest first (largest cw = furthest from camera)
    items.sort((a, b) => b.$1.compareTo(a.$1));
    for (final (_, draw) in items) { draw(); }
  }

  void _draw3DCreature(Canvas canvas, Creature creature, Offset pos, double cw) {
    final r = _camera3D.projectedRadius(creature.size, cw);

    if (creature.type == CreatureType.chaos && creature.isTelegraphing) {
      final telegraphColor = switch (creature.telegraphAction) {
        ChaosAction.stop     => const Color(0xFFFFCC00),
        ChaosAction.reverse  => const Color(0xFFFF6600),
        ChaosAction.burst    => const Color(0xFFFF2200),
        ChaosAction.teleport => const Color(0xFF00FFFF),
      };
      _gp
        ..color = telegraphColor.withValues(alpha: 0.06)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14.0);
      canvas.drawCircle(pos, r * 3.0, _gp);
      _gp.maskFilter = null;
    }

    _killZoneBorderPaint.strokeWidth = 1.5;
    canvas.drawCircle(pos, r, _killZoneFillPaint);
    canvas.drawCircle(pos, r, _killZoneBorderPaint);

    final bodyColor = switch (creature.type) {
      CreatureType.kraken => const Color(0xFF4B0082),
      CreatureType.dragon => const Color(0xFF8B0000),
      CreatureType.hydra  => const Color(0xFF006400),
      CreatureType.wraith => const Color(0xFF0D2744),
      CreatureType.chaos  => const Color(0xFF0A0010),
    };
    _fp.color = bodyColor;
    canvas.drawCircle(pos, r * 0.85, _fp);
    _fp.color = bodyColor.withValues(alpha: 0.6);
    canvas.drawCircle(pos, r * 0.6, _fp);

    final eyeR = r * 0.15;
    final eyeOff = r * 0.3;
    canvas.drawCircle(Offset(pos.dx - eyeOff, pos.dy - eyeOff * 0.5), eyeR, _eyePaint);
    canvas.drawCircle(Offset(pos.dx + eyeOff, pos.dy - eyeOff * 0.5), eyeR, _eyePaint);

    final nameTp = _getCreatureNameTp();
    nameTp.paint(canvas, Offset(pos.dx - nameTp.width / 2, pos.dy + r + 3));
  }

  void _draw3DPlayer(Canvas canvas, UltraballPlayer p, Offset pos, double cw) {
    final r = _camera3D.projectedRadius(1.2, cw);

    // Shadow for airborne players
    if (p.isAirborne) {
      final gndProj = _camera3D.project(p.x, p.y, 0);
      if (gndProj != null) {
        final heightFrac = (p.zHeight / 4.0).clamp(0.0, 1.0);
        _fp.color = Colors.black.withValues(alpha: 0.45 - heightFrac * 0.2);
        canvas.drawOval(
          Rect.fromCenter(center: gndProj, width: r * 2.2, height: r * 0.8),
          _fp,
        );
      }
    }

    if (p.id == gs.currentTargetId) {
      _sp
        ..color = const Color(0xFFFF2222).withValues(alpha: 0.9)
        ..strokeWidth = 2.0;
      canvas.drawCircle(pos, r + 5, _sp);
      _sp
        ..color = const Color(0xFFFF4444).withValues(alpha: 0.4)
        ..strokeWidth = 1.0;
      canvas.drawCircle(pos, r + 8, _sp);
    }

    if (p.isSelected) {
      _sp
        ..color = Colors.white.withValues(alpha: 0.9)
        ..strokeWidth = 2.0;
      canvas.drawCircle(pos, r + 4, _sp);
    }

    if (gs.ball.holderId == p.id) {
      _gp
        ..color = const Color(0xFFFFDD00).withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(pos, r + 6, _gp);
      _gp.maskFilter = null;
    }

    final teamColor = p.team == Team.player
        ? const Color(0xFF1E88E5)
        : const Color(0xFFE53935);
    _fp.color = teamColor;
    canvas.drawCircle(pos, r, _fp);
    _fp.color = teamColor.withValues(alpha: 0.6);
    canvas.drawCircle(pos, r * 0.7, _fp);

    if (p.isStunned) {
      _sp
        ..color = Colors.yellow.withValues(alpha: 0.6)
        ..strokeWidth = 1.5;
      canvas.drawCircle(pos, r + 2, _sp);
    }

    final numTp = _getPlayerNumTp(p.rosterIndex);
    numTp.paint(canvas, Offset(pos.dx - numTp.width / 2, pos.dy - numTp.height / 2));

    final barW = r * 2.5;
    const barH = 4.0;
    final barX = pos.dx - barW / 2;
    final barY = pos.dy - r - barH - 3;
    canvas.drawRect(Rect.fromLTWH(barX, barY, barW, barH), _hpBgPaint);
    final frac = (p.health / p.maxHealth).clamp(0.0, 1.0);
    if (frac > 0) {
      final hpPaint = frac > 0.5 ? _hpGoodPaint : frac > 0.25 ? _hpMedPaint : _hpBadPaint;
      canvas.drawRect(Rect.fromLTWH(barX, barY, barW * frac, barH), hpPaint);
    }
  }

  void _draw3DBall(Canvas canvas, Offset pos, double cw) {
    final ball = gs.ball;
    final r = _camera3D.projectedRadius(0.9, cw);

    final charge = ball.chargePercent;
    final Color ballColor;
    if (charge < 0.5) {
      ballColor = Color.lerp(
          const Color(0xFF88FF88), const Color(0xFFFFFF00), charge * 2)!;
    } else if (charge < 0.75) {
      ballColor = Color.lerp(
          const Color(0xFFFFFF00), const Color(0xFFFF8800), (charge - 0.5) * 4)!;
    } else if (charge < 0.9) {
      ballColor = Color.lerp(
          const Color(0xFFFF8800), const Color(0xFFFF2200), (charge - 0.75) * 6.67)!;
    } else {
      ballColor = const Color(0xFFFF0000);
    }

    if (ball.isHeld || ball.isInFlight) {
      _gp
        ..color = ballColor.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(pos, r * 2, _gp);
      _gp.maskFilter = null;
    }

    _fp.color = ballColor;
    canvas.drawCircle(pos, r, _fp);
    _fp.color = Colors.white.withValues(alpha: 0.85);
    canvas.drawCircle(pos, r * 0.45, _fp);

    if (ball.isHeld && charge > 0) {
      _sp
        ..color = ballColor.withValues(alpha: 0.9)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: pos, radius: r + 3),
        -math.pi / 2,
        charge * 2 * math.pi,
        false,
        _sp,
      );
    }

    if (ball.isInFlight) {
      final speed = math.sqrt(ball.velX * ball.velX + ball.velY * ball.velY);
      if (speed > 0) {
        _sp
          ..color = ballColor.withValues(alpha: 0.5)
          ..strokeWidth = r * 0.8
          ..strokeCap = StrokeCap.round;
        final trailLen = r * 3.0;
        final tdx = -(ball.velX / speed) * trailLen;
        final tdy = -(ball.velY / speed) * trailLen;
        canvas.drawLine(pos, Offset(pos.dx + tdx, pos.dy + tdy), _sp);
      }
    }
  }

  @override
  bool shouldRepaint(FieldPainter old) => false;
}
