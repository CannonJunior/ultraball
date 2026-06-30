import 'dart:math' as math;
import '../../models/player.dart';
import '../../models/act_state.dart';
import '../game_state.dart';

class ActSystem {
  static void update(GameState gs, double dt) {
    final act = gs.actState;

    // Act transition timer must run even while the act is marked ended,
    // so process it before the early-return guard below.
    if (gs.showingActTransition) {
      gs.actTransitionTimer -= dt;
      if (gs.actTransitionTimer <= 0) {
        gs.showingActTransition = false;
        _doStartNextAct(gs);
      }
      return;
    }

    if (!act.isActive || act.actEnded || act.gameOver || gs.paused) return;

    // Tick timer for acts 1-4
    if (!act.isAct5) {
      act.timerSeconds -= dt;
      if (act.timerSeconds <= 0) {
        act.timerSeconds = 0;
        endAct(gs);
      }
    }
    // Act 5 ends via scoreUltra check

    // Update event timer
    if (gs.lastEventTimer > 0) {
      gs.lastEventTimer -= dt;
      if (gs.lastEventTimer <= 0) {
        gs.lastEventMessage = null;
        gs.lastEventTimer = 0;
      }
    }

    // Update combo timer
    if (gs.comboMessageTimer > 0) {
      gs.comboMessageTimer -= dt;
      if (gs.comboMessageTimer <= 0) {
        gs.comboMessage = null;
        gs.comboMessageTimer = 0;
      }
    }
  }

  static void scoreUltra(GameState gs, String teamId) {
    final act = gs.actState;
    if (teamId == 'player') {
      act.playerScore += 7;
      gs.showEvent('ULTRA! +7pts for ${gs.settings.homeTeamName}!');
    } else {
      act.opponentScore += 7;
      gs.showEvent('ULTRA! +7pts for ${gs.settings.awayTeamName}!');
    }

    // Check Act 5 end condition
    if (act.isAct5) {
      bool actEnds = false;

      if (act.act5LeadingTeam == 'tied') {
        // Any ultra ends it
        actEnds = true;
      } else if (act.act5LeadingTeam == 'player') {
        // Leading team (player) scores Ultra, or trailing team comes back
        if (teamId == 'player' && act.playerScore >= act.act5UltraTarget) {
          actEnds = true;
        } else if (teamId == 'opponent' && act.opponentScore > act.playerScore) {
          actEnds = true;
        }
      } else {
        // Leading team (opponent) scores Ultra, or trailing team comes back
        if (teamId == 'opponent' && act.opponentScore >= act.act5UltraTarget) {
          actEnds = true;
        } else if (teamId == 'player' && act.playerScore > act.opponentScore) {
          actEnds = true;
        }
      }

      if (actEnds) {
        endAct(gs);
      }
    }
  }

  static void scoreMeta(GameState gs, String teamId) {
    if (teamId == 'player') {
      gs.actState.playerScore += 3;
      gs.showEvent('META! +3pts for ${gs.settings.homeTeamName}!');
    } else {
      gs.actState.opponentScore += 3;
      gs.showEvent('META! +3pts for ${gs.settings.awayTeamName}!');
    }
  }

  static void scoreKilla(GameState gs, String teamId) {
    if (teamId == 'player') {
      gs.actState.playerScore += 1;
      gs.actState.playerKills += 1;
    } else {
      gs.actState.opponentScore += 1;
      gs.actState.opponentKills += 1;
    }
  }

  static void endAct(GameState gs) {
    final act = gs.actState;
    if (act.actEnded) return;

    act.actEnded = true;
    act.isActive = false;

    act.actResults.add(
      ActResult(act.currentAct, act.playerScore, act.opponentScore),
    );

    if (act.currentAct >= 5 || act.gameOver) {
      // Game over
      gs.showEvent('GAME OVER!');
      return;
    }

    // Show transition
    gs.showingActTransition = true;
    gs.actTransitionTimer = 3.0;
    gs.actTransitionMessage = 'ACT ${act.currentAct} COMPLETE!\nACT ${act.currentAct + 1} BEGINS!';
    gs.showEvent('ACT ${act.currentAct} COMPLETE!');
  }

  static void startNextAct(GameState gs) {
    final act = gs.actState;
    act.currentAct++;
    act.actEnded = false;
    act.isActive = true;
    act.playerSubUsed = false;
    act.opponentSubUsed = false;

    if (act.isAct5) {
      act.startAct5();
      act.timerSeconds = double.infinity;
    } else {
      act.timerSeconds = gs.settings.fastMode ? 60.0 : 180.0;
    }

    // Restock teams to 7 on field (bring in live roster players)
    _restockTeam(gs, Team.player);
    _restockTeam(gs, Team.opponent);

    // Reset positions
    _resetPositions(gs);

    // Reset ball
    gs.ball.x = 70;
    gs.ball.y = 20;
    gs.ball.velX = 0;
    gs.ball.velY = 0;
    gs.ball.holderId = null;
    gs.ball.isInFlight = false;
    gs.ball.chargeTimer = 0;
    gs.ball.cooldownBonus = 0;
    gs.ball.resetPhaseLines();
    gs.ball.possessingTeamId = null;

    gs.showEvent('ACT ${act.currentAct} BEGIN!');
  }

  static void _doStartNextAct(GameState gs) {
    startNextAct(gs);
  }

  static void _restockTeam(GameState gs, Team team) {
    final roster = gs.getTeamRoster(team);
    final onField = roster.where((p) => p.isOnField && p.isAlive).length;
    int needed = 7 - onField;

    if (needed > 0) {
      final available = roster.where((p) => !p.isOnField && p.isAlive).toList();
      final toAdd = math.min(needed, available.length);
      for (int i = 0; i < toAdd; i++) {
        available[i].isOnField = true;
      }
    }

    // Reset health of surviving field players
    for (final p in roster.where((p) => p.isOnField && p.isAlive)) {
      p.health = p.maxHealth;
      p.blueMana = 100;
      p.redMana = 0;
      p.stunTimer = 0;
      p.state = PlayerState.idle;
    }
  }

  static void _resetPositions(GameState gs) {
    final rand = math.Random();
    int playerIdx = 0;
    int oppIdx = 0;

    for (final p in gs.playerRoster.where((p) => p.isOnField && p.isAlive)) {
      p.x = 80.0 + (playerIdx % 4) * 6.0;
      p.y = 8.0 + (playerIdx ~/ 4) * 12.0 + rand.nextDouble() * 4.0;
      p.velX = 0;
      p.velY = 0;
      playerIdx++;
    }

    for (final p in gs.opponentRoster.where((p) => p.isOnField && p.isAlive)) {
      p.x = 40.0 + (oppIdx % 4) * 6.0;
      p.y = 8.0 + (oppIdx ~/ 4) * 12.0 + rand.nextDouble() * 4.0;
      p.velX = 0;
      p.velY = 0;
      oppIdx++;
    }

    // Ensure selected player is still valid
    if (gs.selectedPlayer == null ||
        !gs.selectedPlayer!.isAlive ||
        !gs.selectedPlayer!.isOnField) {
      gs.selectedPlayer?.isSelected = false;
      final alive = gs.playerRoster
          .where((p) => p.isAlive && p.isOnField)
          .toList();
      if (alive.isNotEmpty) {
        gs.selectedPlayer = alive.first;
        gs.selectedPlayer!.isSelected = true;
      }
    }
  }
}
