import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/player.dart';
import '../models/ultraball.dart';
import '../models/creature.dart';
import 'game_state.dart';

class FieldPainter extends CustomPainter {
  final GameState gs;
  final double scale;
  final double offsetX;
  final double offsetY;

  FieldPainter({
    required this.gs,
    required this.scale,
    required this.offsetX,
    required this.offsetY,
  });

  Offset toScreen(double x, double y) {
    return Offset(x * scale + offsetX, y * scale + offsetY);
  }

  double sx(double x) => x * scale + offsetX;
  double sy(double y) => y * scale + offsetY;
  double sm(double m) => m * scale; // scale meters to pixels

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF0A0A14),
    );

    // 2. Left endzone (deep maroon) x=0–20, extends through creature channel zone
    _drawRect(canvas, 0, -5, 20, 50, const Color(0xFF3D0A0A));
    // Label stays in the field-center (y=20)
    _drawZoneLabel(canvas, 10, 20, gs.settings.awayTeamName, const Color(0xFFFF4444));

    // 3. Right endzone (deep blue) x=120–140, extends through creature channel zone
    _drawRect(canvas, 120, -5, 20, 50, const Color(0xFF0A0A3D));
    _drawZoneLabel(canvas, 130, 20, gs.settings.homeTeamName, const Color(0xFF4488FF));

    // 4. Left channel (dark purple) x=20–30, extends above and below the field
    _drawRect(canvas, 20, -5, 10, 50, const Color(0xFF1A0A2A));

    // 5. Right channel (dark purple) x=110–120, extends above and below the field
    _drawRect(canvas, 110, -5, 10, 50, const Color(0xFF1A0A2A));

    // 6. Main field (dark green) x=30–110
    _drawRect(canvas, 30, 0, 80, 40, const Color(0xFF0A1A0A));
    // Field stripes
    _drawFieldStripes(canvas);

    // 6b. Creature connecting strips — the creature travels along the very top
    // and bottom of the main field to move between the two scoring channels.
    // The channels themselves (steps 4 & 5) are already the creature's legs.
    _drawCreatureConnectingStrips(canvas);

    // 7. Phase lines
    _drawPhaseLines(canvas);

    // 8. Field markings
    _drawFieldMarkings(canvas);

    // 9. Creature
    _drawCreature(canvas);

    // 10. Players
    _drawPlayers(canvas);

    // 11. Throw arc preview (above players, below ball)
    _drawThrowArcPreview(canvas);

    // 12. Ball
    _drawBall(canvas);
  }

  void _drawRect(
    Canvas canvas,
    double x,
    double y,
    double w,
    double h,
    Color color,
  ) {
    canvas.drawRect(
      Rect.fromLTWH(sx(x), sy(y), sm(w), sm(h)),
      Paint()..color = color,
    );
  }

  void _drawZoneLabel(
    Canvas canvas,
    double cx,
    double cy,
    String label,
    Color color,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: label.toUpperCase(),
        style: TextStyle(
          color: color.withValues(alpha: 0.3),
          fontSize: sm(3.0).clamp(8.0, 28.0),
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(
      canvas,
      Offset(sx(cx) - tp.width / 2, sy(cy) - tp.height / 2),
    );
  }

  void _drawFieldStripes(Canvas canvas) {
    final paint = Paint()
      ..color = const Color(0xFF0D200D)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 4; i++) {
      final stripeX = 30.0 + i * 20.0;
      canvas.drawRect(
        Rect.fromLTWH(sx(stripeX), sy(0), sm(10), sm(40)),
        paint,
      );
    }
  }

  void _drawCreatureConnectingStrips(Canvas canvas) {
    // The creature's top/bottom connecting paths run OUTSIDE the field:
    // y=-5 to 0 (top) and y=40 to 45 (bottom), spanning x=20–120 to
    // bridge the two scoring channels. The channels already cover their
    // own extents; this fills the main-field gap between them.
    const cc = Color(0xFF1A0A2A);
    _drawRect(canvas, 30, -5, 80, 5, cc);
    _drawRect(canvas, 30, 40, 80, 5, cc);

    // Warning lines at the field boundary (y=0 and y=40) mark where the
    // creature channels meet the playable area.
    final warnPaint = Paint()
      ..color = const Color(0xFF991133).withValues(alpha: 0.55)
      ..strokeWidth = sm(0.2)
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(sx(20), sy(0)),  Offset(sx(120), sy(0)),  warnPaint);
    canvas.drawLine(Offset(sx(20), sy(40)), Offset(sx(120), sy(40)), warnPaint);
  }

  void _drawPhaseLines(Canvas canvas) {
    final positions = Ultraball.phaseLineXPositions;
    for (int i = 0; i < positions.length; i++) {
      final lineX = positions[i];
      final isActive = gs.ball.phaseLineActive[i];

      // Glow effect for active lines
      if (isActive) {
        // Outer glow
        final glowPaint = Paint()
          ..color = const Color(0xFF00FFFF).withValues(alpha: 0.15)
          ..strokeWidth = sm(1.5)
          ..style = PaintingStyle.stroke;
        canvas.drawLine(
          Offset(sx(lineX), sy(0)),
          Offset(sx(lineX), sy(40)),
          glowPaint,
        );
      }

      final linePaint = Paint()
        ..color = isActive
            ? const Color(0xFF00FFFF).withValues(alpha: 0.8)
            : const Color(0xFF444444).withValues(alpha: 0.5)
        ..strokeWidth = isActive ? sm(0.2) : sm(0.1)
        ..style = PaintingStyle.stroke;

      if (!isActive) {
        // Dashed line
        double y = 0;
        while (y < 40) {
          canvas.drawLine(
            Offset(sx(lineX), sy(y)),
            Offset(sx(lineX), sy(math.min(y + 2, 40))),
            linePaint,
          );
          y += 4;
        }
      } else {
        canvas.drawLine(
          Offset(sx(lineX), sy(0)),
          Offset(sx(lineX), sy(40)),
          linePaint,
        );
      }
    }
  }

  void _drawFieldMarkings(Canvas canvas) {
    final borderPaint = Paint()
      ..color = const Color(0xFF888888).withValues(alpha: 0.7)
      ..strokeWidth = sm(0.3)
      ..style = PaintingStyle.stroke;

    // Field border
    canvas.drawRect(
      Rect.fromLTWH(sx(0), sy(0), sm(140), sm(40)),
      borderPaint,
    );

    // Center line
    canvas.drawLine(
      Offset(sx(70), sy(0)),
      Offset(sx(70), sy(40)),
      Paint()
        ..color = const Color(0xFF888888).withValues(alpha: 0.4)
        ..strokeWidth = sm(0.15),
    );

    // Channel boundary lines
    for (final x in [20.0, 30.0, 110.0, 120.0]) {
      canvas.drawLine(
        Offset(sx(x), sy(0)),
        Offset(sx(x), sy(40)),
        Paint()
          ..color = const Color(0xFFAAAAAA).withValues(alpha: 0.5)
          ..strokeWidth = sm(0.2),
      );
    }
  }

  void _drawCreature(Canvas canvas) {
    final creature = gs.creature;
    final pos = toScreen(creature.x, creature.y);
    final r = sm(creature.size);

    // Kill zone indicator
    final killZonePaint = Paint()
      ..color = const Color(0xFFFF0000).withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pos, r, killZonePaint);

    final killZoneBorderPaint = Paint()
      ..color = const Color(0xFFFF0000).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = sm(0.2);
    canvas.drawCircle(pos, r, killZoneBorderPaint);

    // Creature body color based on type
    final bodyColor = switch (creature.type) {
      CreatureType.kraken => const Color(0xFF4B0082),
      CreatureType.dragon => const Color(0xFF8B0000),
      CreatureType.hydra => const Color(0xFF006400),
    };

    // Body
    final bodyPaint = Paint()..color = bodyColor;
    canvas.drawCircle(pos, r * 0.85, bodyPaint);

    // Inner detail
    canvas.drawCircle(
      pos,
      r * 0.6,
      Paint()..color = bodyColor.withValues(alpha: 0.6),
    );

    // Red eyes
    final eyeOffset = r * 0.3;
    final eyeR = r * 0.15;
    final eyePaint = Paint()..color = const Color(0xFFFF3300);
    canvas.drawCircle(Offset(pos.dx - eyeOffset, pos.dy - eyeOffset * 0.5), eyeR, eyePaint);
    canvas.drawCircle(Offset(pos.dx + eyeOffset, pos.dy - eyeOffset * 0.5), eyeR, eyePaint);

    // Creature name label
    final nameTp = TextPainter(
      text: TextSpan(
        text: creature.name,
        style: TextStyle(
          color: const Color(0xFFFFAAAA),
          fontSize: sm(1.5).clamp(8.0, 14.0),
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    nameTp.layout();
    nameTp.paint(
      canvas,
      Offset(pos.dx - nameTp.width / 2, pos.dy + r + sm(0.5)),
    );
  }

  void _drawPlayers(Canvas canvas) {
    final alive = gs.fieldPlayers.where((p) => p.isAlive).toList();

    // Pass 1: ground shadows for airborne players (draw before bodies)
    for (final p in alive) {
      if (p.isAirborne) _drawJumpShadow(canvas, p);
    }

    // Pass 2: player bodies (elevated upward on screen when airborne)
    for (final p in alive) {
      _drawPlayer(canvas, p);
    }
  }

  /// Soft dark ellipse at the player's ground position when they're airborne.
  void _drawJumpShadow(Canvas canvas, UltraballPlayer p) {
    final groundPos = toScreen(p.x, p.y);
    // Shadow shrinks as height increases — feel of distance from ground
    final heightFrac = (p.zHeight / 4.0).clamp(0.0, 1.0);
    final shadowR = sm(1.2) * (1.0 - heightFrac * 0.5);
    canvas.drawOval(
      Rect.fromCenter(
        center: groundPos,
        width: shadowR * 2.2,
        height: shadowR * 0.8,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.45 - heightFrac * 0.2),
    );
  }

  void _drawPlayer(Canvas canvas, UltraballPlayer p) {
    // Airborne players are drawn upward on screen to show altitude
    final groundPos = toScreen(p.x, p.y);
    // 0.5 converts zHeight meters into a reasonable pixel offset (half the scale)
    final liftPixels = p.zHeight * scale * 0.5;
    final pos = Offset(groundPos.dx, groundPos.dy - liftPixels);
    final r = sm(1.2);
    final isTarget = p.id == gs.currentTargetId;

    // Target ring (red, below everything else for this player)
    if (isTarget) {
      final targetPaint = Paint()
        ..color = const Color(0xFFFF2222).withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = sm(0.3);
      canvas.drawCircle(pos, r + sm(0.9), targetPaint);
      // Second spinning-style ring (static double-ring look)
      canvas.drawCircle(
        pos,
        r + sm(1.4),
        Paint()
          ..color = const Color(0xFFFF4444).withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = sm(0.12),
      );
      // Target indicator triangles at cardinal positions
      _drawTargetTriangles(canvas, pos, r + sm(1.7));
    }

    // Selection ring (white double-ring for controlled player)
    if (p.isSelected) {
      canvas.drawCircle(
        pos,
        r + sm(0.6),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = sm(0.25),
      );
      canvas.drawCircle(
        pos,
        r + sm(1.0),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = sm(0.1),
      );
    }

    // Ball holder glow
    if (gs.ball.holderId == p.id) {
      final glowPaint = Paint()
        ..color = const Color(0xFFFFDD00).withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(pos, r + sm(0.8), glowPaint);
    }

    // Player body
    final teamColor = p.team == Team.player
        ? const Color(0xFF1E88E5)
        : const Color(0xFFE53935);

    canvas.drawCircle(pos, r, Paint()..color = teamColor);
    canvas.drawCircle(
      pos,
      r * 0.7,
      Paint()..color = teamColor.withValues(alpha: 0.6),
    );

    // Facing direction wedge — drawn on top of body
    _drawFacingIndicator(canvas, p, pos, r, teamColor);

    // Stunned indicator
    if (p.isStunned) {
      canvas.drawCircle(
        pos,
        r + sm(0.3),
        Paint()
          ..color = Colors.yellow.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = sm(0.2),
      );
    }

    // Player number
    final numTp = TextPainter(
      text: TextSpan(
        text: '${p.rosterIndex + 1}',
        style: TextStyle(
          color: Colors.white,
          fontSize: sm(1.1).clamp(6.0, 12.0),
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    numTp.layout();
    numTp.paint(
      canvas,
      Offset(pos.dx - numTp.width / 2, pos.dy - numTp.height / 2),
    );

    // Health bar
    _drawHealthBar(canvas, p, pos, r);
  }

  /// Draws a small wedge/arrow from the player center indicating facing direction.
  void _drawFacingIndicator(
    Canvas canvas,
    UltraballPlayer p,
    Offset center,
    double r,
    Color teamColor,
  ) {
    final f = p.facing;
    // Arrow tip at edge of body in facing direction
    final tipDist = r * 1.1;
    final tip = Offset(
      center.dx + math.cos(f) * tipDist,
      center.dy + math.sin(f) * tipDist,
    );

    // Two base points forming the wedge base
    const halfAngle = 0.55; // ~31 degrees half-angle
    final baseR = r * 0.45;
    final left = Offset(
      center.dx + math.cos(f + math.pi - halfAngle) * baseR,
      center.dy + math.sin(f + math.pi - halfAngle) * baseR,
    );
    final right = Offset(
      center.dx + math.cos(f + math.pi + halfAngle) * baseR,
      center.dy + math.sin(f + math.pi + halfAngle) * baseR,
    );

    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();

    canvas.drawPath(
      path,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  /// Draws four small inward-pointing triangles around a target (WoW-style target ring).
  void _drawTargetTriangles(Canvas canvas, Offset center, double radius) {
    final paint = Paint()..color = const Color(0xFFFF3333).withValues(alpha: 0.9);
    const size = 5.0;
    for (int i = 0; i < 4; i++) {
      final angle = i * math.pi / 2;
      final tx = center.dx + math.cos(angle) * radius;
      final ty = center.dy + math.sin(angle) * radius;
      // Triangle pointing inward (toward center)
      final inward = angle + math.pi;
      final perpL = angle + math.pi / 2;
      final perpR = angle - math.pi / 2;
      final path = Path()
        ..moveTo(tx + math.cos(inward) * size, ty + math.sin(inward) * size)
        ..lineTo(tx + math.cos(perpL) * size * 0.5, ty + math.sin(perpL) * size * 0.5)
        ..lineTo(tx + math.cos(perpR) * size * 0.5, ty + math.sin(perpR) * size * 0.5)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  void _drawHealthBar(
    Canvas canvas,
    UltraballPlayer p,
    Offset pos,
    double r,
  ) {
    final barW = r * 2.5;
    final barH = sm(0.4);
    final barX = pos.dx - barW / 2;
    final barY = pos.dy - r - barH - sm(0.3);

    // Background
    canvas.drawRect(
      Rect.fromLTWH(barX, barY, barW, barH),
      Paint()..color = const Color(0xFF333333),
    );

    // Health fill
    final healthFrac = (p.health / p.maxHealth).clamp(0.0, 1.0);
    final fillColor = healthFrac > 0.5
        ? const Color(0xFF44FF44)
        : healthFrac > 0.25
            ? const Color(0xFFFFAA00)
            : const Color(0xFFFF2222);

    if (healthFrac > 0) {
      canvas.drawRect(
        Rect.fromLTWH(barX, barY, barW * healthFrac, barH),
        Paint()..color = fillColor,
      );
    }
  }

  void _drawThrowArcPreview(Canvas canvas) {
    final player = gs.selectedPlayer;
    if (player == null || !player.isChargingThrow) return;
    if (gs.ball.holderId != player.id) return;

    const hSpeed = 20.0;
    const gravity = 20.0;
    final dist = player.throwDistance;
    final flightTime = dist / hSpeed;
    final initVZ = 0.5 * gravity * flightTime;

    const steps = 24;

    final arcPaint = Paint()
      ..color = const Color(0xFFFFDD00).withValues(alpha: 0.75)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final shadowPaint = Paint()
      ..color = const Color(0xFFFFDD00).withValues(alpha: 0.22)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = const Color(0xFFFFDD00).withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    Offset? prevArc;
    Offset? prevGround;

    for (int i = 1; i <= steps; i++) {
      final t = (i / steps) * flightTime;
      final tPrev = ((i - 1) / steps) * flightTime;

      final wx = player.x + math.cos(player.facing) * hSpeed * t;
      final wy = player.y + math.sin(player.facing) * hSpeed * t;
      final z = initVZ * t - 0.5 * gravity * t * t;

      final wxPrev = player.x + math.cos(player.facing) * hSpeed * tPrev;
      final wyPrev = player.y + math.sin(player.facing) * hSpeed * tPrev;
      final zPrev = initVZ * tPrev - 0.5 * gravity * tPrev * tPrev;

      final groundPos = toScreen(wx, wy);
      final arcPos = Offset(groundPos.dx, groundPos.dy - z * scale * 0.5);

      final groundPosPrev = prevGround ?? toScreen(wxPrev, wyPrev);
      final zPrevLift = zPrev * scale * 0.5;
      final arcPosPrev = prevArc ?? Offset(groundPosPrev.dx, groundPosPrev.dy - zPrevLift);

      // Draw every other segment for dashed effect
      if (i % 2 == 0) {
        canvas.drawLine(arcPosPrev, arcPos, arcPaint);
        canvas.drawLine(groundPosPrev, groundPos, shadowPaint);
      }

      // Dots at intervals
      if (i % 6 == 0) {
        canvas.drawCircle(arcPos, 3.0, dotPaint);
      }

      prevArc = arcPos;
      prevGround = groundPos;
    }

    // Landing X marker
    final landWx = player.x + math.cos(player.facing) * dist;
    final landWy = player.y + math.sin(player.facing) * dist;
    final landPos = toScreen(landWx, landWy);

    final xPaint = Paint()
      ..color = const Color(0xFFFFDD00).withValues(alpha: 0.9)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    const xs = 6.0;
    canvas.drawLine(
      Offset(landPos.dx - xs, landPos.dy - xs),
      Offset(landPos.dx + xs, landPos.dy + xs),
      xPaint,
    );
    canvas.drawLine(
      Offset(landPos.dx + xs, landPos.dy - xs),
      Offset(landPos.dx - xs, landPos.dy + xs),
      xPaint,
    );

    // Distance label at landing spot
    final distTp = TextPainter(
      text: TextSpan(
        text: '${dist.toStringAsFixed(0)}m',
        style: TextStyle(
          color: const Color(0xFFFFDD00).withValues(alpha: 0.85),
          fontSize: sm(1.2).clamp(8.0, 13.0),
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    distTp.layout();
    distTp.paint(
      canvas,
      Offset(landPos.dx - distTp.width / 2, landPos.dy + xs + 2),
    );
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
      canvas.drawOval(
        Rect.fromCenter(
          center: groundPos,
          width: shadowR * 2.4,
          height: shadowR * 0.9,
        ),
        Paint()..color = Colors.black.withValues(alpha: 0.35),
      );
    }

    // Charge color
    final charge = ball.chargePercent;
    Color ballColor;
    if (charge < 0.5) {
      ballColor = Color.lerp(
        const Color(0xFF88FF88),
        const Color(0xFFFFFF00),
        charge * 2,
      )!;
    } else if (charge < 0.75) {
      ballColor = Color.lerp(
        const Color(0xFFFFFF00),
        const Color(0xFFFF8800),
        (charge - 0.5) * 4,
      )!;
    } else if (charge < 0.9) {
      ballColor = Color.lerp(
        const Color(0xFFFF8800),
        const Color(0xFFFF2200),
        (charge - 0.75) * 6.67,
      )!;
    } else {
      // Critical: pulsing red (use time-based factor for real pulsing)
      ballColor = const Color(0xFFFF0000);
    }

    // Glow
    if (ball.isHeld || ball.isInFlight) {
      final glowPaint = Paint()
        ..color = ballColor.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(pos, r * 2, glowPaint);
    }

    // Ball body
    canvas.drawCircle(pos, r, Paint()..color = ballColor);

    // White core
    canvas.drawCircle(
      pos,
      r * 0.45,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );

    // Charge arc (drawn around ball)
    if (ball.isHeld && charge > 0) {
      final arcRect = Rect.fromCircle(center: pos, radius: r + sm(0.5));
      canvas.drawArc(
        arcRect,
        -math.pi / 2,
        charge * 2 * math.pi,
        false,
        Paint()
          ..color = ballColor.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = sm(0.25)
          ..strokeCap = StrokeCap.round,
      );
    }

    // In-flight trail
    if (ball.isInFlight) {
      final speed = math.sqrt(ball.velX * ball.velX + ball.velY * ball.velY);
      if (speed > 0) {
        final trailLen = sm(3.0);
        final trailDx = -(ball.velX / speed) * trailLen;
        final trailDy = -(ball.velY / speed) * trailLen;
        canvas.drawLine(
          pos,
          Offset(pos.dx + trailDx, pos.dy + trailDy),
          Paint()
            ..color = ballColor.withValues(alpha: 0.5)
            ..strokeWidth = r
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  @override
  bool shouldRepaint(FieldPainter oldDelegate) => true;
}
