import 'package:vector_math/vector_math.dart';
import '../rendering3d/mesh.dart';
import '../rendering3d/math/transform3d.dart';

// Field coordinate system:
//   World X = game entity.x  (0 = home end, 140 = away end)
//   World Z = game entity.y  (0 = top edge, 40 = bottom edge)
//   World Y = vertical (0 = ground, positive = up)
//
// Field sections (game X ranges):
//   Home endzone:   0–20
//   Left channel:  20–30   (home creature zone)
//   Main field:   30–110   (phase lines at 30, 50, 70, 90, 110)
//   Right channel: 110–120 (away creature zone)
//   Away endzone: 120–140

class FieldMeshes {
  final Mesh homeEndzone;
  final Mesh leftChannel;
  final Mesh mainField;
  final Mesh rightChannel;
  final Mesh awayEndzone;
  // Single mesh used for all 5 phase line walls; render system picks
  // active vs inactive based on ball.phaseLineActive[i].
  final Mesh phaseLineActive;
  final Mesh phaseLineInactive;

  FieldMeshes._({
    required this.homeEndzone,
    required this.leftChannel,
    required this.mainField,
    required this.rightChannel,
    required this.awayEndzone,
    required this.phaseLineActive,
    required this.phaseLineInactive,
  });

  // ── Static transform helpers ───────────────────────────────────────────────
  // Mesh.plane is built centered at origin; these positions center each zone
  // in its correct world-space location.

  static Transform3d homeEndzoneTransform() =>
      Transform3d(position: Vector3(10.0, 0, 20.0));

  static Transform3d leftChannelTransform() =>
      Transform3d(position: Vector3(25.0, 0, 20.0));

  static Transform3d mainFieldTransform() =>
      Transform3d(position: Vector3(70.0, 0, 20.0));

  static Transform3d rightChannelTransform() =>
      Transform3d(position: Vector3(115.0, 0, 20.0));

  static Transform3d awayEndzoneTransform() =>
      Transform3d(position: Vector3(130.0, 0, 20.0));

  // Phase line X positions (game coords) correspond to world X.
  // The box is 3 m tall, so center its Y at 1.5.
  static const List<double> _phaseLineXCoords = [30, 50, 70, 90, 110];

  static Transform3d phaseLineTransform(int index) => Transform3d(
        position: Vector3(_phaseLineXCoords[index], 0.04, 20.0),
      );
}

class FieldMeshBuilder {
  static FieldMeshes build() {
    return FieldMeshes._(
      // Ground zones — Mesh.plane: width = X span, height = Z span (depth)
      homeEndzone: Mesh.plane(
        width: 20.0, height: 40.0,
        color: Vector3(0.12, 0.22, 0.50),
      ),
      leftChannel: Mesh.plane(
        width: 10.0, height: 40.0,
        color: Vector3(0.40, 0.28, 0.18),
      ),
      mainField: Mesh.plane(
        width: 80.0, height: 40.0,
        color: Vector3(0.10, 0.38, 0.12),
      ),
      rightChannel: Mesh.plane(
        width: 10.0, height: 40.0,
        color: Vector3(0.40, 0.28, 0.18),
      ),
      awayEndzone: Mesh.plane(
        width: 20.0, height: 40.0,
        color: Vector3(0.50, 0.10, 0.10),
      ),

      // Phase line walls — thin vertical box spanning the full field width (Z)
      phaseLineActive: Mesh.box(
        width: 0.35, height: 0.08, depth: 40.0,
        color: Vector3(0.0, 0.88, 1.0),
      ),
      phaseLineInactive: Mesh.box(
        width: 0.35, height: 0.08, depth: 40.0,
        color: Vector3(0.14, 0.20, 0.28),
      ),
    );
  }
}
