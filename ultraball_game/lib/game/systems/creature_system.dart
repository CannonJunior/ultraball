import 'dart:math' as math;
import '../../models/player.dart';
import '../../models/damage_indicator.dart';
import '../game_state.dart';
import 'combat_system.dart';
import 'act_system.dart';

class CreatureSystem {
  static void update(GameState gs, double dt) {
    gs.creature.update(dt);
    checkKills(gs);
  }

  static void checkKills(GameState gs) {
    final creature = gs.creature;

    for (final p in gs.fieldPlayers.toList()) {
      if (!p.isAlive) continue;

      final dx = p.x - creature.x;
      final dy = p.y - creature.y;
      final dist = math.sqrt(dx * dx + dy * dy);

      if (dist < creature.size) {
        // Creature kills this player
        final hadBall = gs.ball.holderId == p.id;
        p.die();
        gs.markRosterDirty();
        final victimTeamId = p.team == Team.player ? 'player' : 'opponent';
        gs.dataCollector?.onCreatureKill(victimTeamId);

        CombatSystem.addIndicator(
          gs,
          p.x,
          p.y,
          'DEAD',
          IndicatorType.kill,
        );

        // Award killa to opposite team
        final killaTeam = p.team == Team.player ? 'opponent' : 'player';
        ActSystem.scoreKilla(gs, killaTeam);
        gs.showEvent('${creature.name} KILLED ${p.name}! KILLA!');

        // Drop ball if this player had it
        if (hadBall) {
          gs.ball.holderId = null;
          gs.ball.isInFlight = false;
          gs.ball.velX = 0;
          gs.ball.velY = 0;
        }

        // Update selected player if needed
        if (gs.selectedPlayer?.id == p.id) {
          gs.selectNextPlayer();
        }

        // Handle substitution
        CombatSystem.handlePlayerDeath(gs, p);
      }
    }
  }
}
