import 'dart:math' as math;
import 'package:flutter/services.dart';
import '../models/player.dart';
import '../models/ultraball.dart';
import '../models/creature.dart';
import '../models/act_state.dart';
import '../models/damage_indicator.dart';
import '../models/game_settings.dart';

class GameState {
  final GameSettings settings;

  // All players: indices 0-6 = player team on-field, 7-13 = opponent team on-field
  // Plus roster: 7-14 (player) and 7-14 (opponent) stored separately
  List<UltraballPlayer> playerRoster = []; // 15 players for human team
  List<UltraballPlayer> opponentRoster = []; // 15 players for AI team

  List<UltraballPlayer> get allPlayers =>
      [...playerRoster, ...opponentRoster];
  List<UltraballPlayer> get fieldPlayers =>
      allPlayers.where((p) => p.isOnField).toList();

  late Ultraball ball;
  late Creature creature;
  ActState actState = ActState();
  List<DamageIndicator> indicators = [];

  UltraballPlayer? selectedPlayer;
  Set<LogicalKeyboardKey> pressedKeys = {};
  bool paused = false;
  bool gameStarted = false;

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

  GameState({required this.settings});

  void initialize() {
    final rand = math.Random();

    // Create player roster (15 players, home team)
    playerRoster = [];
    final playerNames = [
      'Steel',
      'Blaze',
      'Raven',
      'Ghost',
      'Titan',
      'Nova',
      'Ace',
      'Rex',
      'Vex',
      'Axe',
      'Bolt',
      'Claw',
      'Dusk',
      'Edge',
      'Fury',
    ];
    for (int i = 0; i < 15; i++) {
      final startX = 80.0 + rand.nextDouble() * 20.0;
      final startY = 5.0 + rand.nextDouble() * 30.0;
      playerRoster.add(
        UltraballPlayer(
          id: 'p_$i',
          name: playerNames[i],
          team: Team.player,
          rosterIndex: i,
          x: startX,
          y: startY,
        ),
      );
    }

    // Create opponent roster (15 players, away team)
    opponentRoster = [];
    final opponentNames = [
      'Viper',
      'Shade',
      'Fang',
      'Crypt',
      'Mort',
      'Skull',
      'Gore',
      'Doom',
      'Grim',
      'Reap',
      'Void',
      'Ash',
      'Bone',
      'Blood',
      'Hex',
    ];
    for (int i = 0; i < 15; i++) {
      final startX = 40.0 + rand.nextDouble() * 20.0;
      final startY = 5.0 + rand.nextDouble() * 30.0;
      opponentRoster.add(
        UltraballPlayer(
          id: 'o_$i',
          name: opponentNames[i],
          team: Team.opponent,
          rosterIndex: i,
          x: startX,
          y: startY,
        ),
      );
    }

    // Put first 7 of each team on field
    for (int i = 0; i < 7; i++) {
      playerRoster[i].isOnField = true;
    }
    for (int i = 0; i < 7; i++) {
      opponentRoster[i].isOnField = true;
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
  }

  void selectNextPlayer() {
    final alivePlayers =
        playerRoster.where((p) => p.isAlive && p.isOnField).toList();
    if (alivePlayers.isEmpty) return;

    final currentIndex = selectedPlayer != null
        ? alivePlayers.indexOf(selectedPlayer!)
        : -1;
    final nextIndex = (currentIndex + 1) % alivePlayers.length;

    selectedPlayer?.isSelected = false;
    selectedPlayer?.isPlayerControlled = false;
    selectedPlayer = alivePlayers[nextIndex];
    selectedPlayer!.isSelected = true;
    selectedPlayer!.isPlayerControlled = true;
  }

  /// Cycle Tab-targeting to the next living enemy on field.
  ///
  /// Enemies are sorted: those in the frontal 180° arc of the selected player
  /// first (by distance), then the rest (by distance). Tab cycles through this
  /// ordered list. Wraps around and clears target after the last one.
  void tabToNextEnemyTarget() {
    final enemies =
        opponentRoster.where((p) => p.isAlive && p.isOnField).toList();
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
    try {
      return opponentRoster.firstWhere((p) => p.id == currentTargetId);
    } catch (_) {
      return null;
    }
  }

  void showEvent(String message, {double duration = 2.5}) {
    lastEventMessage = message;
    lastEventTimer = duration;
  }

  void showCombo(String message) {
    comboMessage = message;
    comboMessageTimer = 2.0;
  }

  UltraballPlayer? getPlayerById(String id) {
    try {
      return allPlayers.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  List<UltraballPlayer> getTeamOnField(Team team) {
    return fieldPlayers.where((p) => p.team == team && p.isAlive).toList();
  }

  List<UltraballPlayer> getTeamRoster(Team team) {
    return team == Team.player ? playerRoster : opponentRoster;
  }
}
