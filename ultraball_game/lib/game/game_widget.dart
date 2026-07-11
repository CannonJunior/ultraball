import 'dart:async';
import 'dart:math' as math;
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/player.dart';
import '../models/game_settings.dart';
import 'game_state.dart';
import 'field_painter.dart';
import 'systems/combat_system.dart';
import 'systems/ball_system.dart';
import 'systems/creature_system.dart';
import 'systems/act_system.dart';
import 'systems/ai_system.dart';
import 'systems/terrain_system.dart';
import '../models/terrain_event.dart';
import '../ui/scoreboard.dart';
import '../ui/scoreboard_row.dart';
import '../ui/combo_display.dart';
import '../ui/mana_bars.dart';
import '../ui/throw_charge_bar.dart';
import '../ui/roster_screen.dart';
import '../ui/in_game_settings_panel.dart';
import '../ui/damage_meter.dart';
import '../ui/game_summary_screen.dart';
import '../ui/highlight_clip_list.dart';
import '../ui/ui_theme.dart';
import '../ai/learning_ai.dart';
import '../ai/game_data_collector.dart';
import '../game3d/ultraball_render_system.dart';
import 'highlight_recorder.dart';

class GameWidget extends StatefulWidget {
  final GameSettings settings;

  const GameWidget({super.key, required this.settings});

  @override
  State<GameWidget> createState() => _GameWidgetState();
}

class _GameWidgetState extends State<GameWidget> with WidgetsBindingObserver {
  late GameState _gs;
  Timer? _gameLoop;
  bool _learnDone = false;
  DateTime _lastTick = DateTime.now();
  final FocusNode _focusNode = FocusNode();

  // Scale / layout
  double _scale = 1.0;
  double _offsetX = 0;
  double _offsetY = 0;
  Size?  _lastLayoutSize;

  // 3D WebGL render system (full3D view mode only)
  UltraballRenderSystem? _renderSystem;
  html.CanvasElement?    _webglCanvas;

  HighlightRecorder? _highlightRecorder;

  // Long-lived painter — reused every frame so its cached Paints/TextPainters persist
  late FieldPainter _fieldPainter;
  final ValueNotifier<int> _canvasRepaint = ValueNotifier<int>(0);

  bool _showSettingsPanel = false;
  bool _showDamageMeter   = false;

  // Typed reference retained for finalise() which is not on GameDataSink
  GameDataCollector? _dataCollector;

  @override
  void initState() {
    super.initState();
    _gs = GameState(settings: widget.settings);
    _gs.initialize();
    _showDamageMeter = UiTheme.instance.damageMeterDefaultVisible;
    _fieldPainter = FieldPainter(gs: _gs, repaint: _canvasRepaint)
      ..viewMode = widget.settings.viewMode;
    // Wire up the adaptive AI policy and data collector for this game
    _gs.activePolicy = LearningAi.instance.policyFor(
      widget.settings.aiStrategy,
      widget.settings.aiTactics,
    );
    _dataCollector = GameDataCollector(
      strategy: widget.settings.aiStrategy,
      tactics:  widget.settings.aiTactics,
    );
    _gs.dataCollector = _dataCollector;
    _focusNode.addListener(_onFocusChange);
    WidgetsBinding.instance.addObserver(this);

    _highlightRecorder = HighlightRecorder();

    _startGameLoop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });

    // Full-3D mode: create WebGL canvas behind Flutter UI, then init renderer
    if (widget.settings.viewMode == ViewMode.full3D) {
      _webglCanvas = html.CanvasElement()
        ..style.position    = 'fixed'
        ..style.top         = '0'
        ..style.left        = '0'
        ..style.width       = '100%'
        ..style.height      = '100%'
        ..style.display     = 'block'
        ..style.zIndex      = '-1'
        ..style.pointerEvents = 'none';
      html.document.body?.append(_webglCanvas!);

      _renderSystem = UltraballRenderSystem();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final w = html.window.innerWidth  ?? 1280;
        final h = html.window.innerHeight ?? 720;
        _webglCanvas!.width  = w;
        _webglCanvas!.height = h;
        final initialSize = Size(w.toDouble(), h.toDouble());
        _renderSystem!.init(_webglCanvas!, widget.settings.creatureType, initialSize);
        _renderSystem!.initPlayers(_gs, useCubeModels: widget.settings.useCubeModels);
        _fieldPainter.renderSystem = _renderSystem;
        _highlightRecorder?.setSourceCanvas(_webglCanvas);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.removeListener(_onFocusChange);
    _gameLoop?.cancel();
    _focusNode.dispose();
    _canvasRepaint.dispose();
    _renderSystem?.dispose();
    _webglCanvas?.remove();
    _highlightRecorder?.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      _gs.pressedKeys.clear();
      _gs.isAimingTerrain = false;
      _gs.terrainAimEventType = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _gs.pressedKeys.clear();
    }
  }

  void _startGameLoop() {
    _lastTick = DateTime.now();
    _gameLoop = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted) return;
      final now = DateTime.now();
      var dt = now.difference(_lastTick).inMicroseconds / 1000000.0;
      _lastTick = now;

      // Cap dt to avoid huge jumps
      dt = dt.clamp(0.0, 0.05);

      _update(dt);
    });
  }

  void _update(double dt) {
    // Detect game over — finalise learning exactly once
    if (_gs.actState.gameOver) {
      if (!_learnDone) {
        _learnDone = true;
        final record = _dataCollector?.finalise(_gs);
        if (record != null) LearningAi.instance.onGameEnd(record);
        // Force a rebuild to show the game-over overlay. This matters when
        // forfeit was set outside _update() (e.g. via a key-press ability),
        // because the setState() at the bottom of _update() is never reached.
        if (mounted) setState(() {});
      }
      return;
    }
    if (_gs.paused) return;
    if (_gs.showingRosterScreen) return;
    if (_gs.showingActTransition) {
      ActSystem.update(_gs, dt);
      if (mounted) setState(() {});
      return;
    }

    _gs.matchTimeElapsed += dt;

    // Increment throw charge for the selected player
    final selPlayer = _gs.selectedPlayer;
    if (selPlayer != null) {
      final hasball = _gs.ball.holderId == selPlayer.id;
      final fHeld  = _gs.pressedKeys.contains(LogicalKeyboardKey.keyF);

      if (hasball && fHeld) {
        // Start or continue charging whenever F is held and ball is in hand
        selPlayer.isChargingThrow = true;
        selPlayer.throwChargeTime = (selPlayer.throwChargeTime + dt)
            .clamp(0.0, UltraballPlayer.maxThrowChargeTime);
      } else if (!hasball) {
        // Lost the ball — cancel charge
        selPlayer.isChargingThrow = false;
        selPlayer.throwChargeTime = 0.0;
      }
    }

    // Handle player input
    _handlePlayerMovement(dt);

    // Update all players — iterate rosters directly to avoid allPlayers allocation
    for (final p in _gs.playerRoster)   { p.update(dt); }
    for (final p in _gs.opponentRoster) { p.update(dt); }

    // Drain ability queue for selected player
    final selForQueue = _gs.selectedPlayer;
    if (selForQueue != null && selForQueue.isAlive) {
      CombatSystem.drainAbilityQueue(_gs, selForQueue);
    }

    // Update AI
    AiSystem.update(_gs, dt);

    // Update ball
    BallSystem.update(_gs, dt);

    // Process Trickster traps
    CombatSystem.processTraps(_gs, dt);

    // Update creature
    CreatureSystem.update(_gs, dt);

    // Update terrain (height lerps, hazard timers, pit deaths)
    TerrainSystem.update(_gs, dt);

    // Update act timer
    ActSystem.update(_gs, dt);
    _gs.dataCollector?.tick(dt);

    // Clear target if it died or left the field
    if (_gs.currentTargetId != null) {
      final t = _gs.getPlayerById(_gs.currentTargetId!);
      if (t == null || !t.isAlive || !t.isOnField) _gs.clearTarget();
    }

    // Update damage indicators in a single reverse pass (removes expired + ticks live)
    for (int i = _gs.indicators.length - 1; i >= 0; i--) {
      final ind = _gs.indicators[i];
      ind.update(dt);
      if (ind.isExpired) _gs.indicators.removeAt(i);
    }

    // Advance 3D animations and camera (must happen before render in _paintFull3D)
    if (_renderSystem != null && _renderSystem!.ready) {
      _renderSystem!.update(_gs, dt);
    }

    // Trigger canvas repaint (painter is long-lived; doesn't go through shouldRepaint).
    // ValueListenableBuilder widgets in build() subscribe to this and rebuild their
    // own subtrees, so a full setState() is no longer needed every frame.
    if (mounted) _canvasRepaint.value++;
  }

  // ==================== WOW-STYLE MOVEMENT ====================
  // W = move forward along facing direction
  // S = move backward along facing direction
  // A = turn left (rotate character counter-clockwise)
  // D = turn right (rotate character clockwise)
  // Q = strafe left (move perpendicular-left without turning)
  // E = strafe right (move perpendicular-right without turning)

  static const double _turnSpeed = 150.0 * (math.pi / 180.0); // 150 deg/sec in radians

  void _handlePlayerMovement(double dt) {
    final player = _gs.selectedPlayer;
    if (player == null || !player.isAlive || player.isStunned) return;

    final keys = _gs.pressedKeys;

    // The 3/4 view camera (Y=-30, looking toward +Y) puts game +Y at the top of
    // the screen, inverting perceived left/right vs the flat view — flip to compensate.
    // The full3D renderer's yaw formula already bakes in this inversion, so no flip
    // is needed there (it would double-invert).
    final flip = widget.settings.viewMode == ViewMode.threeQuarter ? -1.0 : 1.0;

    // A/D: rotate facing angle (turning, not moving).
    // Under confusion the turn direction is reversed so left/right are swapped.
    final confusionFlip = player.confusedTimer > 0 ? -1.0 : 1.0;
    if (keys.contains(LogicalKeyboardKey.keyA) ||
        keys.contains(LogicalKeyboardKey.arrowLeft)) {
      player.facing -= _turnSpeed * dt * flip * confusionFlip;
    }
    if (keys.contains(LogicalKeyboardKey.keyD) ||
        keys.contains(LogicalKeyboardKey.arrowRight)) {
      player.facing += _turnSpeed * dt * flip * confusionFlip;
    }
    // Keep facing in [-π, π] so _tabScore's while loop stays O(1)
    player.facing = math.atan2(math.sin(player.facing), math.cos(player.facing));

    // Build movement vector from W/S (forward/back) and Q/E (strafe)
    double vx = 0, vy = 0;

    // Forward direction unit vector
    final fwdX = math.cos(player.facing);
    final fwdY = math.sin(player.facing);
    // Right strafe direction (perpendicular clockwise from forward)
    final rightX = -fwdY;
    final rightY = fwdX;

    if (keys.contains(LogicalKeyboardKey.keyW) ||
        keys.contains(LogicalKeyboardKey.arrowUp)) {
      vx += fwdX;
      vy += fwdY;
    }
    if (keys.contains(LogicalKeyboardKey.keyS) ||
        keys.contains(LogicalKeyboardKey.arrowDown)) {
      vx -= fwdX;
      vy -= fwdY;
    }
    if (keys.contains(LogicalKeyboardKey.keyQ)) {
      vx -= rightX * flip;
      vy -= rightY * flip;
    }
    if (keys.contains(LogicalKeyboardKey.keyE)) {
      vx += rightX * flip;
      vy += rightY * flip;
    }

    // Normalize diagonal movement to maintain consistent speed
    final len = math.sqrt(vx * vx + vy * vy);
    if (len > 0) {
      vx = (vx / len) * player.speed;
      vy = (vy / len) * player.speed;
    }

    // Confusion: reverse movement direction
    if (player.confusedTimer > 0) {
      vx = -vx;
      vy = -vy;
    }
    player.velX = vx;
    player.velY = vy;
  }

  void _handleKeyDown(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final key = event.logicalKey;

    // Q and E are held movement keys — track them but don't consume as actions
    final isMovementKey = key == LogicalKeyboardKey.keyQ ||
        key == LogicalKeyboardKey.keyE ||
        key == LogicalKeyboardKey.keyW ||
        key == LogicalKeyboardKey.keyS ||
        key == LogicalKeyboardKey.keyA ||
        key == LogicalKeyboardKey.keyD ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight;

    _gs.pressedKeys.add(key);

    if (key == LogicalKeyboardKey.escape) {
      // Escape: close settings panel first, then clear target, then pause
      if (_showSettingsPanel) {
        setState(() {
          _showSettingsPanel = false;
          _gs.paused = false;
        });
        _focusNode.requestFocus();
      } else if (_gs.currentTargetId != null) {
        setState(() => _gs.clearTarget());
      } else {
        setState(() => _gs.paused = !_gs.paused);
      }
      return;
    }

    if (_gs.paused) return;
    if (_gs.actState.gameOver) return;
    if (isMovementKey) return;

    final player = _gs.selectedPlayer;

    // Tab: cycle enemy targets (Shift+Tab = switch controlled player)
    if (key == LogicalKeyboardKey.tab) {
      final isShift = _gs.pressedKeys.contains(LogicalKeyboardKey.shiftLeft) ||
          _gs.pressedKeys.contains(LogicalKeyboardKey.shiftRight);
      if (isShift) {
        // Cancel any in-progress Geomancer terrain aim before switching players
        _gs.isAimingTerrain = false;
        _gs.terrainAimEventType = null;
        _gs.selectNextPlayer();
      } else {
        _gs.tabToNextEnemyTarget();
      }
      return;
    }

    // 1–9, 0: class ability slots — goes through GCD/queue system
    if (key == LogicalKeyboardKey.digit1) {
      if (player != null) _tryFireAbility(player, 1);
      return;
    }
    if (key == LogicalKeyboardKey.digit2) {
      if (player != null) {
        if (player.playerClass == PlayerClass.geomancer) {
          // Hold-to-aim: start aiming terrain placement (Geomancer special case)
          if (player.slamCooldown <= 0 && player.redMana >= 25 && player.gcdRemaining <= 0) {
            _gs.isAimingTerrain = true;
            _gs.terrainAimEventType = TerrainEventType.riseMountain;
          } else {
            // On CD, no mana, or GCD active: enqueue via normal path
            _tryFireAbility(player, 2);
          }
        } else {
          _tryFireAbility(player, 2);
        }
      }
      return;
    }
    if (key == LogicalKeyboardKey.digit3) {
      if (player != null) _tryFireAbility(player, 3);
      return;
    }
    if (key == LogicalKeyboardKey.digit4) {
      if (player != null) {
        if (player.playerClass == PlayerClass.geomancer) {
          // Hold-to-aim: start aiming terrain placement (Geomancer special case)
          if (player.ability4Cooldown <= 0 && player.redMana >= 35 && player.gcdRemaining <= 0) {
            _gs.isAimingTerrain = true;
            _gs.terrainAimEventType = TerrainEventType.openPit;
          } else {
            // On CD, no mana, or GCD active: enqueue via normal path
            _tryFireAbility(player, 4);
          }
        } else {
          _tryFireAbility(player, 4);
        }
      }
      return;
    }
    if (key == LogicalKeyboardKey.digit5) {
      if (player != null) _tryFireAbility(player, 5);
      return;
    }
    if (key == LogicalKeyboardKey.digit6) {
      if (player != null) _tryFireAbility(player, 6);
      return;
    }
    if (key == LogicalKeyboardKey.digit7) {
      if (player != null) _tryFireAbility(player, 7);
      return;
    }
    if (key == LogicalKeyboardKey.digit8) {
      if (player != null) _tryFireAbility(player, 8);
      return;
    }
    if (key == LogicalKeyboardKey.digit9) {
      if (player != null) _tryFireAbility(player, 9);
      return;
    }
    if (key == LogicalKeyboardKey.digit0) {
      if (player != null) _tryFireAbility(player, 10);
      return;
    }

    // C: cycle player class (test mode only)
    if (key == LogicalKeyboardKey.keyC) {
      if (player != null && _gs.settings.testMode) {
        final classes = PlayerClass.values;
        final nextCls = classes[(classes.indexOf(player.playerClass) + 1) % classes.length];
        player.playerClass = nextCls;
        player.baseSpeed = nextCls.baseSpeed;
        player.maxHealth = nextCls.maxHealth;
        player.health = nextCls.maxHealth;
        player.redMana = 0;
        player.blueMana = 100;
        player.tackleCooldown = 0;
        player.slamCooldown = 0;
        player.sprintCooldown = 0;
        player.ability4Cooldown = 0;
        player.ability5Cooldown = 0;
        player.ability6Cooldown = 0;
        player.ability7Cooldown = 0;
        player.ability8Cooldown = 0;
        player.ability9Cooldown = 0;
      }
      return;
    }

    // V: toggle 3D camera mode (broadcast ↔ third-person follow)
    if (key == LogicalKeyboardKey.keyV) {
      _renderSystem?.toggleCameraMode();
      return;
    }

    // M: toggle damage/healing meter
    if (key == LogicalKeyboardKey.keyM) {
      setState(() => _showDamageMeter = !_showDamageMeter);
      return;
    }

    // R: start a 6-second highlight recording
    if (key == LogicalKeyboardKey.keyR) {
      _highlightRecorder?.startRecording(_gs);
      return;
    }

    // Space: jump (first press) or double-jump (second press while airborne, costs 15 blue mana)
    if (key == LogicalKeyboardKey.space) {
      player?.tryJump();
      return;
    }

    // F: Begin charging a throw
    if (key == LogicalKeyboardKey.keyF) {
      if (player != null && _gs.ball.holderId == player.id && !player.isChargingThrow) {
        player.isChargingThrow = true;
        player.throwChargeTime = 0.0;
      }
      return;
    }
  }

  void _handleKeyUp(KeyEvent event) {
    if (event is! KeyUpEvent) return;
    _gs.pressedKeys.remove(event.logicalKey);

    // F release: fire the charged throw if the player was charging
    if (event.logicalKey == LogicalKeyboardKey.keyF) {
      final player = _gs.selectedPlayer;
      if (player != null && player.isChargingThrow) {
        BallSystem.tryChargedThrow(_gs, player);
      }
      player?.isChargingThrow = false;
      player?.throwChargeTime = 0.0;
    }

    // Digit2 / Digit4 release: fire terrain ability if Geomancer was aiming.
    // Guard on playerClass so a mid-aim player-switch doesn't fire the wrong unit's slot.
    if (event.logicalKey == LogicalKeyboardKey.digit2 ||
        event.logicalKey == LogicalKeyboardKey.digit4) {
      if (_gs.isAimingTerrain && !_gs.paused && !_gs.actState.gameOver) {
        final player = _gs.selectedPlayer;
        if (player != null && player.playerClass == PlayerClass.geomancer) {
          final slot = event.logicalKey == LogicalKeyboardKey.digit2 ? 2 : 4;
          CombatSystem.useClassAbility(_gs, player, slot);
          player.gcdRemaining = 1.0;
          player.gcdMax = 1.0;
          final names = player.playerClass.abilityNames;
          if (slot >= 1 && slot <= names.length) {
            player.lastExecutedAbility = names[slot - 1];
            player.lastExecutedTimer = 1.2;
          }
        }
        _gs.isAimingTerrain = false;
        _gs.terrainAimEventType = null;
      }
    }
  }

  void _handleCanvasTap(Offset localPos, Size canvasSize) {
    if (_gs.paused || _gs.actState.gameOver) return;

    const double selectionRadius = 24.0;
    UltraballPlayer? closest;
    double closestDist = double.infinity;

    for (final p in _gs.fieldPlayers) {
      if (!p.isAlive) continue;
      final screenPos = _fieldPainter.projectPlayer(p, canvasSize);
      if (screenPos == null) continue;
      final dx = screenPos.dx - localPos.dx;
      final dy = screenPos.dy - localPos.dy;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist < closestDist) {
        closestDist = dist;
        closest = p;
      }
    }

    if (closest == null || closestDist > selectionRadius) {
      return;
    }

    if (closest.team == Team.player) {
      _gs.isAimingTerrain = false;
      _gs.terrainAimEventType = null;
      setState(() => _gs.selectPlayer(closest!));
    } else {
      setState(() => _gs.currentTargetId = closest!.id);
    }
    _focusNode.requestFocus();
  }

  /// Fire an ability immediately if ready, or enqueue it (max 5, no duplicates).
  void _tryFireAbility(UltraballPlayer player, int slot) {
    if (player.gcdRemaining > 0 || player.getSlotCooldown(slot) > 0) {
      // GCD active or slot on cooldown: enqueue
      if (player.abilityQueue.length < 5 && !player.abilityQueue.contains(slot)) {
        player.abilityQueue.add(slot);
      }
      return;
    }
    CombatSystem.useClassAbility(_gs, player, slot);
    // Set GCD and show combat text
    player.gcdRemaining = 1.0;
    player.gcdMax = 1.0;
    final names = player.playerClass.abilityNames;
    if (slot >= 1 && slot <= names.length) {
      player.lastExecutedAbility = names[slot - 1];
      player.lastExecutedTimer = 1.2;
    }
  }

  void _applyRosterAndBeginNextAct(List<UltraballPlayer> orderedAlive) {
    // Apply new deployment order from roster screen
    for (int i = 0; i < orderedAlive.length; i++) {
      orderedAlive[i].deploySlot = i;
      orderedAlive[i].isOnField = i < 7;
    }
    // Dead players always off field
    for (final p in _gs.playerRoster) {
      if (!p.isAlive) p.isOnField = false;
    }
    _gs.markRosterDirty();
    _gs.showingRosterScreen = false;
    ActSystem.startNextAct(_gs);
    setState(() {});
  }

  void _computeLayout(Size size) {
    if (size == _lastLayoutSize) {
      // Size unchanged — update painter offsets in case they drifted, then return
      _fieldPainter.scale   = _scale;
      _fieldPainter.offsetX = _offsetX;
      _fieldPainter.offsetY = _offsetY;
      return;
    }
    _lastLayoutSize = size;

    // Field is 140m x 40m. Creature channels extend 5m above (y=-5)
    // and 5m below (y=45), giving a 50m total world height. Add 2m
    // padding on each side of that world extent.
    const fieldW = 144.0; // 140 + 2 padding each side
    const fieldH = 54.0;  // 50m world + 2m padding each side
    final scaleX = size.width / fieldW;
    final scaleY = size.height / fieldH;
    _scale   = math.min(scaleX, scaleY);
    _offsetX = (size.width  - 140 * _scale) / 2;
    // Center the 50m world (y=-5..45); field y=0 is 5m down from world top.
    _offsetY = (size.height - 50  * _scale) / 2 + 5 * _scale;

    _fieldPainter.scale   = _scale;
    _fieldPainter.offsetX = _offsetX;
    _fieldPainter.offsetY = _offsetY;

    // Sync WebGL viewport to new window dimensions
    if (_renderSystem != null && _renderSystem!.ready) {
      final w = html.window.innerWidth  ?? size.width.toInt();
      final h = html.window.innerHeight ?? size.height.toInt();
      _webglCanvas?.width  = w;
      _webglCanvas?.height = h;
      _renderSystem!.resize(w, h);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.settings.viewMode == ViewMode.full3D
          ? Colors.transparent
          : Colors.black,
      body: Focus(
        focusNode: _focusNode,
        onKeyEvent: (node, event) {
          _handleKeyDown(event);
          _handleKeyUp(event);
          // Consume all game keys so Flutter's focus traversal (Tab) can't
          // steal the FocusNode away from the game canvas.
          return KeyEventResult.handled;
        },
        child: Column(
          children: [
            // IntrinsicHeight measures Scoreboard's natural height (~197 px:
            // _MainBar 110 + _BallDivider 32 + _PlayerCardsRow ~55) and passes
            // that as a bounded maxHeight to ScoreboardRow's
            // Row(CrossAxisAlignment.stretch). ScoreboardRow uses Expanded(flex:)
            // instead of LayoutBuilder, so this measurement succeeds.
            IntrinsicHeight(
              child: ScoreboardRow(
                gs:       _gs,
                repaint:  _canvasRepaint,
                recorder: _highlightRecorder,
              ),
            ),

            // Game canvas
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _computeLayout(Size(constraints.maxWidth, constraints.maxHeight));

                  final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
                  return Stack(
                    children: [
                      // Main game canvas — wrapped in IgnorePointer so
                      // RenderCustomPaint.hitTest() is never called (avoids
                      // assert(hasSize) on unlaid-out render objects).
                      IgnorePointer(
                        child: CustomPaint(
                          painter: _fieldPainter,
                          size: canvasSize,
                        ),
                      ),

                      // Click-to-target: opaque Listener with no child.
                      // opaque → hitTest() returns true even when hitTestSelf
                      // and hitTestChildren both return false, so Stack stops
                      // here and never descends to CustomPaint (no unlaid-out
                      // render box is reached by updateAllDevices).
                      // Positioned.fill gives it definite bounds from the Stack.
                      Positioned.fill(
                        child: Listener(
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: (event) =>
                              _handleCanvasTap(event.localPosition, canvasSize),
                        ),
                      ),

                      // All dynamic overlays subscribe to _canvasRepaint so they
                      // update each tick without a full GameWidget setState().
                      ValueListenableBuilder<int>(
                        valueListenable: _canvasRepaint,
                        builder: (_, __, ___) => Stack(
                          children: [
                            // Event message (center top)
                            if (_gs.lastEventMessage != null)
                              Positioned(
                                top: 16,
                                left: 0,
                                right: 0,
                                child: _EventMessage(message: _gs.lastEventMessage!),
                              ),

                            // Combo display (center bottom)
                            Positioned(
                              bottom: 120,
                              left: 0,
                              right: 0,
                              child: ComboDisplay(gs: _gs),
                            ),

                            // Throw charge bar (bottom center, above mana bars)
                            Positioned(
                              bottom: 80,
                              left: 0,
                              right: 0,
                              child: Center(child: ThrowChargeBar(gs: _gs)),
                            ),

                            // Target frame + target-of-target + mana bars (bottom left)
                            Positioned(
                              bottom: 12,
                              left: 12,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TargetFrame(gs: _gs),
                                  if (_gs.currentTarget != null) const SizedBox(height: 4),
                                  TargetOfTargetFrame(gs: _gs),
                                  if (_gs.currentTarget != null) const SizedBox(height: 6),
                                  ManaBars(gs: _gs),
                                ],
                              ),
                            ),

                            // Team roster panel + highlight clip list (right side, stacked)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _RosterPanel(gs: _gs),
                                  if (_highlightRecorder != null) ...[
                                    const SizedBox(height: 8),
                                    HighlightClipList(
                                      recorder:     _highlightRecorder!,
                                      homeTeamName: widget.settings.homeTeamName,
                                      awayTeamName: widget.settings.awayTeamName,
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Settings gear button (top-left)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: _SettingsButton(onTap: () {
                                setState(() {
                                  _showSettingsPanel = true;
                                  _gs.paused = true;
                                });
                              }),
                            ),

                            // Damage / healing meter (bottom-right, toggled by [M])
                            if (_showDamageMeter && !_gs.actState.gameOver)
                              Positioned(
                                bottom: 12,
                                right: 8,
                                child: DamageMeter(gs: _gs),
                              ),

                            // Pause overlay
                            if (_gs.paused && !_showSettingsPanel)
                              _PauseOverlay(onResume: () {
                                setState(() => _gs.paused = false);
                                _focusNode.requestFocus();
                              }),

                            // Game summary (replaces bare game-over box)
                            if (_gs.actState.gameOver)
                              GameSummaryScreen(
                                gs: _gs,
                                onBack: () => Navigator.of(context).pop(),
                              ),

                            // Act transition overlay
                            if (_gs.showingActTransition)
                              _ActTransitionOverlay(gs: _gs),
                            if (_gs.showingRosterScreen)
                              RosterScreen(
                                gs: _gs,
                                onConfirm: _applyRosterAndBeginNextAct,
                              ),

                            // In-game settings panel
                            if (_showSettingsPanel)
                              InGameSettingsPanel(
                                gs: _gs,
                                onClose: () {
                                  setState(() {
                                    _showSettingsPanel = false;
                                    _gs.paused = false;
                                  });
                                  _focusNode.requestFocus();
                                },
                                onViewModeChanged: (mode) {
                                  _fieldPainter.viewMode = mode;
                                  _canvasRepaint.value++;
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventMessage extends StatelessWidget {
  final String message;
  const _EventMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: const Color(0xFFFFCC00).withValues(alpha: 0.6),
          ),
        ),
        child: Text(
          message,
          style: const TextStyle(
            color: Color(0xFFFFCC00),
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _RosterPanel extends StatelessWidget {
  final GameState gs;
  const _RosterPanel({required this.gs});

  @override
  Widget build(BuildContext context) {
    // Use cached counts from GameState — O(1) instead of 4× O(n) .where().length
    final playerOnField = gs.playerAliveOnField;
    final playerDead    = gs.playerDeadCount;
    final oppOnField    = gs.opponentAliveOnField;
    final oppDead       = gs.opponentDeadCount;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _RosterRow(
            color: const Color(0xFF1E88E5),
            name: gs.settings.homeTeamName,
            onField: playerOnField,
            dead: playerDead,
          ),
          const SizedBox(height: 4),
          _RosterRow(
            color: const Color(0xFFE53935),
            name: gs.settings.awayTeamName,
            onField: oppOnField,
            dead: oppDead,
          ),
        ],
      ),
    );
  }
}

class _RosterRow extends StatelessWidget {
  final Color color;
  final String name;
  final int onField;
  final int dead;

  const _RosterRow({
    required this.color,
    required this.name,
    required this.onField,
    required this.dead,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$onField alive',
          style: const TextStyle(
            color: Color(0xFF44FF44),
            fontSize: 9,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$dead dead',
          style: const TextStyle(
            color: Color(0xFFFF4444),
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}

class _PauseOverlay extends StatelessWidget {
  final VoidCallback onResume;
  const _PauseOverlay({required this.onResume});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'PAUSED',
              style: TextStyle(
                color: Color(0xFFFFCC00),
                fontSize: 48,
                fontWeight: FontWeight.w900,
                letterSpacing: 8,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onResume,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFCC00),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
              child: const Text(
                'RESUME',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _SettingsButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SettingsButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: const Icon(Icons.settings, color: Color(0xAAFFFFFF), size: 18),
      ),
    );
  }
}

class _ActTransitionOverlay extends StatelessWidget {
  final GameState gs;
  const _ActTransitionOverlay({required this.gs});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              gs.actTransitionMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFFFCC00),
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Get ready...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
