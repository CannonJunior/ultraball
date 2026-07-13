import 'dart:math' as math;
import 'package:flutter/services.dart';
import '../models/player.dart';
import '../models/ultraball.dart';
import '../models/creature.dart';
import '../models/act_state.dart';
import '../models/damage_indicator.dart';
import '../models/game_settings.dart';
import '../models/gameplay_preferences.dart';
import '../models/terrain_grid.dart';
import '../models/terrain_event.dart';
import '../ai/ai_policy.dart';
import '../ai/ai_strategy.dart';
import '../ai/game_data_sink.dart';
import 'ability_stats_collector.dart';

class TricksterTrap {
  final double worldX;
  final double worldY;
  final double radius;
  final Team ownerTeam;
  double timer;
  bool triggered = false;
  final double snareDuration;
  final double snareMultiplier;

  TricksterTrap({
    required this.worldX,
    required this.worldY,
    required this.ownerTeam,
    this.radius = 2.5,
    this.timer = 8.0,
    this.snareDuration = 2.0,
    this.snareMultiplier = 0.5,
  });
}

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
  GameDataSink? dataCollector;
  AbilityStatsCollector? abilityStats;

  // Tab-targeting
  String? currentTargetId;      // id of targeted enemy (opponent player)

  String? lastEventMessage;
  double lastEventTimer = 0;

  // Combo display
  String? comboMessage;
  double comboMessageTimer = 0;

  // Pass targeting
  bool isAiming = false;

  // Terrain state
  TerrainGrid terrain = TerrainGrid();

  // Trickster traps
  List<TricksterTrap> tricksterTraps = [];

  // Geomancer hold-to-aim terrain placement
  bool isAimingTerrain = false;
  TerrainEventType? terrainAimEventType;
  static const double terrainAimRange = 10.0;
  static const double fieldWidth  = 140.0;
  static const double fieldHeight =  40.0;

  // Accumulated match clock — incremented every active game tick; used for DPS calculation.
  double matchTimeElapsed = 0.0;

  /// Called by ActSystem whenever an Ultra is scored; wired to
  /// HighlightRecorder.notifyUltraScored() by GameWidget.
  void Function(String teamId, String? scorerName, int playerScore, int opponentScore)? onUltraScored;

  // Act transition state
  bool showingActTransition = false;
  double actTransitionTimer = 0;
  String actTransitionMessage = '';
  bool showingRosterScreen = false;

  // ── Runtime preferences (display + AI overrides) ─────────────────────────
  final GameplayPreferences prefs = GameplayPreferences();

  /// Effective AI strategy for the opponent — override takes precedence.
  AiStrategy get effectiveAiStrategy =>
      prefs.aiStrategyOverride ?? settings.aiStrategy;

  /// Effective AI tactics for the opponent — override takes precedence.
  AiTactics get effectiveAiTactics =>
      prefs.aiTacticsOverride ?? settings.aiTactics;

  GameState({required this.settings});

  /// Minimal constructor for unit tests — populates _playerById without
  /// calling initialize() so tests control roster contents precisely.
  GameState.forTesting({
    required GameSettings testSettings,
    List<UltraballPlayer>? players,
    List<UltraballPlayer>? opponents,
  }) : settings = testSettings {
    playerRoster  = List.of(players   ?? []);
    opponentRoster = List.of(opponents ?? []);
    for (final p in playerRoster)   _playerById[p.id] = p;
    for (final p in opponentRoster) _playerById[p.id] = p;
    ball     = Ultraball(x: 70, y: 20);
    creature = Creature(type: CreatureType.kraken);
    actState.isActive = true;
    actState.timerSeconds = 60.0;
    markRosterDirty();
  }

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

    if (settings.testMode) {
      // Test mode: one player character vs one passive dummy enemy
      const cls = PlayerClass.spectre;
      final p = UltraballPlayer(
        id: 'p_0',
        name: settings.homePlayerNames[0],
        team: Team.player,
        rosterIndex: 0,
        x: 80.0,
        y: 17.5,
      );
      p.playerClass = cls;
      p.baseSpeed = cls.baseSpeed;
      p.maxHealth = cls.maxHealth;
      p.health = cls.maxHealth;
      p.deploySlot = 0;
      p.isOnField = true;
      playerRoster = [p];

      final dummy = UltraballPlayer(
        id: 'o_0',
        name: 'Dummy',
        team: Team.opponent,
        rosterIndex: 0,
        x: 55.0,
        y: 17.5,
      );
      dummy.playerClass = PlayerClass.wrecker;
      dummy.baseSpeed = 0.0;
      dummy.maxHealth = 999.0;
      dummy.health = 999.0;
      dummy.deploySlot = 0;
      dummy.isOnField = true;
      opponentRoster = [dummy];
    } else {
      // Create player roster (15 players, home team)
      playerRoster = [];
      final playerNames = settings.homePlayerNames;
      for (int i = 0; i < 15; i++) {
        final cls = const [
          PlayerClass.spectre, PlayerClass.corsair, PlayerClass.geomancer,
          PlayerClass.archon, PlayerClass.warden, PlayerClass.trickster,
          PlayerClass.wrecker,
        ][i % 7];
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
          PlayerClass.spectre, PlayerClass.corsair, PlayerClass.geomancer,
          PlayerClass.archon, PlayerClass.warden, PlayerClass.trickster,
          PlayerClass.wrecker,
        ][i % 7];
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

      // Apply home roster order: active classes fill slots 0-N consecutively;
      // inactive-class players are marked isInactive and never deployed.
      int homeActiveSlot = 0;
      for (int slot = 0; slot < 15; slot++) {
        final playerIdx = settings.homeRosterOrder[slot];
        final p = playerRoster[playerIdx];
        if (settings.inactiveClasses.contains(playerIdx % 7)) {
          p.isInactive = true;
          p.isOnField  = false;
          p.deploySlot = 100 + slot; // beyond normal range so sort won't pick them
        } else {
          p.deploySlot = homeActiveSlot;
          p.isOnField  = homeActiveSlot < 7;
          homeActiveSlot++;
        }
      }
      // Apply away roster order (same inactive-class exclusion)
      int awayActiveSlot = 0;
      for (int slot = 0; slot < 15; slot++) {
        final oppIdx = settings.awayRosterOrder[slot];
        final p = opponentRoster[oppIdx];
        if (settings.inactiveClasses.contains(oppIdx % 7)) {
          p.isInactive = true;
          p.isOnField  = false;
          p.deploySlot = 100 + slot;
        } else {
          p.deploySlot = awayActiveSlot;
          p.isOnField  = awayActiveSlot < 7;
          awayActiveSlot++;
        }
      }
    }

    // Build O(1) player lookup map
    _playerById.clear();
    for (final p in playerRoster)  { _playerById[p.id] = p; }
    for (final p in opponentRoster) { _playerById[p.id] = p; }

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

    abilityStats = AbilityStatsCollector();

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

  void selectPlayer(UltraballPlayer target) {
    selectedPlayer?.isSelected = false;
    selectedPlayer?.isPlayerControlled = false;
    selectedPlayer = target;
    target.isSelected = true;
    target.isPlayerControlled = true;
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
