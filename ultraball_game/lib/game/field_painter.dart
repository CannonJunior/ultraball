import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart' show Vector3;
import '../models/player.dart';
import '../models/ultraball.dart';
import '../models/creature.dart';
import '../models/damage_indicator.dart';
import '../models/game_settings.dart';
import '../models/terrain_grid.dart';
import 'game_state.dart';
import 'camera_3d.dart';
import '../game3d/ultraball_render_system.dart';
import '../ui/ui_assets.dart';

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
  /// When true the active renderer centres its camera on the ball each frame.
  bool ballCam = false;
  bool _prevBallCam = false; // detects toggle so we can force one camera rebuild

  final Camera3D _camera3D = Camera3D();
  Size _last3DSize = Size.zero;

  // Set by GameWidget after renderer init (full3D mode only)
  UltraballRenderSystem? renderSystem;

  FieldPainter({required this.gs, required Listenable repaint})
      : super(repaint: repaint);

  // ---- Screen-space helpers ----
  double sx(double x) => x * scale + offsetX;
  double sy(double y) => y * scale + offsetY;
  double sm(double m) => m * scale;
  Offset toScreen(double x, double y) => Offset(sx(x), sy(y));

  Offset? projectPlayer(UltraballPlayer p, Size canvasSize) {
    switch (viewMode) {
      case ViewMode.flat:
        return Offset(sx(p.x), sy(p.y));
      case ViewMode.threeQuarter:
        _camera3D.update(canvasSize);
        return _camera3D.project(p.x, p.y, p.zHeight * 1.2);
      case ViewMode.full3D:
        return renderSystem?.project(Vector3(p.x, p.zHeight, p.y), canvasSize);
    }
  }

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
  // Throw-arc preview — allocated once, mutated before each use
  final Paint _arcShadowPaint = Paint()
    ..style      = PaintingStyle.stroke
    ..color      = const Color(0x38FFDD00)   // 0.22 alpha
    ..strokeWidth = 1.5
    ..strokeCap  = StrokeCap.round;
  final Paint _arcDotPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = const Color(0xE6FFDD00);       // 0.90 alpha

  // ====================================================================
  // Reusable Path — reset before each use via ..reset()
  // ====================================================================
  final Path _path = Path();

  // ====================================================================
  // Depth-sort buffer — reused every frame instead of allocating new list
  // ====================================================================
  final List<(double, void Function())> _depthItems = [];

  // ====================================================================
  // Damage indicator TextPainter cache — keyed by indicator instance,
  // layout runs once on first encounter; saveLayer provides per-frame opacity
  // ====================================================================
  final Expando<TextPainter> _indicatorTp = Expando();
  final Paint _indicatorLayerPaint = Paint();

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

  // Ball-cam: update scale/offsetX/offsetY to centre the viewport on the ball.
  // Called at the top of paint() so all sx/sy/sm helpers use the right transform.
  void _applyBallCamTransform(Size size) {
    const viewW = 42.0; // world units visible horizontally
    final viewH = viewW * size.height / size.width;
    final camScale = size.width / viewW;
    final ball = gs.ball;
    final cx = ball.x.clamp(viewW / 2, 140.0 - viewW / 2);
    final cy = ball.y.clamp(viewH / 2, 40.0 - viewH / 2);
    scale   = camScale;
    offsetX = size.width  / 2 - cx * camScale;
    offsetY = size.height / 2 - cy * camScale;
    // Force dash-path cache rebuild since offset changes every frame
    _dashScale = -1;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (viewMode == ViewMode.threeQuarter) { _paint3D(canvas, size); return; }
    if (viewMode == ViewMode.full3D) { _paintFull3D(canvas, size); return; }

    if (ballCam) _applyBallCamTransform(size);

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
    if (gs.prefs.showPhaseLines) _drawPhaseLines(canvas);

    // 8. Field markings
    _drawFieldMarkings(canvas);

    // 8b. Terrain overlays (hills, pits, hazards)
    _drawTerrainOverlay(canvas);

    // 9. Creature
    _drawCreature(canvas);

    // 9b. Trickster traps
    _drawTricksterTraps(canvas);

    // 10. Players
    _drawPlayers(canvas);

    // 10b. Status effects (hex, confusion rings)
    _drawStatusEffects(canvas);

    // 11. Throw arc preview
    _drawThrowArcPreview(canvas);

    // 11b. Terrain aim reticle
    _drawTerrainAimReticle(canvas);

    // 11c. Ability range circle (hovered icon)
    _drawAbilityRangeCircle(canvas);

    // 12. Ball
    _drawBall(canvas);

    // 13. Damage indicators
    if (gs.prefs.showDamageIndicators) _drawDamageIndicators(canvas);

    // 14. Ability queue overlay (above selected player)
    _drawAbilityQueueOverlay(canvas, size);
  }

  void _drawTerrainOverlay(Canvas canvas) {
    final t       = gs.matchTimeElapsed;
    final terrain = gs.terrain.cells;

    gs.terrain.forEach((col, row, cell) {
      if (cell.surface == SurfaceType.normal && !cell.isPit &&
          cell.height.abs() < 0.05 && cell.targetHeight.abs() < 0.05) return;

      final wx   = col * kCellW;
      final wy   = row * kCellH;
      final rect = Rect.fromLTWH(sx(wx), sy(wy), sm(kCellW), sm(kCellH));
      final cx   = rect.center.dx;
      final cy   = rect.center.dy;
      final cw   = rect.width;
      final ch   = rect.height;

      if (cell.isPit) {
        _drawPitCell(canvas, rect, cx, cy, cw, ch, cell, col, row, terrain, t);
      } else if (cell.surface == SurfaceType.lava) {
        _drawLavaCell(canvas, rect, cx, cy, cw, ch, t);
      } else if (cell.surface == SurfaceType.ice) {
        _drawIceCell(canvas, rect, cw, ch, col, row, t);
      } else if (cell.surface == SurfaceType.mud) {
        _drawMudCell(canvas, rect, cx, cy, cw, ch, col, row, t);
      } else if (cell.height > 0.5) {
        _drawHillCell(canvas, rect, cx, cy, cw, ch, cell);
      } else if (cell.height < -0.5) {
        _drawValleyCell(canvas, rect, cx, cy, cw, ch, cell);
      }
    });
  }

  void _drawTerrainOverlay3D(Canvas canvas) {
    final t = gs.matchTimeElapsed;
    gs.terrain.forEach((col, row, cell) {
      if (cell.surface == SurfaceType.normal && !cell.isPit &&
          cell.height.abs() < 0.05 && cell.targetHeight.abs() < 0.05) return;

      final x0 = col * kCellW;
      final y0 = row * kCellH;
      final x1 = x0 + kCellW;
      final y1 = y0 + kCellH;

      if (cell.isPit) {
        final depth = (-cell.height / 3.0).clamp(0.0, 1.0);
        _fp.color = Color.fromARGB((185 * depth).toInt(), 30, 18, 38);
        _draw3DQuad(canvas, x0, y0, x1, y1, _fp);
        final ix = kCellW * 0.18; final iy = kCellH * 0.18;
        _fp.color = Color.fromARGB((215 * depth).toInt(), 12, 6, 20);
        _draw3DQuad(canvas, x0 + ix, y0 + iy, x1 - ix, y1 - iy, _fp);
        final ix2 = kCellW * 0.38; final iy2 = kCellH * 0.38;
        _fp.color = Color.fromARGB((245 * depth).toInt(), 3, 0, 8);
        _draw3DQuad(canvas, x0 + ix2, y0 + iy2, x1 - ix2, y1 - iy2, _fp);
        if (depth > 0.65) {
          final pulse = (math.sin(t * 2.8) * 0.5 + 0.5) * ((depth - 0.65) / 0.35);
          _fp.color = Color.fromARGB((50 * pulse).toInt(), 100, 0, 180);
          _draw3DQuad(canvas, x0, y0, x1, y1, _fp);
        }
      } else if (cell.surface == SurfaceType.lava) {
        _fp.color = const Color(0xD9FF3300);
        _draw3DQuad(canvas, x0, y0, x1, y1, _fp);
        final b1 = math.sin(t * 2.3 + x0 * 0.07 + y0 * 0.11) * 0.5 + 0.5;
        _fp.color = Color.fromARGB((90 + (b1 * 70).toInt()), 255, 190, 0);
        _draw3DQuad(canvas, x0 + kCellW * 0.2, y0 + kCellH * 0.2,
                             x1 - kCellW * 0.2, y1 - kCellH * 0.2, _fp);
      } else if (cell.surface == SurfaceType.ice) {
        _fp.color = const Color(0x7788CCFF);
        _draw3DQuad(canvas, x0, y0, x1, y1, _fp);
      } else if (cell.surface == SurfaceType.mud) {
        _fp.color = const Color(0xCC5C3A1A);
        _draw3DQuad(canvas, x0, y0, x1, y1, _fp);
      } else if (cell.height > 0.5) {
        final h = cell.height;
        _fp.color = Color.fromARGB(180, (30 + h * 8).toInt().clamp(0, 255), 100, 20);
        _draw3DQuadAtZ(canvas, x0, y0, x1, y1, h, _fp);
      }
    });
  }

  // ── Pit / Sinkhole ─────────────────────────────────────────────────────────

  void _drawPitCell(Canvas canvas, Rect rect, double cx, double cy,
      double cw, double ch, TerrainCell cell, int col, int row,
      List<List<TerrainCell>> terrain, double t) {
    final depth = (-cell.height / 3.0).clamp(0.0, 1.0);

    // Three concentric layers simulating depth: outer rim → mid ring → void core
    _fp.color = Color.fromARGB((185 * depth).toInt(), 30, 18, 38);
    canvas.drawRect(rect, _fp);

    _fp.color = Color.fromARGB((215 * depth).toInt(), 12, 6, 20);
    canvas.drawRect(Rect.fromLTRB(
        rect.left + cw * 0.18, rect.top + ch * 0.18,
        rect.right - cw * 0.18, rect.bottom - ch * 0.18), _fp);

    _fp.color = Color.fromARGB((245 * depth).toInt(), 3, 0, 8);
    canvas.drawRect(Rect.fromLTRB(
        rect.left + cw * 0.38, rect.top + ch * 0.38,
        rect.right - cw * 0.38, rect.bottom - ch * 0.38), _fp);

    // Pulsing purple void glow on fully-open pits
    if (depth > 0.65) {
      final pulse = (math.sin(t * 2.8) * 0.5 + 0.5) * ((depth - 0.65) / 0.35);
      _fp.color = Color.fromARGB((50 * pulse).toInt(), 100, 0, 180);
      canvas.drawRect(rect, _fp);
    }

    // Edge cracks on outer faces (sides not adjacent to another pit cell)
    final noLeft   = col == 0               || !terrain[col - 1][row].isPit;
    final noRight  = col >= kTerrainCols - 1 || !terrain[col + 1][row].isPit;
    final noTop    = row == 0               || !terrain[col][row - 1].isPit;
    final noBottom = row >= kTerrainRows - 1 || !terrain[col][row + 1].isPit;

    if (depth > 0.08) {
      _sp.strokeWidth = (sm(0.22)).clamp(1.0, 3.5);
      final seed = col * 53 + row * 97;

      // Draws 2 cracks radiating inward from an edge segment [a → b]
      void drawEdgeCracks(Offset a, Offset b, int kseed) {
        for (int k = 0; k < 2; k++) {
          final frac  = 0.28 + k * 0.44;
          final ex    = a.dx + (b.dx - a.dx) * frac;
          final ey    = a.dy + (b.dy - a.dy) * frac;
          final angle = math.atan2(cy - ey, cx - ex) +
              ((kseed + k * 7) % 9 - 4) * 0.18;
          final len   = (cw * 0.14 + (kseed % 7) * cw * 0.028) * depth;
          _sp.color = Color.fromARGB(
              (190 * depth).toInt(),
              130 + (kseed * 3 % 40), 80 + (kseed % 28), 40);
          canvas.drawLine(
              Offset(ex, ey),
              Offset(ex + math.cos(angle) * len, ey + math.sin(angle) * len),
              _sp);
          // Secondary fork off the first crack
          if (depth > 0.4 && k == 0) {
            final angle2 = angle + 0.5;
            final len2   = len * 0.55;
            final midX   = ex + math.cos(angle) * len * 0.5;
            final midY   = ey + math.sin(angle) * len * 0.5;
            _sp.color = Color.fromARGB(
                (130 * depth).toInt(), 110, 70, 35);
            canvas.drawLine(Offset(midX, midY),
                Offset(midX + math.cos(angle2) * len2,
                       midY + math.sin(angle2) * len2), _sp);
          }
        }
      }

      if (noLeft)   drawEdgeCracks(rect.topLeft,    rect.bottomLeft,  seed);
      if (noRight)  drawEdgeCracks(rect.topRight,   rect.bottomRight, seed + 20);
      if (noTop)    drawEdgeCracks(rect.topLeft,     rect.topRight,   seed + 40);
      if (noBottom) drawEdgeCracks(rect.bottomLeft, rect.bottomRight, seed + 60);
    }
  }

  // ── Lava Pool ──────────────────────────────────────────────────────────────

  void _drawLavaCell(Canvas canvas, Rect rect, double cx, double cy,
      double cw, double ch, double t) {
    // Base orange-red fill
    _fp.color = const Color(0xD9FF3300);
    canvas.drawRect(rect, _fp);

    // Animated yellow/orange hot bubbles (2 per cell, offset by cell position)
    final b1 = math.sin(t * 2.3 + cx * 0.07 + cy * 0.11) * 0.5 + 0.5;
    _fp.color = Color.fromARGB((90 + (b1 * 70).toInt()), 255, 190, 0);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx - cw * 0.17, cy + ch * 0.10),
            width: cw * 0.38, height: ch * 0.32),
        _fp);

    final b2 = math.sin(t * 1.7 + cx * 0.13 + cy * 0.08) * 0.5 + 0.5;
    _fp.color = Color.fromARGB((70 + (b2 * 55).toInt()), 255, 230, 20);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx + cw * 0.16, cy - ch * 0.14),
            width: cw * 0.28, height: ch * 0.24),
        _fp);

    // Dark red cooling-crust cracks (static, cell-position-based)
    _sp.color = const Color(0x99880000);
    _sp.strokeWidth = (sm(0.18)).clamp(1.0, 2.5);
    final ang = (cx * 0.3 + cy * 0.17) % (math.pi);
    canvas.drawLine(
        Offset(rect.left + cw * 0.15, cy + ch * 0.1 * math.sin(ang)),
        Offset(rect.right - cw * 0.15, cy - ch * 0.1 * math.sin(ang)),
        _sp);
    canvas.drawLine(
        Offset(cx + cw * 0.08 * math.cos(ang), rect.top + ch * 0.2),
        Offset(cx - cw * 0.08 * math.cos(ang), rect.bottom - ch * 0.2),
        _sp);

    // Bright edge glow
    _sp.color = const Color(0x66FF8800);
    _sp.strokeWidth = (sm(0.35)).clamp(1.5, 4.0);
    canvas.drawRect(rect, _sp);
  }

  // ── Ice Patch ──────────────────────────────────────────────────────────────

  void _drawIceCell(Canvas canvas, Rect rect, double cw, double ch,
      int col, int row, double t) {
    // Translucent blue base
    _fp.color = const Color(0x7788CCFF);
    canvas.drawRect(rect, _fp);

    // Crystalline diagonal highlight lines (deterministic per cell)
    _sp.color = const Color(0xAADDEEFF);
    _sp.strokeWidth = (sm(0.12)).clamp(0.8, 2.0);
    final seed = col * 41 + row * 71;
    for (int i = 0; i < 3; i++) {
      final frac = 0.15 + i * 0.35 + (seed % 7) * 0.02;
      // Diagonal: top-left area to bottom-right
      canvas.drawLine(
          Offset(rect.left + cw * frac, rect.top),
          Offset(rect.left, rect.top + ch * frac),
          _sp);
      // Cross-diagonal
      canvas.drawLine(
          Offset(rect.right - cw * frac, rect.top),
          Offset(rect.right, rect.top + ch * frac),
          _sp);
    }

    // Subtle shimmer — tiny bright spot that drifts
    final shimX = rect.left + cw * (0.3 + math.sin(t * 1.9 + col * 0.8) * 0.25);
    final shimY = rect.top  + ch * (0.3 + math.cos(t * 2.1 + row * 0.9) * 0.25);
    _fp.color = const Color(0x44FFFFFF);
    canvas.drawCircle(Offset(shimX, shimY), (cw * 0.12).clamp(2.0, 8.0), _fp);

    // Light blue border
    _sp.color = const Color(0x9999DDFF);
    _sp.strokeWidth = (sm(0.20)).clamp(1.0, 3.0);
    canvas.drawRect(rect, _sp);
  }

  // ── Mud Zone ───────────────────────────────────────────────────────────────

  void _drawMudCell(Canvas canvas, Rect rect, double cx, double cy,
      double cw, double ch, int col, int row, double t) {
    // Dark brown base
    _fp.color = const Color(0xCC5C3A1A);
    canvas.drawRect(rect, _fp);

    // Irregular darker mud patches (deterministic)
    _fp.color = const Color(0x993D2410);
    final seed = col * 67 + row * 43;
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx + cw * ((seed % 7 - 3) * 0.08),
                           cy + ch * ((seed % 5 - 2) * 0.10)),
            width: cw * (0.45 + (seed % 5) * 0.05),
            height: ch * (0.35 + (seed % 4) * 0.04)),
        _fp);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx - cw * 0.20 + cw * ((seed % 3) * 0.06),
                           cy + ch * 0.18 + ch * ((seed % 4 - 2) * 0.05)),
            width: cw * 0.28, height: ch * 0.22),
        _fp);

    // Slow "bubble" rising once every ~3s per cell
    final bubblePhase = (t * 0.33 + (seed % 10) * 0.1) % 1.0;
    if (bubblePhase > 0.6) {
      final bAlpha = ((bubblePhase - 0.6) / 0.4 * 180).toInt();
      final bScale = (bubblePhase - 0.6) / 0.4;
      final bx = cx + cw * ((seed % 9 - 4) * 0.06);
      final by = cy - ch * 0.15 - bScale * ch * 0.20;
      _sp.color = Color.fromARGB(bAlpha, 90, 60, 25);
      _sp.strokeWidth = (sm(0.15)).clamp(0.8, 2.0);
      canvas.drawCircle(Offset(bx, by), (cw * 0.06 * bScale).clamp(1.0, 6.0), _sp);
    }

    // Slightly lighter rim
    _sp.color = const Color(0x66806040);
    _sp.strokeWidth = (sm(0.18)).clamp(1.0, 2.5);
    canvas.drawRect(rect, _sp);
  }

  // ── Hill / Raised Terrain ──────────────────────────────────────────────────

  void _drawHillCell(Canvas canvas, Rect rect, double cx, double cy,
      double cw, double ch, TerrainCell cell) {
    final t = (cell.height / 4.0).clamp(0.0, 1.0);

    // Base green fill (stronger with height)
    _fp.color = Color.fromARGB((80 + (t * 140).toInt()), 60, 170, 50);
    canvas.drawRect(rect, _fp);

    // Highlight: lighter upper-left quadrant (light from top-left)
    _fp.color = Color.fromARGB((50 + (t * 80).toInt()), 140, 230, 100);
    canvas.drawRect(
        Rect.fromLTRB(rect.left, rect.top,
            rect.left + cw * 0.55, rect.top + ch * 0.55), _fp);

    // Shadow: darker lower-right quadrant
    _fp.color = Color.fromARGB((60 + (t * 70).toInt()), 20, 80, 15);
    canvas.drawRect(
        Rect.fromLTRB(rect.left + cw * 0.45, rect.top + ch * 0.45,
            rect.right, rect.bottom), _fp);

    // Contour lines (one per meter of height, max 3 visible)
    _sp.color = Color.fromARGB((70 + (t * 60).toInt()), 30, 120, 20);
    _sp.strokeWidth = (sm(0.15)).clamp(0.7, 2.0);
    final levels = cell.height.floor().clamp(1, 3);
    for (int i = 1; i <= levels; i++) {
      final f = 1.0 - (i / 4.0);
      canvas.drawRect(
          Rect.fromLTRB(
              rect.left + cw * f * 0.35, rect.top + ch * f * 0.35,
              rect.right - cw * f * 0.35, rect.bottom - ch * f * 0.35),
          _sp);
    }
  }

  // ── Valley / Sinkhole Depression ───────────────────────────────────────────

  void _drawValleyCell(Canvas canvas, Rect rect, double cx, double cy,
      double cw, double ch, TerrainCell cell) {
    final t = (-cell.height / 3.0).clamp(0.0, 1.0);

    // Dark fill
    _fp.color = Color.fromARGB((100 + (t * 120).toInt()), 10, 8, 18);
    canvas.drawRect(rect, _fp);

    // Slightly lighter shadow-rim (perimeter lighter than center)
    _fp.color = Color.fromARGB((40 + (t * 50).toInt()), 40, 30, 55);
    canvas.drawRect(Rect.fromLTRB(
        rect.left + cw * 0.22, rect.top + ch * 0.22,
        rect.right - cw * 0.22, rect.bottom - ch * 0.22), _fp);

    // Dark center core
    _fp.color = Color.fromARGB((150 + (t * 80).toInt()), 3, 2, 8);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy),
            width: cw * 0.4, height: ch * 0.4),
        _fp);

    // Subtle rim outline
    _sp.color = Color.fromARGB((80 + (t * 60).toInt()), 60, 45, 80);
    _sp.strokeWidth = (sm(0.18)).clamp(0.8, 2.0);
    canvas.drawRect(rect, _sp);
  }

  void _drawTricksterTraps(Canvas canvas) {
    for (final trap in gs.tricksterTraps) {
      if (trap.triggered) continue;
      final tx = sx(trap.worldX), ty = sy(trap.worldY);
      final r = sm(trap.radius);
      final pulse = (trap.timer * 3.0) % 1.0; // pulsing effect
      final alpha = 0.3 + pulse * 0.3;
      _fp.color = Color.fromRGBO(180, 0, 255, alpha);
      canvas.drawCircle(Offset(tx, ty), r, _fp);
      _sp.color = const Color(0xAADD44FF);
      _sp.strokeWidth = 1.5;
      canvas.drawCircle(Offset(tx, ty), r, _sp);
    }
  }

  void _drawStatusEffects(Canvas canvas) {
    for (final p in gs.fieldPlayers) {
      if (!p.isAlive) continue;
      if (p.confusedTimer > 0) {
        final pulse = (p.confusedTimer * 4.0) % 1.0;
        _sp.color = Color.fromRGBO(200, 100, 255, 0.4 + pulse * 0.4);
        _sp.strokeWidth = 2.0;
        canvas.drawCircle(Offset(sx(p.x), sy(p.y)), sm(1.2 + pulse * 0.3), _sp);
      }
      if (p.hexedTimer > 0) {
        _sp.color = const Color(0x88FF6600);
        _sp.strokeWidth = 1.5;
        canvas.drawCircle(Offset(sx(p.x), sy(p.y)), sm(0.9), _sp);
      }
    }
  }

  void _drawTerrainAimReticle(Canvas canvas) {
    if (!gs.isAimingTerrain) return;
    final player = gs.selectedPlayer;
    if (player == null) return;

    final eventType = gs.terrainAimEventType;
    final isPit      = eventType?.name == 'openPit';
    final isFissure  = eventType?.name == 'fissure';
    final isHill     = eventType?.name == 'riseMountain';

    final color = isPit || isFissure
        ? const Color(0xCCFF2200)
        : isHill
            ? const Color(0xAA44FF88)
            : const Color(0xAAFFCC00);

    final px = sx(player.x);
    final py = sy(player.y);

    if (isFissure) {
      // Fissure: show a dash-path preview in the facing direction (5m)
      final dashEndX = (player.x + math.cos(player.facing) * 5.0).clamp(0.0, 140.0);
      final dashEndY = (player.y + math.sin(player.facing) * 5.0).clamp(0.0, 40.0);
      final ex = sx(dashEndX), ey = sy(dashEndY);

      // Dash arrow
      _sp.color = color;
      _sp.strokeWidth = 3.0;
      canvas.drawLine(Offset(px, py), Offset(ex, ey), _sp);

      // Arrow head
      final ang   = math.atan2(ey - py, ex - px);
      final aSize = sm(1.2);
      _path.reset();
      _path.moveTo(ex, ey);
      _path.lineTo(ex - math.cos(ang - 0.45) * aSize,
                   ey - math.sin(ang - 0.45) * aSize);
      _path.lineTo(ex - math.cos(ang + 0.45) * aSize,
                   ey - math.sin(ang + 0.45) * aSize);
      _path.close();
      _fp.color = color;
      canvas.drawPath(_path, _fp);

      // Pit zone at the midpoint of the dash path
      final midX = (player.x + dashEndX) / 2;
      final midY = (player.y + dashEndY) / 2;
      _sp.color = color.withValues(alpha: 0.7);
      _sp.strokeWidth = 1.5;
      canvas.drawCircle(Offset(sx(midX), sy(midY)), sm(3.0), _sp);
    } else {
      final tx = (player.x + math.cos(player.facing) * GameState.terrainAimRange)
          .clamp(0.0, 140.0);
      final ty = (player.y + math.sin(player.facing) * GameState.terrainAimRange)
          .clamp(0.0, 40.0);
      final radius = sm(isPit ? 4.0 : 5.0);

      // Outer reticle circle
      _sp.color = color;
      _sp.strokeWidth = 2.0;
      canvas.drawCircle(Offset(sx(tx), sy(ty)), radius, _sp);

      // Inner fill tint
      _fp.color = color.withValues(alpha: 0.12);
      canvas.drawCircle(Offset(sx(tx), sy(ty)), radius, _fp);

      // Cross-hair
      _sp.strokeWidth = 1.5;
      canvas.drawLine(Offset(sx(tx) - radius, sy(ty)),
                      Offset(sx(tx) + radius, sy(ty)), _sp);
      canvas.drawLine(Offset(sx(tx), sy(ty) - radius),
                      Offset(sx(tx), sy(ty) + radius), _sp);

      // Pit: add rotating danger triangles
      if (isPit) {
        final t = gs.matchTimeElapsed;
        final rot = t * 1.5;
        _fp.color = color.withValues(alpha: 0.55);
        for (int i = 0; i < 4; i++) {
          final a    = rot + i * math.pi / 2;
          final tipX = sx(tx) + math.cos(a) * (radius + sm(0.6));
          final tipY = sy(ty) + math.sin(a) * (radius + sm(0.6));
          _path.reset();
          _path.moveTo(tipX, tipY);
          _path.lineTo(tipX - math.cos(a - 0.5) * sm(0.8),
                       tipY - math.sin(a - 0.5) * sm(0.8));
          _path.lineTo(tipX - math.cos(a + 0.5) * sm(0.8),
                       tipY - math.sin(a + 0.5) * sm(0.8));
          _path.close();
          canvas.drawPath(_path, _fp);
        }
      }

      // Range line
      _sp.color = color.withValues(alpha: 0.35);
      _sp.strokeWidth = 1.0;
      canvas.drawLine(Offset(px, py), Offset(sx(tx), sy(ty)), _sp);
    }
  }

  // Returns the font size for a given indicator type — used for vertical centering.
  static double _indicatorFontSize(IndicatorType type) => switch (type) {
    IndicatorType.damage => 22.0,
    IndicatorType.kill   => 26.0,
    IndicatorType.heal   => 22.0,
    IndicatorType.combo  => 28.0,
    IndicatorType.event  => 18.0,
  };

  // Returns the rise distance in screen pixels for a given indicator type.
  static double _indicatorRise(IndicatorType type) => switch (type) {
    IndicatorType.damage => 60.0,
    IndicatorType.kill   => 80.0,
    IndicatorType.heal   => 60.0,
    IndicatorType.combo  => 100.0,
    IndicatorType.event  => 50.0,
  };

  // Builds and caches a full-opacity TextPainter for the indicator.
  // Layout runs once; opacity is applied later via canvas.saveLayer.
  TextPainter _getOrBuildIndicatorTp(DamageIndicator ind) {
    final existing = _indicatorTp[ind];
    if (existing != null) return existing;

    final (Color baseColor, double fontSize) = switch (ind.type) {
      IndicatorType.damage => (const Color(0xFFFFDD00), 22.0),
      IndicatorType.kill   => (const Color(0xFFFF2222), 26.0),
      IndicatorType.heal   => (const Color(0xFF44FF88), 22.0),
      IndicatorType.combo  => (const Color(0xFFFFAA00), 28.0),
      IndicatorType.event  => (const Color(0xFFFFFFFF), 18.0),
    };
    final tp = TextPainter(
      text: TextSpan(
        text: ind.text,
        style: TextStyle(
          color: baseColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          shadows: const [
            Shadow(color: Color(0xCC000000), blurRadius: 3, offset: Offset(1, 1)),
            Shadow(color: Color(0x88000000), blurRadius: 6),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    _indicatorTp[ind] = tp;
    return tp;
  }

  void _drawAbilityRangeCircle(Canvas canvas) {
    final slot = gs.prefs.hoveredAbilitySlot;
    if (slot == null) return;
    final player = gs.selectedPlayer;
    if (player == null) return;
    final range = player.playerClass.slotRange(slot);
    if (range <= 0) return;

    final cx = sx(player.x);
    final cy = sy(player.y);
    final r  = sm(range);

    // Soft glow fill
    _gp
      ..color      = const Color(0x22FFAA00)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset(cx, cy), r, _gp);
    _gp.maskFilter = null;

    // Solid ring
    _sp
      ..color       = const Color(0xCCFFAA00)
      ..strokeWidth = 2.0
      ..strokeCap   = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), r, _sp);
  }

  // ── Ability queue overlay — drawn above the selected player ─────────────────
  //
  // Layout (bottom-to-top above the player sprite):
  //   • Queue line  — exiting (yellow fading) + waiting (white/dim) ability names
  //   • Executing   — ability name in gold, floats upward on direct-fire only
  //   • Combo badge — "xN COMBO" in gold when queue-chain streak ≥ 2

  void _drawAbilityQueueOverlay(Canvas canvas, Size size) {
    final player = gs.selectedPlayer;
    if (player == null) return;

    final exitingNames  = player.exitingQueueNames;
    final exitingTimers = player.exitingQueueTimers;
    final queue         = player.abilityQueue;
    final executing     = player.lastExecutedAbility;
    final comboStreak   = player.lastExecutedComboStreak;
    final hasExiting    = exitingNames.isNotEmpty;

    if (queue.isEmpty && executing == null && !hasExiting && comboStreak < 2) return;

    final pos = projectPlayer(player, size);
    if (pos == null) return;

    // Fixed pixel offset above the projected player centre (works for all view modes).
    const aboveCenter = 22.0;
    const rowGap      = 24.0;
    const queueFontSz = 18.0;
    const execFontSz  = 22.0;
    const badgeFontSz = 16.0;

    double y = pos.dy - aboveCenter; // y of the bottommost text row (queue line)

    // Row 1 — queue line (exiting + waiting)
    if (hasExiting || queue.isNotEmpty) {
      final abilityNames = player.playerClass.abilityNames;
      final spans = <(String, Color)>[];

      for (int i = 0; i < exitingNames.length; i++) {
        final a = (exitingTimers[i] / UltraballPlayer.queueExitDuration).clamp(0.0, 1.0);
        spans.add((exitingNames[i], Color.fromRGBO(255, 220, 60, a)));
        if (i < exitingNames.length - 1 || queue.isNotEmpty) {
          spans.add((' > ', Color.fromRGBO(255, 255, 255, a * 0.7)));
        }
      }
      for (int i = 0; i < queue.length; i++) {
        if (i > 0) spans.add((' > ', const Color(0xB3FFFFFF)));
        final slot = queue[i];
        final name = (slot >= 1 && slot <= abilityNames.length)
            ? abilityNames[slot - 1]
            : 'Slot $slot';
        spans.add((name, player.getSlotCooldown(slot) > 0
            ? const Color(0x61FFFFFF)
            : const Color(0xB3FFFFFF)));
      }
      _drawQueueSpans(canvas, spans, pos.dx, y, queueFontSz);
      y -= rowGap;
    }

    // Row 2 — executing label (direct-fire only, floats upward)
    if (executing != null) {
      final progress = (1.0 - (player.lastExecutedTimer / 1.2)).clamp(0.0, 1.0);
      _drawQueueLabel(canvas, executing.toUpperCase(), pos.dx,
          y - progress * 20.0, const Color(0xFFFFDD00), execFontSz,
          (1.0 - progress).clamp(0.0, 1.0));
      y -= rowGap;
    }

    // Row 3 — combo badge
    if (comboStreak >= 2) {
      final a = hasExiting
          ? (exitingTimers.last / UltraballPlayer.queueExitDuration).clamp(0.0, 1.0)
          : 1.0;
      _drawQueueLabel(canvas, 'x$comboStreak COMBO', pos.dx, y,
          const Color(0xFFFFAA00), badgeFontSz, a);
    }
  }

  // Draw mixed-color text spans side-by-side, centred horizontally.
  void _drawQueueSpans(
      Canvas canvas, List<(String, Color)> spans, double cx, double cy, double fontSize) {
    final painters = <TextPainter>[];
    double totalW = 0;
    for (final (text, color) in spans) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 3, offset: Offset(1, 1))],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painters.add(tp);
      totalW += tp.width;
    }
    double x = cx - totalW / 2;
    for (final tp in painters) {
      tp.paint(canvas, Offset(x, cy - tp.height / 2));
      x += tp.width;
    }
  }

  // Draw a single centred label with optional opacity.
  void _drawQueueLabel(Canvas canvas, String text, double cx, double cy,
      Color color, double fontSize, [double opacity = 1.0]) {
    if (opacity <= 0) return;
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Color.fromARGB(
            (color.alpha * opacity).round().clamp(0, 255),
            color.red, color.green, color.blue,
          ),
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          shadows: const [
            Shadow(color: Color(0xCC000000), blurRadius: 3, offset: Offset(1, 1)),
            Shadow(color: Color(0x88000000), blurRadius: 6),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  // Red/orange sparkle particles beneath killing-blow numbers — mirrors the
  // _SparkleTrailPainter used in the Warchief damage overlay.
  void _drawDamageSparkles(
    Canvas canvas,
    double cx,
    double cy,
    DamageIndicator ind,
    double opacity,
  ) {
    const sparkleCount = 5;
    // Seed from world position so sparkles are stable across frames.
    final rng = math.Random(ind.worldX.round() * 31 + ind.worldY.round());
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < sparkleCount; i++) {
      final seedX     = rng.nextDouble();
      final seedY     = rng.nextDouble();
      final seedPhase = rng.nextDouble();
      final seedSize  = rng.nextDouble();

      final twinkle = (math.sin((ind.age * 8.0) + seedPhase * math.pi * 2) + 1.0) / 2.0;

      final x = cx - 20 + seedX * 40;
      final y = cy + seedY * 18;

      final sparkleSize    = (1.5 + seedSize * 2.5) * twinkle;
      final sparkleOpacity = (opacity * twinkle * 0.8).clamp(0.0, 1.0);

      final red = Color.lerp(
        const Color(0xFFFF4444),
        const Color(0xFFFF8800),
        seedPhase,
      )!;

      paint.color = red.withValues(alpha: sparkleOpacity);
      canvas.drawCircle(Offset(x, y), sparkleSize, paint);

      if (sparkleSize > 2.0) {
        paint.color = red.withValues(alpha: sparkleOpacity * 0.3);
        canvas.drawCircle(Offset(x, y), sparkleSize * 2.0, paint);
      }
    }
  }

  void _drawDamageIndicators(Canvas canvas) {
    if (gs.indicators.isEmpty) return;
    for (final ind in gs.indicators) {
      // xJitter is now in screen pixels (no scale multiplication).
      final screenX = ind.worldX * scale + offsetX + ind.xJitter;

      // Ease-out vertical rise: starts fast, decelerates — matches Warchief.
      final easedProgress = 1.0 - math.pow(1.0 - ind.progress, 2.0) as double;
      final screenY = ind.worldY * scale + offsetY - easedProgress * _indicatorRise(ind.type);

      // Fade: opaque for the first 70% of lifetime, then linear fade out.
      const fadeStart = 0.7;
      final opacity = ind.progress > fadeStart
          ? ((1.0 - (ind.progress - fadeStart) / (1.0 - fadeStart)).clamp(0.0, 1.0))
          : 1.0;
      if (opacity <= 0) continue;

      // Sparkle trail beneath kill indicators.
      if (ind.type == IndicatorType.kill && ind.progress > 0.05) {
        _drawDamageSparkles(canvas, screenX, screenY, ind, opacity);
      }

      final tp       = _getOrBuildIndicatorTp(ind);
      final fontSize = _indicatorFontSize(ind.type);

      // Brief scale-up at spawn for damage / kill / heal (pop effect).
      final isScalable = ind.type == IndicatorType.damage ||
                         ind.type == IndicatorType.kill   ||
                         ind.type == IndicatorType.heal;
      final scaleT = isScalable && ind.progress < 0.1
          ? 1.0 + (0.1 - ind.progress) * 3.0
          : 1.0;

      _indicatorLayerPaint.color = Color.fromRGBO(255, 255, 255, opacity);
      canvas.saveLayer(
        Rect.fromCenter(
          center: Offset(screenX, screenY),
          width:  (tp.width  + 20) * scaleT,
          height: (tp.height + 20) * scaleT,
        ),
        _indicatorLayerPaint,
      );
      if (scaleT != 1.0) {
        canvas.save();
        canvas.translate(screenX, screenY);
        canvas.scale(scaleT);
        canvas.translate(-screenX, -screenY);
      }
      tp.paint(canvas, Offset(screenX - tp.width / 2, screenY - fontSize / 2));
      if (scaleT != 1.0) canvas.restore();
      canvas.restore();
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

    // Soft aura glows drawn BEFORE body so they appear as outer halos
    if (isTarget) {
      final ts = gs.prefs.targetIndicatorSize;
      _gp
        ..color = const Color(0xFFFF3333).withValues(alpha: 0.32)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(pos, r + sm(1.2) * ts, _gp);
      _gp.maskFilter = null;
    }
    if (p.isSelected) {
      _gp
        ..color = const Color(0xFF1E88E5).withValues(alpha: 0.38)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(pos, r + sm(1.0), _gp);
      _gp.maskFilter = null;
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
    final bodyColor = p.isSelected ? UiAssets.classColor(p.playerClass) : teamColor;

    _fp.color = bodyColor;
    canvas.drawCircle(pos, r, _fp);
    _fp.color = bodyColor.withValues(alpha: 0.6);
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
    if (gs.prefs.showPlayerNumbers) {
      final numTp = _getPlayerNumTp(p.rosterIndex);
      numTp.paint(canvas, Offset(pos.dx - numTp.width / 2, pos.dy - numTp.height / 2));
    }

    // Health bar
    if (gs.prefs.showHpBars) _drawHealthBar(canvas, p, pos, r);

    // Crisp indicator rings drawn AFTER body so they show on top of the sprite
    // (mirrors how _draw3DPlayer works; fixes visibility on same-colour bodies)
    if (isTarget) {
      final ts = gs.prefs.targetIndicatorSize;
      _sp
        ..color = const Color(0xFFFF6B6B).withValues(alpha: 0.92)
        ..strokeWidth = sm(0.3) * ts;
      canvas.drawCircle(pos, r + sm(0.9) * ts, _sp);
      _sp
        ..color = const Color(0xFFFF6B6B).withValues(alpha: 0.5)
        ..strokeWidth = sm(0.14) * ts;
      canvas.drawCircle(pos, r + sm(1.5) * ts, _sp);
      _drawTargetTriangles(canvas, pos, r + sm(1.8) * ts, ts);
    }
    if (p.isSelected) {
      _sp
        ..color = const Color(0xFF4cc9f0).withValues(alpha: 0.95)
        ..strokeWidth = sm(0.28);
      canvas.drawCircle(pos, r + sm(0.6), _sp);
      _sp
        ..color = const Color(0xFF4cc9f0).withValues(alpha: 0.28)
        ..strokeWidth = sm(0.12);
      canvas.drawCircle(pos, r + sm(1.05), _sp);
    }
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

  void _drawTargetTriangles(Canvas canvas, Offset center, double radius, [double scale = 1.0]) {
    final size = 5.0 * scale;
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

    _sp
      ..color     = const Color(0xBFFFDD00)   // 0.75 alpha
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

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
        canvas.drawLine(groundPosPrev, groundPos, _arcShadowPaint);
      }

      if (i % 6 == 0) {
        canvas.drawCircle(arcPos, 3.0, _arcDotPaint);
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

  // Full 3D mode: delegates to WebGL render system, then overlays 2D indicators.
  // Falls through to 3/4 view while the renderer is warming up (first frame).
  void _paintFull3D(Canvas canvas, Size size) {
    final rs = renderSystem;
    if (rs == null || !rs.ready) {
      _paint3D(canvas, size);
      return;
    }
    // WebGL draw calls go to the body-appended canvas (not this Flutter canvas).
    rs.render(gs, size);
    // 2D damage indicators float up from their world positions.
    if (gs.prefs.showDamageIndicators) _drawDamageIndicators3D(canvas, size, rs);
    _drawAbilityQueueOverlay(canvas, size);
  }

  void _drawDamageIndicators3D(
      Canvas canvas, Size size, UltraballRenderSystem rs) {
    if (gs.indicators.isEmpty) return;
    for (final ind in gs.indicators) {
      // Ease-out rise: 3 world units total, decelerating.
      final easedProgress = 1.0 - math.pow(1.0 - ind.progress, 2.0) as double;
      // xJitter is in screen pixels — apply it after projection.
      final projected = rs.project(
        Vector3(ind.worldX, easedProgress * 3.0, ind.worldY),
        size,
      );
      if (projected == null) continue;

      final sx = projected.dx + ind.xJitter;
      final sy = projected.dy;

      // Fade: opaque for the first 70%, then linear fade out.
      const fadeStart = 0.7;
      final opacity = ind.progress > fadeStart
          ? ((1.0 - (ind.progress - fadeStart) / (1.0 - fadeStart)).clamp(0.0, 1.0))
          : 1.0;
      if (opacity <= 0) continue;

      if (ind.type == IndicatorType.kill && ind.progress > 0.05) {
        _drawDamageSparkles(canvas, sx, sy, ind, opacity);
      }

      final tp       = _getOrBuildIndicatorTp(ind);
      final fontSize = _indicatorFontSize(ind.type);

      final isScalable = ind.type == IndicatorType.damage ||
                         ind.type == IndicatorType.kill   ||
                         ind.type == IndicatorType.heal;
      final scaleT = isScalable && ind.progress < 0.1
          ? 1.0 + (0.1 - ind.progress) * 3.0
          : 1.0;

      _indicatorLayerPaint.color = Color.fromRGBO(255, 255, 255, opacity);
      canvas.saveLayer(
        Rect.fromCenter(
          center: Offset(sx, sy),
          width:  (tp.width  + 20) * scaleT,
          height: (tp.height + 20) * scaleT,
        ),
        _indicatorLayerPaint,
      );
      if (scaleT != 1.0) {
        canvas.save();
        canvas.translate(sx, sy);
        canvas.scale(scaleT);
        canvas.translate(-sx, -sy);
      }
      tp.paint(canvas, Offset(sx - tp.width / 2, sy - fontSize / 2));
      if (scaleT != 1.0) canvas.restore();
      canvas.restore();
    }
  }

  void _paint3D(Canvas canvas, Size size) {
    final camToggled = ballCam != _prevBallCam;
    _prevBallCam = ballCam;
    if (ballCam) {
      // Centre the 3/4 camera on the ball's X position every frame.
      final cx = gs.ball.x.clamp(28.0, 112.0);
      _camera3D.camX    = cx;
      _camera3D.targetX = cx;
      _camera3D.update(size);
      _last3DSize = size;
    } else {
      // On the first frame after leaving ball-cam, snap back to midfield.
      if (camToggled) {
        _camera3D.camX    = 70.0;
        _camera3D.targetX = 70.0;
      }
      if (_last3DSize != size || camToggled) {
        _camera3D.update(size);
        _last3DSize = size;
      }
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
    if (gs.prefs.showPhaseLines) _draw3DPhaseLines(canvas);
    _drawTerrainOverlay3D(canvas);
    _draw3DEntities(canvas);
    _draw3DThrowArcPreview(canvas);
    if (gs.prefs.showDamageIndicators) _drawDamageIndicators(canvas);
    _drawAbilityQueueOverlay(canvas, size);
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
      ..color     = const Color(0xBFFFDD00)   // 0.75 alpha
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

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
        canvas.drawLine(gndPosPrev, groundPos, _arcShadowPaint);
      }
      if (arcPos != null && i % 6 == 0) {
        canvas.drawCircle(arcPos, 3.0, _arcDotPaint);
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

  void _draw3DQuadAtZ(Canvas canvas, double x0, double y0, double x1, double y1,
      double z, Paint paint) {
    final p0 = _camera3D.project(x0, y0, z);
    final p1 = _camera3D.project(x1, y0, z);
    final p2 = _camera3D.project(x1, y1, z);
    final p3 = _camera3D.project(x0, y1, z);
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
    final items = _depthItems..clear();

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

    // Sort farthest first (largest cw = furthest from camera)
    items.sort((a, b) => b.$1.compareTo(a.$1));
    for (final (_, draw) in items) { draw(); }

    // Ball drawn last — always on top of every player body so the charge arc
    // and glow are never occluded by the holder's sprite.
    {
      final ball = gs.ball;
      final dep = _camera3D.projectWithDepth(ball.x, ball.y, ball.zHeight * 1.2);
      if (dep != null) {
        final pos = dep.$1; final cw = dep.$2;
        _draw3DBall(canvas, pos, cw);
      }
    }
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

    // Player body
    final teamColor = p.team == Team.player
        ? const Color(0xFF1E88E5)
        : const Color(0xFFE53935);
    final bodyColor = p.isSelected ? UiAssets.classColor(p.playerClass) : teamColor;
    _fp.color = bodyColor;
    canvas.drawCircle(pos, r, _fp);
    _fp.color = bodyColor.withValues(alpha: 0.6);
    canvas.drawCircle(pos, r * 0.7, _fp);

    _draw3DFacingIndicator(canvas, p);

    if (p.isStunned) {
      _sp
        ..color = Colors.yellow.withValues(alpha: 0.6)
        ..strokeWidth = math.max(1.5, r * 0.12);
      canvas.drawCircle(pos, r + r * 0.18, _sp);
    }

    if (gs.prefs.showPlayerNumbers) {
      final numTp = _getPlayerNumTp(p.rosterIndex);
      numTp.paint(canvas, Offset(pos.dx - numTp.width / 2, pos.dy - numTp.height / 2));
    }

    if (gs.prefs.showHpBars) {
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

    // Indicators drawn after body so they appear on top
    if (p.id == gs.currentTargetId) {
      final sw = math.max(2.0, r * 0.15);
      _sp
        ..color = const Color(0xFFFF2222).withValues(alpha: 0.9)
        ..strokeWidth = sw;
      canvas.drawCircle(pos, r * 1.35, _sp);
      _sp
        ..color = const Color(0xFFFF4444).withValues(alpha: 0.4)
        ..strokeWidth = sw * 0.6;
      canvas.drawCircle(pos, r * 1.6, _sp);
    }

    if (p.isSelected) {
      final sw = math.max(2.0, r * 0.18);
      _sp
        ..color = Colors.white.withValues(alpha: 0.95)
        ..strokeWidth = sw;
      canvas.drawCircle(pos, r * 1.4, _sp);
      _sp
        ..color = Colors.white.withValues(alpha: 0.35)
        ..strokeWidth = sw * 0.5;
      canvas.drawCircle(pos, r * 1.7, _sp);
    }

    if (gs.ball.holderId == p.id) {
      // Outer glow
      _gp
        ..color = const Color(0xFFFFDD00).withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(pos, r * 1.8, _gp);
      _gp.maskFilter = null;
      // Solid possession ring
      _sp
        ..color = const Color(0xFFFFDD00).withValues(alpha: 0.95)
        ..strokeWidth = math.max(2.0, r * 0.2);
      canvas.drawCircle(pos, r * 1.55, _sp);
      // Small dot above player head to indicate ball possession
      _fp.color = const Color(0xFFFFDD00);
      canvas.drawCircle(Offset(pos.dx, pos.dy - r * 2.0), math.max(3.0, r * 0.35), _fp);
    }
  }

  void _draw3DFacingIndicator(Canvas canvas, UltraballPlayer p) {
    final f = p.facing;
    final z = p.zHeight * 1.2;
    const tipDist  = 2.2;   // world units ahead of center
    const baseR    = 0.7;   // world units from center to base corners
    const halfAngle = 0.55; // half-width of triangle base in radians

    final tip  = _camera3D.project(
        p.x + math.cos(f) * tipDist,
        p.y + math.sin(f) * tipDist, z);
    final left = _camera3D.project(
        p.x + math.cos(f + math.pi - halfAngle) * baseR,
        p.y + math.sin(f + math.pi - halfAngle) * baseR, z);
    final right = _camera3D.project(
        p.x + math.cos(f + math.pi + halfAngle) * baseR,
        p.y + math.sin(f + math.pi + halfAngle) * baseR, z);

    if (tip == null || left == null || right == null) return;
    _path
      ..reset()
      ..moveTo(tip.dx,   tip.dy)
      ..lineTo(left.dx,  left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    canvas.drawPath(_path, _facingPaint);
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
      final arcR = r + math.max(3.0, r * 0.45);
      final arcSW = math.max(2.0, r * 0.3);
      // Background track
      _sp
        ..color = Colors.white.withValues(alpha: 0.15)
        ..strokeWidth = arcSW
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(pos, arcR, _sp);
      // Charge fill
      _sp
        ..color = ballColor.withValues(alpha: 0.95)
        ..strokeWidth = arcSW
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: pos, radius: arcR),
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
