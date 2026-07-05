import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../game/game_state.dart';
import 'ai_strategy.dart';
import 'game_data_sink.dart';
import 'game_record.dart';

/// Collects gameplay events into a [GameRecord] and persists experience
/// to browser localStorage after each game.
class GameDataCollector implements GameDataSink {
  final GameRecord record;
  double _clock = 0.0;

  // Counters used to build GameStats at game end
  int _aiUltras = 0, _playerUltras = 0;
  int _aiMetas = 0, _playerMetas = 0;
  int _aiKillas = 0, _playerKillas = 0;
  int _aiCreatureKills = 0, _playerCreatureKills = 0;
  int _aiPasses = 0;
  int _aiExplosions = 0, _playerExplosions = 0;
  int _aiTackles = 0, _aiSlams = 0;

  GameDataCollector({
    required AiStrategy strategy,
    required AiTactics tactics,
  }) : record = GameRecord(
          strategy: strategy,
          tactics: tactics,
          startedAt: DateTime.now(),
        );

  @override
  void tick(double dt) => _clock += dt;

  void _emit(GameEventType type, Map<String, dynamic> data) {
    record.events.add(GameEvent(timestamp: _clock, type: type, data: data));
  }

  // ---- Event sinks (called from game systems) ----

  @override
  void onUltra(String teamId) {
    if (teamId == 'opponent') {
      _aiUltras++;
    } else {
      _playerUltras++;
    }
    _emit(GameEventType.ultra, {'team': teamId});
  }

  @override
  void onMeta(String teamId) {
    if (teamId == 'opponent') {
      _aiMetas++;
    } else {
      _playerMetas++;
    }
    _emit(GameEventType.meta, {'team': teamId});
  }

  @override
  void onKilla(String killingTeamId) {
    if (killingTeamId == 'opponent') {
      _aiKillas++;
    } else {
      _playerKillas++;
    }
    _emit(GameEventType.killa, {'killingTeam': killingTeamId});
  }

  @override
  void onCreatureKill(String victimTeamId) {
    // Creature kill benefits the opposing team
    if (victimTeamId == 'player') {
      _aiCreatureKills++;
    } else {
      _playerCreatureKills++;
    }
    _emit(GameEventType.creatureKill, {'victimTeam': victimTeamId});
  }

  @override
  void onPass(String teamId) {
    if (teamId == 'opponent') _aiPasses++;
    _emit(GameEventType.pass, {'team': teamId});
  }

  @override
  void onTackle(String teamId) {
    if (teamId == 'opponent') _aiTackles++;
    _emit(GameEventType.tackle, {'team': teamId});
  }

  @override
  void onSlam(String teamId) {
    if (teamId == 'opponent') _aiSlams++;
    _emit(GameEventType.slam, {'team': teamId});
  }

  @override
  void onExplosion(String holderTeamId) {
    if (holderTeamId == 'opponent') {
      _aiExplosions++;
    } else {
      _playerExplosions++;
    }
    _emit(GameEventType.explosion, {'holderTeam': holderTeamId});
  }

  @override
  void onActEnd(int actNumber) {
    _emit(GameEventType.actEnd, {'act': actNumber});
  }

  /// Called when the match is over. Finalises the record, saves to
  /// localStorage, and returns the completed [GameRecord].
  GameRecord finalise(GameState gs) {
    final actState = gs.actState;
    final aiScore     = actState.opponentScore;
    final playerScore = actState.playerScore;
    final aiWon       = aiScore > playerScore ||
                        actState.playerForfeit;
    final forfeitWin  = actState.playerForfeit;

    record.stats = GameStats(
      aiUltras:           _aiUltras,
      playerUltras:       _playerUltras,
      aiMetas:            _aiMetas,
      playerMetas:        _playerMetas,
      aiKillas:           _aiKillas,
      playerKillas:       _playerKillas,
      aiCreatureKills:    _aiCreatureKills,
      playerCreatureKills: _playerCreatureKills,
      aiPasses:           _aiPasses,
      aiExplosions:       _aiExplosions,
      playerExplosions:   _playerExplosions,
      aiTackles:          _aiTackles,
      aiSlams:            _aiSlams,
      aiFinalScore:       aiScore,
      playerFinalScore:   playerScore,
      aiWon:              aiWon,
      forfeitWin:         forfeitWin,
    );

    _persist(record);
    return record;
  }

  // ---- LocalStorage persistence ----

  static const _storageKey = 'ultraball_game_history';
  static const _maxRecords = 100;

  static void _persist(GameRecord record) {
    try {
      final raw  = html.window.localStorage[_storageKey];
      final List<dynamic> history =
          raw != null ? jsonDecode(raw) as List<dynamic> : [];
      history.add(record.toJson());
      // Keep only the most recent N records
      final trimmed = history.length > _maxRecords
          ? history.sublist(history.length - _maxRecords)
          : history;
      html.window.localStorage[_storageKey] = jsonEncode(trimmed);
    } catch (_) {
      // localStorage unavailable (e.g. in unit tests) — silently skip
    }
  }

  /// Load all saved game records from localStorage.
  static List<Map<String, dynamic>> loadHistory() {
    try {
      final raw = html.window.localStorage[_storageKey];
      if (raw == null) return [];
      return (jsonDecode(raw) as List<dynamic>)
          .cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Export all saved records as a JSON blob download.
  static void downloadHistory() {
    try {
      final raw = html.window.localStorage[_storageKey] ?? '[]';
      final blob = html.Blob([raw], 'application/json');
      final url  = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', 'ultraball_game_data.json')
        ..click();
      html.Url.revokeObjectUrl(url);
    } catch (_) {}
  }
}
