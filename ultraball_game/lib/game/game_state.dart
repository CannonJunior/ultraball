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
  List<UltraballPlayer> _cachedAllPlayers = [];
  List<UltraballPlayer> _cachedPlayerTeamOnField = [];
  List<UltraballPlayer> _cachedOpponentTeamOnField = [];
  int _playerDeadCount = 0;
  int _opponentDeadCount = 0;
  List<UltraballPlayer> _cachedThirdTeamOnField = [];
  int _thirdDeadCount = 0;
  bool _rosterDirty = true;

  late Ultraball ball;
  late Creature creature;
  Creature? creature2;
  List<UltraballPlayer> thirdRoster = [];
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

  // 3-team mode field geometry
  static const double field3Size     = 220.0;
  static const double field3CX       = 110.0;
  static const double field3CY       = 110.0;
  // inradius of equilateral triangle with side 40m: 40/(2*sqrt(3)) ≈ 11.547
  static const double field3Inradius = 11.547005383792515;
  static const double field3ArmHalfWidth = 20.0;
  static const double field3ChanInner  = field3Inradius + 40.0;  // ≈ 51.547
  static const double field3ChanOuter  = field3Inradius + 50.0;  // ≈ 61.547 (inner edge of endzone)
  static const double field3ArmEnd     = field3Inradius + 70.0;  // ≈ 81.547 (far wall of endzone)
  // Outward normals per team (player=bottom, opponent=upper-right, third=upper-left)
  static const List<(double, double)> team3Normals = [
    (0.0,                    1.0),   // player
    ( 0.8660254037844387, -0.5),     // opponent
    (-0.8660254037844387, -0.5),     // third
  ];
  static const List<double> field3PhaseDists = [
    field3Inradius + 10.0,  // ≈ 21.547
    field3Inradius + 20.0,  // ≈ 31.547
    field3Inradius + 30.0,  // ≈ 41.547
  ];

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
    _cachedAllPlayers = [...playerRoster, ...opponentRoster, ...thirdRoster];
    _cachedFieldPlayers = [
      for (final p in playerRoster)   if (p.isOnField) p,
      for (final p in opponentRoster) if (p.isOnField) p,
      for (final p in thirdRoster)    if (p.isOnField) p,
    ];
    _cachedPlayerTeamOnField = [
      for (final p in _cachedFieldPlayers)
        if (p.team == Team.player && p.isAlive) p,
    ];
    _cachedOpponentTeamOnField = [
      for (final p in _cachedFieldPlayers)
        if (p.team == Team.opponent && p.isAlive) p,
    ];
    _cachedThirdTeamOnField = [
      for (final p in _cachedFieldPlayers)
        if (p.team == Team.third && p.isAlive) p,
    ];
    _playerDeadCount =
        playerRoster.fold(0, (s, p) => p.isAlive ? s : s + 1);
    _opponentDeadCount =
        opponentRoster.fold(0, (s, p) => p.isAlive ? s : s + 1);
    _thirdDeadCount =
        thirdRoster.fold(0, (s, p) => p.isAlive ? s : s + 1);
    _rosterDirty = false;
  }

  // ---- Player list accessors (cached) ----

  List<UltraballPlayer> get fieldPlayers {
    if (_rosterDirty) _rebuildRosterCaches();
    return _cachedFieldPlayers;
  }

  /// All players in both rosters — use sparingly; prefer fieldPlayers.
  List<UltraballPlayer> get allPlayers {
    if (_rosterDirty) _rebuildRosterCaches();
    return _cachedAllPlayers;
  }

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

  int get thirdAliveOnField {
    if (_rosterDirty) _rebuildRosterCaches();
    return _cachedThirdTeamOnField.length;
  }

  int get thirdDeadCount {
    if (_rosterDirty) _rebuildRosterCaches();
    return _thirdDeadCount;
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
        double startX, startY;
        if (settings.matchMode == MatchMode.threeTeams) {
          // Player team starts in bottom arm
          final (nx, ny) = team3Normals[0];
          final spreadPerp = ((i % 5) - 2) * 7.0 + rand.nextDouble() * 2 - 1;
          final spreadNorm = (i ~/ 5) * 10.0 + 30.0 + rand.nextDouble() * 4 - 2;
          startX = field3CX + nx * spreadNorm + (-ny) * spreadPerp;
          startY = field3CY + ny * spreadNorm + nx * spreadPerp;
        } else {
          startX = 80.0 + rand.nextDouble() * 20.0;
          startY = 5.0 + rand.nextDouble() * 30.0;
        }
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
        double startX, startY;
        if (settings.matchMode == MatchMode.threeTeams) {
          // Opponent team starts in upper-right arm
          final (nx, ny) = team3Normals[1];
          final spreadPerp = ((i % 5) - 2) * 7.0 + rand.nextDouble() * 2 - 1;
          final spreadNorm = (i ~/ 5) * 10.0 + 30.0 + rand.nextDouble() * 4 - 2;
          startX = field3CX + nx * spreadNorm + (-ny) * spreadPerp;
          startY = field3CY + ny * spreadNorm + nx * spreadPerp;
        } else {
          startX = 40.0 + rand.nextDouble() * 20.0;
          startY = 5.0 + rand.nextDouble() * 30.0;
        }
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

      // Third team roster (3-team mode only)
      if (settings.matchMode == MatchMode.threeTeams) {
        thirdRoster = [];
        final thirdNames = settings.thirdPlayerNames.isNotEmpty
            ? settings.thirdPlayerNames
            : List.generate(15, (i) => 'T${i + 1}');
        for (int i = 0; i < 15; i++) {
          final cls = const [
            PlayerClass.spectre, PlayerClass.corsair, PlayerClass.geomancer,
            PlayerClass.archon, PlayerClass.warden, PlayerClass.trickster,
            PlayerClass.wrecker,
          ][i % 7];
          // Third team starts in upper-left arm
          final (nx, ny) = team3Normals[2]; // third team normal
          final spreadPerp = ((i % 5) - 2) * 7.0 + rand.nextDouble() * 2 - 1;
          final spreadNorm = (i ~/ 5) * 10.0 + 30.0 + rand.nextDouble() * 4 - 2;
          final startX = field3CX + nx * spreadNorm + (-ny) * spreadPerp;
          final startY = field3CY + ny * spreadNorm + nx * spreadPerp;
          final p = UltraballPlayer(
            id: 't_$i',
            name: thirdNames[i],
            team: Team.third,
            rosterIndex: i,
            x: startX,
            y: startY,
          );
          p.playerClass = cls;
          p.baseSpeed = cls.baseSpeed;
          p.maxHealth = cls.maxHealth;
          p.health = cls.maxHealth;
          p.maxFieldX = field3Size;
          p.maxFieldY = field3Size;
          thirdRoster.add(p);
        }
        // Apply roster order for third team (first 7 on field)
        for (int slot = 0; slot < 15; slot++) {
          final p = thirdRoster[slot];
          p.deploySlot = slot;
          p.isOnField = slot < 7;
        }
      }

      // Update field bounds for all rosters in 3-team mode
      if (settings.matchMode == MatchMode.threeTeams) {
        for (final p in playerRoster) { p.maxFieldX = field3Size; p.maxFieldY = field3Size; }
        for (final p in opponentRoster) { p.maxFieldX = field3Size; p.maxFieldY = field3Size; }
      }
    }

    // Build O(1) player lookup map
    _playerById.clear();
    for (final p in playerRoster)  { _playerById[p.id] = p; }
    for (final p in opponentRoster) { _playerById[p.id] = p; }
    for (final p in thirdRoster)    { _playerById[p.id] = p; }

    // Select the first on-field player by deploy slot (respects roster reordering and inactive classes)
    final onField = playerRoster.where((p) => p.isOnField && p.isAlive).toList();
    final first = onField.isNotEmpty
        ? onField.reduce((a, b) => a.deploySlot <= b.deploySlot ? a : b)
        : playerRoster[0];
    selectedPlayer = first;
    first.isSelected = true;
    first.isPlayerControlled = true;
    // Face toward opponents at start.
    // 3-team: player arm goes in +y direction; face toward center = -π/2.
    // 2-team: opponents are to the left; face = π.
    first.facing = settings.matchMode == MatchMode.threeTeams ? -math.pi / 2 : math.pi;

    // Create ball at midfield
    if (settings.matchMode == MatchMode.threeTeams) {
      ball = Ultraball(x: field3CX, y: field3CY);
    } else {
      ball = Ultraball(x: 70, y: 20);
    }

    // Create creature
    creature = Creature(type: settings.creatureType);
    if (settings.matchMode == MatchMode.threeTeams) {
      // Build 9-waypoint star perimeter for creature patrol.
      // CW order: arm 0 (player/south), arm 2 (third/upper-left), arm 1 (opponent/upper-right).
      // Each arm: inner corner (at inradius, ±chanPathHalfW), outer corners (at chanPathMid, ±chanPathHalfW).
      // chanPathHalfW = halfW + 5 = center of the 10m side channel.
      // chanPathMid = chanInner + 5 = center of the 10m endzone channel.
      const chanPathHalfW = field3ArmHalfWidth + 5.0;
      const chanPathMid   = field3ChanInner + 5.0;
      final perim = <(double, double)>[];
      for (int t in [0, 2, 1]) {
        final (nx, ny) = team3Normals[t];
        final px = -ny; final py = nx;
        perim.add((field3CX + nx * field3Inradius - chanPathHalfW * px,
                   field3CY + ny * field3Inradius - chanPathHalfW * py));
        perim.add((field3CX + nx * chanPathMid - chanPathHalfW * px,
                   field3CY + ny * chanPathMid - chanPathHalfW * py));
        perim.add((field3CX + nx * chanPathMid + chanPathHalfW * px,
                   field3CY + ny * chanPathMid + chanPathHalfW * py));
      }
      creature.setStarPatrol(perim);
      creature2 = Creature(type: settings.thirdCreatureType)
        ..setStarPatrol(perim, reversed: true);
    } else {
      creature2 = null;
    }

    // Start act
    actState.isActive = true;
    actState.actEnded = false;
    actState.timerSeconds = settings.fastMode ? 60.0 : 180.0;
    actState.isThreeTeams = settings.matchMode == MatchMode.threeTeams;

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
    final isThreeTeam = settings.matchMode == MatchMode.threeTeams;
    final enemies = isThreeTeam
        ? [..._cachedOpponentTeamOnField, ..._cachedThirdTeamOnField]
        : _cachedOpponentTeamOnField.toList();
    if (enemies.isEmpty) {
      currentTargetId = null;
      return;
    }

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
    if (p == null || !p.isAlive) return null;
    if (settings.matchMode == MatchMode.threeTeams) {
      return (p.team == Team.opponent || p.team == Team.third) ? p : null;
    }
    return p.team == Team.opponent ? p : null;
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
    return switch (team) {
      Team.player   => _cachedPlayerTeamOnField,
      Team.opponent => _cachedOpponentTeamOnField,
      Team.third    => _cachedThirdTeamOnField,
    };
  }

  List<UltraballPlayer> getTeamRoster(Team team) {
    return switch (team) {
      Team.player   => playerRoster,
      Team.opponent => opponentRoster,
      Team.third    => thirdRoster,
    };
  }
}
