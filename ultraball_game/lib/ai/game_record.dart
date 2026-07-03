import 'ai_strategy.dart';

/// A single timestamped gameplay event emitted by the data collector.
class GameEvent {
  final double timestamp;
  final GameEventType type;
  final Map<String, dynamic> data;

  const GameEvent({
    required this.timestamp,
    required this.type,
    required this.data,
  });

  Map<String, dynamic> toJson() => {
    'ts':   timestamp,
    'type': type.name,
    'data': data,
  };
}

enum GameEventType {
  ultra,       // Ball carrier crossed the goal line (7 pts)
  meta,        // Pass caught in endzone (3 pts)
  killa,       // A player was killed
  creatureKill,// Creature killed a player
  tackle,      // A tackle landed
  slam,        // A power-slam landed
  pass,        // A pass was thrown
  pickup,      // Ball picked up
  explosion,   // Ball exploded (holder died)
  actEnd,      // An act ended
}

/// Summary statistics extracted from a game for reward computation.
class GameStats {
  final int aiUltras;
  final int playerUltras;
  final int aiMetas;
  final int playerMetas;
  final int aiKillas;
  final int playerKillas;
  final int aiCreatureKills;   // creature killed a player-team player (ai benefits)
  final int playerCreatureKills; // creature killed an ai-team player (player benefits)
  final int aiPasses;
  final int aiExplosions;      // ai ball carrier exploded (bad)
  final int playerExplosions;  // player ball carrier exploded (good for ai)
  final int aiTackles;
  final int aiSlams;
  final int aiFinalScore;
  final int playerFinalScore;
  final bool aiWon;
  final bool forfeitWin;       // true if win came from roster elimination

  const GameStats({
    required this.aiUltras,
    required this.playerUltras,
    required this.aiMetas,
    required this.playerMetas,
    required this.aiKillas,
    required this.playerKillas,
    required this.aiCreatureKills,
    required this.playerCreatureKills,
    required this.aiPasses,
    required this.aiExplosions,
    required this.playerExplosions,
    required this.aiTackles,
    required this.aiSlams,
    required this.aiFinalScore,
    required this.playerFinalScore,
    required this.aiWon,
    required this.forfeitWin,
  });

  Map<String, dynamic> toJson() => {
    'aiUltras':          aiUltras,
    'playerUltras':      playerUltras,
    'aiMetas':           aiMetas,
    'playerMetas':       playerMetas,
    'aiKillas':          aiKillas,
    'playerKillas':      playerKillas,
    'aiCreatureKills':   aiCreatureKills,
    'playerCreatureKills': playerCreatureKills,
    'aiPasses':          aiPasses,
    'aiExplosions':      aiExplosions,
    'playerExplosions':  playerExplosions,
    'aiTackles':         aiTackles,
    'aiSlams':           aiSlams,
    'aiFinalScore':      aiFinalScore,
    'playerFinalScore':  playerFinalScore,
    'aiWon':             aiWon,
    'forfeitWin':        forfeitWin,
  };
}

/// A complete record of one game, ready for reward computation and storage.
class GameRecord {
  final AiStrategy strategy;
  final AiTactics  tactics;
  final DateTime   startedAt;
  final List<GameEvent> events;
  GameStats? stats; // populated at game end

  GameRecord({
    required this.strategy,
    required this.tactics,
    required this.startedAt,
    List<GameEvent>? events,
  }) : events = events ?? [];

  Map<String, dynamic> toJson() => {
    'strategy':  strategy.name,
    'tactics':   tactics.name,
    'startedAt': startedAt.toIso8601String(),
    'events':    events.map((e) => e.toJson()).toList(),
    'stats':     stats?.toJson(),
  };
}
