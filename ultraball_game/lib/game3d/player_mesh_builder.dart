import 'package:vector_math/vector_math.dart';
import '../rendering3d/mesh.dart';
import '../rendering3d/character_rig.dart';
import '../models/player.dart';

// Build a CharacterRig for a player.
//
// Mesh objects are cached by (team, class, part) key so all players of the
// same team+class share GPU buffers.  Each call returns a NEW CharacterRig
// (independent animation state) pointing at the same cached Mesh instances.
//
// Character root: feet at world origin.  Parts use Y-up rest positions.
// Approximate height: ~1.78 m (head top ≈ 1.775).
//
// Rest positions (character-local, Y-up):
//   head:          (0,    1.60, 0)   0.30 × 0.35 × 0.30
//   upperTorso:    (0,    1.20, 0)   0.50 × 0.42 × 0.28
//   lowerTorso:    (0,    0.86, 0)   0.42 × 0.30 × 0.24
//   rightUpperArm: (+0.37, 1.18, 0)  0.18 × 0.36 × 0.18
//   leftUpperArm:  (-0.37, 1.18, 0)  0.18 × 0.36 × 0.18
//   rightForearm:  (+0.40, 0.84, 0)  0.15 × 0.32 × 0.15
//   leftForearm:   (-0.40, 0.84, 0)  0.15 × 0.32 × 0.15
//   rightThigh:    (+0.12, 0.57, 0)  0.20 × 0.36 × 0.20
//   leftThigh:     (-0.12, 0.57, 0)  0.20 × 0.36 × 0.20
//   rightShin:     (+0.12, 0.18, 0)  0.16 × 0.34 × 0.16
//   leftShin:      (-0.12, 0.18, 0)  0.16 × 0.34 × 0.16

class PlayerMeshBuilder {
  static final Map<String, Mesh> _cache = {};

  static Mesh _box(String key, double w, double h, double d, Vector3 color) {
    return _cache.putIfAbsent(
      key, () => Mesh.box(width: w, height: h, depth: d, color: color));
  }

  static CharacterRig buildCube(Team team) {
    final color = team == Team.player
        ? Vector3(0.15, 0.30, 0.85)
        : Vector3(0.88, 0.15, 0.15);
    final mesh = _cache.putIfAbsent(
      'cube_${team.name}',
      () => Mesh.cube(size: 1.6, color: color),
    );
    return CharacterRig(parts: [
      RigPart(
        mesh: mesh,
        name: 'body',
        restPosition: Vector3(0, 0.8, 0), // centre at half-height
      ),
    ]);
  }

  static CharacterRig buildCubeSelected(Team team, PlayerClass playerClass) {
    final color = _classColorVec(playerClass);
    final mesh = _cache.putIfAbsent(
      'cube_selected_${playerClass.name}',
      () => Mesh.cube(size: 1.6, color: color),
    );
    return CharacterRig(parts: [
      RigPart(
        mesh: mesh,
        name: 'body',
        restPosition: Vector3(0, 0.8, 0),
      ),
    ]);
  }

  static Vector3 _classColorVec(PlayerClass cls) => switch (cls) {
    PlayerClass.spectre   => Vector3(0x44 / 255, 1.0,          0xCC / 255),
    PlayerClass.corsair   => Vector3(1.0,         0x44 / 255,  0xAA / 255),
    PlayerClass.geomancer => Vector3(1.0,         0x55 / 255,  0x44 / 255),
    PlayerClass.archon    => Vector3(0x44 / 255,  0x88 / 255,  1.0        ),
    PlayerClass.warden    => Vector3(1.0,         0xCC / 255,  0x44 / 255 ),
    PlayerClass.trickster => Vector3(0xAA / 255,  0x44 / 255,  1.0        ),
    PlayerClass.wrecker   => Vector3(1.0,         0x77 / 255,  0.0        ),
  };

  static CharacterRig build(Team team, PlayerClass playerClass) {
    final t = team.name;
    final c = playerClass.name;

    final jersey = _jerseyColor(team, playerClass);
    final pants  = _pantsColor(team);
    final helmet = _helmetColor(playerClass);
    final skin   = Vector3(0.82, 0.62, 0.45);
    final boot   = Vector3(0.22, 0.22, 0.24);

    return CharacterRig(parts: [
      RigPart(
        mesh: _box('${t}_${c}_head', 0.30, 0.35, 0.30, helmet),
        name: 'head',
        restPosition: Vector3(0, 1.60, 0),
      ),
      RigPart(
        mesh: _box('${t}_upperTorso', 0.50, 0.42, 0.28, jersey),
        name: 'upperTorso',
        restPosition: Vector3(0, 1.20, 0),
      ),
      RigPart(
        mesh: _box('${t}_lowerTorso', 0.42, 0.30, 0.24, pants),
        name: 'lowerTorso',
        restPosition: Vector3(0, 0.86, 0),
      ),
      RigPart(
        mesh: _box('${t}_upperArm', 0.18, 0.36, 0.18, skin),
        name: 'rightUpperArm',
        restPosition: Vector3(0.37, 1.18, 0),
      ),
      RigPart(
        mesh: _box('${t}_upperArm', 0.18, 0.36, 0.18, skin),
        name: 'leftUpperArm',
        restPosition: Vector3(-0.37, 1.18, 0),
      ),
      RigPart(
        mesh: _box('${t}_forearm', 0.15, 0.32, 0.15, skin),
        name: 'rightForearm',
        restPosition: Vector3(0.40, 0.84, 0),
      ),
      RigPart(
        mesh: _box('${t}_forearm', 0.15, 0.32, 0.15, skin),
        name: 'leftForearm',
        restPosition: Vector3(-0.40, 0.84, 0),
      ),
      RigPart(
        mesh: _box('${t}_thigh', 0.20, 0.36, 0.20, pants),
        name: 'rightThigh',
        restPosition: Vector3(0.12, 0.57, 0),
      ),
      RigPart(
        mesh: _box('${t}_thigh', 0.20, 0.36, 0.20, pants),
        name: 'leftThigh',
        restPosition: Vector3(-0.12, 0.57, 0),
      ),
      RigPart(
        mesh: _box('${t}_shin', 0.16, 0.34, 0.16, boot),
        name: 'rightShin',
        restPosition: Vector3(0.12, 0.18, 0),
      ),
      RigPart(
        mesh: _box('${t}_shin', 0.16, 0.34, 0.16, boot),
        name: 'leftShin',
        restPosition: Vector3(-0.12, 0.18, 0),
      ),
    ]);
  }

  // ── Color helpers ──────────────────────────────────────────────────────────

  static Vector3 _jerseyColor(Team team, PlayerClass playerClass) {
    // Base team color slightly shifted per class for lineup readability
    final base = team == Team.player
        ? Vector3(0.15, 0.30, 0.85)   // home: electric blue
        : Vector3(0.88, 0.15, 0.15);  // away: crimson

    final shift = _classJerseyShift(playerClass);
    return Vector3(
      (base.x + shift.x).clamp(0.0, 1.0),
      (base.y + shift.y).clamp(0.0, 1.0),
      (base.z + shift.z).clamp(0.0, 1.0),
    );
  }

  // Subtle per-class jersey tint so classes are distinguishable on the same team
  static Vector3 _classJerseyShift(PlayerClass cls) => switch (cls) {
    PlayerClass.spectre   => Vector3( 0.00,  0.08, -0.05),  // brighter mid
    PlayerClass.geomancer => Vector3(-0.05, -0.05,  0.00),  // slightly darker
    PlayerClass.archon   => Vector3( 0.05,  0.05,  0.05),  // lighter
    PlayerClass.warden  => Vector3(-0.02,  0.08,  0.04),  // cyan-ish
    PlayerClass.corsair  => Vector3( 0.08, -0.02, -0.08),  // warmer
    PlayerClass.trickster => Vector3(-0.10,  0.05,  0.15),  // TRICKSTER — purple shift
    PlayerClass.wrecker  => Vector3( 0.15, -0.08, -0.10),  // WRECKER — deep red-orange shift
  };

  static Vector3 _pantsColor(Team team) => team == Team.player
      ? Vector3(0.08, 0.12, 0.42)   // dark navy
      : Vector3(0.42, 0.08, 0.08);  // dark maroon

  static Vector3 _helmetColor(PlayerClass cls) => switch (cls) {
    PlayerClass.spectre   => Vector3(0.90, 0.75, 0.10),  // SPECTRE — gold
    PlayerClass.corsair  => Vector3(0.90, 0.45, 0.08),  // CORSAIR — orange
    PlayerClass.geomancer => Vector3(0.12, 0.45, 0.12),  // GEOMANCER — earthy green
    PlayerClass.archon   => Vector3(0.78, 0.78, 0.80),  // ARCHON — silver
    PlayerClass.warden  => Vector3(0.10, 0.80, 0.85),  // WARDEN — cyan
    PlayerClass.trickster => Vector3(0.60, 0.10, 0.90),  // TRICKSTER — violet
    PlayerClass.wrecker  => Vector3(0.85, 0.20, 0.02),  // WRECKER — crimson
  };
}
