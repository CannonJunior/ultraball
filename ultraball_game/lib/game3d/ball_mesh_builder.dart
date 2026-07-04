import 'package:vector_math/vector_math.dart';
import '../rendering3d/mesh.dart';
import '../rendering3d/math/transform3d.dart';

// The Ultraball is rendered as a core box surrounded by three perpendicular
// spike bars — one along each axis.  This gives it a recognisable cross/star
// silhouette from any camera angle.
//
// Core size: 0.40 m cube.  Spike bars: 0.10 m × 0.10 m × 0.60 m.
//
// Ball state determines which core mesh the render system draws:
//   coreLoose    – no possession (silver/gold)
//   coreHome     – home team holding (blue-white)
//   coreAway     – away team holding (red-white)
//   coreCharged  – charge > 50 % (orange)
//   coreCritical – charge > 80 % (alarm red)
//
// The three spike meshes (spikeX/Y/Z) are neutral and shared across all states.
// Their restRotation in the Transform3d provided by BallMeshes.spikeTransforms
// aligns each spike with its respective axis.

class BallMeshes {
  final Mesh coreLoose;
  final Mesh coreHome;
  final Mesh coreAway;
  final Mesh coreCharged;
  final Mesh coreCritical;

  // Single spike mesh geometry; render system places it three times using
  // spikeTransforms below.
  final Mesh spike;

  BallMeshes._({
    required this.coreLoose,
    required this.coreHome,
    required this.coreAway,
    required this.coreCharged,
    required this.coreCritical,
    required this.spike,
  });

  // ── Spike transforms ───────────────────────────────────────────────────────
  // The spike mesh is built as a Y-aligned bar (tall, thin).
  // We rotate it to align along X and Z for the other two spikes.
  // All three are centred at the same position as the core (no translation).

  static Transform3d spikeCoreTransform(Vector3 ballWorldPos) =>
      Transform3d(position: ballWorldPos);

  static Transform3d spikeXTransform(Vector3 ballWorldPos) =>
      Transform3d(position: ballWorldPos, rotation: Vector3(0, 0, 90));

  static Transform3d spikeYTransform(Vector3 ballWorldPos) =>
      Transform3d(position: ballWorldPos);

  static Transform3d spikeZTransform(Vector3 ballWorldPos) =>
      Transform3d(position: ballWorldPos, rotation: Vector3(90, 0, 0));
}

class BallMeshBuilder {
  static BallMeshes build() {
    const cw = 0.40; // core box half-side
    const sw = 0.10; // spike cross-section
    const sl = 0.60; // spike length

    return BallMeshes._(
      coreLoose: Mesh.box(
        width: cw, height: cw, depth: cw,
        color: Vector3(1.00, 0.95, 0.70),  // warm gold-white
      ),
      coreHome: Mesh.box(
        width: cw, height: cw, depth: cw,
        color: Vector3(0.60, 0.75, 1.00),  // blue-white
      ),
      coreAway: Mesh.box(
        width: cw, height: cw, depth: cw,
        color: Vector3(1.00, 0.68, 0.65),  // red-white
      ),
      coreCharged: Mesh.box(
        width: cw, height: cw, depth: cw,
        color: Vector3(1.00, 0.55, 0.08),  // orange
      ),
      coreCritical: Mesh.box(
        width: cw, height: cw, depth: cw,
        color: Vector3(1.00, 0.08, 0.08),  // alarm red
      ),
      // Y-aligned bar; rotated for X and Z spikes via spikeXTransform / spikeZTransform
      spike: Mesh.box(
        width: sw, height: sl, depth: sw,
        color: Vector3(0.90, 0.88, 0.60),  // slightly dim gold
      ),
    );
  }
}
