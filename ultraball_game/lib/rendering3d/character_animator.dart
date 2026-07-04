import 'dart:math' as math;
import 'character_rig.dart';

/// Drives procedural animations on a [CharacterRig] each frame.
///
/// Call [update] once per frame. Priority: death > hit > attack > walk > idle.
class CharacterAnimator {
  CharacterAnimator._();

  static void update(CharacterRig rig, double dt) {
    rig.animTime += dt;

    if (rig.attackTimer > 0) {
      rig.attackTimer = math.max(0, rig.attackTimer - dt);
    }
    if (rig.hitTimer > 0) {
      rig.hitTimer = math.max(0, rig.hitTimer - dt);
    }
    if (rig.isDead) {
      rig.deathTimer += dt;
    }

    _resetAnimRotations(rig);

    if (rig.isDead) {
      rig.animState = AnimationState.death;
      _applyDeath(rig);
    } else if (rig.hitTimer > 0) {
      rig.animState = AnimationState.hit;
      _applyHit(rig);
    } else if (rig.attackTimer > 0) {
      rig.animState = AnimationState.attack;
      _applyAttack(rig);
    } else if (rig.isMoving) {
      rig.animState = AnimationState.walk;
      _applyWalk(rig);
    } else {
      rig.animState = AnimationState.idle;
      _applyIdle(rig);
    }
  }

  static void _resetAnimRotations(CharacterRig rig) {
    for (final p in rig.parts) {
      p.animRotation.setZero();
    }
  }

  static void _applyIdle(CharacterRig rig) {
    final t = rig.animTime;
    final breathe = math.sin(t * 1.2) * 0.6;
    rig.upperTorso?.animRotation.x = breathe;
    rig.head?.animRotation.x = math.sin(t * 1.2 + 0.2) * 0.4;
    final sway = math.sin(t * 0.9) * 1.8;
    rig.rightUpperArm?.animRotation.z = -sway;
    rig.leftUpperArm?.animRotation.z = sway;
    rig.rightForearm?.animRotation.z = -sway * 0.5;
    rig.leftForearm?.animRotation.z = sway * 0.5;
  }

  static void _applyWalk(CharacterRig rig) {
    final t = rig.animTime;
    final cycleSpeed = 3.0 + rig.moveSpeed * 0.6;
    final swing = math.sin(t * cycleSpeed);

    final armSwing = swing * 24.0;
    final legSwing = swing * 30.0;

    rig.rightUpperArm?.animRotation.x = armSwing;
    rig.leftUpperArm?.animRotation.x = -armSwing;
    rig.rightForearm?.animRotation.x = armSwing * 0.45;
    rig.leftForearm?.animRotation.x = -armSwing * 0.45;

    rig.rightThigh?.animRotation.x = -legSwing;
    rig.leftThigh?.animRotation.x = legSwing;
    rig.rightShin?.animRotation.x = math.max(0, -swing * 14.0);
    rig.leftShin?.animRotation.x = math.max(0, swing * 14.0);

    rig.upperTorso?.animRotation.y = swing * 3.5;
    rig.lowerTorso?.animRotation.y = -swing * 2.0;
  }

  static void _applyAttack(CharacterRig rig) {
    final phase = rig.attackTimer;
    double armAngle;

    if (phase > 0.25) {
      final t = (phase - 0.25) / 0.25;
      armAngle = t * -38.0;
    } else {
      final t = phase / 0.25;
      armAngle = (1.0 - t) * 78.0;
    }

    rig.rightUpperArm?.animRotation.x = armAngle;
    rig.rightForearm?.animRotation.x = armAngle * 0.55;
    rig.leftUpperArm?.animRotation.x = -armAngle * 0.18;
    rig.upperTorso?.animRotation.x = -armAngle * 0.13;
    rig.head?.animRotation.x = -armAngle * 0.09;
    rig.upperTorso?.animRotation.y = -armAngle * 0.15;
  }

  static void _applyHit(CharacterRig rig) {
    final t = rig.hitTimer / 0.3;
    final lean = t * -13.0;

    rig.upperTorso?.animRotation.x = lean;
    rig.head?.animRotation.x = lean * 0.9;
    rig.rightUpperArm?.animRotation.x = lean * 0.6;
    rig.leftUpperArm?.animRotation.x = lean * 0.6;
    rig.upperTorso?.animRotation.z = math.sin(t * math.pi) * 4.0;
  }

  static void _applyDeath(CharacterRig rig) {
    final rawT = (rig.deathTimer / 0.7).clamp(0.0, 1.0);
    final t = 1.0 - math.pow(1.0 - rawT, 3.0);

    final fallAngle = t * 88.0;
    rig.upperTorso?.animRotation.x = -fallAngle;
    rig.lowerTorso?.animRotation.x = -fallAngle * 0.55;
    rig.head?.animRotation.x = -fallAngle * 0.28;
    rig.rightUpperArm?.animRotation.x = -fallAngle * 0.35;
    rig.leftUpperArm?.animRotation.x = -fallAngle * 0.35;
    rig.rightThigh?.animRotation.x = fallAngle * 0.15;
    rig.leftThigh?.animRotation.x = fallAngle * 0.15;
  }
}
