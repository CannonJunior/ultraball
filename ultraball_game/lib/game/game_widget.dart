import 'dart:async';
import 'dart:math' as math;
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
import '../ui/scoreboard.dart';
import '../ui/damage_indicator_overlay.dart';
import '../ui/combo_display.dart';
import '../ui/mana_bars.dart';
import '../ui/throw_charge_bar.dart';

class GameWidget extends StatefulWidget {
  final GameSettings settings;

  const GameWidget({super.key, required this.settings});

  @override
  State<GameWidget> createState() => _GameWidgetState();
}

class _GameWidgetState extends State<GameWidget> {
  late GameState _gs;
  Timer? _gameLoop;
  DateTime _lastTick = DateTime.now();
  final FocusNode _focusNode = FocusNode();

  // Scale / layout
  double _scale = 1.0;
  double _offsetX = 0;
  double _offsetY = 0;

  @override
  void initState() {
    super.initState();
    _gs = GameState(settings: widget.settings);
    _gs.initialize();
    _startGameLoop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _gameLoop?.cancel();
    _focusNode.dispose();
    super.dispose();
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
    if (_gs.paused || _gs.actState.gameOver) return;
    if (_gs.showingActTransition) {
      ActSystem.update(_gs, dt);
      if (mounted) setState(() {});
      return;
    }

    // Increment throw charge for the selected player
    final selPlayer = _gs.selectedPlayer;
    if (selPlayer != null && selPlayer.isChargingThrow) {
      if (_gs.ball.holderId == selPlayer.id) {
        selPlayer.throwChargeTime = (selPlayer.throwChargeTime + dt)
            .clamp(0.0, UltraballPlayer.maxThrowChargeTime);
      } else {
        // Lost the ball while charging — cancel
        selPlayer.isChargingThrow = false;
        selPlayer.throwChargeTime = 0.0;
      }
    }

    // Handle player input
    _handlePlayerMovement(dt);

    // Update all players
    for (final p in _gs.allPlayers) {
      p.update(dt);
    }

    // Update AI
    AiSystem.update(_gs, dt);

    // Update ball
    BallSystem.update(_gs, dt);

    // Update creature
    CreatureSystem.update(_gs, dt);

    // Update act timer
    ActSystem.update(_gs, dt);

    // Update damage indicators
    _gs.indicators.removeWhere((ind) => ind.isExpired);
    for (final ind in _gs.indicators) {
      ind.update(dt);
    }

    if (mounted) setState(() {});
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

    // A/D: rotate facing angle (turning, not moving)
    if (keys.contains(LogicalKeyboardKey.keyA) ||
        keys.contains(LogicalKeyboardKey.arrowLeft)) {
      player.facing -= _turnSpeed * dt;
    }
    if (keys.contains(LogicalKeyboardKey.keyD) ||
        keys.contains(LogicalKeyboardKey.arrowRight)) {
      player.facing += _turnSpeed * dt;
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
      // Q = strafe left = negative right direction
      vx -= rightX;
      vy -= rightY;
    }
    if (keys.contains(LogicalKeyboardKey.keyE)) {
      // E = strafe right = positive right direction
      vx += rightX;
      vy += rightY;
    }

    // Normalize diagonal movement to maintain consistent speed
    final len = math.sqrt(vx * vx + vy * vy);
    if (len > 0) {
      vx = (vx / len) * player.speed;
      vy = (vy / len) * player.speed;
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
      // Escape: clear target first, then pause if no target
      if (_gs.currentTargetId != null) {
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
        _gs.selectNextPlayer();
      } else {
        _gs.tabToNextEnemyTarget();
      }
      return;
    }

    // 1: Tackle (basic attack)
    if (key == LogicalKeyboardKey.digit1) {
      if (player != null) {
        CombatSystem.tryAttack(_gs, player, 'tackle');
      }
      return;
    }

    // 2: Power Slam
    if (key == LogicalKeyboardKey.digit2) {
      if (player != null) {
        CombatSystem.tryAttack(_gs, player, 'slam');
      }
      return;
    }

    // 3: Sprint
    if (key == LogicalKeyboardKey.digit3) {
      if (player != null &&
          player.sprintCooldown <= 0 &&
          player.blueMana >= 20 &&
          player.speedBoostTimer <= 0) {
        player.blueMana -= 20;
        player.speedBoostTimer = 3.0;
        player.sprintCooldown = 6.0;
      }
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

    // F release: fire the charged throw
    if (event.logicalKey == LogicalKeyboardKey.keyF) {
      final player = _gs.selectedPlayer;
      if (player != null && player.isChargingThrow) {
        BallSystem.tryChargedThrow(_gs, player);
      }
    }
  }

  void _computeLayout(Size size) {
    // Field is 140m x 40m. Creature channels extend 5m above (y=-5)
    // and 5m below (y=45), giving a 50m total world height. Add 2m
    // padding on each side of that world extent.
    const fieldW = 144.0; // 140 + 2 padding each side
    const fieldH = 54.0;  // 50m world + 2m padding each side
    final scaleX = size.width / fieldW;
    final scaleY = size.height / fieldH;
    _scale = math.min(scaleX, scaleY);
    _offsetX = (size.width - 140 * _scale) / 2;
    // Center the 50m world (y=-5..45); field y=0 is 5m down from world top.
    _offsetY = (size.height - 50 * _scale) / 2 + 5 * _scale;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
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
            // Scoreboard
            Scoreboard(gs: _gs),

            // Game canvas
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _computeLayout(Size(constraints.maxWidth, constraints.maxHeight));

                  return Stack(
                    children: [
                      // Main game canvas
                      CustomPaint(
                        painter: FieldPainter(
                          gs: _gs,
                          scale: _scale,
                          offsetX: _offsetX,
                          offsetY: _offsetY,
                        ),
                        size: Size(constraints.maxWidth, constraints.maxHeight),
                      ),

                      // Damage indicator overlay
                      DamageIndicatorOverlay(
                        gs: _gs,
                        scale: _scale,
                        offsetX: _offsetX,
                        offsetY: _offsetY,
                      ),

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

                      // Mana bars (bottom left)
                      Positioned(
                        bottom: 12,
                        left: 12,
                        child: ManaBars(gs: _gs),
                      ),

                      // Team roster panel (right side)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: _RosterPanel(gs: _gs),
                      ),

                      // Pause overlay
                      if (_gs.paused) _PauseOverlay(onResume: () {
                        setState(() => _gs.paused = false);
                        _focusNode.requestFocus();
                      }),

                      // Game over overlay
                      if (_gs.actState.gameOver) _GameOverOverlay(gs: _gs),

                      // Act transition overlay
                      if (_gs.showingActTransition)
                        _ActTransitionOverlay(gs: _gs),
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
    final playerOnField = gs.playerRoster.where((p) => p.isOnField && p.isAlive).length;
    final playerDead = gs.playerRoster.where((p) => !p.isAlive).length;
    final oppOnField = gs.opponentRoster.where((p) => p.isOnField && p.isAlive).length;
    final oppDead = gs.opponentRoster.where((p) => !p.isAlive).length;

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

class _GameOverOverlay extends StatelessWidget {
  final GameState gs;
  const _GameOverOverlay({required this.gs});

  @override
  Widget build(BuildContext context) {
    final act = gs.actState;
    final playerWon = act.playerScore > act.opponentScore;
    final tied = act.playerScore == act.opponentScore;

    String headline;
    Color headlineColor;
    if (act.playerForfeit) {
      headline = '${gs.settings.awayTeamName} WINS BY FORFEIT!';
      headlineColor = const Color(0xFFE53935);
    } else if (act.opponentForfeit) {
      headline = '${gs.settings.homeTeamName} WINS BY FORFEIT!';
      headlineColor = const Color(0xFF1E88E5);
    } else if (tied) {
      headline = 'DRAW!';
      headlineColor = const Color(0xFFFFCC00);
    } else if (playerWon) {
      headline = '${gs.settings.homeTeamName} WINS!';
      headlineColor = const Color(0xFF1E88E5);
    } else {
      headline = '${gs.settings.awayTeamName} WINS!';
      headlineColor = const Color(0xFFE53935);
    }

    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'GAME OVER',
              style: TextStyle(
                color: Color(0xFF888888),
                fontSize: 20,
                letterSpacing: 5,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              headline,
              style: TextStyle(
                color: headlineColor,
                fontSize: 40,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ScoreBox(
                  team: gs.settings.awayTeamName,
                  score: act.opponentScore,
                  color: const Color(0xFFE53935),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'VS',
                    style: TextStyle(
                      color: Color(0xFF555555),
                      fontSize: 18,
                    ),
                  ),
                ),
                _ScoreBox(
                  team: gs.settings.homeTeamName,
                  score: act.playerScore,
                  color: const Color(0xFF1E88E5),
                ),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFCC00),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
              child: const Text(
                'BACK TO MENU',
                style: TextStyle(
                  fontSize: 16,
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

class _ScoreBox extends StatelessWidget {
  final String team;
  final int score;
  final Color color;

  const _ScoreBox({required this.team, required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$score',
          style: TextStyle(
            color: color,
            fontSize: 64,
            fontWeight: FontWeight.w900,
            height: 1.0,
          ),
        ),
        Text(
          team,
          style: TextStyle(
            color: color.withValues(alpha: 0.7),
            fontSize: 12,
            letterSpacing: 2,
          ),
        ),
      ],
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
