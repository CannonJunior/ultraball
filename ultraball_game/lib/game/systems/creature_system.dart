import '../../models/player.dart';
import '../../models/creature.dart';
import '../../models/damage_indicator.dart';
import '../game_state.dart';
import 'combat_system.dart';
import 'act_system.dart';

class CreatureSystem {
  static void update(GameState gs, double dt) {
    gs.creature.update(dt);
    gs.creature2?.update(dt);
    checkKills(gs);
  }

  static void checkKills(GameState gs) {
    _checkCreatureKills(gs, gs.creature);
    if (gs.creature2 != null) _checkCreatureKills(gs, gs.creature2!);
  }

  static void _checkCreatureKills(GameState gs, Creature creature) {
    for (final p in gs.fieldPlayers) {
      if (!p.isAlive) continue;

      final dx = p.x - creature.x;
      final dy = p.y - creature.y;

      if (dx * dx + dy * dy < creature.size * creature.size) {
        // Creature kills this player
        final hadBall = gs.ball.holderId == p.id;
        p.die();
        gs.markRosterDirty();
        final victimTeamId = p.team == Team.player ? 'player'
            : p.team == Team.opponent ? 'opponent' : 'third';
        gs.dataCollector?.onCreatureKill(victimTeamId);

        CombatSystem.addIndicator(
          gs,
          p.x,
          p.y,
          'DEAD',
          IndicatorType.kill,
        );

        // Award killa to opposite team
        final killaTeam = p.team == Team.player ? 'opponent'
            : p.team == Team.opponent ? 'player' : 'player';
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
