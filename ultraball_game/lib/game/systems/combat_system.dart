import 'dart:math' as math;
import '../../models/player.dart';
import '../../models/damage_indicator.dart';
import '../../models/terrain_event.dart';
import '../game_state.dart';
import '../ability_stats_collector.dart';
import 'act_system.dart';
import 'terrain_system.dart';

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

    final stats = gs.abilityStats;
    final before = stats != null
        ? AbilityStatsCollector.snap(gs, player.team)
        : null;

    switch (player.playerClass) {
      case PlayerClass.spectre:
        _spectreAbility(gs, player, slot);
      case PlayerClass.geomancer:
        _geomancerAbility(gs, player, slot);
      case PlayerClass.archon:
        _archonAbility(gs, player, slot);
      case PlayerClass.warden:
        _wardenAbility(gs, player, slot);
      case PlayerClass.corsair:
        _corsairAbility(gs, player, slot);
      case PlayerClass.trickster:
        _tricksterAbility(gs, player, slot);
      case PlayerClass.wrecker:
        _wreckerAbility(gs, player, slot);
    }

    if (stats != null && before != null) {
      final after = AbilityStatsCollector.snap(gs, player.team);
      stats.recordUse(
        player: player,
        slot: slot,
        before: before,
        after: after,
        gameTimeRemaining: gs.actState.timerSeconds,
      );
    }
  }

  // ─── SPECTRE abilities ────────────────────────────────────────────────────
  // Speed-focused ball carrier. Fragile (75 HP) but fastest (10 m/s).

  static void _spectreAbility(GameState gs, UltraballPlayer p, int slot) {
    if (slot == 1) {
      // Quick Strike — 12 dmg, 0.5s CD
      if (p.tackleCooldown > 0) return;
      final t = _resolveTarget(gs, p, 2.5);
      if (t == null) return;
      p.tackleCooldown = 1.5;
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
      p.slamCooldown = 5.0;
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
      p.speedBoostMax = 3.0;
      p.sprintCooldown = 5.0;

    } else if (slot == 4) {
      // Dash — 6m teleport forward, 7s CD, 20 blue
      if (p.ability4Cooldown > 0) return;
      if (p.blueMana < 20) return;
      p.blueMana -= 20;
      p.ability4Cooldown = 7.0;
      p.x = (p.x + math.cos(p.facing) * 6.0).clamp(0.0, GameState.fieldWidth);
      p.y = (p.y + math.sin(p.facing) * 6.0).clamp(0.0, GameState.fieldHeight);
      addIndicator(gs, p.x, p.y - 1, 'PHASE!', IndicatorType.event);

    } else if (slot == 5) {
      // Spin Move — 1.5s dodge (invulnerability frames), 8s CD, 25 blue
      if (p.ability5Cooldown > 0) return;
      if (p.blueMana < 25) return;
      p.blueMana -= 25;
      p.ability5Cooldown = 10.0;
      p.applyDodge(1.5);
      addIndicator(gs, p.x, p.y - 1, 'GHOST!', IndicatorType.event);

    } else if (slot == 6) {
      // Eye Gouge — 15 dmg + 2s stun, 10s CD, 30 red
      if (p.ability6Cooldown > 0) return;
      if (p.redMana < 30) return;
      final t = _resolveTarget(gs, p, 2.5);
      if (t == null) return;
      p.redMana -= 30;
      p.ability6Cooldown = 20.0;
      applyDamage(gs, t, 15.0, p);
      t.stun(2.0);

    } else if (slot == 7) {
      // Clear Out — self-cleanse + heal 25 HP, 15s CD, 40 blue
      if (p.ability7Cooldown > 0) return;
      if (p.blueMana < 40) return;
      p.ability7Cooldown = 20.0;
      p.blueMana -= 40;
      p.cleanse();
      _applyHealing(gs, p, 25.0, p);
      addIndicator(gs, p.x, p.y - 2, '+25 HP', IndicatorType.heal);
      addIndicator(gs, p.x, p.y - 3, 'CLEANSED!', IndicatorType.event);

    } else if (slot == 8) {
      // Cut Back — 4m backward dash + AoE 3m snare (2s, 40% slow), 12s CD, 25 red
      if (p.ability8Cooldown > 0) return;
      if (p.redMana < 25) return;
      p.redMana -= 25;
      p.ability8Cooldown = 10.0;
      // Move backward
      p.x = (p.x - math.cos(p.facing) * 4.0).clamp(0.0, GameState.fieldWidth);
      p.y = (p.y - math.sin(p.facing) * 4.0).clamp(0.0, GameState.fieldHeight);
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
      p.ability9Cooldown = 10.0;
      p.stunImmune = true;
      p.stunImmuneTimer = 3.0;
      p.stunImmuneMax = 3.0;
      p.speedBoostTimer = 3.0;
      p.speedBoostMax = 3.0;
      addIndicator(gs, p.x, p.y - 1, 'SLIPSTREAM!', IndicatorType.event);

    } else if (slot == 10) {
      // FULL SPRINT — 7s: 2.5× speed + stun immune, costs 5 ultra mana
      if (p.ultraMana < 5) return;
      p.ultraMana -= 5;
      p.speedMultiplierOverride = 2.5;
      p.speedMultiplierTimer = 7.0;
      p.speedMultiplierMax = 7.0;
      p.stunImmune = true;
      p.stunImmuneTimer = 7.0;
      p.stunImmuneMax = 7.0;
      addIndicator(gs, p.x, p.y - 2, 'ULTRAVIOLET!', IndicatorType.kill);
      gs.showEvent('ULTRAVIOLET! ${p.name} is beyond reach for 7 seconds!');
    }
  }

  // ─── GEOMANCER abilities ──────────────────────────────────────────────────
  // Terrain shaper. Medium HP (115), medium speed (7 m/s). Red-mana focused.
  // Slots 2 and 4 use hold-to-aim (human player) — AI calls them directly here.

  static void _geomancerAbility(GameState gs, UltraballPlayer p, int slot) {
    if (slot == 1) {
      // Earth Fist — 18 dmg, 1s CD
      if (p.tackleCooldown > 0) return;
      final t = _resolveTarget(gs, p, 2.5);
      if (t == null) return;
      p.tackleCooldown = 1.5;
      gs.dataCollector?.onTackle(p.team == Team.opponent ? 'opponent' : 'player');
      applyDamage(gs, t, 18.0, p);
      checkCombo(gs, p);

    } else if (slot == 2) {
      // Raise Hill — hold-to-aim for human; AI calls directly
      if (p.slamCooldown > 0) return;
      if (p.redMana < 25) return;
      p.redMana -= 25;
      p.slamCooldown = 20.0;
      gs.dataCollector?.onSlam(p.team == Team.opponent ? 'opponent' : 'player');
      final tx = (p.x + math.cos(p.facing) * GameState.terrainAimRange).clamp(0.0, GameState.fieldWidth);
      final ty = (p.y + math.sin(p.facing) * GameState.terrainAimRange).clamp(0.0, GameState.fieldHeight);
      TerrainSystem.applyEvent(gs, TerrainEvent(
        type: TerrainEventType.riseMountain,
        worldX: tx, worldY: ty,
        radius: 5.0, intensity: 1.0, duration: 6.0,
      ));
      addIndicator(gs, tx, ty - 1, 'RAISE HILL!', IndicatorType.event);

    } else if (slot == 3) {
      // Seismic Shove — 12 dmg + push 4m, 5s CD, 15 red
      if (p.sprintCooldown > 0) return;
      if (p.redMana < 15) return;
      final t = _resolveTarget(gs, p, 3.0);
      if (t == null) return;
      p.redMana -= 15;
      p.sprintCooldown = 5.0;
      applyDamage(gs, t, 12.0, p);
      if (t.isAlive) {
        final dx = t.x - p.x, dy = t.y - p.y;
        final dist = math.sqrt(dx * dx + dy * dy);
        if (dist > 0) {
          t.x = (t.x + (dx / dist) * 4.0).clamp(0.0, GameState.fieldWidth);
          t.y = (t.y + (dy / dist) * 4.0).clamp(0.0, GameState.fieldHeight);
        }
        addIndicator(gs, t.x, t.y - 1, 'SHOVED!', IndicatorType.event);
      }

    } else if (slot == 4) {
      // Open Sinkhole — hold-to-aim for human; AI calls directly
      if (p.ability4Cooldown > 0) return;
      if (p.redMana < 35) return;
      p.redMana -= 35;
      p.ability4Cooldown = 20.0;
      final tx = (p.x + math.cos(p.facing) * GameState.terrainAimRange).clamp(0.0, GameState.fieldWidth);
      final ty = (p.y + math.sin(p.facing) * GameState.terrainAimRange).clamp(0.0, GameState.fieldHeight);
      TerrainSystem.applyEvent(gs, TerrainEvent(
        type: TerrainEventType.openPit,
        worldX: tx, worldY: ty,
        radius: 4.0, intensity: 1.0, duration: 6.0,
      ));
      addIndicator(gs, tx, ty - 1, 'SINKHOLE!', IndicatorType.kill);

    } else if (slot == 5) {
      // Tremor — AoE 5m: 15 dmg + 1.5s snare (40% slow), 8s CD, 25 red
      if (p.ability5Cooldown > 0) return;
      if (p.redMana < 25) return;
      p.redMana -= 25;
      p.ability5Cooldown = 10.0;
      int hit = 0;
      for (final enemy in gs.fieldPlayers) {
        if (enemy.team == p.team || !enemy.isAlive) continue;
        final dx = enemy.x - p.x, dy = enemy.y - p.y;
        if (math.sqrt(dx * dx + dy * dy) <= 5.0) {
          applyDamage(gs, enemy, 15.0, p);
          enemy.applySnare(1.5, 0.4);
          hit++;
        }
      }
      addIndicator(gs, p.x, p.y - 1, hit > 0 ? 'TREMOR! ×$hit' : 'TREMOR!', IndicatorType.kill);

    } else if (slot == 6) {
      // Stone Armor — 40% dmg reduction for 4s, self, 12s CD, 30 blue
      if (p.ability6Cooldown > 0) return;
      if (p.blueMana < 30) return;
      p.blueMana -= 30;
      p.ability6Cooldown = 10.0;
      p.damageReductionFactor = 0.60;
      p.damageReductionTimer = 4.0;
      p.damageReductionMax = 4.0;
      addIndicator(gs, p.x, p.y - 2, 'STONE ARMOR!', IndicatorType.event);

    } else if (slot == 7) {
      // Earthmend — self +35 HP, 15s CD, 35 blue
      if (p.ability7Cooldown > 0) return;
      if (p.blueMana < 35) return;
      p.ability7Cooldown = 10.0;
      p.blueMana -= 35;
      _applyHealing(gs, p, 35.0, p);
      addIndicator(gs, p.x, p.y - 2, '+35 HP', IndicatorType.heal);

    } else if (slot == 8) {
      // Upheaval — +20% speed 4s + gain 30 red mana, 10s CD, 20 blue
      if (p.ability8Cooldown > 0) return;
      if (p.blueMana < 20) return;
      p.blueMana -= 20;
      p.ability8Cooldown = 5.0;
      p.speedBoostTimer = 4.0;
      p.speedBoostMax = 4.0;
      p.gainRedMana(30.0);
      addIndicator(gs, p.x, p.y - 2, 'UPHEAVAL!', IndicatorType.event);

    } else if (slot == 9) {
      // Fissure — dash 5m + leave pit strip along path (2 cells wide, 2s), 12s CD, 30 red
      if (p.ability9Cooldown > 0) return;
      if (p.redMana < 30) return;
      p.redMana -= 30;
      p.ability9Cooldown = 5.0;
      final destX = (p.x + math.cos(p.facing) * 5.0).clamp(0.0, GameState.fieldWidth);
      final destY = (p.y + math.sin(p.facing) * 5.0).clamp(0.0, GameState.fieldHeight);
      TerrainSystem.applyEvent(gs, TerrainEvent(
        type: TerrainEventType.openPit,
        worldX: (p.x + destX) / 2, worldY: (p.y + destY) / 2,
        radius: 3.0, intensity: 1.0, duration: 2.0,
        directionRad: p.facing,
      ));
      p.x = destX;
      p.y = destY;
      addIndicator(gs, destX, destY - 1, 'FISSURE!', IndicatorType.kill);

    } else if (slot == 10) {
      // TERRA NOVA — raise hills + open pits under all enemies, costs 5 ultra
      if (p.ultraMana < 5) return;
      p.ultraMana -= 5;
      // Raise hills in a wide radius around self
      TerrainSystem.applyEvent(gs, TerrainEvent(
        type: TerrainEventType.riseMountain,
        worldX: p.x, worldY: p.y,
        radius: 30.0, intensity: 0.7, duration: 8.0,
      ));
      // Open pits under each living enemy
      for (final enemy in gs.fieldPlayers) {
        if (enemy.team == p.team || !enemy.isAlive) continue;
        TerrainSystem.applyEvent(gs, TerrainEvent(
          type: TerrainEventType.openPit,
          worldX: enemy.x, worldY: enemy.y,
          radius: 3.0, intensity: 1.0, duration: 6.0,
        ));
      }
      addIndicator(gs, p.x, p.y - 2, 'TERRA NOVA!', IndicatorType.kill);
      gs.showEvent('TERRA NOVA! ${p.name} reshapes the earth!');
    }
  }

  // ─── ARCHON abilities ─────────────────────────────────────────────────────
  // Defensive anchor and team healer. High HP (120), medium speed (7.5 m/s).

  static void _archonAbility(GameState gs, UltraballPlayer p, int slot) {
    if (slot == 1) {
      // Shield Bash — 15 dmg + 2m push, 0.8s CD
      if (p.tackleCooldown > 0) return;
      final t = _resolveTarget(gs, p, 2.5);
      if (t == null) return;
      p.tackleCooldown = 1.5;
      gs.dataCollector?.onTackle(p.team == Team.opponent ? 'opponent' : 'player');
      applyDamage(gs, t, 15.0, p);
      if (t.isAlive) {
        final dx = t.x - p.x, dy = t.y - p.y;
        final dist = math.sqrt(dx * dx + dy * dy);
        if (dist > 0) {
          t.x = (t.x + (dx / dist) * 2.0).clamp(0.0, GameState.fieldWidth);
          t.y = (t.y + (dy / dist) * 2.0).clamp(0.0, GameState.fieldHeight);
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
      p.slamCooldown = 10.0;
      gs.dataCollector?.onSlam(p.team == Team.opponent ? 'opponent' : 'player');
      applyDamage(gs, t, 30.0, p);
      t.stun(1.0);

    } else if (slot == 3) {
      // Sprint — 1.5× speed for 3s, 6s CD, 20 blue
      if (p.sprintCooldown > 0) return;
      if (p.blueMana < 20) return;
      p.blueMana -= 20;
      p.speedBoostTimer = 3.0;
      p.speedBoostMax = 3.0;
      p.sprintCooldown = 5.0;

    } else if (slot == 4) {
      // Bulwark — self 50% dmg reduction for 3s, 10s CD, 25 blue
      if (p.ability4Cooldown > 0) return;
      if (p.blueMana < 25) return;
      p.blueMana -= 25;
      p.ability4Cooldown = 10.0;
      p.damageReductionFactor = 0.50;
      p.damageReductionTimer = 3.0;
      p.damageReductionMax = 3.0;
      addIndicator(gs, p.x, p.y - 2, 'FORTRESS!', IndicatorType.event);

    } else if (slot == 5) {
      // Mend — heal nearest ally 35 HP (5m range), 10s CD, 30 blue
      if (p.ability5Cooldown > 0) return;
      if (p.blueMana < 30) return;
      final t = _findNearestAlly(gs, p, 5.0);
      if (t == null) return;
      p.blueMana -= 30;
      p.ability5Cooldown = 5.0;
      _applyHealing(gs, t, 35.0, p);
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
      p.ability7Cooldown = 10.0;
      p.blueMana -= 35;
      _applyHealing(gs, p, 35.0, p);
      p.blueMana = math.min(100, p.blueMana + 20.0);
      addIndicator(gs, p.x, p.y - 2, '+35 HP', IndicatorType.heal);

    } else if (slot == 8) {
      // Fortify — 30% dmg reduction to nearest ally (5m) for 4s, 14s CD, 30 blue
      if (p.ability8Cooldown > 0) return;
      if (p.blueMana < 30) return;
      final t = _findNearestAlly(gs, p, 5.0);
      if (t == null) return;
      p.blueMana -= 30;
      p.ability8Cooldown = 20.0;
      t.damageReductionFactor = 0.70;
      t.damageReductionTimer = 4.0;
      t.damageReductionMax = 4.0;
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
          _applyHealing(gs, mate, 25.0, p);
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
        target.damageReductionMax = 6.0;
        target.stunImmune = true;
        target.stunImmuneTimer = 6.0;
        target.stunImmuneMax = 6.0;
        target.applyHoT(6.0, 8.0, casterCredit: (amt) => p.totalHealingDone += amt);
        addIndicator(gs, target.x, target.y - 2, 'CITADEL!', IndicatorType.event);
      }
      gs.showEvent('CITADEL! ${targets.length} players shielded for 6s!');
    }
  }

  // ─── WARDEN abilities ─────────────────────────────────────────────────────
  // Field captain and support quarterback. Medium stats (95 HP, 8 m/s).

  static void _wardenAbility(GameState gs, UltraballPlayer p, int slot) {
    if (slot == 1) {
      // Quick Jab — 10 dmg, 0.6s CD
      if (p.tackleCooldown > 0) return;
      final t = _resolveTarget(gs, p, 2.5);
      if (t == null) return;
      p.tackleCooldown = 1.5;
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
      p.slamCooldown = 5.0;
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
      p.speedBoostMax = 3.0;
      p.sprintCooldown = 5.0;

    } else if (slot == 4) {
      // Field Medic — heal nearest ally 30 HP (5m), 10s CD, 30 blue
      if (p.ability4Cooldown > 0) return;
      if (p.blueMana < 30) return;
      final t = _findNearestAlly(gs, p, 5.0);
      if (t == null) return;
      p.blueMana -= 30;
      p.ability4Cooldown = 10.0;
      _applyHealing(gs, t, 30.0, p);
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
      p.ability7Cooldown = 20.0;
      _applyHealing(gs, t, 60.0, p);
      t.cleanse();
      addIndicator(gs, t.x, t.y - 2, '+60 HP', IndicatorType.heal);
      addIndicator(gs, t.x, t.y - 3, 'CLEANSED!', IndicatorType.event);

    } else if (slot == 8) {
      // Team Rally — AoE 8m: restore 20 blue to all allies, 18s CD, 40 blue
      if (p.ability8Cooldown > 0) return;
      if (p.blueMana < 40) return;
      p.blueMana -= 40;
      p.ability8Cooldown = 20.0;
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
      p.ability9Cooldown = 10.0;
      p.x = (p.x + math.cos(p.facing) * 5.0).clamp(0.0, GameState.fieldWidth);
      p.y = (p.y + math.sin(p.facing) * 5.0).clamp(0.0, GameState.fieldHeight);
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
        _applyHealing(gs, mate, 35.0, p);
        mate.blueMana = math.min(100, mate.blueMana + 40.0);
        mate.cleanse();
        addIndicator(gs, mate.x, mate.y - 2, 'SYMPHONY!', IndicatorType.heal);
        targets++;
      }
      // Also apply to self
      _applyHealing(gs, p, 35.0, p);
      p.blueMana = math.min(100, p.blueMana + 40.0);
      p.cleanse();
      addIndicator(gs, p.x, p.y - 2, 'SYMPHONY!', IndicatorType.heal);
      gs.showEvent('SYMPHONY! ${targets + 1} players healed and cleansed!');
    }
  }

  // ─── CORSAIR abilities ─────────────────────────────────────────────────────
  // Aggressive disruptor. Balanced stats (105 HP, 8.5 m/s). Mixed mana.

  static void _corsairAbility(GameState gs, UltraballPlayer p, int slot) {
    if (slot == 1) {
      // Blitz Strike — 18 dmg, 0.7s CD
      if (p.tackleCooldown > 0) return;
      final t = _resolveTarget(gs, p, 2.5);
      if (t == null) return;
      p.tackleCooldown = 1.5;
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
      p.slamCooldown = 20.0;
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
      p.speedBoostMax = 3.0;
      p.sprintCooldown = 5.0;

    } else if (slot == 4) {
      // Aggressive Rush — dash 5m + snare enemy at landing (2s, 50% slow), 8s CD, 20 red
      if (p.ability4Cooldown > 0) return;
      if (p.redMana < 20) return;
      p.redMana -= 20;
      p.ability4Cooldown = 5.0;
      p.x = (p.x + math.cos(p.facing) * 5.0).clamp(0.0, GameState.fieldWidth);
      p.y = (p.y + math.sin(p.facing) * 5.0).clamp(0.0, GameState.fieldHeight);
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
      p.damageBoostMax = 4.0;
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
          t.x = (t.x + (dx / dist) * 4.0).clamp(0.0, GameState.fieldWidth);
          t.y = (t.y + (dy / dist) * 4.0).clamp(0.0, GameState.fieldHeight);
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
      p.ability7Cooldown = 10.0;
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
          enemy.x = (enemy.x + (dx / dist) * 3.0).clamp(0.0, GameState.fieldWidth);
          enemy.y = (enemy.y + (dy / dist) * 3.0).clamp(0.0, GameState.fieldHeight);
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
      p.ability9Cooldown = 20.0;
      final creature = gs.creature;
      final dx = creature.x - t.x;
      final dy = creature.y - t.y;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist > 0) {
        t.x = (t.x + (dx / dist) * 4.0).clamp(0.0, GameState.fieldWidth);
        t.y = (t.y + (dy / dist) * 4.0).clamp(0.0, GameState.fieldHeight);
      }
      t.applyMark(5.0);
      addIndicator(gs, t.x, t.y - 1, 'BAIT!', IndicatorType.kill);

    } else if (slot == 10) {
      // BLOOD RUSH — 7s: 2× speed + 35% dmg boost + stun immune + attacks apply snare, costs 5 ultra
      if (p.ultraMana < 5) return;
      p.ultraMana -= 5;
      p.speedMultiplierOverride = 2.0;
      p.speedMultiplierTimer = 7.0;
      p.speedMultiplierMax = 7.0;
      p.damageBoostFactor = 1.35;
      p.damageBoostTimer = 7.0;
      p.damageBoostMax = 7.0;
      p.stunImmune = true;
      p.stunImmuneTimer = 7.0;
      p.stunImmuneMax = 7.0;
      p.attacksApplySnare = true;
      p.attacksApplySnareTimer = 7.0;
      p.attacksApplySnareMax = 7.0;
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
      if (dist <= range + 4.0) {
        attacker.currentTargetId = tabTarget.id;
        return tabTarget;
      }
    }
    final nearest = _findNearestEnemy(gs, attacker, range);
    if (nearest != null) attacker.currentTargetId = nearest.id;
    return nearest;
  }

  /// Drain the ability queue for a player — called each tick for the selected player.
  static void drainAbilityQueue(GameState gs, UltraballPlayer player) {
    if (player.abilityQueue.isEmpty) return;
    if (player.gcdRemaining > 0) return;

    final slot = player.abilityQueue.first;
    if (player.getSlotCooldown(slot) > 0) return; // not ready yet, wait

    player.abilityQueue.removeAt(0);
    useClassAbility(gs, player, slot);

    // Set GCD and combat text
    player.gcdRemaining = 1.0;
    player.gcdMax = 1.0;
    final names = player.playerClass.abilityNames;
    if (slot >= 1 && slot <= names.length) {
      player.lastExecutedAbility = names[slot - 1];
      player.lastExecutedTimer = 1.2;
    }
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

    // High-ground bonus: +15% if attacker is on elevated terrain
    final highGroundMult = (attacker != null &&
            gs.terrain.cellAt(attacker.x, attacker.y).height > 1.0)
        ? 1.15
        : 1.0;

    final finalDmg = (damage
            * (attacker?.damageBoostFactor ?? 1.0)
            * (attacker?.hexedFactor ?? 1.0)
            * victim.damageReductionFactor
            * markMult
            * highGroundMult)
        .clamp(0.0, 9999.0);

    victim.health -= finalDmg;
    attacker?.gainRedMana(5.0);
    attacker?.totalDamageDealt += finalDmg;

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
    ActSystem.notifyPlayerDeath(gs, victim);
  }

  static void _applyHealing(
    GameState gs,
    UltraballPlayer target,
    double amount,
    UltraballPlayer caster,
  ) {
    final actual = math.min(target.maxHealth - target.health, amount);
    if (actual <= 0) return;
    target.health += actual;
    caster.totalHealingDone += actual;
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

  static void processTraps(GameState gs, double dt) {
    for (int i = gs.tricksterTraps.length - 1; i >= 0; i--) {
      final trap = gs.tricksterTraps[i];
      trap.timer -= dt;
      if (trap.timer <= 0) { gs.tricksterTraps.removeAt(i); continue; }
      if (trap.triggered) continue;
      for (final p in gs.fieldPlayers) {
        if (p.team == trap.ownerTeam || !p.isAlive) continue;
        final dx = p.x - trap.worldX, dy = p.y - trap.worldY;
        if (dx * dx + dy * dy <= trap.radius * trap.radius) {
          p.applySnare(trap.snareDuration, trap.snareMultiplier);
          addIndicator(gs, p.x, p.y - 1, 'TRAPPED!', IndicatorType.event);
          trap.triggered = true;
          break;
        }
      }
    }
  }

  // ─── TRICKSTER abilities ──────────────────────────────────────────────────
  // Crowd-control specialist and trickster. Low HP (85) but fast (9 m/s).
  // Inspired by Loki, Anansi, Puck, Kitsune, Coyote.

  static void _tricksterAbility(GameState gs, UltraballPlayer p, int slot) {
    if (slot == 1) {
      // Hex Strike — 10 dmg + 3s Hex (−20% dmg output), 1.5s CD
      if (p.tackleCooldown > 0) return;
      final t = _resolveTarget(gs, p, 2.5);
      if (t == null) return;
      p.tackleCooldown = 1.5;
      gs.dataCollector?.onTackle(p.team == Team.opponent ? 'opponent' : 'player');
      applyDamage(gs, t, 10.0, p);
      if (t.isAlive) {
        t.applyHex(3.0, 0.80);
        addIndicator(gs, t.x, t.y - 1, 'HEX!', IndicatorType.event);
      }
      checkCombo(gs, p);

    } else if (slot == 2) {
      // Phantom Step — teleport 7m forward, leave snare trap at origin
      if (p.slamCooldown > 0) return;
      if (p.blueMana < 20) return;
      p.blueMana -= 20;
      p.slamCooldown = 5.0;
      final trapX = p.x, trapY = p.y;
      p.x = (p.x + math.cos(p.facing) * 7.0).clamp(0.0, GameState.fieldWidth);
      p.y = (p.y + math.sin(p.facing) * 7.0).clamp(0.0, GameState.fieldHeight);
      gs.tricksterTraps.add(TricksterTrap(
        worldX: trapX, worldY: trapY, ownerTeam: p.team,
        radius: 2.5, timer: 8.0, snareDuration: 2.0, snareMultiplier: 0.5,
      ));
      addIndicator(gs, p.x, p.y - 1, 'PHANTOM!', IndicatorType.event);

    } else if (slot == 3) {
      // Fox Sprint — 1.5× speed for 3s, 5s CD, 15 blue
      if (p.sprintCooldown > 0) return;
      if (p.blueMana < 15) return;
      p.blueMana -= 15;
      p.speedBoostTimer = 3.0;
      p.speedBoostMax = 3.0;
      p.sprintCooldown = 5.0;

    } else if (slot == 4) {
      // Befuddle — 2.5s confusion + force fumble if target has ball, 10s CD, 25 red
      if (p.ability4Cooldown > 0) return;
      if (p.redMana < 25) return;
      final t = _resolveTarget(gs, p, 3.0);
      if (t == null) return;
      p.redMana -= 25;
      p.ability4Cooldown = 10.0;
      t.applyConfusion(2.5);
      addIndicator(gs, t.x, t.y - 1, 'CONFUSED!', IndicatorType.kill);
      if (gs.ball.holderId == t.id) {
        gs.ball.holderId = null;
        gs.ball.isInFlight = false;
        gs.ball.velX = 0;
        gs.ball.velY = 0;
        addIndicator(gs, t.x, t.y - 2, 'FUMBLE!', IndicatorType.kill);
        gs.showEvent('BEFUDDLE! ${t.name} drops the ball in confusion!');
      }

    } else if (slot == 5) {
      // Creature Goad — reverse creature direction 5s + push nearby enemies, 20s CD, 40 red
      if (p.ability5Cooldown > 0) return;
      if (p.redMana < 40) return;
      p.redMana -= 40;
      p.ability5Cooldown = 10.0;
      gs.creature.reverseDirection(5.0);
      int pushed = 0;
      for (final enemy in gs.fieldPlayers) {
        if (enemy.team == p.team || !enemy.isAlive) continue;
        final dx = enemy.x - gs.creature.x, dy = enemy.y - gs.creature.y;
        final dist = math.sqrt(dx * dx + dy * dy);
        if (dist <= 8.0 && dist > 0) {
          enemy.x = (enemy.x + (dx / dist) * 5.0).clamp(0.0, GameState.fieldWidth);
          enemy.y = (enemy.y + (dy / dist) * 5.0).clamp(0.0, GameState.fieldHeight);
          pushed++;
        }
      }
      addIndicator(gs, gs.creature.x, gs.creature.y - 2, 'GOADED!', IndicatorType.kill);
      gs.showEvent('CREATURE GOAD! ${gs.creature.name} reverses direction${pushed > 0 ? ", $pushed enemies scattered!" : "!"}');

    } else if (slot == 6) {
      // Position Swap — swap positions with target (8m range); steal ball if they have it, 60s CD, 35 blue
      if (p.ability6Cooldown > 0) return;
      if (p.blueMana < 35) return;
      final t = _findNearestEnemy(gs, p, 8.0);
      if (t == null) return;
      p.blueMana -= 35;
      p.ability6Cooldown = 20.0;
      final oldX = p.x, oldY = p.y;
      p.x = t.x; p.y = t.y;
      t.x = oldX; t.y = oldY;
      if (gs.ball.holderId == t.id) {
        gs.ball.holderId = p.id;
        gs.ball.changePossession(p.team == Team.player ? 'player' : 'opponent');
        addIndicator(gs, p.x, p.y - 2, 'STOLEN!', IndicatorType.kill);
      } else {
        addIndicator(gs, p.x, p.y - 1, 'SWAPPED!', IndicatorType.event);
      }

    } else if (slot == 7) {
      // Jinx — drain 25 red + 20 blue from target; give self half; stun 1s if drained full, 10s CD, 25 blue
      if (p.ability7Cooldown > 0) return;
      if (p.blueMana < 25) return;
      final t = _resolveTarget(gs, p, 5.0);
      if (t == null) return;
      p.blueMana -= 25;
      p.ability7Cooldown = 10.0;
      final drainedRed = math.min(t.redMana, 25.0);
      final drainedBlue = math.min(t.blueMana, 20.0);
      t.redMana = math.max(0, t.redMana - 25.0);
      t.blueMana = math.max(0, t.blueMana - 20.0);
      p.gainRedMana(drainedRed / 2.0);
      p.blueMana = math.min(100, p.blueMana + drainedBlue / 2.0);
      if (drainedRed >= 25.0) {
        t.stun(1.0);
        addIndicator(gs, t.x, t.y - 1, 'JINXED!', IndicatorType.kill);
      } else {
        addIndicator(gs, t.x, t.y - 1, 'DRAINED!', IndicatorType.event);
      }

    } else if (slot == 8) {
      // Hex Nova — if target is hexed: spread 4s hex to all enemies within 5m.
      // If not: hex target + all enemies within 3m for 3s. 10s CD, 20 blue.
      if (p.ability8Cooldown > 0) return;
      if (p.blueMana < 20) return;
      final t = _resolveTarget(gs, p, 5.0);
      if (t == null) return;
      p.blueMana -= 20;
      p.ability8Cooldown = 10.0;
      if (t.hexedTimer > 0) {
        // Spread phase: erupt the hex outward from the target
        int spread = 0;
        for (final enemy in gs.fieldPlayers) {
          if (enemy.team == p.team || !enemy.isAlive) continue;
          final dx = enemy.x - t.x, dy = enemy.y - t.y;
          if (dx * dx + dy * dy <= 25.0) { // 5m radius
            enemy.applyHex(4.0, 0.80);
            addIndicator(gs, enemy.x, enemy.y - 1, 'HEX!', IndicatorType.event);
            spread++;
          }
        }
        gs.showEvent('HEX NOVA! Curse erupts — $spread enemies hexed!');
      } else {
        // Seed phase: hex target and nearby cluster
        int hit = 0;
        for (final enemy in gs.fieldPlayers) {
          if (enemy.team == p.team || !enemy.isAlive) continue;
          final dx = enemy.x - t.x, dy = enemy.y - t.y;
          if (dx * dx + dy * dy <= 9.0) { // 3m radius from target
            enemy.applyHex(3.0, 0.80);
            addIndicator(gs, enemy.x, enemy.y - 1, 'HEX!', IndicatorType.event);
            hit++;
          }
        }
        t.applyHex(3.0, 0.80); // always hex the primary target
        if (hit == 0) addIndicator(gs, t.x, t.y - 1, 'HEX!', IndicatorType.event);
        gs.showEvent('HEX NOVA! ${t.name} hexed${hit > 1 ? " + ${hit - 1} nearby!" : "!"}');
      }

    } else if (slot == 9) {
      // Chaos Fumble — force fumble + 1.5s stun if target has ball; else 20 dmg + Hex, 10s CD, 30 red
      if (p.ability9Cooldown > 0) return;
      if (p.redMana < 30) return;
      final t = _resolveTarget(gs, p, 3.5);
      if (t == null) return;
      p.redMana -= 30;
      p.ability9Cooldown = 20.0;
      if (gs.ball.holderId == t.id) {
        gs.ball.holderId = null;
        gs.ball.isInFlight = false;
        gs.ball.velX = 0;
        gs.ball.velY = 0;
        t.stun(1.5);
        addIndicator(gs, t.x, t.y - 1, 'CHAOS!', IndicatorType.kill);
        gs.showEvent('CHAOS FUMBLE! ${t.name} loses the ball!');
      } else {
        applyDamage(gs, t, 20.0, p);
        if (t.isAlive) {
          t.applyHex(3.0, 0.80);
          addIndicator(gs, t.x, t.y - 1, 'HEX!', IndicatorType.event);
        }
      }

    } else if (slot == 10) {
      // PANDEMONIUM — mass confusion 3s on all enemies; reverse creature; drain enemy red mana, 5 ultra
      if (p.ultraMana < 5) return;
      p.ultraMana -= 5;
      int confused = 0;
      for (final enemy in gs.fieldPlayers) {
        if (enemy.team == p.team || !enemy.isAlive) continue;
        enemy.applyConfusion(3.0);
        p.gainRedMana(enemy.redMana / 2.0);
        enemy.redMana = 0;
        addIndicator(gs, enemy.x, enemy.y - 1, '?!?!', IndicatorType.kill);
        confused++;
      }
      gs.creature.reverseDirection(6.0);
      addIndicator(gs, p.x, p.y - 2, 'PANDEMONIUM!', IndicatorType.kill);
      gs.showEvent('PANDEMONIUM! $confused enemies confused, creature reverses!');
    }
  }

  // ─── WRECKER abilities ────────────────────────────────────────────────────
  // Pure damage and kill specialist. 110 HP, 8 m/s. Red mana offense engine.

  static void _wreckerAbility(GameState gs, UltraballPlayer p, int slot) {
    if (slot == 1) {
      // Iron Fist — 20 dmg, 1.5s CD
      if (p.tackleCooldown > 0) return;
      final t = _resolveTarget(gs, p, 2.5);
      if (t == null) return;
      p.tackleCooldown = 1.5;
      gs.dataCollector?.onTackle(p.team == Team.opponent ? 'opponent' : 'player');
      applyDamage(gs, t, 20.0, p);
      checkCombo(gs, p);

    } else if (slot == 2) {
      // Sledge — 25 dmg + 1s stun, 5s CD, 20 red
      if (p.slamCooldown > 0) return;
      if (p.redMana < 20) return;
      final t = _resolveTarget(gs, p, 2.5);
      if (t == null) return;
      p.redMana -= 20;
      p.slamCooldown = 5.0;
      gs.dataCollector?.onSlam(p.team == Team.opponent ? 'opponent' : 'player');
      applyDamage(gs, t, 25.0, p);
      if (t.isAlive) {
        t.stun(1.0);
        addIndicator(gs, t.x, t.y - 1, 'SLEDGE!', IndicatorType.kill);
      }
      checkCombo(gs, p);

    } else if (slot == 3) {
      // Bull Rush — dash 5m forward; 20 dmg + 2m knockback to first enemy hit, 5s CD, 25 red
      if (p.sprintCooldown > 0) return;
      if (p.redMana < 25) return;
      p.redMana -= 25;
      p.sprintCooldown = 5.0;
      final destX = (p.x + math.cos(p.facing) * 5.0).clamp(0.0, GameState.fieldWidth);
      final destY = (p.y + math.sin(p.facing) * 5.0).clamp(0.0, GameState.fieldHeight);
      // Check for enemies along the dash path
      UltraballPlayer? hit;
      double bestDist = double.infinity;
      for (final enemy in gs.fieldPlayers) {
        if (enemy.team == p.team || !enemy.isAlive) continue;
        final dx = enemy.x - p.x, dy = enemy.y - p.y;
        final dist = math.sqrt(dx * dx + dy * dy);
        if (dist <= 5.5 && dist < bestDist) {
          bestDist = dist;
          hit = enemy;
        }
      }
      p.x = destX;
      p.y = destY;
      if (hit != null) {
        applyDamage(gs, hit, 20.0, p);
        if (hit.isAlive) {
          hit.x = (hit.x + math.cos(p.facing) * 2.0).clamp(0.0, GameState.fieldWidth);
          hit.y = (hit.y + math.sin(p.facing) * 2.0).clamp(0.0, GameState.fieldHeight);
          addIndicator(gs, hit.x, hit.y - 1, 'BULL RUSH!', IndicatorType.kill);
        }
      } else {
        addIndicator(gs, p.x, p.y - 1, 'RUSH!', IndicatorType.event);
      }

    } else if (slot == 4) {
      // Crumple — 30 dmg + 2s snare (50% slow), 10s CD, 25 red
      if (p.ability4Cooldown > 0) return;
      if (p.redMana < 25) return;
      final t = _resolveTarget(gs, p, 3.0);
      if (t == null) return;
      p.redMana -= 25;
      p.ability4Cooldown = 10.0;
      applyDamage(gs, t, 30.0, p);
      if (t.isAlive) {
        t.applySnare(2.0, 0.5);
        addIndicator(gs, t.x, t.y - 1, 'CRUMPLE!', IndicatorType.kill);
      }

    } else if (slot == 5) {
      // Shockwave — 10 dmg + 1m knockback to all enemies in 4m AoE, 1.5s CD, 15 red
      if (p.ability5Cooldown > 0) return;
      if (p.redMana < 15) return;
      p.redMana -= 15;
      p.ability5Cooldown = 1.5;
      int hit = 0;
      for (final enemy in gs.fieldPlayers) {
        if (enemy.team == p.team || !enemy.isAlive) continue;
        final dx = enemy.x - p.x, dy = enemy.y - p.y;
        final dist = math.sqrt(dx * dx + dy * dy);
        if (dist <= 4.0) {
          applyDamage(gs, enemy, 10.0, p);
          if (enemy.isAlive && dist > 0) {
            enemy.x = (enemy.x + (dx / dist) * 1.0).clamp(0.0, GameState.fieldWidth);
            enemy.y = (enemy.y + (dy / dist) * 1.0).clamp(0.0, GameState.fieldHeight);
          }
          hit++;
        }
      }
      addIndicator(gs, p.x, p.y - 1, hit > 0 ? 'SHOCKWAVE! ×$hit' : 'SHOCKWAVE!', IndicatorType.kill);

    } else if (slot == 6) {
      // Spine Breaker — 30 dmg + 1.5s stun, 10s CD, 25 red
      if (p.ability6Cooldown > 0) return;
      if (p.redMana < 25) return;
      final t = _resolveTarget(gs, p, 2.5);
      if (t == null) return;
      p.redMana -= 25;
      p.ability6Cooldown = 10.0;
      applyDamage(gs, t, 30.0, p);
      if (t.isAlive) {
        t.stun(1.5);
        addIndicator(gs, t.x, t.y - 1, 'BROKEN!', IndicatorType.kill);
      }

    } else if (slot == 7) {
      // Wrecking Ball — dash 6m; 20 dmg + 2m knockback to all enemies hit along path, 10s CD, 25 red
      if (p.ability7Cooldown > 0) return;
      if (p.redMana < 25) return;
      p.redMana -= 25;
      p.ability7Cooldown = 10.0;
      final destX = (p.x + math.cos(p.facing) * 6.0).clamp(0.0, GameState.fieldWidth);
      final destY = (p.y + math.sin(p.facing) * 6.0).clamp(0.0, GameState.fieldHeight);
      int hit = 0;
      for (final enemy in gs.fieldPlayers) {
        if (enemy.team == p.team || !enemy.isAlive) continue;
        final dx = enemy.x - p.x, dy = enemy.y - p.y;
        final dist = math.sqrt(dx * dx + dy * dy);
        if (dist <= 6.5) {
          applyDamage(gs, enemy, 20.0, p);
          if (enemy.isAlive && dist > 0) {
            enemy.x = (enemy.x + (dx / dist) * 2.0).clamp(0.0, GameState.fieldWidth);
            enemy.y = (enemy.y + (dy / dist) * 2.0).clamp(0.0, GameState.fieldHeight);
          }
          addIndicator(gs, enemy.x, enemy.y - 1, 'WRECKED!', IndicatorType.kill);
          hit++;
        }
      }
      p.x = destX;
      p.y = destY;
      if (hit == 0) addIndicator(gs, p.x, p.y - 1, 'WRECKING BALL!', IndicatorType.event);

    } else if (slot == 8) {
      // Ground Pound — 30 dmg + 1.5s stun to all enemies in 3m AoE, 20s CD, 30 red
      if (p.ability8Cooldown > 0) return;
      if (p.redMana < 30) return;
      p.redMana -= 30;
      p.ability8Cooldown = 20.0;
      int hit = 0;
      for (final enemy in gs.fieldPlayers) {
        if (enemy.team == p.team || !enemy.isAlive) continue;
        final dx = enemy.x - p.x, dy = enemy.y - p.y;
        if (math.sqrt(dx * dx + dy * dy) <= 3.0) {
          applyDamage(gs, enemy, 30.0, p);
          if (enemy.isAlive) {
            enemy.stun(1.5);
            addIndicator(gs, enemy.x, enemy.y - 1, 'STUNNED!', IndicatorType.kill);
          }
          hit++;
        }
      }
      addIndicator(gs, p.x, p.y - 2, hit > 0 ? 'GROUND POUND! ×$hit' : 'GROUND POUND!', IndicatorType.kill);
      gs.showEvent('GROUND POUND! ${p.name} slams the earth — $hit stunned!');

    } else if (slot == 9) {
      // Death Blow — 55 dmg + 3s stun, 20s CD, 35 red
      if (p.ability9Cooldown > 0) return;
      if (p.redMana < 35) return;
      final t = _resolveTarget(gs, p, 2.5);
      if (t == null) return;
      p.redMana -= 35;
      p.ability9Cooldown = 20.0;
      applyDamage(gs, t, 55.0, p);
      if (t.isAlive) {
        t.stun(3.0);
        addIndicator(gs, t.x, t.y - 1, 'DEATH BLOW!', IndicatorType.kill);
        gs.showEvent('DEATH BLOW! ${t.name} hit for 55 — stunned for 3 seconds!');
      }

    } else if (slot == 10) {
      // DEMOLISH — 35 dmg + 1.5s stun to all in 6m; self gains +40% dmg for 5s, 5 ultra
      if (p.ultraMana < 5) return;
      p.ultraMana -= 5;
      int stunned = 0;
      for (final enemy in gs.fieldPlayers) {
        if (enemy.team == p.team || !enemy.isAlive) continue;
        final dx = enemy.x - p.x, dy = enemy.y - p.y;
        if (math.sqrt(dx * dx + dy * dy) <= 6.0) {
          applyDamage(gs, enemy, 35.0, p);
          if (enemy.isAlive) {
            enemy.stun(1.5);
            addIndicator(gs, enemy.x, enemy.y - 1, 'DEMOLISHED!', IndicatorType.kill);
          }
          stunned++;
        }
      }
      p.damageBoostFactor = math.max(p.damageBoostFactor, 1.40);
      p.damageBoostTimer = 5.0;
      p.damageBoostMax = 5.0;
      addIndicator(gs, p.x, p.y - 2, 'DEMOLISH!', IndicatorType.kill);
      gs.showEvent('DEMOLISH! ${p.name} demolishes $stunned enemies — +40% dmg for 5s!');
    }
  }
}
