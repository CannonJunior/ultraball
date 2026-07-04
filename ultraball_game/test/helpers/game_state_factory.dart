import 'package:ultraball_game/game/game_state.dart';
import 'package:ultraball_game/models/player.dart';
import 'package:ultraball_game/models/game_settings.dart';
import 'package:ultraball_game/models/creature.dart';

GameSettings _testSettings() => GameSettings(
      homeTeamName: 'HOME',
      awayTeamName: 'AWAY',
      creatureType: CreatureType.kraken,
      fastMode: true,
    );

UltraballPlayer makePlayer({
  String id = 'p1',
  String name = 'Test',
  Team team = Team.player,
  double x = 70.0,
  double y = 20.0,
  PlayerClass playerClass = PlayerClass.runner,
  bool isOnField = true,
}) {
  final p = UltraballPlayer(
    id: id,
    name: name,
    team: team,
    rosterIndex: 0,
    x: x,
    y: y,
  );
  p.playerClass = playerClass;
  p.baseSpeed = playerClass.baseSpeed;
  p.maxHealth = playerClass.maxHealth;
  p.health = playerClass.maxHealth;
  p.isOnField = isOnField;
  return p;
}

/// Minimal GameState with 2 players per team for unit tests.
/// Terrain defaults to flat (height=0 everywhere) — no high-ground bonus.
GameState makeGs({
  List<UltraballPlayer>? players,
  List<UltraballPlayer>? opponents,
}) {
  return GameState.forTesting(
    testSettings: _testSettings(),
    players: players ??
        [
          makePlayer(id: 'p1', team: Team.player, x: 70, y: 20),
          makePlayer(id: 'p2', team: Team.player, x: 72, y: 20),
        ],
    opponents: opponents ??
        [
          makePlayer(id: 'o1', team: Team.opponent, x: 50, y: 20),
          makePlayer(id: 'o2', team: Team.opponent, x: 52, y: 20),
        ],
  );
}
