import 'dart:math' as math;
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart' show Size, Offset;
import 'package:vector_math/vector_math.dart';

import '../rendering3d/webgl_renderer.dart';
import '../rendering3d/perspective_camera.dart';
import '../rendering3d/mesh.dart';
import '../rendering3d/math/transform3d.dart';
import '../rendering3d/character_rig.dart';
import '../models/player.dart';
import '../models/creature.dart';
import '../models/ultraball.dart';
import '../game/game_state.dart';
import 'field_mesh_builder.dart';
import 'ball_mesh_builder.dart';
import 'player_mesh_builder.dart';
import 'creature_mesh_builder.dart';
import 'player_animator.dart';
import 'utils/screen_projection.dart';

// UltraballRenderSystem — owns all 3D WebGL state for ViewMode.full3D.
//
// Lifecycle (called by GameWidget in Phase 4):
//   1. init(canvas, creatureType, size)   — after first postFrameCallback
//   2. initPlayers(gs)                    — immediately after gs.initialize()
//   3. update(gs, dt)                     — from game-loop tick (_update)
//   4. render(gs, size)                   — from FieldPainter._paintFull3D
//   5. resize(w, h)                       — on LayoutBuilder size change
//   6. dispose()                          — from State.dispose()
//
// Coordinate convention:
//   World X = game entity.x  (0 = home end, 140 = away end)
//   World Z = game entity.y  (0 = top edge, 40 = bottom edge)
//   World Y = altitude       (0 = ground, up = positive)
//
// update() MUST be called before render() each frame.

class UltraballRenderSystem {
  WebGLRenderer? _renderer;
  PerspectiveCamera? _camera;
  FieldMeshes? _fieldMeshes;
  BallMeshes? _ballMeshes;
  CharacterRig? _creatureRig;

  final Map<String, CharacterRig> _playerRigs = {};
  bool _useCubeModels = false;

  bool _ready = false;
  bool get ready => _ready;

  // ── Target indicator state ────────────────────────────────────────────────
  double _elapsedTime = 0.0;
  Mesh? _targetIndicatorMesh;
  Transform3d? _targetIndicatorTransform;
  Mesh? _targetAcquiredMesh;
  Transform3d? _targetAcquiredTransform;
  Vector3? _targetIndicatorAnimFrom;
  double _targetIndicatorAnimStartTime = -1.0;
  double _targetAcquiredStartTime      = -1.0;
  String? _lastTargetIndicatorId;
  double  _lastTargetIndicatorSize = 0.0;
  static const double _targetIndicatorAnimDuration = 0.30;
  static const double _targetAcquiredDuration       = 0.50;

  // ── Creature motion tracking ───────────────────────────────────────────────
  double _creatureAnimTime = 0.0;
  double _prevCreatureX = double.nan;  // nan = first-frame sentinel
  double _prevCreatureY = double.nan;
  double _lastCreatureYaw = 180.0;  // creatures start at right side moving left

  // ── Cached field-geometry transforms (immutable after init) ───────────────
  late Transform3d _homeEndzoneT;
  late Transform3d _leftChannelT;
  late Transform3d _mainFieldT;
  late Transform3d _rightChannelT;
  late Transform3d _awayEndzoneT;
  late List<Transform3d> _phaseLineTs;

  // ── init ──────────────────────────────────────────────────────────────────

  void init(
    html.CanvasElement canvas,
    CreatureType creatureType,
    Size initialSize,
  ) {
    _renderer = WebGLRenderer(canvas);

    // Broadcast camera: elevated side view, pans toward ball in update().
    // FOV=65°, pitch=35°, distance=55 shows ~55 m of field width (tracks ball).
    _camera = PerspectiveCamera(
      fov: 65.0,
      aspectRatio: initialSize.width / initialSize.height,
      near: 0.5,
      far: 600.0,
    );
    _camera!.setTarget(Vector3(70.0, 0.0, 20.0));
    _camera!.pitchBy(35.0);
    _camera!.setTargetDistance(55.0);

    _fieldMeshes = FieldMeshBuilder.build();
    _ballMeshes  = BallMeshBuilder.build();
    _creatureRig = CreatureMeshBuilder.build(creatureType);

    // Cache immutable field transforms
    _homeEndzoneT  = FieldMeshes.homeEndzoneTransform();
    _leftChannelT  = FieldMeshes.leftChannelTransform();
    _mainFieldT    = FieldMeshes.mainFieldTransform();
    _rightChannelT = FieldMeshes.rightChannelTransform();
    _awayEndzoneT  = FieldMeshes.awayEndzoneTransform();
    _phaseLineTs   = [for (int i = 0; i < 5; i++) FieldMeshes.phaseLineTransform(i)];

    // Warm scene lighting from above-left (sun-like)
    _renderer!.lightPosition = Vector3(50.0, 60.0, -15.0);
    _renderer!.lightColor    = Vector3(1.00, 0.97, 0.90);
    _renderer!.ambientColor  = Vector3(0.28, 0.30, 0.36);

    _ready = true;
    debugPrint('[UltraballRenderSystem] initialized');
  }

  // ── initPlayers ───────────────────────────────────────────────────────────

  void initPlayers(GameState gs, {bool useCubeModels = false}) {
    _useCubeModels = useCubeModels;
    _playerRigs.clear();
    for (final p in gs.playerRoster) {
      _playerRigs[p.id] = useCubeModels
          ? PlayerMeshBuilder.buildCube(p.team)
          : PlayerMeshBuilder.build(p.team, p.playerClass);
    }
    for (final p in gs.opponentRoster) {
      _playerRigs[p.id] = useCubeModels
          ? PlayerMeshBuilder.buildCube(p.team)
          : PlayerMeshBuilder.build(p.team, p.playerClass);
    }
  }

  // ── update ────────────────────────────────────────────────────────────────

  // Advances animation timers and camera.  Must be called before render().
  void update(GameState gs, double dt) {
    if (!_ready) return;
    _elapsedTime += dt;

    // Player animation
    for (final player in gs.fieldPlayers) {
      PlayerAnimator.update(player, _getRig(player), dt);
    }

    // Creature body-bob + facing update
    _updateCreature(gs.creature, dt);

    // Camera update — behaviour depends on active mode
    final cam = _camera!;
    if (cam.mode == CameraMode.thirdPerson) {
      final player = gs.selectedPlayer;
      if (player != null) {
        // Convert game facing (radians, 0=+X) to Transform3d yaw convention (degrees)
        final worldYaw = -(player.facing * (180.0 / math.pi) + 90.0);
        cam.updateThirdPersonFollow(
          Vector3(player.x, player.zHeight, player.y),
          worldYaw,
          dt,
        );
      }
    } else {
      // Broadcast: smoothly pan camera X toward ball (clamp to channel entrances)
      final ballTargetX = gs.ball.x.clamp(28.0, 112.0);
      final curTarget = cam.getTarget();
      final lerpT = math.min(1.0, 1.8 * dt);
      cam.setTarget(Vector3(
        curTarget.x + (ballTargetX - curTarget.x) * lerpT,
        0.0,
        20.0,
      ));
      cam.updateCameraLerp(dt);
    }
  }

  // ── toggleCameraMode ──────────────────────────────────────────────────────

  // Toggles between broadcast and third-person follow camera (V key).
  void toggleCameraMode() {
    if (!_ready) return;
    final cam = _camera!;
    cam.toggleMode();
    // When returning to broadcast, re-anchor target at field centre and lerp
    // pitch/distance back to the standard overhead parameters.
    if (cam.mode == CameraMode.broadcast) {
      cam.setTarget(Vector3(70.0, 0.0, 20.0));
      cam.startCameraTransition(targetPitch: 35.0, targetDistance: 55.0);
    }
  }

  CameraMode get cameraMode => _camera?.mode ?? CameraMode.broadcast;

  // ── render ────────────────────────────────────────────────────────────────

  // Issues all WebGL draw calls for one frame.  Reads game state directly;
  // assumes update() was already called this tick.
  void render(GameState gs, Size size) {
    if (!_ready) return;
    final r  = _renderer!;
    final c  = _camera!;
    final fm = _fieldMeshes!;

    r.clear();

    // ── Ground zones (lit) ───────────────────────────────────────────────
    r.render(fm.homeEndzone,  _homeEndzoneT,  c);
    r.render(fm.leftChannel,  _leftChannelT,  c);
    r.render(fm.mainField,    _mainFieldT,    c);
    r.render(fm.rightChannel, _rightChannelT, c);
    r.render(fm.awayEndzone,  _awayEndzoneT,  c);

    // ── Phase lines (unlit — glow effect) ────────────────────────────────
    for (int i = 0; i < 5; i++) {
      final mesh = gs.ball.phaseLineActive[i]
          ? fm.phaseLineActive
          : fm.phaseLineInactive;
      r.renderUnlit(mesh, _phaseLineTs[i], c);
    }

    // ── Creature (lit) ───────────────────────────────────────────────────
    if (_creatureRig != null) {
      final ct = _creatureTransform(gs.creature);
      for (final part in _creatureRig!.parts) {
        r.render(part.mesh, part.getWorldTransform(ct), c);
      }
    }

    // ── Players (lit) ────────────────────────────────────────────────────
    for (final player in gs.fieldPlayers) {
      _renderPlayer(r, c, player);
    }

    // ── Target indicator (unlit — always on top of field geometry) ────────
    _renderTargetIndicator(r, c, gs);

    // ── Ball (unlit — self-luminous energy sphere) ────────────────────────
    _renderBall(r, c, gs);
  }

  // ── project (for 2D overlay damage indicators) ───────────────────────────

  Offset? project(Vector3 worldPos, Size screenSize) {
    if (!_ready) return null;
    return worldToScreen(
      worldPos,
      _camera!.getViewMatrix(),
      _camera!.getProjectionMatrix(),
      screenSize,
    );
  }

  // ── resize ────────────────────────────────────────────────────────────────

  void resize(int width, int height) {
    if (!_ready) return;
    _renderer!.resize(width, height);
    _camera!.aspectRatio = width / height;
  }

  // ── dispose ───────────────────────────────────────────────────────────────

  void dispose() {
    _renderer?.dispose();
    _renderer = null;
    _camera = null;
    _fieldMeshes = null;
    _ballMeshes = null;
    _creatureRig = null;
    _playerRigs.clear();
    _ready = false;
    debugPrint('[UltraballRenderSystem] disposed');
  }

  // ── Private: animation helpers ────────────────────────────────────────────

  CharacterRig _getRig(UltraballPlayer player) {
    return _playerRigs.putIfAbsent(
      player.id,
      () => _useCubeModels
          ? PlayerMeshBuilder.buildCube(player.team)
          : PlayerMeshBuilder.build(player.team, player.playerClass),
    );
  }

  void _updateCreature(Creature creature, double dt) {
    _creatureAnimTime += dt;

    // Compute facing from position delta (creature mesh faces +X in local space)
    _lastCreatureYaw = _computeCreatureYaw(creature);
    _prevCreatureX = creature.x;
    _prevCreatureY = creature.y;

    // Gentle body-bob on the primary part
    final rig = _creatureRig;
    if (rig != null && rig.parts.isNotEmpty) {
      rig.parts[0].animRotation.x = math.sin(_creatureAnimTime * 1.2) * 1.8;
    }
  }

  double _computeCreatureYaw(Creature creature) {
    // First frame: initialise sentinel and return a default angle.
    // Creatures start at (115, −2.5) moving left, so 180° faces −X.
    if (_prevCreatureX.isNaN) return 180.0;

    final dx = creature.x - _prevCreatureX;
    final dz = creature.y - _prevCreatureY;   // game Y == world Z
    if (dx.abs() + dz.abs() < 0.01) return _lastCreatureYaw;

    // Mesh built facing +X in local space:
    //   local +X → world (cos(yaw), 0, −sin(yaw))
    // Solving for yaw given movement direction (dx, dz):
    //   cos(yaw) = dx/len, −sin(yaw) = dz/len → yaw = atan2(−dz, dx)
    return math.atan2(-dz, dx) * (180.0 / math.pi);
  }

  // ── Private: render helpers ───────────────────────────────────────────────

  void _renderPlayer(
    WebGLRenderer r,
    PerspectiveCamera c,
    UltraballPlayer player,
  ) {
    final rig = _getRig(player);
    final charT = _playerTransform(player);
    for (final part in rig.parts) {
      r.render(part.mesh, part.getWorldTransform(charT), c);
    }
  }

  void _renderTargetIndicator(WebGLRenderer r, PerspectiveCamera c, GameState gs) {
    if (gs.currentTargetId == null) {
      _targetIndicatorMesh = null;
      _lastTargetIndicatorId = null;
      return;
    }

    UltraballPlayer? target;
    for (final p in gs.fieldPlayers) {
      if (p.id == gs.currentTargetId) { target = p; break; }
    }
    if (target == null || !target.isAlive) return;

    final prefSize  = gs.prefs.targetIndicatorSize;
    final size      = 1.5 * prefSize;
    final lineWidth = 0.10 * prefSize;
    // Red for enemy targets; green for player-team targets (e.g. pass targeting).
    final color = target.team == Team.opponent
        ? Vector3(1.0, 0.15, 0.15)
        : Vector3(0.15, 1.0, 0.35);

    final targetChanged = _lastTargetIndicatorId != gs.currentTargetId;
    final sizeChanged   = _lastTargetIndicatorSize != prefSize;

    if (_targetIndicatorMesh == null || targetChanged || sizeChanged) {
      if (targetChanged && _targetIndicatorTransform != null) {
        _targetIndicatorAnimFrom = _targetIndicatorTransform!.position.clone();
        _targetIndicatorAnimStartTime = _elapsedTime;
      }
      _targetIndicatorMesh = Mesh.targetIndicator(size: size, lineWidth: lineWidth, color: color);
      _lastTargetIndicatorId   = gs.currentTargetId;
      _lastTargetIndicatorSize = prefSize;
    }

    // "Target acquired" flash — yellow ring that briefly appears on target change.
    if (targetChanged) {
      _targetAcquiredMesh = Mesh.targetIndicator(
        size: size * 1.3,
        lineWidth: lineWidth * 1.3,
        color: Vector3(1.0, 1.0, 0.1),
      );
      _targetAcquiredStartTime = _elapsedTime;
    }

    final targetPos = Vector3(target.x, target.zHeight, target.y);

    if (_targetAcquiredMesh != null && _targetAcquiredStartTime >= 0) {
      final age = _elapsedTime - _targetAcquiredStartTime;
      if (age < _targetAcquiredDuration) {
        _targetAcquiredTransform ??= Transform3d();
        _targetAcquiredTransform!.position = targetPos;
        r.renderUnlit(_targetAcquiredMesh!, _targetAcquiredTransform!, c);
      }
    }

    // Ease-out cubic slide from old target position to new.
    _targetIndicatorTransform ??= Transform3d();
    Vector3 displayPos;
    final animFrom = _targetIndicatorAnimFrom;
    if (animFrom != null && _targetIndicatorAnimStartTime >= 0) {
      final age = _elapsedTime - _targetIndicatorAnimStartTime;
      final raw = (age / _targetIndicatorAnimDuration).clamp(0.0, 1.0);
      final t   = 1.0 - math.pow(1.0 - raw, 3.0).toDouble();
      displayPos = Vector3(
        animFrom.x + (targetPos.x - animFrom.x) * t,
        0.0,
        animFrom.z + (targetPos.z - animFrom.z) * t,
      );
      if (raw >= 1.0) _targetIndicatorAnimFrom = null;
    } else {
      displayPos = targetPos;
    }

    _targetIndicatorTransform!.position = displayPos;
    r.renderUnlit(_targetIndicatorMesh!, _targetIndicatorTransform!, c);
  }

  void _renderBall(WebGLRenderer r, PerspectiveCamera c, GameState gs) {
    final bm      = _ballMeshes!;
    final worldPos = _ballWorldPos(gs.ball, gs);
    final coreT    = Transform3d(position: worldPos);

    r.renderUnlit(_ballCoreMesh(gs.ball), coreT, c);

    // Three perpendicular spikes give the ball a recognisable silhouette
    r.renderUnlit(bm.spike, BallMeshes.spikeXTransform(worldPos), c);
    r.renderUnlit(bm.spike, BallMeshes.spikeYTransform(worldPos), c);
    r.renderUnlit(bm.spike, BallMeshes.spikeZTransform(worldPos), c);
  }

  // ── Private: transform factories ─────────────────────────────────────────

  Transform3d _playerTransform(UltraballPlayer player) {
    // Convert game facing (radians, 0 = +X game-right) to character yaw (degrees).
    // At yaw = −90°: Transform3d.forward = +X world, matching game-right facing.
    // Formula: worldYaw = −(facingDeg + 90)
    final worldYaw = -(player.facing * (180.0 / math.pi) + 90.0);
    return Transform3d(
      position: Vector3(player.x, player.zHeight, player.y),
      rotation: Vector3(0, worldYaw, 0),
    );
  }

  Transform3d _creatureTransform(Creature creature) {
    return Transform3d(
      position: Vector3(creature.x, 0.0, creature.y),
      rotation: Vector3(0, _lastCreatureYaw, 0),
    );
  }

  // ── Private: ball helpers ─────────────────────────────────────────────────

  Vector3 _ballWorldPos(Ultraball ball, GameState gs) {
    if (ball.holderId != null) {
      final holder = gs.getPlayerById(ball.holderId!);
      if (holder != null) {
        // Ball carried above holder's head
        return Vector3(holder.x, holder.zHeight + 2.2, holder.y);
      }
    }
    // Loose or in-flight: use ball's own position + small ground clearance
    return Vector3(ball.x, ball.zHeight + 0.3, ball.y);
  }

  Mesh _ballCoreMesh(Ultraball ball) {
    // Charge state takes priority over team colour when ball is getting hot
    if (ball.chargePercent > 0.80) return _ballMeshes!.coreCritical;
    if (ball.chargePercent > 0.50) return _ballMeshes!.coreCharged;
    if (ball.possessingTeamId == 'player')   return _ballMeshes!.coreHome;
    if (ball.possessingTeamId == 'opponent') return _ballMeshes!.coreAway;
    return _ballMeshes!.coreLoose;
  }
}
