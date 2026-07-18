import 'dart:math' as math;

/// A Fissure rock projectile arcing through the air toward its landing target.
class FissureProjectile {
  final double launchX, launchY;
  final double targetX, targetY;
  final double flightTime;
  final double radius;
  final double pitDuration;
  double age = 0.0;

  bool   get isDone    => age >= flightTime;
  double get progress  => flightTime > 0 ? (age / flightTime).clamp(0.0, 1.0) : 1.0;
  double get currentX  => launchX + (targetX - launchX) * progress;
  double get currentY  => launchY + (targetY - launchY) * progress;

  double get zHeight {
    const g = 20.0;
    final initVZ = 0.5 * g * flightTime;
    final t = age.clamp(0.0, flightTime);
    return math.max(0.0, initVZ * t - 0.5 * g * t * t);
  }

  FissureProjectile({
    required this.launchX,
    required this.launchY,
    required this.targetX,
    required this.targetY,
    required this.flightTime,
    this.radius = 3.0,
    this.pitDuration = 5.0,
  });
}

/// World-space circular pit used for rendering (circles, not grid squares).
/// Cell grid retains isPit for collision; this drives all visual drawing.
class PitEffect {
  final double worldX, worldY, radius;
  final double duration;
  double age = 0.0;

  bool   get isDone => age >= duration;
  double get depth  => (age * 2.0).clamp(0.0, 1.0); // 0→1 over 0.5 s

  PitEffect({required this.worldX, required this.worldY, required this.radius, required this.duration});
}

/// The ground cracks and shakes for [warningDuration] seconds before the pit opens.
class FissureWarning {
  final double worldX, worldY;
  final double radius;
  final double pitDuration;
  static const double warningDuration = 1.5;
  double age = 0.0;

  double get progress => (age / warningDuration).clamp(0.0, 1.0);
  bool   get isDone   => age >= warningDuration;

  FissureWarning({
    required this.worldX,
    required this.worldY,
    this.radius = 3.0,
    this.pitDuration = 5.0,
  });
}
