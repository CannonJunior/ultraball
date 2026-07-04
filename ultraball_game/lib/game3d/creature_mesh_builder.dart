import 'package:vector_math/vector_math.dart';
import '../rendering3d/mesh.dart';
import '../rendering3d/character_rig.dart';
import '../models/creature.dart';

// Builds a CharacterRig representing each creature type.
//
// Creature root transform: position = Vector3(creature.x, 0, creature.y).
// All parts have restPositions above ground (Y > 0).
//
// Creature footprint sizes match game creature.size values (radius in metres):
//   Kraken  3.5 → 7 m diameter flat disc + tentacles
//   Dragon  3.0 → elongated 8 m body + head + wings + tail
//   Hydra   4.0 → 8 m squat body + three heads on necks
//   Wraith  2.5 → tall 5 m wispy column + floating head
//   Chaos   3.0 → irregular spiked cube cluster
//
// CharacterAnimator is NOT called on creature rigs; they have no standard
// walk/attack animation.  A custom creature animator may use animRotation
// for body-bob effects in Phase 3.

class CreatureMeshBuilder {
  static CharacterRig build(CreatureType type) => switch (type) {
    CreatureType.kraken => _buildKraken(),
    CreatureType.dragon => _buildDragon(),
    CreatureType.hydra  => _buildHydra(),
    CreatureType.wraith => _buildWraith(),
    CreatureType.chaos  => _buildChaos(),
  };

  // ── Helpers ────────────────────────────────────────────────────────────────

  static RigPart _part(String name, Mesh mesh, Vector3 pos, {Vector3? rot}) =>
      RigPart(mesh: mesh, name: name, restPosition: pos, restRotation: rot);

  // ── Kraken ─────────────────────────────────────────────────────────────────
  // Deep purple: squat disc body + 4 thick tentacles radiating outward.

  static CharacterRig _buildKraken() {
    final bodyColor      = Vector3(0.35, 0.05, 0.55);
    final tentacleColor  = Vector3(0.45, 0.08, 0.65);
    final pupilColor     = Vector3(0.90, 0.10, 0.10);

    return CharacterRig(parts: [
      _part('body', Mesh.box(width: 7.0, height: 1.8, depth: 7.0, color: bodyColor),
            Vector3(0, 0.9, 0)),
      // 4 tentacles at cardinal positions, lying slightly above ground
      _part('tentacle0', Mesh.box(width: 1.2, height: 1.0, depth: 4.0, color: tentacleColor),
            Vector3(0, 0.5, 4.5)),
      _part('tentacle1', Mesh.box(width: 1.2, height: 1.0, depth: 4.0, color: tentacleColor),
            Vector3(0, 0.5, -4.5)),
      _part('tentacle2', Mesh.box(width: 4.0, height: 1.0, depth: 1.2, color: tentacleColor),
            Vector3(4.5, 0.5, 0)),
      _part('tentacle3', Mesh.box(width: 4.0, height: 1.0, depth: 1.2, color: tentacleColor),
            Vector3(-4.5, 0.5, 0)),
      // Glowing red eye on top
      _part('eye', Mesh.box(width: 0.8, height: 0.5, depth: 0.8, color: pupilColor),
            Vector3(0, 1.85, 0)),
    ]);
  }

  // ── Dragon ─────────────────────────────────────────────────────────────────
  // Fiery orange: elongated body facing +X, head/neck forward, wings, tail.

  static CharacterRig _buildDragon() {
    final bodyColor = Vector3(0.88, 0.38, 0.05);
    final headColor = Vector3(0.75, 0.28, 0.02);
    final wingColor = Vector3(0.70, 0.22, 0.02);
    final eyeColor  = Vector3(1.0, 0.85, 0.0);

    return CharacterRig(parts: [
      _part('body', Mesh.box(width: 5.0, height: 2.0, depth: 2.5, color: bodyColor),
            Vector3(0, 1.0, 0)),
      _part('neck', Mesh.box(width: 1.2, height: 0.9, depth: 1.0, color: bodyColor),
            Vector3(3.0, 1.8, 0)),
      _part('head', Mesh.box(width: 2.2, height: 1.4, depth: 1.8, color: headColor),
            Vector3(4.5, 2.2, 0)),
      _part('eye', Mesh.box(width: 0.35, height: 0.35, depth: 0.4, color: eyeColor),
            Vector3(5.5, 2.6, 0.6)),
      // Wings spread to each side in Z
      _part('leftWing',  Mesh.box(width: 3.0, height: 0.25, depth: 3.0, color: wingColor),
            Vector3(-0.5, 2.2,  3.5)),
      _part('rightWing', Mesh.box(width: 3.0, height: 0.25, depth: 3.0, color: wingColor),
            Vector3(-0.5, 2.2, -3.5)),
      // Tail extends behind in -X
      _part('tail', Mesh.box(width: 3.5, height: 0.6, depth: 0.6, color: bodyColor),
            Vector3(-3.8, 0.5, 0)),
    ]);
  }

  // ── Hydra ──────────────────────────────────────────────────────────────────
  // Dark green: massive squat body + three long necks each ending in a head.

  static CharacterRig _buildHydra() {
    final bodyColor = Vector3(0.12, 0.42, 0.08);
    final headColor = Vector3(0.18, 0.55, 0.10);
    final eyeColor  = Vector3(0.90, 0.80, 0.0);
    final neckColor = Vector3(0.10, 0.36, 0.06);

    return CharacterRig(parts: [
      _part('body', Mesh.box(width: 5.0, height: 3.5, depth: 4.5, color: bodyColor),
            Vector3(0, 1.75, 0)),

      // Left head
      _part('neckLeft',  Mesh.box(width: 0.7, height: 2.5, depth: 0.7, color: neckColor),
            Vector3(1.2, 4.5, -1.5)),
      _part('headLeft',  Mesh.box(width: 1.6, height: 1.2, depth: 1.6, color: headColor),
            Vector3(2.0, 5.8, -1.5)),
      _part('eyeLeft',   Mesh.box(width: 0.3, height: 0.3, depth: 0.4, color: eyeColor),
            Vector3(2.8, 6.1, -1.0)),

      // Centre head
      _part('neckCentre',  Mesh.box(width: 0.7, height: 2.5, depth: 0.7, color: neckColor),
            Vector3(1.8, 4.8, 0)),
      _part('headCentre',  Mesh.box(width: 1.6, height: 1.2, depth: 1.6, color: headColor),
            Vector3(2.8, 6.2, 0)),
      _part('eyeCentre',   Mesh.box(width: 0.3, height: 0.3, depth: 0.4, color: eyeColor),
            Vector3(3.6, 6.5, 0.4)),

      // Right head
      _part('neckRight',  Mesh.box(width: 0.7, height: 2.5, depth: 0.7, color: neckColor),
            Vector3(1.2, 4.5, 1.5)),
      _part('headRight',  Mesh.box(width: 1.6, height: 1.2, depth: 1.6, color: headColor),
            Vector3(2.0, 5.8, 1.5)),
      _part('eyeRight',   Mesh.box(width: 0.3, height: 0.3, depth: 0.4, color: eyeColor),
            Vector3(2.8, 6.1, 2.0)),
    ]);
  }

  // ── Wraith ─────────────────────────────────────────────────────────────────
  // Pale spectral: tall thin shroud + floating head + wispy trailing arms.

  static CharacterRig _buildWraith() {
    final shroudColor = Vector3(0.82, 0.88, 0.95);
    final headColor   = Vector3(0.92, 0.95, 1.00);
    final armColor    = Vector3(0.70, 0.78, 0.88);
    final eyeColor    = Vector3(0.50, 0.10, 0.90);  // violet glow

    return CharacterRig(parts: [
      // Shroud — tall, very thin
      _part('shroud', Mesh.box(width: 2.0, height: 4.0, depth: 0.7, color: shroudColor),
            Vector3(0, 2.0, 0)),
      // Floating head slightly detached above shroud
      _part('head', Mesh.box(width: 1.2, height: 1.0, depth: 0.6, color: headColor),
            Vector3(0, 4.6, 0)),
      _part('eyes', Mesh.box(width: 0.6, height: 0.25, depth: 0.25, color: eyeColor),
            Vector3(0, 4.8, 0.32)),
      // Wispy arms
      _part('leftArm',  Mesh.box(width: 0.25, height: 2.0, depth: 0.25, color: armColor),
            Vector3(-1.4, 2.8, 0), rot: Vector3(0, 0, 20)),
      _part('rightArm', Mesh.box(width: 0.25, height: 2.0, depth: 0.25, color: armColor),
            Vector3( 1.4, 2.8, 0), rot: Vector3(0, 0, -20)),
    ]);
  }

  // ── Chaos ──────────────────────────────────────────────────────────────────
  // Bright magenta: asymmetric cube cluster that telegraphs chaotic behaviour.

  static CharacterRig _buildChaos() {
    final coreColor   = Vector3(0.95, 0.05, 0.90);   // magenta
    final spike1Color = Vector3(1.0,  0.85, 0.0);    // yellow spike
    final spike2Color = Vector3(0.0,  0.9,  0.95);   // cyan spike
    final eyeColor    = Vector3(1.0,  1.0,  1.0);    // white stare

    return CharacterRig(parts: [
      // Core — a large irregular cube
      _part('core', Mesh.box(width: 4.5, height: 4.5, depth: 4.5, color: coreColor),
            Vector3(0, 2.25, 0)),
      // Asymmetric vertical spike
      _part('spikeUp',    Mesh.box(width: 0.6, height: 3.5, depth: 0.6, color: spike1Color),
            Vector3(0.8, 5.5, 0.4)),
      // Horizontal spike in X
      _part('spikeRight', Mesh.box(width: 3.5, height: 0.6, depth: 0.6, color: spike1Color),
            Vector3(3.8, 2.8, -0.5)),
      // Diagonal spike in Z
      _part('spikeFront', Mesh.box(width: 0.6, height: 0.6, depth: 3.5, color: spike2Color),
            Vector3(-1.2, 1.8, 3.5)),
      // Extra off-centre spike for asymmetry
      _part('spikeSkew',  Mesh.box(width: 0.5, height: 2.5, depth: 0.5, color: spike2Color),
            Vector3(-2.0, 4.2, -1.0)),
      // Glaring white eye cluster
      _part('eyes', Mesh.box(width: 1.2, height: 0.5, depth: 0.6, color: eyeColor),
            Vector3(2.3, 3.5, 2.3)),
    ]);
  }
}
