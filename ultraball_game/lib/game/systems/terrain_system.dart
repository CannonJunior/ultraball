import 'dart:math' as math;
import '../../models/terrain_grid.dart';
import '../../models/terrain_event.dart';
import '../../models/damage_indicator.dart';
import '../../models/player.dart';
import '../game_state.dart';
import 'ball_system.dart';
import 'combat_system.dart';
import 'act_system.dart';

class TerrainSystem {
  static void update(GameState gs, double dt) {
    _tickCells(gs, dt);
    _applyTerrainEffectsToPlayers(gs, dt);
  }

  static void _tickCells(GameState gs, double dt) {
    gs.terrain.forEach((_, __, cell) {
      if ((cell.height - cell.targetHeight).abs() > 0.001) {
        cell.height += (cell.targetHeight - cell.height) * (cell.lerpSpeed * dt).clamp(0.0, 1.0);
      } else {
        cell.height = cell.targetHeight;
      }
      if (cell.hazardTimer > 0) {
        cell.hazardTimer -= dt;
        if (cell.hazardTimer <= 0) cell.reset();
      }
    });
  }

  static void _applyTerrainEffectsToPlayers(GameState gs, double dt) {
    for (final p in gs.fieldPlayers) {
      if (!p.isAlive) continue;
      if (p.isAirborne) { p.terrainSpeedMult = 1.0; continue; }
      final cell = gs.terrain.cellAt(p.x, p.y);
      p.terrainSpeedMult = cell.speedMult;

      // Pit: instant death for non-creature players
      if (cell.isPit) {
        p.health = 0;
        p.isAlive = false;
        p.isOnField = false;
        gs.markRosterDirty();
        CombatSystem.addIndicator(gs, p.x, p.y - 1, 'FELL IN!', IndicatorType.kill);
        if (gs.ball.holderId == p.id) BallSystem.dropBall(gs);
        if (gs.selectedPlayer?.id == p.id) gs.selectNextPlayer();
        final killaTeam = p.team == Team.player ? 'opponent'
            : p.team == Team.opponent ? 'player' : 'opponent';
        ActSystem.scoreKilla(gs, killaTeam);
        CombatSystem.handlePlayerDeath(gs, p);
        continue;
      }

      // Hazard DoT
      if (cell.hazardDps > 0) {
        final dmg = cell.hazardDps * dt;
        p.health -= dmg;
        if (p.health <= 0) {
          p.die();
          gs.markRosterDirty();
          CombatSystem.addIndicator(gs, p.x, p.y, 'DEAD', IndicatorType.kill);
          if (gs.ball.holderId == p.id) BallSystem.dropBall(gs);
          if (gs.selectedPlayer?.id == p.id) gs.selectNextPlayer();
          final killaTeam = p.team == Team.player ? 'opponent'
              : p.team == Team.opponent ? 'player' : 'opponent';
          ActSystem.scoreKilla(gs, killaTeam);
          CombatSystem.handlePlayerDeath(gs, p);
        }
      }
    }
  }

  static void applyEvent(GameState gs, TerrainEvent event) {
    switch (event.type) {
      case TerrainEventType.riseMountain:
        for (final cell in gs.terrain.cellsInRadius(event.worldX, event.worldY, event.radius)) {
          cell.targetHeight = event.intensity * 4.0;
          cell.hazardTimer  = event.duration;
          cell.lerpSpeed    = 3.0;
        }

      case TerrainEventType.openPit:
        for (final cell in gs.terrain.cellsInRadius(event.worldX, event.worldY, event.radius)) {
          cell.isPit        = true;
          cell.targetHeight = -3.0;
          cell.hazardTimer  = event.duration;
          cell.lerpSpeed    = 5.0;
        }

      case TerrainEventType.closePit:
        for (final cell in gs.terrain.cellsInRadius(event.worldX, event.worldY, event.radius)) {
          if (cell.isPit) {
            cell.isPit        = false;
            cell.targetHeight = 0.0;
            cell.hazardTimer  = 0.0;
            cell.lerpSpeed    = 2.0;
          }
        }

      case TerrainEventType.flatten:
      case TerrainEventType.normalize:
        for (final cell in gs.terrain.cellsInRadius(event.worldX, event.worldY, event.radius)) {
          cell.reset();
        }

      case TerrainEventType.sinkValley:
        for (final cell in gs.terrain.cellsInRadius(event.worldX, event.worldY, event.radius)) {
          cell.targetHeight = -event.intensity * 2.0;
          cell.hazardTimer  = event.duration;
          cell.lerpSpeed    = 2.0;
        }

      case TerrainEventType.lavaPool:
        for (final cell in gs.terrain.cellsInRadius(event.worldX, event.worldY, event.radius)) {
          cell.surface     = SurfaceType.lava;
          cell.hazard      = HazardType.fire;
          cell.hazardDps   = 15.0 * event.intensity;
          cell.hazardTimer = event.duration;
        }

      case TerrainEventType.icePatch:
        for (final cell in gs.terrain.cellsInRadius(event.worldX, event.worldY, event.radius)) {
          cell.surface     = SurfaceType.ice;
          cell.speedMult   = 1.8;
          cell.hazardTimer = event.duration;
        }

      case TerrainEventType.mudZone:
        for (final cell in gs.terrain.cellsInRadius(event.worldX, event.worldY, event.radius)) {
          cell.surface     = SurfaceType.mud;
          cell.speedMult   = 0.45;
          cell.hazardTimer = event.duration;
        }

      case TerrainEventType.shockwave:
        // Radial push of all units in range — applied immediately
        for (final p in gs.fieldPlayers) {
          if (!p.isAlive) continue;
          final dx = p.x - event.worldX;
          final dy = p.y - event.worldY;
          final dist = math.sqrt(dx * dx + dy * dy);
          if (dist < event.radius && dist > 0) {
            final force = (1.0 - dist / event.radius) * event.intensity * 8.0;
            p.x = (p.x + (dx / dist) * force).clamp(0.0, p.maxFieldX);
            p.y = (p.y + (dy / dist) * force).clamp(0.0, p.maxFieldY);
          }
        }

      // Other event types are stubs (Phase 5+)
      default:
        break;
    }
  }
}
