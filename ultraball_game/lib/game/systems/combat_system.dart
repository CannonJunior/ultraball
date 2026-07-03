import 'dart:math' as math;
import '../../models/player.dart';
import '../../models/damage_indicator.dart';
import '../game_state.dart';
import 'act_system.dart';

class CombatSystem {
  // Legacy entry-point used by AI; delegates to the class ability system.
  static void tryAttack(GameState gs, UltraballPlayer attacker, String attackType) {
    if (attackType == 'tackle') {
      useClassAbility(gs, attacker, 1);
    } else if (attackType == 'slam') {
      useClassAbility(gs, attacker, 2);
    }
  }

  // ─── Public ability dispatcher ────────────────────────────────────────────

  static void useClassAbility(GameState gs, UltraballPlayer player, int slot) {
    if (!player.isAlive || player.isStunned) return;
    switch (player.playerClass) {
      case PlayerClass.runner:
        _runnerAbility(gs, player, slot);
      case PlayerClass.enforcer:
        _enforcerAbility(gs, player, slot);
      case PlayerClass.warden:
        _wardenAbility(gs, player, slot);
      case PlayerClass.handler:
        _handlerAbility(gs, player, slot);
      case PlayerClass.blitzer:
        _blitzerAbility(gs, player, slot);
    }
  }

  // ─── RUNNER abilities ─────────────────────────────────────────────────────
  // Speed-focused ball carrier. Fragile (75 HP) but fastest (10 m/s).

  static void _runnerAbility(GameState gs, UltraballPlayer p, int slot) {
    if (slot == 1) {
      // Quick Strike — 12 dmg, 0.5s CD
      if (p.tackleCooldown > 0) return;
      final t = _resolveTarget(gs, p, 2.5);
      if (t == null) return;
      p.tackleCooldown = 0.5;
      gs.dataCollector?.onTackle(p.team == Team.opponent ? 'opponent' : 'player');
      applyDamage(gs, t, 12.0, p);
      checkCombo(gs, p);

    } else if (slot == 2) {
      // Slide Tackle — 18 dmg + 1.5s snare (50% slow), 3s CD, 20 red
      if (p.slamCooldown > 0) return;
      if (p.redMana < 20) return;
      final t = _resolveTarget(gs, p, 3.0);
      if (t == null) return;
      p.redMana -= 20;
      p.slamCooldown = 3.0;
      gs.dataCollector?.onSlam(p.team == Team.opponent ? 'opponent' : 'player');
      applyDamage(gs, t, 18.0, p);
      t.applySnare(1.5, 0.5);
      if (t.isAlive) { addIndicator(gs, t.x, t.y - 1, 'SNARE!', IndicatorType.event); }

    } else if (slot == 3) {
      // Sprint — 1.5× speed for 3s, 5s CD, 15 blue
      if (p.sprintCooldown > 0) return;
      if (p.blueMana < 15) return;
      p.blueMana -= 15;
      p.speedBoostTimer = 3.0;
      p.sprintCooldown = 5.0;

    } else if (slot == 4) {
      // Dash — 6m teleport forward, 7s CD, 20 blue
      if (p.ability4Cooldown > 0) return;
      if (p.blueMana < 20) return;
      p.blueMana -= 20;
      p.ability4Cooldown = 7.0;
      p.x = (p.x + math.cos(p.facing) * 6.0).clamp(0.0, 140.0);
      p.y = (p.y + math.sin(p.facing) * 6.0).clamp(0.0, 40.0);
      addIndicator(gs, p.x, p.y - 1, 'PHASE!', IndicatorType.event);

    } else if (slot == 5) {
      // Spin Move — 1.5s dodge (invulnerability frames), 8s CD, 25 blue
      if (p.ability5Cooldown > 0) return;
      if (p.blueMana < 25) return;
      p.blueMana -= 25;
      p.ability5Cooldown = 8.0;
      p.applyDodge(1.5);
      addIndicator(gs, p.x, p.y - 1, 'GHOST!', IndicatorType.event);

    } else if (slot == 6) {
      // Eye Gouge — 15 dmg + 2s stun, 10s CD, 30 red
      if (p.ability6Cooldown > 0) return;
      if (p.redMana < 30) return;
      final t = _resolveTarget(gs, p, 2.5);
      if (t == null) return;
      p.redMana -= 30;
      p.ability6Cooldown = 10.0;
      applyDamage(gs, t, 15.0, p);
      t.stun(2.0);

    } else if (slot == 7) {
      // Clear Out — self-cleanse + heal 25 HP, 15s CD, 40 blue
      if (p.ability7Cooldown > 0) return;
      if (p.blueMana < 40) return;
      p.ability7Cooldown = 15.0;
      p.blueMana -= 40;
      p.cleanse();
      p.health = math.min(p.maxHealth, p.health + 25.0);
      addIndicator(gs, p.x, p.y - 2, '+25 HP', IndicatorType.heal);
      addIndicator(gs, p.x, p.y - 3, 'CLEANSED!', IndicatorType.event);

    } else if (slot == 8) {
      // Cut Back — 4m backward dash + AoE 3m snare (2s, 40% slow), 12s CD, 25 red
      if (p.ability8Cooldown > 0) return;
      if (p.redMana < 25) return;
      p.redMana -= 25;
      p.ability8Cooldown = 12.0;
      // Move backward
      p.x = (p.x - math.cos(p.facing) * 4.0).clamp(0.0, 140.0);
      p.y = (p.y - math.sin(p.facing) * 4.0).clamp(0.0, 40.0);
      int hit = 0;
      for (final enemy in gs.fieldPlayers) {
        if (enemy.team == p.team || !enemy.isAlive) continue;
        final dx = enemy.x - p.x, dy = enemy.y - p.y;
        if (math.sqrt(dx * dx + dy * dy) <= 3.0) {
          enemy.applySnare(2.0, 0.4);
          addIndicator(gs, enemy.x, enemy.y - 1, 'SNARE!', IndicatorType.event);
          hit++;
        }
      }
      addIndicator(gs, p.x, p.y - 1, hit > 0 ? 'CUTBACK! ×$hit' : 'CUTBACK!', IndicatorType.event);

    } else if (slot == 9) {
      // Feint — 3s stun immunity + 20% speed boost, 12s CD, 20 blue
      if (p.ability9Cooldown > 0) return;
      if (p.blueMana < 20) return;
      p.blueMana -= 20;
      p.ability9Cooldown = 12.0;
      p.stunImmune = true;
      p.stunImmuneTimer = 3.0;
      p.speedBoostTimer = 3.0;
      addIndicator(gs, p.x, p.y - 1, 'SLIPSTREAM!', IndicatorType.event);

    } else if (slot == 10) {
      // FULL SPRINT — 7s: 2.5× speed + stun immune, costs 5 ultra mana
      if (p.ultraMana < 5) return;
      p.ultraMana -= 5;
      p.speedMultiplierOverride = 2.5;
      p.speedMultiplierTimer = 7.0;
      p.stunImmune = true;
      p.stunImmuneTimer = 7.0;
      addIndicator(gs, p.x, p.y - 2, 'ULTRAVIOLET!', IndicatorType.kill);
      gs.showEvent('ULTRAVIOLET! ${p.name} is beyond reach for 7 seconds!');
    }
  }

  // ─── ENFORCER abilities ───────────────────────────────────────────────────
  // Physical dominator. Tanky (145 HP) but slowest (6.5 m/s). Red-mana focused.

  static void _enforcerAbility(GameState gs, UltraballPlayer p, int slot) {
    if (slot == 1) {
      // Haymaker — 22 dmg, 1s CD
      if (p.tackleCooldown > 0) return;
      final t = _resolveTarget(gs, p, 2.5);
      if (t == null) return;
      p.tackleCooldown = 1.0;
      gs.dataCollector?.onTackle(p.team == Team.opponent ? 'opponent' : 'player');
      applyDamage(gs, t, 22.0, p);
      checkCombo(gs, p);

    } else if (slot == 2) {
      // Thunder Slam — 40 dmg + 6m knockback, 3s CD, 25 red
      if (p.slamCooldown > 0) return;
      if (p.redMana < 25) return;
      final t = _resolveTarget(gs, p, 3.5);
      if (t == null) return;
      p.redMana -= 25;
      p.slamCooldown = 3.0;
      gs.dataCollector?.onSlam(p.team == Team.opponent ? 'opponent' : 'player');
      applyDamage(gs, t, 40.0, p);
      if (t.isAlive) {
        final dx = t.x - p.x, dy = t.y - p.y;
        final dist = math.sqrt(dx * dx + dy * dy);
        if (dist > 0) {
          t.x = (t.x + (dx / dist) * 6.0).clamp(0.0, 140.0);
          t.y = (t.y + (dy / dist) * 6.0).clamp(0.0, 40.0);
        }
      }

    } else if (slot == 3) {
      // Sprint — 1.5× speed for 3s, 6s CD, 20 blue
      if (p.sprintCooldown > 0) return;
      if (p.blueMana < 20) return;
      p.blueMana -= 20;
      p.speedBoostTimer = 3.0;
      p.sprintCooldown = 6.0;

    } else if (slot == 4) {
      // Headbutt — 20 dmg + 2s stun, 8s CD, 25 red
      if (p.ability4Cooldown > 0) return;
      if (p.redMana < 25) return;
      final t = _resolveTarget(gs, p, 2.5);
      if (t == null) return;
      p.redMana -= 25;
      p.ability4Cooldown = 8.0;
      applyDamage(gs, t, 20.0, p);
      t.stun(2.0);

    } else if (slot == 5) {
      // Ground Stomp — AoE 4m: 20 dmg + 1.5s snare (40% slow), 8s CD, 35 red
      if (p.ability5Cooldown > 0) return;
      if (p.redMana < 35) return;
      p.redMana -= 35;
      p.ability5Cooldown = 8.0;
      int hit = 0;
      for (final enemy in gs.fieldPlayers) {
        if (enemy.team == p.team || !enemy.isAlive) continue;
        final dx = enemy.x - p.x, dy = enemy.y - p.y;
        if (math.sqrt(dx * dx + dy * dy) <= 4.0) {
          applyDamage(gs, enemy, 20.0, p);
          enemy.applySnare(1.5, 0.4);
          hit++;
        }
      }
      addIndicator(gs, p.x, p.y - 1, hit > 0 ? 'QUAKE! ×$hit' : 'QUAKE!', IndicatorType.kill);

    } else if (slot == 6) {
      // Bull Rush — dash 7m; stun + 10 dmg any enemy at landing, 10s CD, 20 red
      if (p.ability6Cooldown > 0) return;
      if (p.redMana < 20) return;
      p.redMana -= 20;
      p.ability6Cooldown = 10.0;
      p.x = (p.x + math.cos(p.facing) * 7.0).clamp(0.0, 140.0);
      p.y = (p.y + math.sin(p.facing) * 7.0).clamp(0.0, 40.0);
      for (final enemy in gs.fieldPlayers) {
        if (enemy.team == p.team || !enemy.isAlive) continue;
        final dx = enemy.x - p.x, dy = enemy.y - p.y;
        if (math.sqrt(dx * dx + dy * dy) <= 2.5) {
          applyDamage(gs, enemy, 10.0, p);
          enemy.stun(1.0);
          addIndicator(gs, enemy.x, enemy.y - 1, 'DEAD AHEAD!', IndicatorType.event);
          break;
        }
      }

    } else if (slot == 7) {
      // Bloodlust — self-heal 40 HP, 15s CD, 40 blue
      if (p.ability7Cooldown > 0) return;
      if (p.blueMana < 40) return;
      p.ability7Cooldown = 15.0;
      p.blueMana -= 40;
      p.health = math.min(p.maxHealth, p.health + 40.0);
      addIndicator(gs, p.x, p.y - 2, '+40 HP', IndicatorType.heal);

    } else if (slot == 8) {
      // Battle Cry — self +30% dmg for 5s + 25 red mana, 12s CD, 20 blue
      if (p.ability8Cooldown > 0) return;
      if (p.blueMana < 20) return;
      p.blueMana -= 20;
      p.ability8Cooldown = 12.0;
      p.damageBoostFactor = 1.30;
      p.damageBoostTimer = 5.0;
      p.gainRedMana(25.0);
      addIndicator(gs, p.x, p.y - 2, 'BERSERK!', IndicatorType.kill);

    } else if (slot == 9) {
      // Shoulder Charge — dash 5m, knock back all enemies hit 3m, 12s CD, 30 red
      if (p.ability9Cooldown > 0) return;
      if (p.redMana < 30) return;
      p.redMana -= 30;
      p.ability9Cooldown = 12.0;
      final destX = (p.x + math.cos(p.facing) * 5.0).clamp(0.0, 140.0);
      final destY = (p.y + math.sin(p.facing) * 5.0).clamp(0.0, 40.0);
      // Check for enemies along the path
      for (final enemy in gs.fieldPlayers) {
        if (enemy.team == p.team || !enemy.isAlive) continue;
        final dx = enemy.x - p.x, dy = enemy.y - p.y;
        if (math.sqrt(dx * dx + dy * dy) <= 6.0) {
          final eDx = enemy.x - destX, eDy = enemy.y - destY;
          final dist = math.sqrt(eDx * eDx + eDy * eDy);
          if (dist > 0) {
            enemy.x = (enemy.x + (eDx / dist) * 3.0).clamp(0.0, 140.0);
            enemy.y = (enemy.y + (eDy / dist) * 3.0).clamp(0.0, 40.0);
          }
          applyDamage(gs, enemy, 15.0, p);
          addIndicator(gs, enemy.x, enemy.y - 1, 'TORPEDO!', IndicatorType.event);
        }
      }
      p.x = destX;
      p.y = destY;

    } else if (slot == 10) {
      // RAMPAGE — 8s: 50% dmg boost + 30% dmg reduction + stun immune, costs 5 ultra
      if (p.ultraMana < 5) return;
      p.ultraMana -= 5;
      p.damageBoostFactor = 1.50;
      p.damageBoostTimer = 8.0;
      p.damageReductionFactor = 0.70;
      p.damageReductionTimer = 8.0;
      p.stunImmune = true;
      p.stunImmuneTimer = 8.0;
      addIndicator(gs, p.x, p.y - 2, 'RAMPAGE!', IndicatorType.kill);
      gs.showEvent('RAMPAGE! ${p.name} is an unstoppable force for 8 seconds!');
    }
  }

  // ─── WARDEN abilities ─────────────────────────────────────────────────────
  // Defensive anchor and team healer. High HP (120), medium speed (7.5 m/s).

  static void _wardenAbility(GameState gs, UltraballPlayer p, int slot) {
    if (slot == 1) {
      // Shield Bash — 15 dmg + 2m push, 0.8s CD
      if (p.tackleCooldown > 0) return;
      final t = _resolveTarget(gs, p, 2.5);
      if (t == null) return;
      p.tackleCooldown = 0.8;
      gs.dataCollector?.onTackle(p.team == Team.opponent ? 'opponent' : 'player');
      applyDamage(gs, t, 15.0, p);
      if (t.isAlive) {
        final dx = t.x - p.x, dy = t.y - p.y;
        final dist = math.sqrt(dx * dx + dy * dy);
        if (dist > 0) {
          t.x = (t.x + (dx / dist) * 2.0).clamp(0.0, 140.0);
          t.y = (t.y + (dy / dist) * 2.0).clamp(0.0, 40.0);
        }
      }
      checkCombo(gs, p);

    } else if (slot == 2) {
      // Shockwave — 30 dmg + 1s stun, 3s CD, 25 red
      if (p.slamCooldown > 0) return;
      if (p.redMana < 25) return;
      final t = _resolveTarget(gs, p, 3.0);
      if (t == null) return;
      p.redMana -= 25;
      p.slamCooldown = 3.0;
      gs.dataCollector?.onSlam(p.team == Team.opponent ? 'opponent' : 'player');
      applyDamage(gs, t, 30.0, p);
      t.stun(1.0);

    } else if (slot == 3) {
      // Sprint — 1.5× speed for 3s, 6s CD, 20 blue
      if (p.sprintCooldown > 0) return;
      if (p.blueMana < 20) return;
      p.blueMana -= 20;
      p.speedBoostTimer = 3.0;
      p.sprintCooldown = 6.0;

    } else if (slot == 4) {
      // Bulwark — self 50% dmg reduction for 3s, 10s CD, 25 blue
      if (p.ability4Cooldown > 0) return;
      if (p.blueMana < 25) return;
      p.blueMana -= 25;
      p.ability4Cooldown = 10.0;
      p.damageReductionFactor = 0.50;
      p.damageReductionTimer = 3.0;
      addIndicator(gs, p.x, p.y - 2, 'FORTRESS!', IndicatorType.event);

    } else if (slot == 5) {
      // Mend — heal nearest ally 35 HP (5m range), 10s CD, 30 blue
      if (p.ability5Cooldown > 0) return;
      if (p.blueMana < 30) return;
      final t = _findNearestAlly(gs, p, 5.0);
      if (t == null) return;
      p.blueMana -= 30;
      p.ability5Cooldown = 10.0;
      t.health = math.min(t.maxHealth, t.health + 35.0);
      addIndicator(gs, t.x, t.y - 2, '+35 HP', IndicatorType.heal);

    } else if (slot == 6) {
      // Cleanse — remove CC from nearest ally (5m), 12s CD, 20 blue
      if (p.ability6Cooldown > 0) return;
      if (p.blueMana < 20) return;
      final t = _findNearestAlly(gs, p, 5.0);
      if (t == null) return;
      p.blueMana -= 20;
      p.ability6Cooldown = 12.0;
      t.cleanse();
      addIndicator(gs, t.x, t.y - 2, 'ABSOLVED!', IndicatorType.event);

    } else if (slot == 7) {
      // Second Wind — self +35 HP + 20 blue, 18s CD, 35 blue
      if (p.ability7Cooldown > 0) return;
      if (p.blueMana < 35) return;
      p.ability7Cooldown = 18.0;
      p.blueMana -= 35;
      p.health = math.min(p.maxHealth, p.health + 35.0);
      p.blueMana = math.min(100, p.blueMana + 20.0);
      addIndicator(gs, p.x, p.y - 2, '+35 HP', IndicatorType.heal);

    } else if (slot == 8) {
      // Fortify — 30% dmg reduction to nearest ally (5m) for 4s, 14s CD, 30 blue
      if (p.ability8Cooldown > 0) return;
      if (p.blueMana < 30) return;
      final t = _findNearestAlly(gs, p, 5.0);
      if (t == null) return;
      p.blueMana -= 30;
      p.ability8Cooldown = 14.0;
      t.damageReductionFactor = 0.70;
      t.damageReductionTimer = 4.0;
      addIndicator(gs, t.x, t.y - 2, 'AEGIS!', IndicatorType.event);

    } else if (slot == 9) {
      // Rally — AoE 7m: heal allies 25 HP + cleanse snares, 20s CD, 50 blue
      if (p.ability9Cooldown > 0) return;
      if (p.blueMana < 50) return;
      p.blueMana -= 50;
      p.ability9Cooldown = 20.0;
      int healed = 0;
      for (final mate in gs.fieldPlayers) {
        if (mate.team != p.team || !mate.isAlive) continue;
        final dx = mate.x - p.x, dy = mate.y - p.y;
        if (math.sqrt(dx * dx + dy * dy) <= 7.0) {
          mate.health = math.min(mate.maxHealth, mate.health + 25.0);
          mate.snareTimer = 0;
          mate.snareMultiplier = 1.0;
          addIndicator(gs, mate.x, mate.y - 2, '+25 HP', IndicatorType.heal);
          healed++;
        }
      }
      if (healed > 0) { gs.showEvent('SALVATION! $healed teammates healed and freed!'); }

    } else if (slot == 10) {
      // SANCTUARY — 6s: 10m range, 50% dmg reduction + stun immune + HoT 8/s, costs 5 ultra
      if (p.ultraMana < 5) return;
      p.ultraMana -= 5;
      final targets = <UltraballPlayer>[];
      for (final mate in gs.fieldPlayers) {
        if (mate.team != p.team || !mate.isAlive) continue;
        final dx = mate.x - p.x, dy = mate.y - p.y;
        if (math.sqrt(dx * dx + dy * dy) <= 10.0) { targets.add(mate); }
      }
      targets.add(p);
      for (final target in targets) {
        target.damageReductionFactor = 0.50;
        target.damageReductionTimer = 6.0;
        target.stunImmune = true;
        target.stunImmuneTimer = 6.0;
        target.applyHoT(6.0, 8.0);
        addIndicator(gs, target.x, target.y - 2, 'CITADEL!', IndicatorType.event);
      }
      gs.showEvent('CITADEL! ${targets.length} players shielded for 6s!');
    }
  }

  // ─── HANDLER abilities ────────────────────────────────────────────────────
  // Field captain and support quarterback. Medium stats (95 HP, 8 m/s).

  static void _handlerAbility(GameState gs, UltraballPlayer p, int slot) {
    if (slot == 1) {
      // Quick Jab — 10 dmg, 0.6s CD
      if (p.tackleCooldown > 0) return;
      final t = _resolveTarget(gs, p, 2.5);
      if (t == null) return;
      p.tackleCooldown = 0.6;
      gs.dataCollector?.onTackle(p.team == Team.opponent ? 'opponent' : 'player');
      applyDamage(gs, t, 10.0, p);
      checkCombo(gs, p);

    } else if (slot == 2) {
      // Ankle Snap — 15 dmg + 2s snare (60% slow), 3s CD, 20 red
      if (p.slamCooldown > 0) return;
      if (p.redMana < 20) return;
      final t = _resolveTarget(gs, p, 3.0);
      if (t == null) return;
      p.redMana -= 20;
      p.slamCooldown = 3.0;
      gs.dataCollector?.onSlam(p.team == Team.opponent ? 'opponent' : 'player');
      applyDamage(gs, t, 15.0, p);
      t.applySnare(2.0, 0.4);
      if (t.isAlive) { addIndicator(gs, t.x, t.y - 1, 'SNARE!', IndicatorType.event); }

    } else if (slot == 3) {
      // Sprint — 1.5× speed for 3s, 5s CD, 15 blue
      if (p.sprintCooldown > 0) return;
      if (p.blueMana < 15) return;
      p.blueMana -= 15;
      p.speedBoostTimer = 3.0;
      p.sprintCooldown = 5.0;

    } else if (slot == 4) {
      // Field Medic — heal nearest ally 30 HP (5m), 10s CD, 30 blue
      if (p.ability4Cooldown > 0) return;
      if (p.blueMana < 30) return;
      final t = _findNearestAlly(gs, p, 5.0);
      if (t == null) return;
      p.blueMana -= 30;
      p.ability4Cooldown = 10.0;
      t.health = math.min(t.maxHealth, t.health + 30.0);
      addIndicator(gs, t.x, t.y - 2, '+30 HP', IndicatorType.heal);

    } else if (slot == 5) {
      // Energize — restore 35 blue mana to nearest ally (5m), 12s CD, 25 blue
      if (p.ability5Cooldown > 0) return;
      if (p.blueMana < 25) return;
      final t = _findNearestAlly(gs, p, 5.0);
      if (t == null) return;
      p.blueMana -= 25;
      p.ability5Cooldown = 12.0;
      t.blueMana = math.min(100, t.blueMana + 35.0);
      addIndicator(gs, t.x, t.y - 1, '+35 BLU', IndicatorType.combo);

    } else if (slot == 6) {
      // Suppress — 20 dmg + 1s stun + 2s snare, 10s CD, 30 red
      if (p.ability6Cooldown > 0) return;
      if (p.redMana < 30) return;
      final t = _resolveTarget(gs, p, 3.0);
      if (t == null) return;
      p.redMana -= 30;
      p.ability6Cooldown = 10.0;
      applyDamage(gs, t, 20.0, p);
      t.stun(1.0);
      t.applySnare(2.0, 0.5);

    } else if (slot == 7) {
      // Trauma Pack — heal nearest ally 60 HP + cleanse all CC (5m), 18s CD, 45 blue
      if (p.ability7Cooldown > 0) return;
      if (p.blueMana < 45) return;
      final t = _findNearestAlly(gs, p, 5.0);
      if (t == null) return;
      p.blueMana -= 45;
      p.ability7Cooldown = 18.0;
      t.health = math.min(t.maxHealth, t.health + 60.0);
      t.cleanse();
      addIndicator(gs, t.x, t.y - 2, '+60 HP', IndicatorType.heal);
      addIndicator(gs, t.x, t.y - 3, 'CLEANSED!', IndicatorType.event);

    } else if (slot == 8) {
      // Team Rally — AoE 8m: restore 20 blue to all allies, 18s CD, 40 blue
      if (p.ability8Cooldown > 0) return;
      if (p.blueMana < 40) return;
      p.blueMana -= 40;
      p.ability8Cooldown = 18.0;
      int boosted = 0;
      for (final mate in gs.fieldPlayers) {
        if (mate.team != p.team || mate.id == p.id || !mate.isAlive) continue;
        final dx = mate.x - p.x, dy = mate.y - p.y;
        if (math.sqrt(dx * dx + dy * dy) <= 8.0) {
          mate.blueMana = math.min(100, mate.blueMana + 20.0);
          addIndicator(gs, mate.x, mate.y - 1, '+20 BLU', IndicatorType.combo);
          boosted++;
        }
      }
      if (boosted > 0) { gs.showEvent('RESUPPLY! +20 Blue to $boosted teammates!'); }

    } else if (slot == 9) {
      // Intercept — dash 5m + stun enemy at destination 1.5s, 12s CD, 25 red
      if (p.ability9Cooldown > 0) return;
      if (p.redMana < 25) return;
      p.redMana -= 25;
      p.ability9Cooldown = 12.0;
      p.x = (p.x + math.cos(p.facing) * 5.0).clamp(0.0, 140.0);
      p.y = (p.y + math.sin(p.facing) * 5.0).clamp(0.0, 40.0);
      for (final enemy in gs.fieldPlayers) {
        if (enemy.team == p.team || !enemy.isAlive) continue;
        final dx = enemy.x - p.x, dy = enemy.y - p.y;
        if (math.sqrt(dx * dx + dy * dy) <= 2.5) {
          enemy.stun(1.5);
          applyDamage(gs, enemy, 10.0, p);
          addIndicator(gs, enemy.x, enemy.y - 1, 'BLINDSIDE!', IndicatorType.event);
          break;
        }
      }

    } else if (slot == 10) {
      // GAME PLAN — instant: all field teammates +35 HP + 40 blue + cleanse, costs 5 ultra
      if (p.ultraMana < 5) return;
      p.ultraMana -= 5;
      int targets = 0;
      for (final mate in gs.getTeamOnField(p.team)) {
        if (mate.id == p.id || !mate.isAlive) continue;
        mate.health = math.min(mate.maxHealth, mate.health + 35.0);
        mate.blueMana = math.min(100, mate.blueMana + 40.0);
        mate.cleanse();
        addIndicator(gs, mate.x, mate.y - 2, 'SYMPHONY!', IndicatorType.heal);
        targets++;
      }
      // Also apply to self
      p.health = math.min(p.maxHealth, p.health + 35.0);
      p.blueMana = math.min(100, p.blueMana + 40.0);
      p.cleanse();
      addIndicator(gs, p.x, p.y - 2, 'SYMPHONY!', IndicatorType.heal);
      gs.showEvent('SYMPHONY! ${targets + 1} players healed and cleansed!');
    }
  }

  // ─── BLITZER abilities ────────────────────────────────────────────────────
  // Aggressive disruptor. Balanced stats (105 HP, 8.5 m/s). Mixed mana.

  static void _blitzerAbility(GameState gs, UltraballPlayer p, int slot) {
    if (slot == 1) {
      // Blitz Strike — 18 dmg, 0.7s CD
      if (p.tackleCooldown > 0) return;
      final t = _resolveTarget(gs, p, 2.5);
      if (t == null) return;
      p.tackleCooldown = 0.7;
      gs.dataCollector?.onTackle(p.team == Team.opponent ? 'opponent' : 'player');
      applyDamage(gs, t, 18.0, p);
      checkCombo(gs, p);

    } else if (slot == 2) {
      // Strip Tackle — 25 dmg + 1.5s stun; force fumble if target holds ball, 3s CD, 25 red
      if (p.slamCooldown > 0) return;
      if (p.redMana < 25) return;
      final t = _resolveTarget(gs, p, 3.0);
      if (t == null) return;
      p.redMana -= 25;
      p.slamCooldown = 3.0;
      gs.dataCollector?.onSlam(p.team == Team.opponent ? 'opponent' : 'player');
      final hadBall = gs.ball.holderId == t.id;
      applyDamage(gs, t, 25.0, p);
      t.stun(1.5);
      // Force fumble if target survived with ball (applyDamage may have cleared holderId on death)
      if (hadBall && t.isAlive && gs.ball.holderId == t.id) {
        gs.ball.holderId = null;
        gs.ball.isInFlight = false;
        gs.ball.velX = 0;
        gs.ball.velY = 0;
        gs.showEvent('STRIP TACKLE! Ball fumbled by ${t.name}!');
        addIndicator(gs, t.x, t.y - 1, 'STRIPPED!', IndicatorType.kill);
      }

    } else if (slot == 3) {
      // Sprint — 1.5× speed for 3s, 5s CD, 15 blue
      if (p.sprintCooldown > 0) return;
      if (p.blueMana < 15) return;
      p.blueMana -= 15;
      p.speedBoostTimer = 3.0;
      p.sprintCooldown = 5.0;

    } else if (slot == 4) {
      // Aggressive Rush — dash 5m + snare enemy at landing (2s, 50% slow), 8s CD, 20 red
      if (p.ability4Cooldown > 0) return;
      if (p.redMana < 20) return;
      p.redMana -= 20;
      p.ability4Cooldown = 8.0;
      p.x = (p.x + math.cos(p.facing) * 5.0).clamp(0.0, 140.0);
      p.y = (p.y + math.sin(p.facing) * 5.0).clamp(0.0, 40.0);
      for (final enemy in gs.fieldPlayers) {
        if (enemy.team == p.team || !enemy.isAlive) continue;
        final dx = enemy.x - p.x, dy = enemy.y - p.y;
        if (math.sqrt(dx * dx + dy * dy) <= 2.5) {
          enemy.applySnare(2.0, 0.5);
          addIndicator(gs, enemy.x, enemy.y - 1, 'SNARE!', IndicatorType.event);
          break;
        }
      }

    } else if (slot == 5) {
      // Pack Hunter — self +20% dmg boost for 4s, 8s CD, 20 blue
      if (p.ability5Cooldown > 0) return;
      if (p.blueMana < 20) return;
      p.blueMana -= 20;
      p.ability5Cooldown = 8.0;
      p.damageBoostFactor = math.max(p.damageBoostFactor, 1.20);
      p.damageBoostTimer = 4.0;
      addIndicator(gs, p.x, p.y - 2, '+DMG!', IndicatorType.kill);

    } else if (slot == 6) {
      // Clothesline — 20 dmg + 4m knockback + 1.5s snare, 10s CD, 30 red
      if (p.ability6Cooldown > 0) return;
      if (p.redMana < 30) return;
      final t = _resolveTarget(gs, p, 3.0);
      if (t == null) return;
      p.redMana -= 30;
      p.ability6Cooldown = 10.0;
      applyDamage(gs, t, 20.0, p);
      if (t.isAlive) {
        final dx = t.x - p.x, dy = t.y - p.y;
        final dist = math.sqrt(dx * dx + dy * dy);
        if (dist > 0) {
          t.x = (t.x + (dx / dist) * 4.0).clamp(0.0, 140.0);
          t.y = (t.y + (dy / dist) * 4.0).clamp(0.0, 40.0);
        }
        t.applySnare(1.5, 0.5);
        addIndicator(gs, t.x, t.y - 1, 'SNARE!', IndicatorType.event);
      }

    } else if (slot == 7) {
      // Mark — mark enemy for 5s: target takes +25% damage, 12s CD, 20 blue
      if (p.ability7Cooldown > 0) return;
      if (p.blueMana < 20) return;
      final t = _resolveTarget(gs, p, 20.0); // long range, targeting only
      if (t == null) return;
      p.blueMana -= 20;
      p.ability7Cooldown = 12.0;
      t.applyMark(5.0);
      addIndicator(gs, t.x, t.y - 2, 'CONDEMNED!', IndicatorType.kill);

    } else if (slot == 8) {
      // Intimidate — AoE push 3m all enemies in 4m range, 10s CD, 25 blue
      if (p.ability8Cooldown > 0) return;
      if (p.blueMana < 25) return;
      p.blueMana -= 25;
      p.ability8Cooldown = 10.0;
      int hit = 0;
      for (final enemy in gs.fieldPlayers) {
        if (enemy.team == p.team || !enemy.isAlive) continue;
        final dx = enemy.x - p.x, dy = enemy.y - p.y;
        final dist = math.sqrt(dx * dx + dy * dy);
        if (dist <= 4.0 && dist > 0) {
          enemy.x = (enemy.x + (dx / dist) * 3.0).clamp(0.0, 140.0);
          enemy.y = (enemy.y + (dy / dist) * 3.0).clamp(0.0, 40.0);
          hit++;
        }
      }
      addIndicator(gs, p.x, p.y - 1, hit > 0 ? 'ROUT! ×$hit' : 'ROUT!', IndicatorType.event);

    } else if (slot == 9) {
      // Creature Bait — push enemy 4m toward creature + mark 5s, 14s CD, 25 red
      if (p.ability9Cooldown > 0) return;
      if (p.redMana < 25) return;
      final t = _resolveTarget(gs, p, 3.5);
      if (t == null) return;
      p.redMana -= 25;
      p.ability9Cooldown = 14.0;
      final creature = gs.creature;
      final dx = creature.x - t.x;
      final dy = creature.y - t.y;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist > 0) {
        t.x = (t.x + (dx / dist) * 4.0).clamp(0.0, 140.0);
        t.y = (t.y + (dy / dist) * 4.0).clamp(0.0, 40.0);
      }
      t.applyMark(5.0);
      addIndicator(gs, t.x, t.y - 1, 'BAIT!', IndicatorType.kill);

    } else if (slot == 10) {
      // BLOOD RUSH — 7s: 2× speed + 35% dmg boost + stun immune + attacks apply snare, costs 5 ultra
      if (p.ultraMana < 5) return;
      p.ultraMana -= 5;
      p.speedMultiplierOverride = 2.0;
      p.speedMultiplierTimer = 7.0;
      p.damageBoostFactor = 1.35;
      p.damageBoostTimer = 7.0;
      p.stunImmune = true;
      p.stunImmuneTimer = 7.0;
      p.attacksApplySnare = true;
      p.attacksApplySnareTimer = 7.0;
      addIndicator(gs, p.x, p.y - 2, 'APEX!', IndicatorType.kill);
      gs.showEvent('APEX! ${p.name} is a wrecking machine for 7 seconds!');
    }
  }

  // ─── Shared helpers ───────────────────────────────────────────────────────

  /// Resolve attack target: prefer tab target if in range, fall back to nearest.
  static UltraballPlayer? _resolveTarget(
    GameState gs,
    UltraballPlayer attacker,
    double range,
  ) {
    final tabTarget = attacker.isPlayerControlled ? gs.currentTarget : null;
    if (tabTarget != null && tabTarget.isAlive && tabTarget.isOnField) {
      if (tabTarget.isAirborne) return null;
      final dx = tabTarget.x - attacker.x;
      final dy = tabTarget.y - attacker.y;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist <= range + 4.0) return tabTarget;
    }
    return _findNearestEnemy(gs, attacker, range);
  }

  static UltraballPlayer? _findNearestEnemy(
    GameState gs,
    UltraballPlayer attacker,
    double range,
  ) {
    UltraballPlayer? nearest;
    double nearestDist = range;

    for (final enemy in gs.fieldPlayers) {
      if (enemy.team == attacker.team || !enemy.isAlive || enemy.isAirborne) continue;
      final dx = enemy.x - attacker.x;
      final dy = enemy.y - attacker.y;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist < nearestDist) {
        nearestDist = dist;
        nearest = enemy;
      }
    }
    return nearest;
  }

  static UltraballPlayer? _findNearestAlly(
    GameState gs,
    UltraballPlayer user,
    double range,
  ) {
    UltraballPlayer? nearest;
    double nearestDist = range;

    for (final ally in gs.getTeamOnField(user.team)) {
      if (ally.id == user.id || !ally.isAlive) continue;
      final dx = ally.x - user.x;
      final dy = ally.y - user.y;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist < nearestDist) {
        nearestDist = dist;
        nearest = ally;
      }
    }
    return nearest;
  }

  static void applyDamage(
    GameState gs,
    UltraballPlayer victim,
    double damage,
    UltraballPlayer? attacker,
  ) {
    if (!victim.isAlive) return;

    // Dodge frames: absorb all damage and CC
    if (victim.dodgeTimer > 0) {
      addIndicator(gs, victim.x, victim.y - 1.5, 'DODGE!', IndicatorType.event);
      return;
    }

    // Mark bonus: +25% damage to marked targets
    final markMult = victim.markedTimer > 0 ? 1.25 : 1.0;

    final finalDmg = (damage
            * (attacker?.damageBoostFactor ?? 1.0)
            * victim.damageReductionFactor
            * markMult)
        .clamp(0.0, 9999.0);

    victim.health -= finalDmg;
    attacker?.gainRedMana(5.0);

    // Blood Rush: attacks apply snare
    if (attacker != null && attacker.attacksApplySnare && victim.isAlive) {
      victim.applySnare(2.0, 0.5);
    }

    addIndicator(gs, victim.x, victim.y - 1.5, '-${finalDmg.toInt()}', IndicatorType.damage);

    if (victim.health <= 0) {
      final hadBall = gs.ball.holderId == victim.id;
      victim.die();
      gs.markRosterDirty();

      addIndicator(gs, victim.x, victim.y, 'DEAD', IndicatorType.kill);

      if (attacker != null) {
        final killaTeam = attacker.team;
        ActSystem.scoreKilla(gs, killaTeam == Team.player ? 'player' : 'opponent', attacker);
        gs.showEvent('KILLA! +1pt');
      }

      if (hadBall) {
        gs.ball.holderId = null;
        gs.ball.isInFlight = false;
        gs.ball.velX = 0;
        gs.ball.velY = 0;
      }

      if (gs.selectedPlayer?.id == victim.id) {
        gs.selectNextPlayer();
      }

      handlePlayerDeath(gs, victim);
    }
  }

  static void handlePlayerDeath(GameState gs, UltraballPlayer victim) {
    final roster = gs.getTeamRoster(victim.team);
    final onField = roster.where((p) => p.isOnField && p.isAlive).length;
    final teamId = victim.team == Team.player ? 'player' : 'opponent';

    final allDead = roster.every((p) => !p.isAlive);
    if (allDead) {
      if (victim.team == Team.player) {
        gs.actState.playerForfeit = true;
        gs.showEvent('PLAYER TEAM FORFEIT!');
      } else {
        gs.actState.opponentForfeit = true;
        gs.showEvent('OPPONENT TEAM FORFEIT!');
      }
      return;
    }

    final subUsed = teamId == 'player'
        ? gs.actState.playerSubUsed
        : gs.actState.opponentSubUsed;
    if (!subUsed && onField < 7) {
      final sub = roster.firstWhere(
        (p) => !p.isOnField && p.isAlive,
        orElse: () => roster[0],
      );
      if (!sub.isOnField && sub.isAlive) {
        sub.isOnField = true;
        sub.x = victim.team == Team.player ? 90.0 : 50.0;
        sub.y = 20.0;
        sub.health = sub.maxHealth;
        sub.blueMana = 100;
        sub.redMana = 0;
        if (teamId == 'player') {
          gs.actState.playerSubUsed = true;
        } else {
          gs.actState.opponentSubUsed = true;
        }
        gs.showEvent('SUB IN: ${sub.name}!');
      }
    }
  }

  static void checkCombo(GameState gs, UltraballPlayer attacker) {
    attacker.comboCount++;
    attacker.comboTimer = 0;

    if (attacker.comboCount >= 3) {
      attacker.gainRedMana(30.0);
      addIndicator(gs, attacker.x, attacker.y - 3.0, 'COMBO!', IndicatorType.combo);
      gs.showCombo('${attacker.comboCount}x COMBO!');
      attacker.comboCount = 0;
      attacker.comboTimer = 0;
    }
  }

  static void addIndicator(
    GameState gs,
    double x,
    double y,
    String text,
    IndicatorType type,
  ) {
    gs.indicators.add(
      DamageIndicator(worldX: x, worldY: y, text: text, type: type),
    );
  }
}
