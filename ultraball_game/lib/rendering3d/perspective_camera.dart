import 'dart:math' as math;
import 'package:vector_math/vector_math.dart';
import 'math/transform3d.dart';

enum CameraMode {
  broadcast,    // Fixed overhead broadcast camera
  thirdPerson,  // Third-person follow camera (possession view)
}

class PerspectiveCamera {
  final Transform3d transform;

  double fov;
  double aspectRatio;
  final double near;
  final double far;

  Vector3? _target;
  double _targetDistance = 10.0;

  final double minPitch = -89.0;
  final double maxPitch = 89.0;

  CameraMode _mode = CameraMode.broadcast;

  double _thirdPersonDistance = 8.0;
  double _thirdPersonHeight = 4.0;
  double _thirdPersonPitch = 25.0;
  final double _thirdPersonFOV = 90.0;
  final double _broadcastFOV = 60.0;

  // Unused in Ultraball but retained for API compatibility with updateCameraLerp
  double rollAngle = 0.0;
  double targetPitchOffset = 0.0;

  final double _cameraLerpSpeed = 8.0;

  double? _lerpTargetPitch;
  double? _lerpTargetDistance;
  double? _lerpTargetFov;

  PerspectiveCamera({
    Vector3? position,
    Vector3? rotation,
    this.fov = 60.0,
    this.aspectRatio = 16.0 / 9.0,
    this.near = 0.1,
    this.far = 1000.0,
  }) : transform = Transform3d(
          position: position ?? Vector3(0, 5, 10),
          rotation: rotation ?? Vector3(0, 0, 0),
        );

  Matrix4 getViewMatrix() {
    final up = _getCameraUpVector();

    if (_target != null) {
      final effectiveTarget = targetPitchOffset != 0.0
          ? Vector3(_target!.x, _target!.y + targetPitchOffset, _target!.z)
          : _target!;
      return makeViewMatrix(transform.position, effectiveTarget, up);
    } else {
      final forward = transform.forward;
      final lookAt = transform.position + forward;
      return makeViewMatrix(transform.position, lookAt, up);
    }
  }

  Vector3 _getCameraUpVector() {
    if (rollAngle == 0.0) return Vector3(0, 1, 0);

    Vector3 viewDir;
    if (_target != null) {
      viewDir = (_target! - transform.position).normalized();
    } else {
      viewDir = transform.forward;
    }

    final rollRad = radians(rollAngle);
    final cosA = math.cos(rollRad);
    final sinA = math.sin(rollRad);
    final worldUp = Vector3(0, 1, 0);
    final dot = viewDir.dot(worldUp);
    final cross = viewDir.cross(worldUp);

    return worldUp * cosA + cross * sinA + viewDir * (dot * (1 - cosA));
  }

  Matrix4 getProjectionMatrix() {
    return makePerspectiveMatrix(radians(fov), aspectRatio, near, far);
  }

  void setTarget(Vector3 target) {
    _target = target;
    updatePositionFromTarget();
  }

  Vector3 getTarget() => _target ?? Vector3.zero();

  void clearTarget() {
    _target = null;
  }

  void updatePositionFromTarget() {
    if (_target == null) return;

    final pitchRad = radians(transform.rotation.x);
    final yawRad = radians(transform.rotation.y);

    final x = _targetDistance * -math.sin(yawRad) * math.cos(pitchRad);
    final y = _targetDistance * math.sin(pitchRad);
    final z = _targetDistance * -math.cos(yawRad) * math.cos(pitchRad);

    transform.position = _target! + Vector3(x, y, z);
  }

  void pitchBy(double deltaDegrees) {
    transform.rotation.x = (transform.rotation.x + deltaDegrees).clamp(minPitch, maxPitch);
    if (_target != null) updatePositionFromTarget();
  }

  void yawBy(double deltaDegrees) {
    transform.rotation.y = (transform.rotation.y + deltaDegrees) % 360.0;
    if (_target != null) updatePositionFromTarget();
  }

  void setTargetDistance(double distance) {
    _targetDistance = distance.clamp(1.0, 100.0);
    if (_target != null) updatePositionFromTarget();
  }

  void zoom(double delta) {
    setTargetDistance(_targetDistance + delta);
  }

  void moveForward(double distance) {
    transform.position += transform.forward * distance;
  }

  void strafe(double distance) {
    transform.position += transform.right * distance;
  }

  void moveVertical(double distance) {
    transform.position.y += distance;
  }

  double get pitch => transform.rotation.x;
  double get yaw => transform.rotation.y;
  Vector3 get position => transform.position;
  Vector3 get forward => transform.forward;
  Vector3 get right => transform.right;
  Vector3 get up => transform.up;

  CameraMode get mode => _mode;

  void setMode(CameraMode newMode) {
    if (_mode == newMode) return;
    _mode = newMode;
    fov = _mode == CameraMode.thirdPerson ? _thirdPersonFOV : _broadcastFOV;
  }

  void toggleMode() {
    setMode(_mode == CameraMode.broadcast ? CameraMode.thirdPerson : CameraMode.broadcast);
  }

  void updateThirdPersonFollow(Vector3 targetPosition, double targetRotation, double dt) {
    if (_mode != CameraMode.thirdPerson) return;

    final rotationRad = radians(targetRotation + 180.0);
    final offsetX = -math.sin(rotationRad) * _thirdPersonDistance;
    final offsetZ = -math.cos(rotationRad) * _thirdPersonDistance;

    final desiredPosition = Vector3(
      targetPosition.x + offsetX,
      targetPosition.y + _thirdPersonHeight,
      targetPosition.z + offsetZ,
    );

    final lerpFactor = math.min(1.0, _cameraLerpSpeed * dt);
    transform.position = Vector3(
      transform.position.x + (desiredPosition.x - transform.position.x) * lerpFactor,
      transform.position.y + (desiredPosition.y - transform.position.y) * lerpFactor,
      transform.position.z + (desiredPosition.z - transform.position.z) * lerpFactor,
    );

    _target = Vector3(targetPosition.x, targetPosition.y + 1.0, targetPosition.z);
    transform.rotation.x = _thirdPersonPitch;
    transform.rotation.y = targetRotation;
  }

  void setThirdPersonDistance(double distance) {
    _thirdPersonDistance = distance.clamp(3.0, 15.0);
  }

  void setThirdPersonHeight(double height) {
    _thirdPersonHeight = height.clamp(1.0, 10.0);
  }

  void setThirdPersonPitch(double pitch) {
    _thirdPersonPitch = pitch.clamp(0.0, 60.0);
  }

  /// Set lerp targets for a smooth camera transition. Call [updateCameraLerp]
  /// each frame to advance toward the targets.
  void startCameraTransition({
    double? targetPitch,
    double? targetDistance,
    double? targetFov,
  }) {
    _lerpTargetPitch    = targetPitch;
    _lerpTargetDistance = targetDistance;
    _lerpTargetFov      = targetFov;
  }

  /// Advance active lerp targets each frame. Clears a target once converged
  /// so manual input takes over from that point.
  void updateCameraLerp(double dt) {
    final t = math.min(1.0, _cameraLerpSpeed * dt);

    if (_lerpTargetPitch != null) {
      final cur = transform.rotation.x;
      final next = cur + (_lerpTargetPitch! - cur) * t;
      transform.rotation.x = next.clamp(minPitch, maxPitch);
      if ((transform.rotation.x - _lerpTargetPitch!).abs() < 0.05) {
        transform.rotation.x = _lerpTargetPitch!;
        _lerpTargetPitch = null;
      }
      if (_target != null) updatePositionFromTarget();
    }

    if (_lerpTargetDistance != null) {
      _targetDistance += (_lerpTargetDistance! - _targetDistance) * t;
      if ((_targetDistance - _lerpTargetDistance!).abs() < 0.05) {
        _targetDistance     = _lerpTargetDistance!;
        _lerpTargetDistance = null;
      }
      if (_target != null) updatePositionFromTarget();
    }

    if (_lerpTargetFov != null) {
      fov += (_lerpTargetFov! - fov) * t;
      if ((fov - _lerpTargetFov!).abs() < 0.05) {
        fov            = _lerpTargetFov!;
        _lerpTargetFov = null;
      }
    }
  }
}
