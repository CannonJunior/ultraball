import 'dart:math' as math;
import 'package:flutter/services.dart';
import '../models/player.dart';
import '../models/ultraball.dart';
import '../models/creature.dart';
import '../models/act_state.dart';
import '../models/damage_indicator.dart';
import '../models/game_settings.dart';
import '../ai/ai_policy.dart';
import '../ai/game_data_collector.dart';

class GameState {
  final GameSettings settings;

  // All players: indices 0-6 = player team on-field, 7-13 = opponent team on-field
  // Plus roster: 7-14 (player) and 7-14 (opponent) stored separately
  List<UltraballPlayer> playerRoster = []; // 15 players for human team
  List<UltraballPlayer> opponentRoster = []; // 15 players for AI team

  // O(1) player lookup by id — built once in initialize(), never changes
  final Map<String, UltraballPlayer> _playerById = {};

  // Cached filtered lists — rebuilt lazily when _rosterDirty is set
  List<UltraballPlayer> _cachedFieldPlayers = [];
  List<UltraballPlayer> _cachedPlayerTeamOnField = [];
  List<UltraballPlayer> _cachedOpponentTeamOnField = [];
  int _playerDeadCount = 0;
  int _opponentDeadCount = 0;
  bool _rosterDirty = true;

  late Ultraball ball;
  late Creature creature;
  ActState actState = ActState();
  List<DamageIndicator> indicators = [];

  UltraballPlayer? selectedPlayer;
  Set<LogicalKeyboardKey> pressedKeys = {};
  bool paused = false;
  bool gameStarted = false;
  AiPolicy? activePolicy;
  GameDataCollector? dataCollector;

  // Tab-targeting
  String? currentTargetId;      // id of targeted enemy (opponent player)

  String? lastEventMessage;
  double lastEventTimer = 0;

  // Combo display
  String? comboMessage;
  double comboMessageTimer = 0;

  // Pass targeting
  bool isAiming = false;

  // Act transition state
  bool showingActTransition = false;
  double actTransitionTimer = 0;
  String actTransitionMessage = '';
  bool showingRosterScreen = false;

  GameState({required this.settings});

  // ---- Roster cache management ----

  /// Call whenever isAlive or isOnField changes on any player.
  void markRosterDirty() => _rosterDirty = true;

  void _rebuildRosterCaches() {
    _cachedFieldPlayers = [
      for (final p in playerRoster) if (p.isOnField) p,
      for (final p in opponentRoster) if (p.isOnField) p,
    ];
    _cachedPlayerTeamOnField = [
      for (final p in _cachedFieldPlayers)
        if (p.team == Team.player && p.isAlive) p,
    ];
    _cachedOpponentTeamOnField = [
      for (final p in _cachedFieldPlayers)
        if (p.team == Team.opponent && p.isAlive) p,
    ];
    _playerDeadCount =
        playerRoster.fold(0, (s, p) => p.isAlive ? s : s + 1);
    _opponentDeadCount =
        opponentRoster.fold(0, (s, p) => p.isAlive ? s : s + 1);
    _rosterDirty = false;
  }

  // ---- Player list accessors (cached) ----

  List<UltraballPlayer> get fieldPlayers {
    if (_rosterDirty) _rebuildRosterCaches();
    return _cachedFieldPlayers;
  }

  /// All players in both rosters — use sparingly; prefer fieldPlayers.
  List<UltraballPlayer> get allPlayers =>
      [...playerRoster, ...opponentRoster];

  // ---- Roster count getters (used by UI, avoid 4× .where().length) ----

  int get playerAliveOnField {
    if (_rosterDirty) _rebuildRosterCaches();
    return _cachedPlayerTeamOnField.length;
  }

  int get playerDeadCount {
    if (_rosterDirty) _rebuildRosterCaches();
    return _playerDeadCount;
  }

  int get opponentAliveOnField {
    if (_rosterDirty) _rebuildRosterCaches();
    return _cachedOpponentTeamOnField.length;
  }

  int get opponentDeadCount {
    if (_rosterDirty) _rebuildRosterCaches();
    return _opponentDeadCount;
  }

  void initialize() {
    final rand = math.Random();

    // Create player roster (15 players, home team)
    playerRoster = [];
    final playerNames = settings.homePlayerNames;
    for (int i = 0; i < 15; i++) {
      final cls = const [
        PlayerClass.runner, PlayerClass.blitzer, PlayerClass.enforcer,
        PlayerClass.warden, PlayerClass.handler,
      ][i % 5];
      final startX = 80.0 + rand.nextDouble() * 20.0;
      final startY = 5.0 + rand.nextDouble() * 30.0;
      final p = UltraballPlayer(
        id: 'p_$i',
        name: playerNames[i],
        team: Team.player,
        rosterIndex: i,
        x: startX,
        y: startY,
      );
      p.playerClass = cls;
      p.baseSpeed = cls.baseSpeed;
      p.maxHealth = cls.maxHealth;
      p.health = cls.maxHealth;
      playerRoster.add(p);
    }

    // Create opponent roster (15 players, away team)
    opponentRoster = [];
    final opponentNames = settings.awayPlayerNames;
    for (int i = 0; i < 15; i++) {
      final cls = const [
        PlayerClass.runner, PlayerClass.blitzer, PlayerClass.enforcer,
        PlayerClass.warden, PlayerClass.handler,
      ][i % 5];
      final startX = 40.0 + rand.nextDouble() * 20.0;
      final startY = 5.0 + rand.nextDouble() * 30.0;
      final p = UltraballPlayer(
        id: 'o_$i',
        name: opponentNames[i],
        team: Team.opponent,
        rosterIndex: i,
        x: startX,
        y: startY,
      );
      p.playerClass = cls;
      p.baseSpeed = cls.baseSpeed;
      p.maxHealth = cls.maxHealth;
      p.health = cls.maxHealth;
      opponentRoster.add(p);
    }

    // Build O(1) player lookup map
    _playerById.clear();
    for (final p in playerRoster)  { _playerById[p.id] = p; }
    for (final p in opponentRoster) { _playerById[p.id] = p; }

    // Apply home roster order: first 7 slots go on field, rest are reserves
    for (int slot = 0; slot < 15; slot++) {
      final playerIdx = settings.homeRosterOrder[slot];
      playerRoster[playerIdx].deploySlot = slot;
      playerRoster[playerIdx].isOnField = slot < 7;
    }
    // Apply away roster order
    for (int slot = 0; slot < 15; slot++) {
      final oppIdx = settings.awayRosterOrder[slot];
      opponentRoster[oppIdx].deploySlot = slot;
      opponentRoster[oppIdx].isOnField = slot < 7;
    }

    // Select first player
    selectedPlayer = playerRoster[0];
    playerRoster[0].isSelected = true;
    playerRoster[0].isPlayerControlled = true;
    // Face right (toward opponents) at start
    playerRoster[0].facing = math.pi;

    // Create ball at midfield
    ball = Ultraball(x: 70, y: 20);

    // Create creature
    creature = Creature(type: settings.creatureType);

    // Start act
    actState.isActive = true;
    actState.actEnded = false;
    actState.timerSeconds = settings.fastMode ? 60.0 : 180.0;

    gameStarted = true;
    markRosterDirty();
  }

  void selectNextPlayer() {
    if (_rosterDirty) _rebuildRosterCaches();
    if (_cachedPlayerTeamOnField.isEmpty) {
      selectedPlayer?.isSelected = false;
      selectedPlayer?.isPlayerControlled = false;
      selectedPlayer = null;
      return;
    }

    final currentIndex = selectedPlayer != null
        ? _cachedPlayerTeamOnField.indexOf(selectedPlayer!)
        : -1;
    final nextIndex = (currentIndex + 1) % _cachedPlayerTeamOnField.length;

    selectedPlayer?.isSelected = false;
    selectedPlayer?.isPlayerControlled = false;
    selectedPlayer = _cachedPlayerTeamOnField[nextIndex];
    selectedPlayer!.isSelected = true;
    selectedPlayer!.isPlayerControlled = true;
  }

  /// Cycle Tab-targeting to the next living enemy on field.
  ///
  /// Enemies are sorted: those in the frontal 180° arc of the selected player
  /// first (by distance), then the rest (by distance). Tab cycles through this
  /// ordered list. Wraps around and clears target after the last one.
  void tabToNextEnemyTarget() {
    if (_rosterDirty) _rebuildRosterCaches();
    if (_cachedOpponentTeamOnField.isEmpty) {
      currentTargetId = null;
      return;
    }

    // Work on a copy so we can sort without mutating the cache
    final enemies = _cachedOpponentTeamOnField.toList();

    final anchor = selectedPlayer;
    if (anchor != null) {
      enemies.sort((a, b) {
        final aScore = _tabScore(anchor, a);
        final bScore = _tabScore(anchor, b);
        return aScore.compareTo(bScore);
      });
    }

    // Find current target in sorted list
    int currentIdx = -1;
    if (currentTargetId != null) {
      currentIdx = enemies.indexWhere((e) => e.id == currentTargetId);
    }

    final nextIdx = (currentIdx + 1) % enemies.length;
    currentTargetId = enemies[nextIdx].id;
  }

  /// Lower score = higher priority for tab-targeting (in front, close)
  double _tabScore(UltraballPlayer anchor, UltraballPlayer target) {
    final dx = target.x - anchor.x;
    final dy = target.y - anchor.y;
    final dist = math.sqrt(dx * dx + dy * dy);

    // Angle difference from facing direction
    final angleToTarget = math.atan2(dy, dx);
    var diff = (angleToTarget - anchor.facing).abs();
    while (diff > math.pi) { diff = (diff - 2 * math.pi).abs(); }

    // Front-arc bonus: in-arc targets get score 0..dist, out-of-arc get dist*3..
    final inFront = diff < math.pi / 2;
    return inFront ? dist : dist * 3.0;
  }

  void clearTarget() {
    currentTargetId = null;
  }

  UltraballPlayer? get currentTarget {
    if (currentTargetId == null) return null;
    final p = _playerById[currentTargetId!];
    return (p != null && p.team == Team.opponent) ? p : null;
  }

  void showEvent(String message, {double duration = 2.5}) {
    lastEventMessage = message;
    lastEventTimer = duration;
  }

  void showCombo(String message) {
    comboMessage = message;
    comboMessageTimer = 2.0;
  }

  /// O(1) player lookup — backed by a map built at initialize().
  UltraballPlayer? getPlayerById(String id) => _playerById[id];

  /// Returns the alive on-field players for the given team (cached).
  List<UltraballPlayer> getTeamOnField(Team team) {
    if (_rosterDirty) _rebuildRosterCaches();
    return team == Team.player
        ? _cachedPlayerTeamOnField
        : _cachedOpponentTeamOnField;
  }

  List<UltraballPlayer> getTeamRoster(Team team) {
    return team == Team.player ? playerRoster : opponentRoster;
  }
}
