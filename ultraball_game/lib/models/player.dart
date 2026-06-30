import 'dart:math' as math;

enum PlayerState { idle, moving, attacking, stunned, dead }

enum Team { player, opponent }

class UltraballPlayer {
  final String id;
  final String name;
  final Team team;
  final int rosterIndex; // 0–14

  // Position in field meters
  double x, y;
  double velX = 0, velY = 0;
  double facing = 0.0; // radians, 0=right

  // Stats
  double health = 100;
  double maxHealth = 100;
  double redMana = 0;
  double blueMana = 100;
  bool isAlive = true;
  bool isOnField = false; // false=on sideline
  bool isSelected = false; // player is controlling this unit

  // State
  PlayerState state = PlayerState.idle;
  double stunTimer = 0;
  double speedBoostTimer = 0;
  double baseSpeed = 8.0; // m/s

  // Cooldowns
  double tackleCooldown = 0;
  double slamCooldown = 0;
  double sprintCooldown = 0;
  double passCooldown = 0;

  // Combat
  double redManaDecayTimer = 0;
  int comboCount = 0;
  double comboTimer = 0;

  // Red mana decay
  static const double redDecayDelay = 3.0;
  static const double redDecayRate = 3.0;

  // Jump physics
  double zHeight = 0.0;        // altitude in meters above ground (0 = grounded)
  double zVelocity = 0.0;      // vertical velocity in m/s (+up, −down)
  bool hasDoubleJumped = false; // true once the double-jump has been consumed

  static const double _jumpVelocity       = 16.0;  // m/s upward on first jump
  static const double _doubleJumpVelocity = 14.0;  // m/s upward on double-jump
  static const double _gravity            = 35.0;  // m/s² downward acceleration
  static const double doubleJumpManaCost  = 15.0;  // blue mana cost

  bool get isAirborne => zHeight > 0 || zVelocity > 0;

  // When true, facing is controlled by A/D input — not derived from velocity
  bool isPlayerControlled = false;

  // Throw charging
  bool isChargingThrow = false;
  double throwChargeTime = 0.0;
  static const double maxThrowChargeTime = 2.0;

  double get throwChargePercent =>
      (throwChargeTime / maxThrowChargeTime).clamp(0.0, 1.0);

  // 5m at zero charge → 40m at full charge
  double get throwDistance => 5.0 + 35.0 * throwChargePercent;

  UltraballPlayer({
    required this.id,
    required this.name,
    required this.team,
    required this.rosterIndex,
    required this.x,
    required this.y,
  });

  double get speed =>
      isAlive ? baseSpeed * (speedBoostTimer > 0 ? 1.5 : 1.0) : 0;

  bool get isStunned => state == PlayerState.stunned;

  void update(double dt) {
    if (!isAlive) return;

    // Update timers
    if (stunTimer > 0) {
      stunTimer -= dt;
      if (stunTimer <= 0) {
        stunTimer = 0;
        state = PlayerState.idle;
      }
    }
    if (speedBoostTimer > 0) speedBoostTimer -= dt;
    if (tackleCooldown > 0) tackleCooldown -= dt;
    if (slamCooldown > 0) slamCooldown -= dt;
    if (sprintCooldown > 0) sprintCooldown -= dt;
    if (passCooldown > 0) passCooldown -= dt;

    // Combo timer
    if (comboCount > 0) {
      comboTimer += dt;
      if (comboTimer > 4.0) {
        comboCount = 0;
        comboTimer = 0;
      }
    }

    // Red mana decay
    redManaDecayTimer += dt;
    if (redManaDecayTimer > redDecayDelay && redMana > 0) {
      redMana = math.max(0, redMana - redDecayRate * dt);
    }

    // Blue mana regen
    blueMana = math.min(100, blueMana + 8.0 * dt);

    // Jump physics — gravity pulls zHeight back to ground
    if (isAirborne) {
      zVelocity -= _gravity * dt;
      zHeight += zVelocity * dt;
      if (zHeight <= 0) {
        zHeight = 0.0;
        zVelocity = 0.0;
        hasDoubleJumped = false; // jumps reset on landing
      }
    }

    // Apply velocity
    if (state != PlayerState.stunned) {
      x += velX * dt;
      y += velY * dt;
    }

    // Clamp to field
    x = x.clamp(0.0, 140.0);
    y = y.clamp(0.0, 40.0);

    // AI-controlled units auto-face their movement direction
    if (!isPlayerControlled && (velX != 0 || velY != 0)) {
      facing = math.atan2(velY, velX);
    }
  }

  void stun(double duration) {
    if (!isAlive) return;
    state = PlayerState.stunned;
    stunTimer = duration;
    velX = 0;
    velY = 0;
  }

  void die() {
    isAlive = false;
    isOnField = false;
    state = PlayerState.dead;
    velX = 0;
    velY = 0;
    health = 0;
  }

  /// Attempt a jump or double-jump. Returns true if a jump was initiated.
  bool tryJump() {
    if (!isAlive || isStunned) return false;

    if (!isAirborne) {
      // First jump — free
      zVelocity = _jumpVelocity;
      zHeight = 0.001; // ensure isAirborne becomes true this frame
      return true;
    }

    if (!hasDoubleJumped && blueMana >= doubleJumpManaCost) {
      // Double-jump — costs blue mana, boosts vertical velocity upward again
      blueMana -= doubleJumpManaCost;
      zVelocity = _doubleJumpVelocity;
      hasDoubleJumped = true;
      return true;
    }

    return false;
  }

  void gainRedMana(double amount) {
    redMana = math.min(100, redMana + amount);
    redManaDecayTimer = 0;
  }
}
