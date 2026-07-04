import 'dart:math' as math;
import 'package:vector_math/vector_math.dart';

class Transform3d {
  Vector3 position;
  Vector3 rotation;
  Vector3 scale;

  Transform3d({
    Vector3? position,
    Vector3? rotation,
    Vector3? scale,
  })  : position = position ?? Vector3.zero(),
        rotation = rotation ?? Vector3.zero(),
        scale = scale ?? Vector3(1, 1, 1);

  factory Transform3d.fromMatrix(Matrix4 matrix) {
    final position = matrix.getTranslation();
    final scale = matrix.getMaxScaleOnAxis();
    return Transform3d(
      position: position,
      scale: Vector3(scale, scale, scale),
    );
  }

  Matrix4 toMatrix() {
    final matrix = Matrix4.identity();

    matrix.translateByVector3(position);

    final yawRad = radians(rotation.y);
    final pitchRad = radians(rotation.x);
    final rollRad = radians(rotation.z);

    matrix.rotateY(yawRad);
    matrix.rotateX(pitchRad);
    matrix.rotateZ(rollRad);

    matrix.scaleByVector3(scale);

    return matrix;
  }

  Vector3 get forward {
    final yawRad = radians(rotation.y);
    final pitchRad = radians(rotation.x);

    return Vector3(
      -math.sin(yawRad) * math.cos(pitchRad),
      math.sin(pitchRad),
      -math.cos(yawRad) * math.cos(pitchRad),
    ).normalized();
  }

  Vector3 get right {
    final yawRad = radians(rotation.y);

    return Vector3(
      math.cos(yawRad),
      0,
      -math.sin(yawRad),
    ).normalized();
  }

  Vector3 get up {
    return forward.cross(right).normalized();
  }

  void translate(Vector3 delta) {
    position += delta;
  }

  void rotate(Vector3 deltaRotation) {
    rotation += deltaRotation;

    rotation.x = rotation.x % 360;
    rotation.y = rotation.y % 360;
    rotation.z = rotation.z % 360;
  }

  void scaleUniform(double factor) {
    scale.scale(factor);
  }

  Transform3d clone() {
    return Transform3d(
      position: Vector3.copy(position),
      rotation: Vector3.copy(rotation),
      scale: Vector3.copy(scale),
    );
  }

  Transform3d lerp(Transform3d other, double t) {
    return Transform3d(
      position: position * (1 - t) + other.position * t,
      rotation: rotation * (1 - t) + other.rotation * t,
      scale: scale * (1 - t) + other.scale * t,
    );
  }

  @override
  String toString() {
    return 'Transform3d(pos: $position, rot: $rotation, scale: $scale)';
  }
}
