import 'dart:math' as math;
import '../../models/terrain_grid.dart';
import '../../models/terrain_event.dart';
import '../../models/fissure_event.dart';
import '../../models/damage_indicator.dart';
import '../../models/player.dart';
import '../game_state.dart';
import 'ball_system.dart';
import 'combat_system.dart';
import 'act_system.dart';

class TerrainSystem {
  static void update(GameState gs, double dt) {
    gs.elevGrid.tick(dt);
    _tickCells(gs, dt);
    _tickPitEffects(gs, dt);
    _applyTerrainEffectsToPlayers(gs, dt);
  }

  static void _tickPitEffects(GameState gs, double dt) {
    for (final pit in gs.pitEffects) pit.age += dt;
    gs.pitEffects.removeWhere((p) => p.isDone);
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
      // Terrain elevation from fine grid (positive = hill, negative = valley)
      p.terrainElevation = gs.elevGrid.heightAt(p.x, p.y);
      if (!p.isAirborne && p.terrainElevation > 0.5) {
        p.terrainSpeedMult *= math.max(0.5, 1.0 - p.terrainElevation * 0.08);
      }
      if (!p.isAirborne && p.terrainElevation < -0.5) {
        p.terrainSpeedMult *= math.max(0.4, 1.0 + p.terrainElevation * 0.1);
      }

      // Pit: instant death unless a hill is present (elevation >= 1m lifts player over gap)
      if (cell.isPit && p.terrainElevation < 1.0) {
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
        final maxH      = event.intensity * 4.0;
        final plateauR  = event.radius * event.plateauFrac;
        final slopeSpan = event.radius - plateauR;
        final noiseAmp  = maxH * 0.15;
        final colMin = ((event.worldX - event.radius) / kElevCellW).floor().clamp(0, kElevCols - 1);
        final colMax = ((event.worldX + event.radius) / kElevCellW).floor().clamp(0, kElevCols - 1);
        final rowMin = ((event.worldY - event.radius) / kElevCellH).floor().clamp(0, kElevRows - 1);
        final rowMax = ((event.worldY + event.radius) / kElevCellH).floor().clamp(0, kElevRows - 1);
        for (int col = colMin; col <= colMax; col++) {
          for (int row = rowMin; row <= rowMax; row++) {
            final cellCx = (col + 0.5) * kElevCellW;
            final cellCy = (row + 0.5) * kElevCellH;
            final dx = cellCx - event.worldX;
            final dy = cellCy - event.worldY;
            final d  = math.sqrt(dx * dx + dy * dy);
            if (d > event.radius) continue;
            final h = d <= plateauR
                ? maxH
                : maxH * (1.0 - (d - plateauR) / slopeSpan);
            // Per-cell hash noise for natural variation (breaks up uniform rings)
            final hash = ((col * 1013904223) ^ (row * 1664525)) & 0x7FFFFFFF;
            final noise = ((hash % 10000) / 10000.0 * 2.0 - 1.0) * noiseAmp;
            final ec = gs.elevGrid.cells[col][row];
            ec.target  = (h + noise).clamp(0.0, maxH);
            ec.current = ec.target * 0.5;
            ec.timer   = event.duration;
          }
        }

      case TerrainEventType.openPit:
        for (final cell in gs.terrain.cellsInRadius(event.worldX, event.worldY, event.radius)) {
          cell.isPit        = true;
          cell.height       = -2.0;
          cell.targetHeight = -3.0;
          cell.hazardTimer  = event.duration;
          cell.lerpSpeed    = 5.0;
        }
        gs.pitEffects.add(PitEffect(
          worldX: event.worldX, worldY: event.worldY,
          radius: event.radius, duration: event.duration,
        ));

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
        final maxDepth  = -event.intensity * 4.0; // negative
        final plateauR  = event.radius * event.plateauFrac;
        final slopeSpan = event.radius - plateauR;
        final noiseAmp  = maxDepth.abs() * 0.15;
        final colMinV = ((event.worldX - event.radius) / kElevCellW).floor().clamp(0, kElevCols - 1);
        final colMaxV = ((event.worldX + event.radius) / kElevCellW).floor().clamp(0, kElevCols - 1);
        final rowMinV = ((event.worldY - event.radius) / kElevCellH).floor().clamp(0, kElevRows - 1);
        final rowMaxV = ((event.worldY + event.radius) / kElevCellH).floor().clamp(0, kElevRows - 1);
        for (int col = colMinV; col <= colMaxV; col++) {
          for (int row = rowMinV; row <= rowMaxV; row++) {
            final cellCx = (col + 0.5) * kElevCellW;
            final cellCy = (row + 0.5) * kElevCellH;
            final dx = cellCx - event.worldX;
            final dy = cellCy - event.worldY;
            final d  = math.sqrt(dx * dx + dy * dy);
            if (d > event.radius) continue;
            final h = d <= plateauR
                ? maxDepth
                : maxDepth * (1.0 - (d - plateauR) / slopeSpan);
            final hash = ((col * 1013904223) ^ (row * 1664525)) & 0x7FFFFFFF;
            final noise = ((hash % 10000) / 10000.0 * 2.0 - 1.0) * noiseAmp;
            final ec = gs.elevGrid.cells[col][row];
            ec.target  = (h + noise).clamp(maxDepth, 0.0);
            ec.current = ec.target * 0.5;
            ec.timer   = event.duration;
          }
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
