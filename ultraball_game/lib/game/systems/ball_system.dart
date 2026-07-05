import 'dart:math' as math;
import '../../models/player.dart';
import '../../models/damage_indicator.dart';
import '../game_state.dart';
import 'combat_system.dart';
import 'act_system.dart';

class BallSystem {
  static const double ballSpeed = 25.0;
  static const double powerBallSpeed = 35.0;
  static const double pickupRadius = 1.0;
  static const double catchRadius = 2.5;
  static const double throwHorizontalSpeed = 20.0;
  static const double throwBallGravity = 20.0;

  static void update(GameState gs, double dt) {
    final ball = gs.ball;

    if (ball.isInFlight) {
      _updateFlight(gs, dt);
    } else if (ball.isHeld) {
      _updateHeld(gs, dt);
    } else {
      // Loose ball: decelerate and check pickups
      ball.velX *= (1.0 - 5.0 * dt).clamp(0.0, 1.0);
      ball.velY *= (1.0 - 5.0 * dt).clamp(0.0, 1.0);

      final prevX = ball.x;
      ball.x += ball.velX * dt;
      ball.y += ball.velY * dt;
      ball.x = ball.x.clamp(0.0, 140.0);
      ball.y = ball.y.clamp(0.0, 40.0);

      // Check phase line crossing while loose
      final lineIdx = ball.checkPhaseLineCrossing(prevX, ball.x);
      if (lineIdx >= 0 && ball.phaseLineActive[lineIdx]) {
        ball.phaseLineActive[lineIdx] = false;
      }

      // Check if any player can pick up the ball
      for (final p in gs.fieldPlayers) {
        if (!p.isAlive || p.isStunned) continue;
        final dx = p.x - ball.x;
        final dy = p.y - ball.y;
        if (math.sqrt(dx * dx + dy * dy) < pickupRadius) {
          tryPickup(gs, p);
          break;
        }
      }
    }
  }

  static void _updateFlight(GameState gs, double dt) {
    final ball = gs.ball;
    final prevX = ball.x;

    // Charged throw: arc physics determine landing, no horizontal drag
    if (ball.isChargedThrow) {
      ball.flightAge += dt;
      ball.zVelocity -= throwBallGravity * dt;
      ball.zHeight += ball.zVelocity * dt;

      if (ball.zHeight <= 0) {
        // Ball has landed — become loose, no stun penalty
        ball.zHeight = 0.0;
        ball.zVelocity = 0.0;
        ball.isInFlight = false;
        ball.isChargedThrow = false;
        ball.velX = 0;
        ball.velY = 0;
        return;
      }
    }

    ball.x += ball.velX * dt;
    ball.y += ball.velY * dt;

    // Bounce off field boundaries
    if (ball.y < 0 || ball.y > 40) {
      ball.velY = -ball.velY;
      ball.y = ball.y.clamp(0.0, 40.0);
    }
    if (ball.x < 0) {
      ball.x = 0;
      ball.velX = -ball.velX * 0.5;
    }
    if (ball.x > 140) {
      ball.x = 140;
      ball.velX = -ball.velX * 0.5;
    }

    // Check phase line crossing during flight
    final lineIdx = ball.checkPhaseLineCrossing(prevX, ball.x);
    if (lineIdx >= 0 && ball.phaseLineActive[lineIdx]) {
      ball.phaseLineActive[lineIdx] = false;
    }

    // Check if a player catches the ball
    bool caught = false;
    for (final p in gs.fieldPlayers) {
      if (!p.isAlive || p.isStunned) continue;
      // Charged throw: block all catches for first 0.2s (prevents thrower self-catch on short arcs)
      if (ball.isChargedThrow && ball.flightAge < 0.2) continue;
      // Airborne ball can't be caught until it's nearly grounded
      if (ball.isChargedThrow && ball.zHeight > 1.5) continue;
      final dx = p.x - ball.x;
      final dy = p.y - ball.y;
      if (math.sqrt(dx * dx + dy * dy) < catchRadius) {
        final wasPlayerTeam = ball.possessingTeamId == 'player';
        final catcherIsPlayer = p.team == Team.player;
        final friendlyCatch = (wasPlayerTeam && catcherIsPlayer) ||
            (!wasPlayerTeam && !catcherIsPlayer);

        // Clear isInFlight before any pickup/interception call so that
        // tryPickup's guard (isInFlight check) doesn't bail out early.
        ball.isInFlight = false;
        ball.isChargedThrow = false;
        ball.zHeight = 0;
        ball.zVelocity = 0;
        if (friendlyCatch) {
          tryPickup(gs, p);
        } else {
          _handleInterception(gs, p);
        }
        caught = true;
        break;
      }
    }

    if (caught) return;

    // Regular pass: stop at the target distance; bounce if uncaught.
    if (!ball.isChargedThrow) {
      final speed = math.sqrt(
        ball.velX * ball.velX + ball.velY * ball.velY,
      );
      if (speed > 0) {
        ball.flightDistance -= speed * dt;
        if (ball.flightDistance <= 0) {
          ball.isInFlight = false;
          // Leave a small residual velocity so the ball rolls just a little.
          ball.velX *= 0.15;
          ball.velY *= 0.15;
          _handleFailedPass(gs);
        }
      }
    }
  }

  static void _handleInterception(GameState gs, UltraballPlayer catcher) {
    // Enemy caught our pass — stun original team
    final originalTeam =
        gs.ball.possessingTeamId == 'player' ? Team.player : Team.opponent;
    for (final p in gs.fieldPlayers) {
      if (p.team == originalTeam && p.isAlive) {
        p.stun(1.0);
        CombatSystem.addIndicator(
          gs,
          p.x,
          p.y,
          'STUNNED',
          IndicatorType.event,
        );
      }
    }

    // New team picks up ball
    gs.ball.isInFlight = false;
    gs.ball.holderId = catcher.id;
    gs.ball.changePossession(catcher.team == Team.player ? 'player' : 'opponent');
    gs.ball.chargeTimer = 0;
    gs.ball.cooldownBonus = 0;

    gs.showEvent('INTERCEPTED!');
  }

  static void _handleFailedPass(GameState gs) {
    // Stun the passing team
    final originalTeam =
        gs.ball.possessingTeamId == 'player' ? Team.player : Team.opponent;
    for (final p in gs.fieldPlayers) {
      if (p.team == originalTeam && p.isAlive) {
        p.stun(1.0);
        CombatSystem.addIndicator(
          gs,
          p.x,
          p.y,
          'STUNNED',
          IndicatorType.event,
        );
      }
    }
    gs.showEvent('FAILED PASS!');
  }

  static void _updateHeld(GameState gs, double dt) {
    final ball = gs.ball;
    final holder = gs.getPlayerById(ball.holderId!);

    if (holder == null || !holder.isAlive) {
      ball.holderId = null;
      ball.isInFlight = false;
      return;
    }

    // Ball follows holder
    ball.x = holder.x;
    ball.y = holder.y;

    // Accumulate charge; holder earns 1 ultra mana per second
    ball.chargeTimer += dt;
    holder.gainUltraMana(dt);

    // Check phase line crossing
    final prevX = holder.x - holder.velX * dt;
    final lineIdx = ball.checkPhaseLineCrossing(prevX, holder.x);
    if (lineIdx >= 0 && ball.phaseLineActive[lineIdx]) {
      // Don't reset charge when the carrier is entering their own scoring endzone:
      // player team crosses x=30 leftward (lineIdx 0), opponent crosses x=110 rightward (lineIdx 4).
      final enteringOwnEndzone =
          (holder.team == Team.player  && lineIdx == 0 && holder.velX < 0) ||
          (holder.team == Team.opponent && lineIdx == 4 && holder.velX > 0);
      if (enteringOwnEndzone) {
        ball.phaseLineActive[lineIdx] = false; // deactivate without resetting charge
      } else {
        handlePhaseLineCrossing(gs, lineIdx);
      }
    }

    // Check explosion
    if (ball.chargeTimer >= ball.effectiveMaxCharge) {
      handleExplosion(gs);
    }

    // Check if holder entered an endzone (scoring)
    _checkEndzoneSCoring(gs, holder);
  }

  static void _checkEndzoneSCoring(GameState gs, UltraballPlayer holder) {
    // Player team attacks left endzone (x=0-20), opponent team attacks right endzone (x=120-140)
    if (holder.team == Team.player && holder.x <= 20) {
      // Player scored Ultra (reached opponent's left endzone)
      // Check if it's a Meta (pass caught by player already in endzone)
      // We handle that in tryPickup
      ActSystem.scoreUltra(gs, 'player', holder);
      holder.gainUltraMana(7.0);
      CombatSystem.addIndicator(
        gs,
        holder.x,
        holder.y,
        'ULTRA!',
        IndicatorType.event,
      );
      gs.showEvent('ULTRA! 7 POINTS!');
      _resetAfterScore(gs);
    } else if (holder.team == Team.opponent && holder.x >= 120) {
      // Opponent scored Ultra
      ActSystem.scoreUltra(gs, 'opponent', holder);
      holder.gainUltraMana(7.0);
      CombatSystem.addIndicator(
        gs,
        holder.x,
        holder.y,
        'ULTRA!',
        IndicatorType.event,
      );
      gs.showEvent('ULTRA! Opponent +7 POINTS!');
      _resetAfterScore(gs);
    }
  }

  static void handlePhaseLineCrossing(GameState gs, int lineIndex) {
    gs.ball.phaseLineActive[lineIndex] = false;
    gs.ball.chargeTimer = 0;
    gs.ball.cooldownBonus = 0;
    CombatSystem.addIndicator(
      gs,
      gs.ball.x,
      gs.ball.y - 2,
      'PHASE!',
      IndicatorType.event,
    );
  }

  static void handleExplosion(GameState gs) {
    final holderTeam = gs.getPlayerById(gs.ball.holderId!)?.team == Team.player ? 'player' : 'opponent';
    gs.dataCollector?.onExplosion(holderTeam);
    final ball = gs.ball;
    final holder = gs.getPlayerById(ball.holderId!);

    if (holder == null) return;

    CombatSystem.addIndicator(
      gs,
      ball.x,
      ball.y,
      'BOOM!',
      IndicatorType.kill,
    );

    // Kill holder
    holder.die();
    gs.markRosterDirty();
    gs.showEvent('BALL EXPLODED! ${holder.name} is DEAD!');

    // Award Killa to opposite team
    final killaTeam = holder.team == Team.player ? 'opponent' : 'player';
    ActSystem.scoreKilla(gs, killaTeam);

    // Stun surviving teammates
    for (final p in gs.fieldPlayers) {
      if (p.team == holder.team && p.isAlive && p.id != holder.id) {
        p.stun(1.0);
      }
    }

    // Drop ball
    ball.holderId = null;
    ball.isInFlight = false;
    ball.chargeTimer = 0;
    ball.cooldownBonus = 0;
    ball.velX = 0;
    ball.velY = 0;

    // Select next player if this was selected
    if (gs.selectedPlayer?.id == holder.id) {
      gs.selectNextPlayer();
    }
  }

  static void tryPickup(GameState gs, UltraballPlayer player) {
    final ball = gs.ball;
    if (ball.isHeld || ball.isInFlight) return;

    final dx = player.x - ball.x;
    final dy = player.y - ball.y;
    if (math.sqrt(dx * dx + dy * dy) > pickupRadius) return;

    // Check if this is a Meta score (player already in endzone catches ball)
    if (player.team == Team.player && player.x <= 20) {
      ball.holderId = player.id;
      ball.changePossession('player');
      ActSystem.scoreMeta(gs, 'player', player);
      player.gainUltraMana(3.0);
      CombatSystem.addIndicator(
        gs,
        player.x,
        player.y,
        'META!',
        IndicatorType.event,
      );
      gs.showEvent('META! +3 POINTS!');
      _resetAfterScore(gs);
      return;
    } else if (player.team == Team.opponent && player.x >= 120) {
      ball.holderId = player.id;
      ball.changePossession('opponent');
      ActSystem.scoreMeta(gs, 'opponent', player);
      player.gainUltraMana(3.0);
      CombatSystem.addIndicator(
        gs,
        player.x,
        player.y,
        'META!',
        IndicatorType.event,
      );
      gs.showEvent('META! Opponent +3 POINTS!');
      _resetAfterScore(gs);
      return;
    }

    // Normal pickup
    ball.holderId = player.id;
    ball.cooldownBonus = 0;
    final newTeam = player.team == Team.player ? 'player' : 'opponent';
    if (ball.possessingTeamId != newTeam) {
      ball.changePossession(newTeam);
    }
  }

  static void tryChargedThrow(GameState gs, UltraballPlayer thrower) {
    final ball = gs.ball;
    if (ball.holderId != thrower.id) return;
    if (thrower.passCooldown > 0) return;

    final dist = thrower.throwDistance;
    final flightTime = dist / throwHorizontalSpeed;
    final initVZ = 0.5 * throwBallGravity * flightTime;

    ball.velX = math.cos(thrower.facing) * throwHorizontalSpeed;
    ball.velY = math.sin(thrower.facing) * throwHorizontalSpeed;
    ball.zHeight = 0.001;
    ball.zVelocity = initVZ;
    ball.flightAge = 0.0;
    ball.holderId = null;
    ball.isInFlight = true;
    ball.isChargedThrow = true;
    ball.isPowerPass = false;
    ball.cooldownBonus = 0;
    ball.chargeTimer = 0;

    thrower.passCooldown = 0.5;
    thrower.throwChargeTime = 0.0;
    thrower.isChargingThrow = false;
  }

  static void tryPass(
    GameState gs,
    UltraballPlayer thrower,
    double targetX,
    double targetY,
    bool isPowerPass,
  ) {
    final ball = gs.ball;
    if (ball.holderId != thrower.id) return;
    if (thrower.passCooldown > 0) return;

    final dx = targetX - thrower.x;
    final dy = targetY - thrower.y;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist == 0) return;

    if (isPowerPass) {
      if (thrower.blueMana < 30) return;
      thrower.blueMana -= 30;
    }

    gs.dataCollector?.onPass(thrower.team == Team.player ? 'player' : 'opponent');
    thrower.passCooldown = 0.5;

    final speed = isPowerPass ? powerBallSpeed : ballSpeed;
    ball.velX = (dx / dist) * speed;
    ball.velY = (dy / dist) * speed;
    ball.holderId = null;
    ball.isInFlight = true;
    ball.isPowerPass = isPowerPass;
    ball.flightDistance = dist; // ball stops at target if uncaught

    ball.cooldownBonus = 0;
    ball.chargeTimer = 0;
  }

  /// Reset the ball to the midfield start state — used at the top of each act.
  static void resetForAct(GameState gs) {
    final ball = gs.ball;
    ball.x = 70;
    ball.y = 20;
    ball.velX = 0;
    ball.velY = 0;
    ball.holderId = null;
    ball.isInFlight = false;
    ball.isChargedThrow = false;
    ball.zHeight = 0;
    ball.zVelocity = 0;
    ball.chargeTimer = 0;
    ball.cooldownBonus = 0;
    ball.flightDistance = 0;
    ball.resetPhaseLines();
    ball.possessingTeamId = null;
  }

  static void _resetAfterScore(GameState gs) => resetForAct(gs);
}
