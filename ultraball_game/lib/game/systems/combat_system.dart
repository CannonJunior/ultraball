import 'dart:math' as math;
import '../../models/player.dart';
import '../../models/damage_indicator.dart';
import '../game_state.dart';
import 'act_system.dart';

class CombatSystem {
  static const double tackleRange = 2.5;
  static const double slamRange = 3.0;
  static const double tackleDamage = 15.0;
  static const double slamDamage = 35.0;
  static const double tackleCooldownDuration = 0.8;
  static const double slamCooldownDuration = 3.0;

  static void tryAttack(
    GameState gs,
    UltraballPlayer attacker,
    String attackType,
  ) {
    if (!attacker.isAlive || attacker.isStunned) return;

    if (attackType == 'tackle') {
      if (attacker.tackleCooldown > 0) return;
      // Prefer tab-targeted enemy; fall back to nearest in range
      final target = _resolveTarget(gs, attacker, tackleRange);
      if (target == null) return;
      attacker.tackleCooldown = tackleCooldownDuration;
      applyDamage(gs, target, tackleDamage, attacker);
      checkCombo(gs, attacker);
    } else if (attackType == 'slam') {
      if (attacker.slamCooldown > 0) return;
      if (attacker.redMana < 25) return;
      final target = _resolveTarget(gs, attacker, slamRange);
      if (target == null) return;
      attacker.redMana -= 25;
      attacker.slamCooldown = slamCooldownDuration;
      applyDamage(gs, target, slamDamage, attacker);
      // Knockback
      final dx = target.x - attacker.x;
      final dy = target.y - attacker.y;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist > 0) {
        final knockback = 5.0;
        target.x += (dx / dist) * knockback;
        target.y += (dy / dist) * knockback;
        target.x = target.x.clamp(0.0, 140.0);
        target.y = target.y.clamp(0.0, 40.0);
      }
      checkCombo(gs, attacker);
    }
  }

  /// Resolve attack target: use tab target if in range, else nearest enemy.
  /// Airborne targets evade ground-level attacks.
  static UltraballPlayer? _resolveTarget(
    GameState gs,
    UltraballPlayer attacker,
    double range,
  ) {
    final tabTarget = attacker.isPlayerControlled ? gs.currentTarget : null;
    if (tabTarget != null && tabTarget.isAlive && tabTarget.isOnField) {
      if (tabTarget.isAirborne) return null; // airborne — untouchable
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
    final enemies = gs.fieldPlayers
        .where((p) => p.team != attacker.team && p.isAlive && !p.isAirborne)
        .toList();

    UltraballPlayer? nearest;
    double nearestDist = range;

    for (final enemy in enemies) {
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

  static void applyDamage(
    GameState gs,
    UltraballPlayer victim,
    double damage,
    UltraballPlayer? attacker,
  ) {
    if (!victim.isAlive) return;

    victim.health -= damage;
    attacker?.gainRedMana(5.0);

    // Add damage indicator
    addIndicator(
      gs,
      victim.x,
      victim.y - 1.5,
      '-${damage.toInt()}',
      IndicatorType.damage,
    );

    if (victim.health <= 0) {
      // Kill
      final hadBall = gs.ball.holderId == victim.id;
      victim.die();

      addIndicator(gs, victim.x, victim.y, 'DEAD', IndicatorType.kill);

      // Award killa to attacker's team
      if (attacker != null) {
        final killaTeam = attacker.team;
        ActSystem.scoreKilla(gs, killaTeam == Team.player ? 'player' : 'opponent');
        gs.showEvent('KILLA! +1pt');
      }

      // Drop ball if victim had it
      if (hadBall) {
        gs.ball.holderId = null;
        gs.ball.isInFlight = false;
        gs.ball.velX = 0;
        gs.ball.velY = 0;
      }

      // If the player-controlled unit was just killed, hand off to the next
      // alive teammate immediately so the player never loses their selection.
      if (gs.selectedPlayer?.id == victim.id) {
        gs.selectNextPlayer();
      }

      // Check if on-field player team needs sub
      handlePlayerDeath(gs, victim);
    }
  }

  static void handlePlayerDeath(GameState gs, UltraballPlayer victim) {
    final roster = gs.getTeamRoster(victim.team);
    final onField = roster.where((p) => p.isOnField && p.isAlive).length;
    final teamId = victim.team == Team.player ? 'player' : 'opponent';

    // Check forfeit: all 15 dead
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

    // Try substitution (one per act)
    final subUsed = teamId == 'player'
        ? gs.actState.playerSubUsed
        : gs.actState.opponentSubUsed;
    if (!subUsed && onField < 7) {
      // Find a live roster player not on field
      final sub = roster.firstWhere(
        (p) => !p.isOnField && p.isAlive,
        orElse: () => roster[0],
      );
      if (!sub.isOnField && sub.isAlive) {
        sub.isOnField = true;
        // Enter at midfield sideline
        sub.x = victim.team == Team.player ? 90.0 : 50.0;
        sub.y = 20.0;
        sub.health = 100;
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
    attacker.comboTimer = 0; // reset window

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
