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

  // ── Per-match team colors (set once per game via setTeamColors) ───────────
  static Vector3 _homePrimary   = Vector3(0.15, 0.30, 0.85);
  static Vector3 _homeSecondary = Vector3(0.08, 0.12, 0.42);
  static Vector3 _awayPrimary   = Vector3(0.88, 0.15, 0.15);
  static Vector3 _awaySecondary = Vector3(0.42, 0.08, 0.08);

  /// Call once at game start. Clears the mesh cache so new colors take effect.
  static void setTeamColors({
    required Vector3 homePrimary,
    required Vector3 homeSecondary,
    required Vector3 awayPrimary,
    required Vector3 awaySecondary,
  }) {
    _homePrimary   = homePrimary;
    _homeSecondary = homeSecondary;
    _awayPrimary   = awayPrimary;
    _awaySecondary = awaySecondary;
    _cache.clear();
  }

  static Vector3 _teamPrimary(Team team) =>
      team == Team.player ? _homePrimary : _awayPrimary;

  static Vector3 _teamSecondary(Team team) =>
      team == Team.player ? _homeSecondary : _awaySecondary;

  static Mesh _box(String key, double w, double h, double d, Vector3 color) {
    return _cache.putIfAbsent(
      key, () => Mesh.box(width: w, height: h, depth: d, color: color));
  }

  static CharacterRig buildCube(Team team) {
    final color = _teamPrimary(team);
    final key = 'cube_${team.name}_${color.r}_${color.g}_${color.b}';
    final mesh = _cache.putIfAbsent(
      key,
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
    final color = playerClass.meshColor;
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

  static CharacterRig build(Team team, PlayerClass playerClass) {
    final t = team.name;
    final c = playerClass.name;

    final jersey = _jerseyColor(team, playerClass);
    final pants  = _pantsColor(team);
    final helmet = playerClass.helmetColor;
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
    final base  = _teamPrimary(team);
    final shift = playerClass.jerseyShift;
    return Vector3(
      (base.x + shift.x).clamp(0.0, 1.0),
      (base.y + shift.y).clamp(0.0, 1.0),
      (base.z + shift.z).clamp(0.0, 1.0),
    );
  }

  static Vector3 _pantsColor(Team team) => _teamSecondary(team);
}
