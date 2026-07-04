import 'dart:math' as math;
import 'player_class.dart';

export 'player_class.dart';

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

  // Class
  PlayerClass playerClass = PlayerClass.runner;

  // Stats
  double health = 100;
  double maxHealth = 100;
  double redMana = 0;
  double blueMana = 100;
  // Third mana — Ultra: earned by holding ball, scoring, and act wins
  double ultraMana = 0.0;
  static const double maxUltraMana = 10.0;

  bool isAlive = true;
  bool isOnField = false;
  int deploySlot = 0; // position in deployment order: 0 = first on field, 14 = last reserve
  bool isSelected = false;

  // State
  PlayerState state = PlayerState.idle;
  double stunTimer = 0;
  double speedBoostTimer = 0;  // 1.5× sprint
  double baseSpeed = 8.0;

  // Ability cooldowns — slots 1–3 keep legacy names for AI compat
  double tackleCooldown = 0;    // slot 1
  double slamCooldown = 0;      // slot 2
  double sprintCooldown = 0;    // slot 3
  double passCooldown = 0;
  double ability4Cooldown = 0;  // slot 4
  double ability5Cooldown = 0;  // slot 5
  double ability6Cooldown = 0;  // slot 6
  double ability7Cooldown = 0;  // slot 7
  double ability8Cooldown = 0;  // slot 8
  double ability9Cooldown = 0;  // slot 9
  // slot 10 = ultra, no cooldown — gated by ultra mana

  // Combat
  double redManaDecayTimer = 0;
  int comboCount = 0;
  double comboTimer = 0;

  // Buffs
  double damageBoostFactor = 1.0;
  double damageBoostTimer = 0.0;
  double damageReductionFactor = 1.0;
  double damageReductionTimer = 0.0;
  bool stunImmune = false;
  double stunImmuneTimer = 0.0;
  double speedMultiplierOverride = 1.5;
  double speedMultiplierTimer = 0.0;

  // Snare debuff
  double snareTimer = 0.0;
  double snareMultiplier = 1.0; // 1.0 = not snared; <1.0 reduces speed

  // Mark debuff (victim takes +25% damage)
  double markedTimer = 0.0;

  // Dodge frames (brief invulnerability — negates damage and CC)
  double dodgeTimer = 0.0;

  // Heal over time
  double hotTimer = 0.0;
  double hotRate = 0.0; // HP healed per second

  // Blood Rush: attacks apply snare
  bool attacksApplySnare = false;
  double attacksApplySnareTimer = 0.0;

  // Trickster status effects
  double hexedTimer = 0.0;
  double hexedFactor = 1.0; // <1.0 = reduced damage output when hexed
  double confusedTimer = 0.0;

  // Red mana decay
  static const double redDecayDelay = 3.0;
  static const double redDecayRate = 3.0;

  // Jump physics
  double zHeight = 0.0;
  double zVelocity = 0.0;
  bool hasDoubleJumped = false;

  static const double _jumpVelocity       = 16.0;
  static const double _doubleJumpVelocity = 14.0;
  static const double _gravity            = 35.0;
  static const double doubleJumpManaCost  = 15.0;

  bool get isAirborne => zHeight > 0 || zVelocity > 0;

  bool isPlayerControlled = false;

  // Throw charging
  bool isChargingThrow = false;
  double throwChargeTime = 0.0;
  static const double maxThrowChargeTime = 2.0;

  double get throwChargePercent =>
      (throwChargeTime / maxThrowChargeTime).clamp(0.0, 1.0);

  double get throwDistance => 5.0 + 35.0 * throwChargePercent;

  UltraballPlayer({
    required this.id,
    required this.name,
    required this.team,
    required this.rosterIndex,
    required this.x,
    required this.y,
  });

  double get speed {
    if (!isAlive) return 0;
    double s = baseSpeed;
    if (speedMultiplierTimer > 0) {
      s *= speedMultiplierOverride;
    } else if (speedBoostTimer > 0) {
      s *= 1.5;
    }
    if (snareTimer > 0) { s *= snareMultiplier; }
    return s;
  }

  bool get isStunned => state == PlayerState.stunned;

  void update(double dt) {
    if (!isAlive) return;

    // Stun timer
    if (stunTimer > 0) {
      stunTimer -= dt;
      if (stunTimer <= 0) {
        stunTimer = 0;
        state = PlayerState.idle;
      }
    }

    // Slot cooldowns
    if (speedBoostTimer > 0) speedBoostTimer -= dt;
    if (tackleCooldown > 0) tackleCooldown -= dt;
    if (slamCooldown > 0) slamCooldown -= dt;
    if (sprintCooldown > 0) sprintCooldown -= dt;
    if (passCooldown > 0) passCooldown -= dt;
    if (ability4Cooldown > 0) ability4Cooldown -= dt;
    if (ability5Cooldown > 0) ability5Cooldown -= dt;
    if (ability6Cooldown > 0) ability6Cooldown -= dt;
    if (ability7Cooldown > 0) ability7Cooldown -= dt;
    if (ability8Cooldown > 0) ability8Cooldown -= dt;
    if (ability9Cooldown > 0) ability9Cooldown -= dt;

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

    // Buff timers
    if (damageBoostTimer > 0) {
      damageBoostTimer -= dt;
      if (damageBoostTimer <= 0) {
        damageBoostTimer = 0;
        damageBoostFactor = 1.0;
      }
    }
    if (damageReductionTimer > 0) {
      damageReductionTimer -= dt;
      if (damageReductionTimer <= 0) {
        damageReductionTimer = 0;
        damageReductionFactor = 1.0;
      }
    }
    if (stunImmuneTimer > 0) {
      stunImmuneTimer -= dt;
      stunImmune = stunImmuneTimer > 0;
    }
    if (speedMultiplierTimer > 0) {
      speedMultiplierTimer -= dt;
      if (speedMultiplierTimer <= 0) {
        speedMultiplierTimer = 0;
        speedMultiplierOverride = 1.5;
      }
    }

    // Snare timer
    if (snareTimer > 0) {
      snareTimer -= dt;
      if (snareTimer <= 0) {
        snareTimer = 0;
        snareMultiplier = 1.0;
      }
    }

    // Mark timer
    if (markedTimer > 0) {
      markedTimer -= dt;
      if (markedTimer <= 0) { markedTimer = 0; }
    }

    // Dodge timer
    if (dodgeTimer > 0) {
      dodgeTimer -= dt;
      if (dodgeTimer <= 0) { dodgeTimer = 0; }
    }

    // Heal over time
    if (hotTimer > 0) {
      hotTimer -= dt;
      health = math.min(maxHealth, health + hotRate * dt);
      if (hotTimer <= 0) {
        hotTimer = 0;
        hotRate = 0;
      }
    }

    // Passive health regen — slow enough not to prevent burst kills but makes sustained fights recoverable
    if (health < maxHealth) {
      health = math.min(maxHealth, health + 2.0 * dt);
    }

    // Blood Rush: attacks apply snare
    if (attacksApplySnareTimer > 0) {
      attacksApplySnareTimer -= dt;
      attacksApplySnare = attacksApplySnareTimer > 0;
    }

    // Trickster debuffs
    if (hexedTimer > 0) {
      hexedTimer -= dt;
      if (hexedTimer <= 0) { hexedTimer = 0; hexedFactor = 1.0; }
    }
    if (confusedTimer > 0) {
      confusedTimer -= dt;
      if (confusedTimer <= 0) confusedTimer = 0;
    }

    // Jump physics
    if (isAirborne) {
      zVelocity -= _gravity * dt;
      zHeight += zVelocity * dt;
      if (zHeight <= 0) {
        zHeight = 0.0;
        zVelocity = 0.0;
        hasDoubleJumped = false;
      }
    }

    // Apply velocity
    if (state != PlayerState.stunned) {
      x += velX * dt;
      y += velY * dt;
    }

    x = x.clamp(0.0, 140.0);
    y = y.clamp(0.0, 40.0);

    if (!isPlayerControlled && (velX != 0 || velY != 0)) {
      facing = math.atan2(velY, velX);
    }
  }

  void stun(double duration) {
    if (!isAlive) return;
    if (stunImmune) return;
    if (dodgeTimer > 0) return; // dodge frames block CC
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

  bool tryJump() {
    if (!isAlive || isStunned) return false;

    if (!isAirborne) {
      zVelocity = _jumpVelocity;
      zHeight = 0.001;
      return true;
    }

    if (!hasDoubleJumped && blueMana >= doubleJumpManaCost) {
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

  void gainUltraMana(double amount) {
    ultraMana = math.min(maxUltraMana, ultraMana + amount);
  }

  // Snare: apply only if it worsens the current snare
  void applySnare(double duration, double multiplier) {
    if (dodgeTimer > 0) return;
    if (duration > snareTimer) { snareTimer = duration; }
    if (multiplier < snareMultiplier) { snareMultiplier = multiplier; }
  }

  void applyMark(double duration) {
    if (markedTimer < duration) { markedTimer = duration; }
  }

  void applyDodge(double duration) {
    if (dodgeTimer < duration) { dodgeTimer = duration; }
  }

  void applyHoT(double duration, double rate) {
    if (hotTimer < duration) { hotTimer = duration; }
    if (hotRate < rate) { hotRate = rate; }
  }

  void applyHex(double duration, double factor) {
    if (dodgeTimer > 0) return;
    if (duration > hexedTimer) hexedTimer = duration;
    if (factor < hexedFactor) hexedFactor = factor;
  }

  void applyConfusion(double duration) {
    if (dodgeTimer > 0) return;
    if (stunImmune) return;
    if (duration > confusedTimer) confusedTimer = duration;
  }

  // Remove all crowd-control debuffs
  void cleanse() {
    snareTimer = 0.0;
    snareMultiplier = 1.0;
    markedTimer = 0.0;
    hexedTimer = 0.0; hexedFactor = 1.0; confusedTimer = 0.0;
    if (!stunImmune && state == PlayerState.stunned) {
      stunTimer = 0.0;
      state = PlayerState.idle;
    }
  }

  void resetBuffs() {
    damageBoostFactor = 1.0;
    damageBoostTimer = 0;
    damageReductionFactor = 1.0;
    damageReductionTimer = 0;
    stunImmune = false;
    stunImmuneTimer = 0;
    speedMultiplierTimer = 0;
    speedMultiplierOverride = 1.5;
    snareTimer = 0;
    snareMultiplier = 1.0;
    markedTimer = 0;
    dodgeTimer = 0;
    hotTimer = 0;
    hotRate = 0;
    attacksApplySnare = false;
    attacksApplySnareTimer = 0;
    hexedTimer = 0.0; hexedFactor = 1.0; confusedTimer = 0.0;
  }
}
