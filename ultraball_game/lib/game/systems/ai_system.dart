import 'dart:math' as math;
import '../../models/player.dart';
import '../game_state.dart';
import 'combat_system.dart';
import 'ball_system.dart';

class AiSystem {
  static const double avoidCreatureRadius = 6.0;
  static const double passConsiderRange = 15.0;

  static void update(GameState gs, double dt) {
    if (!gs.actState.isActive || gs.actState.gameOver) return;

    // Update opponent AI
    _updateOpponentAI(gs, dt);

    // Update friendly non-selected AI
    _updateFriendlyAI(gs, dt);
  }

  static void _updateOpponentAI(GameState gs, double dt) {
    final opponents = gs.getTeamOnField(Team.opponent);
    final ball = gs.ball;

    for (final opp in opponents) {
      if (!opp.isAlive || opp.isStunned) {
        opp.velX = 0;
        opp.velY = 0;
        continue;
      }

      // Avoid creature
      final creatureAvoid = _getCreatureAvoidance(gs, opp);

      if (ball.holderId == null && !ball.isInFlight) {
        // No one has the ball - nearest opponent goes for it
        final closestOpp = _findClosestToPoint(
          opponents,
          ball.x,
          ball.y,
        );
        if (closestOpp?.id == opp.id) {
          _moveToward(opp, ball.x, ball.y, creatureAvoid);
        } else {
          // Others position strategically
          _moveToStrategicPosition(opp, gs, creatureAvoid);
        }
      } else if (ball.possessingTeamId == 'opponent') {
        // Opponent team has the ball
        if (ball.holderId == opp.id) {
          // This player has the ball - move toward player's right endzone (x=120)
          _aiHolderBehavior(opp, gs, creatureAvoid, dt);
        } else {
          // Support the ball carrier - move ahead
          _aiSupportBehavior(opp, gs, creatureAvoid);
        }
      } else {
        // Player team has the ball - defend
        _aiDefenseBehavior(opp, gs, creatureAvoid, dt);
      }

      // Clamp movement
      opp.x = opp.x.clamp(0.0, 140.0);
      opp.y = opp.y.clamp(0.0, 40.0);
    }
  }

  static void _aiHolderBehavior(
    UltraballPlayer opp,
    GameState gs,
    _Vec2 avoid,
    double dt,
  ) {
    // Look for a teammate to pass to who's closer to the target endzone
    const targetX = 130.0; // Deep in right endzone so holder crosses the x≥120 goal line
    final teammates = gs.getTeamOnField(Team.opponent)
        .where((p) => p.id != opp.id)
        .toList();

    UltraballPlayer? bestPassTarget;
    for (final tm in teammates) {
      if (tm.x > opp.x + 5) {
        // Teammate is ahead
        // Check they're not heavily defended
        final defenders = gs.getTeamOnField(Team.player)
            .where((p) {
              final dx = p.x - tm.x;
              final dy = p.y - tm.y;
              return math.sqrt(dx * dx + dy * dy) < 4.0;
            })
            .length;
        if (defenders == 0) {
          bestPassTarget = tm;
          break;
        }
      }
    }

    if (bestPassTarget != null) {
      // Pass to teammate
      BallSystem.tryPass(gs, opp, bestPassTarget.x, bestPassTarget.y, false);
    } else {
      // Move forward
      _moveToward(opp, targetX, 20.0, avoid);
    }

    // Try to attack nearby player
    CombatSystem.tryAttack(gs, opp, 'tackle');
  }

  static void _aiSupportBehavior(
    UltraballPlayer opp,
    GameState gs,
    _Vec2 avoid,
  ) {
    final holder = gs.getPlayerById(gs.ball.holderId ?? '');
    if (holder == null) return;

    // Spread out ahead of ball holder
    final spreadX = holder.x + 10.0 + (opp.rosterIndex % 3) * 8.0;
    final spreadY = 8.0 + (opp.rosterIndex % 5) * 7.0;
    _moveToward(opp, spreadX.clamp(30.0, 120.0), spreadY, avoid);
  }

  static void _aiDefenseBehavior(
    UltraballPlayer opp,
    GameState gs,
    _Vec2 avoid,
    double dt,
  ) {
    final holder = gs.getPlayerById(gs.ball.holderId ?? '');

    // Sort by distance to ball carrier
    final opponents = gs.getTeamOnField(Team.opponent);
    opponents.sort((a, b) {
      final ax = holder != null
          ? (a.x - holder.x).abs() + (a.y - holder.y).abs()
          : 0.0;
      final bx = holder != null
          ? (b.x - holder.x).abs() + (b.y - holder.y).abs()
          : 0.0;
      return ax.compareTo(bx);
    });

    final myRank = opponents.indexWhere((p) => p.id == opp.id);

    if (holder != null && myRank < 2) {
      // Closest 2 opponents rush the ball carrier
      _moveToward(opp, holder.x, holder.y, avoid);
      CombatSystem.tryAttack(gs, opp, 'tackle');
    } else {
      // Others defend strategically (block passing lanes)
      // Position between ball and own endzone (x=120, the opponent's endzone)
      final defX = (opp.x + 120) / 2.0;
      final defY = holder != null
          ? holder.y + (opp.rosterIndex % 3 - 1) * 6.0
          : 20.0;
      _moveToward(opp, defX.clamp(30.0, 119.0), defY.clamp(2.0, 38.0), avoid);
    }
  }

  static void _updateFriendlyAI(GameState gs, double dt) {
    // Exclude the player-controlled unit by flag rather than by ID so that a
    // stale selectedPlayer pointer (e.g. dead player not yet cleared) can
    // never accidentally hand AI control back to the unit the player owns.
    final players = gs.getTeamOnField(Team.player)
        .where((p) => !p.isPlayerControlled)
        .toList();

    final ball = gs.ball;

    for (final p in players) {
      if (!p.isAlive || p.isStunned) {
        p.velX = 0;
        p.velY = 0;
        continue;
      }

      final creatureAvoid = _getCreatureAvoidance(gs, p);

      if (ball.possessingTeamId == 'player') {
        // Player team has ball
        final holder = gs.getPlayerById(ball.holderId ?? '');
        if (ball.holderId == p.id) {
          // This AI player has the ball — run deep into the left endzone to score
          _moveToward(p, 10.0, 20.0, creatureAvoid);
        } else if (holder != null && ball.holderId == gs.selectedPlayer?.id) {
          // Selected player has ball - teammates spread ahead
          final spreadX = holder.x - 12.0 - (p.rosterIndex % 3) * 7.0;
          final spreadY = 8.0 + (p.rosterIndex % 5) * 7.0;
          _moveToward(p, spreadX.clamp(20.0, 110.0), spreadY, creatureAvoid);
        } else {
          // Teammate has ball - support
          if (holder != null) {
            final spreadX = holder.x - 8.0;
            final spreadY = holder.y + (p.rosterIndex % 3 - 1) * 6.0;
            _moveToward(p, spreadX.clamp(20.0, 110.0), spreadY, creatureAvoid);
          }
        }
      } else if (ball.holderId == null && !ball.isInFlight) {
        // Ball is loose - go get it
        final nearest = _findClosestToPoint(players, ball.x, ball.y);
        if (nearest?.id == p.id) {
          _moveToward(p, ball.x, ball.y, creatureAvoid);
        } else {
          // Position defensively
          _moveToward(p, 70.0, 20.0, creatureAvoid);
        }
      } else {
        // Opponent has ball - intercept
        final oppHolder = gs.getPlayerById(ball.holderId ?? '');
        if (oppHolder != null) {
          _moveToward(
            p,
            oppHolder.x + (p.rosterIndex % 3 - 1) * 4.0,
            oppHolder.y + (p.rosterIndex % 3 - 1) * 4.0,
            creatureAvoid,
          );
          // Try to tackle
          CombatSystem.tryAttack(gs, p, 'tackle');
        }
      }

      p.x = p.x.clamp(0.0, 140.0);
      p.y = p.y.clamp(0.0, 40.0);
    }
  }

  static _Vec2 _getCreatureAvoidance(GameState gs, UltraballPlayer p) {
    final creature = gs.creature;
    final dx = p.x - creature.x;
    final dy = p.y - creature.y;
    final dist = math.sqrt(dx * dx + dy * dy);

    if (dist < avoidCreatureRadius && dist > 0) {
      final strength = (1.0 - dist / avoidCreatureRadius) * 2.0;
      return _Vec2((dx / dist) * strength, (dy / dist) * strength);
    }
    return _Vec2(0, 0);
  }

  static void _moveToward(
    UltraballPlayer p,
    double tx,
    double ty,
    _Vec2 avoid,
  ) {
    final dx = tx - p.x;
    final dy = ty - p.y;
    final dist = math.sqrt(dx * dx + dy * dy);

    if (dist < 0.5) {
      p.velX = avoid.x * p.speed;
      p.velY = avoid.y * p.speed;
      return;
    }

    var vx = (dx / dist) + avoid.x;
    var vy = (dy / dist) + avoid.y;

    // Normalize combined vector
    final len = math.sqrt(vx * vx + vy * vy);
    if (len > 0) {
      vx = (vx / len) * p.speed;
      vy = (vy / len) * p.speed;
    }

    p.velX = vx;
    p.velY = vy;
  }

  static void _moveToStrategicPosition(
    UltraballPlayer opp,
    GameState gs,
    _Vec2 avoid,
  ) {
    // Position near midfield ready to attack
    final targetX = 55.0 + (opp.rosterIndex % 4) * 8.0;
    final targetY = 8.0 + (opp.rosterIndex % 5) * 7.0;
    _moveToward(opp, targetX, targetY, avoid);
  }

  static UltraballPlayer? _findClosestToPoint(
    List<UltraballPlayer> players,
    double x,
    double y,
  ) {
    if (players.isEmpty) return null;
    UltraballPlayer? closest;
    double closestDist = double.infinity;

    for (final p in players) {
      if (!p.isAlive) continue;
      final dx = p.x - x;
      final dy = p.y - y;
      final dist = dx * dx + dy * dy;
      if (dist < closestDist) {
        closestDist = dist;
        closest = p;
      }
    }
    return closest;
  }
}

class _Vec2 {
  final double x, y;
  _Vec2(this.x, this.y);
}
