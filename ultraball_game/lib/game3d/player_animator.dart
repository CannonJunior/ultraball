import '../rendering3d/character_rig.dart';
import '../rendering3d/character_animator.dart';
import '../models/player.dart';

// Maps UltraballPlayer game state onto a CharacterRig, then delegates to
// CharacterAnimator.update() to advance the procedural animation.
//
// Called once per frame per on-field player from UltraballRenderSystem.update().
//
// State mapping:
//   player.isAlive == false    → rig.triggerDeath() (once)
//   PlayerState.moving         → rig.isMoving = true, rig.moveSpeed = player.speed
//   PlayerState.attacking      → rig.triggerAttack() (once per attack, gated by timer)
//   PlayerState.stunned        → rig.triggerHit() (once at stun onset)
//   idle / all others          → rig.isMoving = false
//
// isCasting is intentionally unused — Ultraball has no cast state.

class PlayerAnimator {
  PlayerAnimator._();

  static void update(UltraballPlayer player, CharacterRig rig, double dt) {
    // Death takes priority over everything
    if (!player.isAlive) {
      if (!rig.isDead) rig.triggerDeath();
      CharacterAnimator.update(rig, dt);
      return;
    }

    // Velocity-based walk detection; more reliable than PlayerState alone since
    // the state machine may lag behind physics by a frame.
    rig.isMoving = player.velX.abs() + player.velY.abs() > 0.3;
    rig.moveSpeed = player.speed;

    // Attack — fire once per attack sequence, don't spam while state persists.
    if (player.state == PlayerState.attacking && rig.attackTimer <= 0) {
      rig.triggerAttack();
    }

    // Stun → hit-reaction.  Gate on stunTimer > 0.25 so we only trigger at
    // the start of a fresh stun, not every frame while stunned.
    if (player.state == PlayerState.stunned &&
        player.stunTimer > 0.25 &&
        rig.hitTimer <= 0) {
      rig.triggerHit();
    }

    CharacterAnimator.update(rig, dt);
  }
}
