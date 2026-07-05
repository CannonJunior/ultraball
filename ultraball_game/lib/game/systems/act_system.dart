import 'dart:math' as math;
import '../../models/player.dart';
import '../../models/act_state.dart';
import '../game_state.dart';
import 'ball_system.dart';

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

  static void scoreUltra(GameState gs, String teamId, [UltraballPlayer? scorer]) {
    gs.dataCollector?.onUltra(teamId);
    scorer?.pointsThisMatch += 7;
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

  static void scoreMeta(GameState gs, String teamId, [UltraballPlayer? scorer]) {
    gs.dataCollector?.onMeta(teamId);
    scorer?.pointsThisMatch += 3;
    if (teamId == 'player') {
      gs.actState.playerScore += 3;
      gs.showEvent('META! +3pts for ${gs.settings.homeTeamName}!');
    } else {
      gs.actState.opponentScore += 3;
      gs.showEvent('META! +3pts for ${gs.settings.awayTeamName}!');
    }
  }

  /// Handles forfeit/sub logic when a player dies — extracted from CombatSystem
  /// so that act-state mutations are owned by ActSystem.
  static void notifyPlayerDeath(GameState gs, UltraballPlayer victim) {
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

  static void scoreKilla(GameState gs, String teamId, [UltraballPlayer? scorer]) {
    gs.dataCollector?.onKilla(teamId);
    scorer?.gainUltraMana(1.0);
    scorer?.killsThisMatch += 1;
    scorer?.pointsThisMatch += 1;
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
    gs.dataCollector?.onActEnd(act.currentAct);
    if (act.actEnded) return;

    act.actEnded = true;
    act.isActive = false;

    // Award 5 ultra mana to field players on the act-winning team
    final prevPlayerScore = act.actResults.isNotEmpty ? act.actResults.last.playerScore : 0;
    final prevOppScore    = act.actResults.isNotEmpty ? act.actResults.last.opponentScore : 0;
    final actPlayerPts = act.playerScore - prevPlayerScore;
    final actOppPts    = act.opponentScore - prevOppScore;
    if (actPlayerPts > actOppPts) {
      for (final p in gs.fieldPlayers) {
        if (p.team == Team.player && p.isAlive) p.gainUltraMana(5.0);
      }
    } else if (actOppPts > actPlayerPts) {
      for (final p in gs.fieldPlayers) {
        if (p.team == Team.opponent && p.isAlive) p.gainUltraMana(5.0);
      }
    }

    act.actResults.add(
      ActResult(act.currentAct, act.playerScore, act.opponentScore),
    );

    if (act.currentAct >= 5 || act.gameOver) {
      // Game over
      gs.showEvent('GAME OVER!');
      return;
    }

    gs.showingRosterScreen = true;
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

    // Player team: roster was configured by roster screen; just fill any gaps
    _fillPlayerTeamGaps(gs);
    // AI team: auto-restock in deployment order
    _restockTeam(gs, Team.opponent);

    // Reset positions
    _resetPositions(gs);

    // Reset ball
    BallSystem.resetForAct(gs);

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
      final available = roster.where((p) => !p.isOnField && p.isAlive).toList()
          ..sort((a, b) => a.deploySlot.compareTo(b.deploySlot));
      final toAdd = math.min(needed, available.length);
      for (int i = 0; i < toAdd; i++) {
        available[i].isOnField = true;
      }
      gs.markRosterDirty();
    }

    // Reset health of surviving field players (preserve ultra mana across acts)
    for (final p in roster.where((p) => p.isOnField && p.isAlive)) {
      p.health = p.maxHealth;
      p.blueMana = 100;
      p.redMana = 0;
      p.stunTimer = 0;
      p.state = PlayerState.idle;
      p.resetBuffs();
    }
  }

  static void _fillPlayerTeamGaps(GameState gs) {
    final roster = gs.playerRoster;
    final onField = roster.where((p) => p.isOnField && p.isAlive).length;
    if (onField < 7) {
      final available = roster.where((p) => !p.isOnField && p.isAlive).toList()
          ..sort((a, b) => a.deploySlot.compareTo(b.deploySlot));
      final toAdd = math.min(7 - onField, available.length);
      for (int i = 0; i < toAdd; i++) {
        available[i].isOnField = true;
      }
      gs.markRosterDirty();
    }
    for (final p in roster.where((p) => p.isOnField && p.isAlive)) {
      p.health = p.maxHealth;
      p.blueMana = 100;
      p.redMana = 0;
      p.stunTimer = 0;
      p.state = PlayerState.idle;
      p.resetBuffs();
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
