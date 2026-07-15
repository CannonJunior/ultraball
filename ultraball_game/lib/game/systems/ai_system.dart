import 'dart:math' as math;
import '../../models/player.dart';
import '../../models/game_settings.dart';
import '../../ai/ai_strategy.dart';
import '../game_state.dart';
import 'combat_system.dart';
import 'ball_system.dart';

class AiSystem {
  static const double avoidCreatureRadius = 6.0;
  static const double _avoidRadiusSq     = avoidCreatureRadius * avoidCreatureRadius;

  // Enemies within this radius of the holder count as pressure
  static const double _pressureRadius   = 5.0;
  static const double _pressureRadiusSq = _pressureRadius * _pressureRadius;

  // Fraction of effectiveMaxCharge at which the holder urgently wants to pass
  static const double _chargeDangerFrac = 0.55;

  // AI attacks anyone within this range (tackle/slam check range internally)
  static const double _attackScanSq = 16.0; // 4 m²

  // ─── Public entry ────────────────────────────────────────────────────────

  static void update(GameState gs, double dt) {
    if (!gs.actState.isActive || gs.actState.gameOver) return;
    if (gs.settings.matchMode == MatchMode.threeTeams) {
      if (!gs.settings.testMode) {
        _update3TeamAI(gs, dt, Team.opponent);
        _update3TeamAI(gs, dt, Team.third);
      }
      _update3TeamFriendlyAI(gs, dt);
      return;
    }
    if (!gs.settings.testMode) _updateOpponentAI(gs, dt);
    _updateFriendlyAI(gs, dt);
  }

  // ─── OPPONENT AI ─────────────────────────────────────────────────────────

  static void _updateOpponentAI(GameState gs, double dt) {
    final opponents  = gs.getTeamOnField(Team.opponent);
    final playerTeam = gs.getTeamOnField(Team.player);
    final ball       = gs.ball;
    final policy     = gs.activePolicy;
    final tactics    = gs.effectiveAiTactics;
    final strategy   = gs.effectiveAiStrategy;

    // Pre-sort opponents by distance to holder for defense ranking
    final holderForSort = gs.getPlayerById(ball.holderId ?? '');
    Map<String, int>? defenseRankMap;
    if (ball.possessingTeamId != 'opponent' && holderForSort != null) {
      final sorted = opponents..sort((a, b) {
          final ax = (a.x - holderForSort.x).abs() + (a.y - holderForSort.y).abs();
          final bx = (b.x - holderForSort.x).abs() + (b.y - holderForSort.y).abs();
          return ax.compareTo(bx);
        });
      defenseRankMap = {for (int i = 0; i < sorted.length; i++) sorted[i].id: i};
    }

    // Count defenders threatening the opponent's ball holder (pressure)
    int holderPressure = 0;
    if (ball.holderId != null && ball.possessingTeamId == 'opponent') {
      final holder = gs.getPlayerById(ball.holderId!);
      if (holder != null) {
        for (final p in playerTeam) {
          if (!p.isAlive || p.isStunned) continue;
          final dx = p.x - holder.x;
          final dy = p.y - holder.y;
          if (dx * dx + dy * dy < _pressureRadiusSq) holderPressure++;
        }
      }
    }

    // When a friendly pass is in-flight, teammates should converge to catch it.
    // FloodEndzone uses multiple catchers (all players already in the endzone area
    // plus the closest overall); other strategies use only the single closest.
    final inFlightChaserSet = <String>{};
    if (ball.isInFlight && ball.possessingTeamId == 'opponent') {
      final closest = _findClosestToPoint(opponents, ball.x, ball.y);
      if (closest != null) inFlightChaserSet.add(closest.id);
      if (strategy == AiStrategy.floodEndzone) {
        for (final o in opponents) {
          if (o.isAlive && !o.isStunned && o.x >= 105.0) {
            inFlightChaserSet.add(o.id);
          }
        }
      }
    }

    // For NumericalEdge / FocusFire: pre-select the single weakest player-team target
    UltraballPlayer? focusTarget;
    if (strategy == AiStrategy.numericalEdge || tactics == AiTactics.focusFire) {
      focusTarget = _findWeakestAlive(playerTeam);
    }

    for (final opp in opponents) {
      if (!opp.isAlive || opp.isStunned) {
        opp.velX = 0;
        opp.velY = 0;
        continue;
      }

      // Confused: move erratically
      if (opp.confusedTimer > 0) {
        opp.velX = math.sin(opp.confusedTimer * 7.3) * opp.speed;
        opp.velY = math.cos(opp.confusedTimer * 5.1) * opp.speed;
        continue;
      }

      final avoid = _getAvoidance(gs, opp);

      if (ball.holderId == null && !ball.isInFlight) {
        // ── Ball loose ──
        final closest = _findClosestToPoint(opponents, ball.x, ball.y);
        if (closest?.id == opp.id) {
          _moveToward(opp, ball.x, ball.y, avoid);
        } else {
          _moveToStrategicPosition(opp, gs, avoid, strategy);
        }
        _tryAttackNearest(gs, opp, playerTeam, focusTarget);

      } else if (ball.possessingTeamId == 'opponent') {
        // ── Opponent has ball ──
        if (ball.holderId == opp.id) {
          _opponentHolderBehavior(opp, gs, avoid, opponents, playerTeam,
              holderPressure, policy, tactics, strategy);
        } else if (inFlightChaserSet.contains(opp.id)) {
          // Chase in-flight ball to catch it
          _moveToward(opp, ball.x, ball.y, avoid);
        } else {
          _opponentSupportBehavior(opp, gs, avoid, playerTeam,
              policy, tactics, strategy);
        }
        _tryAttackNearest(gs, opp, playerTeam, focusTarget);

      } else {
        // ── Player has ball — defend ──
        final myRank = defenseRankMap?[opp.id] ?? 0;
        _opponentDefenseBehavior(opp, gs, avoid, myRank, opponents, playerTeam,
            policy, tactics, strategy, focusTarget);
      }

      _tryUseSprint(gs, opp);
      _tryUseHealing(gs, opp);

      opp.x = opp.x.clamp(0.0, 140.0);
      opp.y = opp.y.clamp(0.0, 40.0);
    }
  }

  // ── Opponent holder ──────────────────────────────────────────────────────

  static void _opponentHolderBehavior(
    UltraballPlayer opp,
    GameState gs,
    _Vec2 avoid,
    List<UltraballPlayer> teammates,
    List<UltraballPlayer> defenders,
    int pressure,
    dynamic policy,
    AiTactics tactics,
    AiStrategy strategy,
  ) {
    final filteredTM = teammates
        .where((p) => p.id != opp.id && p.isAlive && !p.isStunned)
        .toList();

    final passEagerness    = policy?.passEagerness    as double? ?? 0.5;
    final endzonePressure  = policy?.endzonePressure  as double? ?? 0.7;
    final aggression       = policy?.aggression       as double? ?? 0.5;

    // Opponent scores by entering x >= 120 (right endzone)
    final targetX = 122.0 + endzonePressure * 16.0;
    // passThreshold: how far ahead a teammate must be to trigger a pass
    // QuickRelease always passes eagerly; PossessionBleed only when safe
    final passThreshold = (tactics == AiTactics.quickRelease)
        ? 1.0
        : 5.0 - passEagerness * 3.0;

    final chargeRatio = gs.ball.chargeTimer / gs.ball.effectiveMaxCharge;
    final chargeDanger = chargeRatio > _chargeDangerFrac;

    // ── FloodEndzone: throw-first strategy ──────────────────────────────────
    // Find the most open receiver (endzone preferred), tolerating up to 2 nearby
    // defenders so the team actually throws rather than running every time.
    if (strategy == AiStrategy.floodEndzone) {
      UltraballPlayer? floodTarget;
      double floodBestScore = -double.infinity;

      for (final tm in filteredTM) {
        if (tm.x < opp.x + 3.0) continue; // must be at least 3m ahead
        int nearDefs = 0;
        double closestDefDistSq = double.infinity;
        for (final d in defenders) {
          if (!d.isAlive || d.isStunned) continue;
          final dx = d.x - tm.x;
          final dy = d.y - tm.y;
          final dSq = dx * dx + dy * dy;
          if (dSq < 49.0) nearDefs++; // 7m coverage radius
          if (dSq < closestDefDistSq) closestDefDistSq = dSq;
        }
        if (nearDefs > 2) continue; // allow up to 2 defenders — flood beats coverage
        final endzoneBonus  = tm.x >= 112.0 ? 25.0 : 0.0;
        final advanceScore  = tm.x - opp.x;
        final opennessScore = (math.sqrt(closestDefDistSq) / 10.0).clamp(0.0, 2.0);
        final score = advanceScore + opennessScore + endzoneBonus;
        if (score > floodBestScore) {
          floodBestScore = score;
          floodTarget    = tm;
        }
      }

      if (floodTarget != null) {
        _aiPassTo(gs, opp, floodTarget);
      } else {
        // No open receiver yet — advance toward endzone to close the gap
        _moveToward(opp, targetX, _openLaneY(opp, defenders), avoid);
      }
      CombatSystem.tryAttack(gs, opp, 'tackle');
      if (aggression > 0.5 && opp.redMana >= 20) CombatSystem.tryAttack(gs, opp, 'slam');
      return;
    }

    UltraballPlayer? bestPass;
    double bestScore = -double.infinity;

    for (final tm in filteredTM) {
      // Teammate must be ahead (higher X) by passThreshold, or charge is critical
      if (tm.x < opp.x + (chargeDanger ? -5.0 : passThreshold)) continue;

      // Count defenders near the receiver and find closest
      int nearDefs = 0;
      double closestDefDistSq = double.infinity;
      for (final d in defenders) {
        if (!d.isAlive || d.isStunned) continue;
        final dx = d.x - tm.x;
        final dy = d.y - tm.y;
        final dSq = dx * dx + dy * dy;
        if (dSq < 25.0) nearDefs++;  // 5 m guard radius
        if (dSq < closestDefDistSq) closestDefDistSq = dSq;
      }

      // Allow one nearby defender when charge is dangerous
      final maxDefs = chargeDanger ? 1 : 0;
      if (nearDefs > maxDefs) continue;

      final advanceScore  = tm.x - opp.x;
      final opennessScore = (math.sqrt(closestDefDistSq) / 10.0).clamp(0.0, 2.0);
      final score = advanceScore + opennessScore;
      if (score > bestScore) {
        bestScore = score;
        bestPass = tm;
      }
    }

    // Under heavy pressure with no clean pass, take any open teammate
    if (bestPass == null && pressure >= 2) {
      for (final tm in filteredTM) {
        int nearDefs = 0;
        for (final d in defenders) {
          if (!d.isAlive) continue;
          final dx = d.x - tm.x;
          final dy = d.y - tm.y;
          if (dx * dx + dy * dy < 16.0) nearDefs++;
        }
        if (nearDefs == 0) { bestPass = tm; break; }
      }
    }

    if (bestPass != null) {
      _aiPassTo(gs, opp, bestPass);
    } else {
      // Run toward endzone — pick open Y lane when pressured
      final laneY = (pressure >= 2 || tactics == AiTactics.wedgeRun)
          ? _openLaneY(opp, defenders)
          : 20.0;
      _moveToward(opp, targetX, laneY, avoid);
    }

    // Holder fights back against nearby defenders
    CombatSystem.tryAttack(gs, opp, 'tackle');
    if (aggression > 0.5 && opp.redMana >= 20) {
      CombatSystem.tryAttack(gs, opp, 'slam');
    }
  }

  // ── Opponent support ─────────────────────────────────────────────────────

  static void _opponentSupportBehavior(
    UltraballPlayer opp,
    GameState gs,
    _Vec2 avoid,
    List<UltraballPlayer> defenders,
    dynamic policy,
    AiTactics tactics,
    AiStrategy strategy,
  ) {
    final holder = gs.getPlayerById(gs.ball.holderId ?? '');
    if (holder == null) return;

    final cohesion      = policy?.cohesion      as double? ?? 0.5;
    final passEagerness = policy?.passEagerness as double? ?? 0.5;

    double targetX, targetY;

    // Y lane based on roster index for natural spread
    final laneY = 5.0 + (opp.rosterIndex % 5) * 7.0;

    switch (tactics) {
      case AiTactics.pickAndScreen:
        // rosterIndex % 3 == 0,1: screen between holder and nearest defender
        // rosterIndex % 3 == 2:  run ahead as a pass option
        if (opp.rosterIndex % 3 < 2) {
          final screen = _nearestEnemy(holder, defenders);
          if (screen != null) {
            targetX = (holder.x + screen.x) / 2.0;
            targetY = (holder.y + screen.y) / 2.0;
          } else {
            targetX = holder.x + 5.0;
            targetY = laneY;
          }
        } else {
          final spread = 10.0 + (1.0 - cohesion) * 8.0;
          targetX = holder.x + spread;
          targetY = laneY;
        }

      case AiTactics.wedgeRun:
        // Tight triangle: front-center, back-left, back-right
        const offsets = [
          (dx: 5.0, dy: 0.0),
          (dx: -3.0, dy: -4.0),
          (dx: -3.0, dy: 4.0),
        ];
        final off = offsets[opp.rosterIndex % 3];
        targetX = holder.x + off.dx;
        targetY = holder.y + off.dy;

      case AiTactics.quickRelease:
        // Wide spread ahead so there's always an open receiver
        // passEagerness drives spread distance: high eagerness = spread wider
        final spread = 10.0 + passEagerness * 10.0 + (opp.rosterIndex % 3) * 5.0;
        targetX = holder.x + spread;
        targetY = laneY;

      case AiTactics.creatureFlank:
        // Opposite side of creature from holder to escort the herding line
        final cY = gs.creature.y;
        final sideY = (holder.y < cY) ? laneY.clamp(22.0, 38.0) : laneY.clamp(2.0, 18.0);
        final spread = 8.0 + (opp.rosterIndex % 3) * 6.0;
        targetX = holder.x + spread;
        targetY = sideY;

      case AiTactics.heroBall:
        // All support units pack tightly around the ball holder
        const heroOffsets = [
          (dx:  3.0, dy: -4.0),
          (dx:  3.0, dy:  4.0),
          (dx: -4.0, dy: -3.0),
          (dx: -4.0, dy:  3.0),
          (dx:  0.0, dy: -5.0),
          (dx:  0.0, dy:  5.0),
        ];
        final off = heroOffsets[opp.rosterIndex % heroOffsets.length];
        targetX = holder.x + off.dx;
        targetY = holder.y + off.dy;

      default: // focusFire and fallback
        final spread = 8.0 + (1.0 - cohesion) * 8.0;
        targetX = holder.x + spread + (opp.rosterIndex % 3) * 4.0;
        targetY = laneY;
    }

    // FloodEndzone: pre-position players at staggered endzone slots so there are
    // always live receivers when the holder looks to throw.
    if (strategy == AiStrategy.floodEndzone) {
      // Six distinct positions — each support player occupies a different slot
      // based on their roster index, creating spread coverage across the endzone.
      const double deep  = 135.0;
      const double mid   = 124.0;
      const double near  = 114.0;
      const double short = 10.0; // distance ahead of holder (used below)
      final positions = [
        (x: near,  y: laneY),            // 0: near-endzone entry point
        (x: mid,   y:  5.0),             // 1: mid-endzone top lane
        (x: deep,  y: 12.0),             // 2: deep endzone top
        (x: mid,   y: 20.0),             // 3: mid-endzone center
        (x: deep,  y: 28.0),             // 4: deep endzone bottom
        (x: near,  y: 35.0),             // 5: near-endzone bottom lane
      ];
      final slot = opp.rosterIndex % positions.length;
      final pos  = positions[slot];
      // Outlet slot stays close to the holder for a safe short dump-off pass
      if (slot == 0 && pos.x > holder.x + short) {
        targetX = holder.x + short;
        targetY = laneY;
      } else {
        targetX = pos.x;
        targetY = pos.y;
      }
    }

    // PossessionBleed: support stays closer to holder for safe dump-off passes
    if (strategy == AiStrategy.possessionBleed) {
      targetX = (targetX + holder.x) / 2.0;
    }

    _moveToward(opp, targetX.clamp(30.0, 138.0), targetY.clamp(2.0, 38.0), avoid);
  }

  // ── Opponent defense ─────────────────────────────────────────────────────

  static void _opponentDefenseBehavior(
    UltraballPlayer opp,
    GameState gs,
    _Vec2 avoid,
    int myRank,
    List<UltraballPlayer> teammates,
    List<UltraballPlayer> playerTeam,
    dynamic policy,
    AiTactics tactics,
    AiStrategy strategy,
    UltraballPlayer? focusTarget,
  ) {
    final holder        = gs.getPlayerById(gs.ball.holderId ?? '');
    final aggression    = policy?.aggression      as double? ?? 0.5;
    final passEagerness = policy?.passEagerness   as double? ?? 0.5;
    final creatureHerd  = policy?.creatureHerding as double? ?? 0.3;
    final rushers       = 1 + (aggression * 2).round();

    if (holder != null && myRank < rushers) {
      // ── Rusher: chase the carrier ──
      if (tactics == AiTactics.focusFire && focusTarget != null) {
        // Converge on the single weakest target, not necessarily the holder
        opp.currentTargetId = focusTarget.id;
        _moveToward(opp, focusTarget.x, focusTarget.y, avoid);
        CombatSystem.tryAttack(gs, opp, 'tackle');
        if (opp.redMana >= 20) CombatSystem.tryAttack(gs, opp, 'slam');
      } else if (creatureHerd > 0.5 || tactics == AiTactics.creatureFlank) {
        opp.currentTargetId = holder.id;
        final c = gs.creature;
        final pushX = holder.x + (holder.x < c.x ? 8.0 : -8.0);
        final pushY = holder.y + (holder.y < c.y ? 6.0 : -6.0);
        _moveToward(opp, pushX.clamp(0.0, 140.0), pushY.clamp(0.0, 40.0), avoid);
        CombatSystem.tryAttack(gs, opp, 'tackle');
        if (aggression > 0.5 && opp.redMana >= 20) CombatSystem.tryAttack(gs, opp, 'slam');
      } else {
        opp.currentTargetId = holder.id;
        _moveToward(opp, holder.x, holder.y, avoid);
        CombatSystem.tryAttack(gs, opp, 'tackle');
        if (aggression > 0.5 && opp.redMana >= 20) CombatSystem.tryAttack(gs, opp, 'slam');
      }
    } else if (holder != null) {
      // ── Non-rusher: cover passing lanes ──
      // Player team runs LEFT (lower X), so their receivers are at lower X than holder
      final receivers = playerTeam
          .where((p) => p.isAlive && !p.isStunned && p.x < holder.x - 3.0)
          .toList()
        ..sort((a, b) => a.x.compareTo(b.x)); // most advanced first

      if (passEagerness > 0.5 && receivers.isNotEmpty) {
        // Cover the furthest-ahead receiver proportional to rank
        final coverIdx = (myRank - rushers) % receivers.length;
        final target = receivers[coverIdx];
        opp.currentTargetId = target.id;
        _moveToward(opp, target.x, target.y, avoid);
      } else {
        // Zone: halfway between holder and player's scoring zone (x=20)
        final defX = ((holder.x + 20.0) / 2.0).clamp(20.0, 100.0);
        final defY = holder.y + (opp.rosterIndex % 3 - 1) * 6.0;
        _moveToward(opp, defX, defY.clamp(2.0, 38.0), avoid);
      }

      // Non-rushers also attack anyone who wanders close
      CombatSystem.tryAttack(gs, opp, 'tackle');
    } else {
      // No known holder — defensive midfield position
      final defX = 80.0 + (opp.rosterIndex % 4) * 10.0;
      final defY = 5.0  + (opp.rosterIndex % 5) * 7.0;
      _moveToward(opp, defX.clamp(30.0, 119.0), defY.clamp(2.0, 38.0), avoid);
    }
  }

  // ─── 3-TEAM AI ───────────────────────────────────────────────────────────

  static void _update3TeamAI(GameState gs, double dt, Team myTeam) {
    final myPlayers = gs.getTeamOnField(myTeam);
    final ball      = gs.ball;
    final myTeamId  = myTeam == Team.opponent ? 'opponent' : 'third';

    final enemies = [
      if (myTeam != Team.player)   ...gs.getTeamOnField(Team.player),
      if (myTeam != Team.opponent) ...gs.getTeamOnField(Team.opponent),
      if (myTeam != Team.third)    ...gs.getTeamOnField(Team.third),
    ];

    final inFlightChaserSet = <String>{};
    if (ball.isInFlight && ball.possessingTeamId == myTeamId) {
      final closest = _findClosestToPoint(myPlayers, ball.x, ball.y);
      if (closest != null) inFlightChaserSet.add(closest.id);
    }

    final enemyHolder = gs.getPlayerById(ball.holderId ?? '');
    Map<String, int> defenseRankMap = {};
    if (ball.possessingTeamId != myTeamId && enemyHolder != null) {
      final sorted = myPlayers..sort((a, b) {
          final ad = (a.x-enemyHolder.x).abs() + (a.y-enemyHolder.y).abs();
          final bd = (b.x-enemyHolder.x).abs() + (b.y-enemyHolder.y).abs();
          return ad.compareTo(bd);
        });
      defenseRankMap = {for (int i = 0; i < sorted.length; i++) sorted[i].id: i};
    }

    int holderPressure = 0;
    if (ball.holderId != null && ball.possessingTeamId == myTeamId) {
      final holder = gs.getPlayerById(ball.holderId!);
      if (holder != null) {
        for (final e in enemies) {
          final dx = e.x - holder.x; final dy = e.y - holder.y;
          if (dx * dx + dy * dy < _pressureRadiusSq) holderPressure++;
        }
      }
    }

    for (final p in myPlayers) {
      if (!p.isAlive || p.isStunned) { p.velX = 0; p.velY = 0; continue; }
      final avoid = _getAvoidance(gs, p);

      if (ball.holderId == null && !ball.isInFlight) {
        final closest = _findClosestToPoint(myPlayers, ball.x, ball.y);
        if (closest?.id == p.id) {
          _moveToward(p, ball.x, ball.y, avoid);
        } else {
          _moveToward3TeamSupport(p, gs, avoid, myPlayers, enemies);
        }
        _tryAttackNearest(gs, p, enemies, null);

      } else if (ball.possessingTeamId == myTeamId) {
        if (ball.holderId == p.id) {
          _threeTeamHolderBehavior(p, gs, avoid, myPlayers, enemies, holderPressure);
        } else if (inFlightChaserSet.contains(p.id)) {
          _moveToward(p, ball.x, ball.y, avoid);
        } else {
          _moveToward3TeamSupport(p, gs, avoid, myPlayers, enemies);
        }
        _tryAttackNearest(gs, p, enemies, null);

      } else {
        final rank = defenseRankMap[p.id] ?? 0;
        if (rank < 2 && enemyHolder != null) {
          _moveToward(p, enemyHolder.x, enemyHolder.y, avoid);
          CombatSystem.tryAttack(gs, p, 'tackle');
        } else {
          final midX = (p.x + GameState.field3CX) / 2;
          final midY = (p.y + GameState.field3CY) / 2;
          _moveToward(p, midX, midY, avoid);
          _tryAttackNearest(gs, p, enemies, null);
        }
      }

      _tryUseSprint(gs, p);
      _tryUseHealing(gs, p);

      p.x = p.x.clamp(0.0, GameState.field3Size);
      p.y = p.y.clamp(0.0, GameState.field3Size);
    }
  }

  static void _threeTeamHolderBehavior(
    UltraballPlayer p,
    GameState gs,
    _Vec2 avoid,
    List<UltraballPlayer> teammates,
    List<UltraballPlayer> enemies,
    int pressure,
  ) {
    // Endzone center points: cx + normal * (chanOuter + 10)
    const endzoneTargets = [
      (110.0, 181.547),   // player endzone
      (171.96, 74.23),    // opponent endzone
      (48.04, 74.23),     // third endzone
    ];
    double bestDist = double.infinity;
    double targetX = endzoneTargets[0].$1;
    double targetY = endzoneTargets[0].$2;
    for (final (ex, ey) in endzoneTargets) {
      final dx = ex - p.x; final dy = ey - p.y;
      final d = dx*dx + dy*dy;
      if (d < bestDist) { bestDist = d; targetX = ex; targetY = ey; }
    }

    final filteredTM = teammates.where((t) => t.id != p.id && t.isAlive && !t.isStunned).toList();
    final chargeRatio  = gs.ball.chargeTimer / gs.ball.effectiveMaxCharge;
    final chargeDanger = chargeRatio > _chargeDangerFrac;

    UltraballPlayer? bestPass;
    double bestScore = -double.infinity;
    for (final tm in filteredTM) {
      final dx = tm.x - targetX; final dy = tm.y - targetY;
      final tmDistSq = dx*dx + dy*dy;
      final dx2 = p.x - targetX; final dy2 = p.y - targetY;
      final myDistSq = dx2*dx2 + dy2*dy2;
      if (!chargeDanger && tmDistSq >= myDistSq - 100) continue;
      int nearEnemies = 0;
      for (final e in enemies) {
        final ex = e.x - tm.x; final ey = e.y - tm.y;
        if (ex*ex + ey*ey < 25.0) nearEnemies++;
      }
      if (!chargeDanger && nearEnemies > 0) continue;
      final score = myDistSq - tmDistSq;
      if (score > bestScore) { bestScore = score; bestPass = tm; }
    }

    if (bestPass != null) {
      _aiPassTo(gs, p, bestPass);
    } else {
      _moveToward(p, targetX, targetY, avoid);
    }
    CombatSystem.tryAttack(gs, p, 'tackle');
  }

  static void _moveToward3TeamSupport(
    UltraballPlayer p,
    GameState gs,
    _Vec2 avoid,
    List<UltraballPlayer> teammates,
    List<UltraballPlayer> enemies,
  ) {
    final holder = gs.getPlayerById(gs.ball.holderId ?? '');
    if (holder == null) {
      _moveToward(p, GameState.field3CX, GameState.field3CY, avoid);
      return;
    }
    const endzoneTargets = [
      (110.0, 181.547),
      (171.96, 74.23),
      (48.04, 74.23),
    ];
    double bestDist = double.infinity;
    double ex = endzoneTargets[0].$1, ey = endzoneTargets[0].$2;
    for (final (etx, ety) in endzoneTargets) {
      final dx = etx - holder.x; final dy = ety - holder.y;
      final d = dx*dx + dy*dy;
      if (d < bestDist) { bestDist = d; ex = etx; ey = ety; }
    }
    final frac = 0.3 + (p.rosterIndex % 3) * 0.2;
    final targetX = (holder.x + (ex - holder.x) * frac).clamp(0.0, GameState.field3Size);
    final targetY = (holder.y + (ey - holder.y) * frac).clamp(0.0, GameState.field3Size);
    _moveToward(p, targetX, targetY, avoid);
  }

  static void _update3TeamFriendlyAI(GameState gs, double dt) {
    final players = gs.getTeamOnField(Team.player)
        .where((p) => !p.isPlayerControlled)
        .toList();
    final ball = gs.ball;
    final enemies = [
      ...gs.getTeamOnField(Team.opponent),
      ...gs.getTeamOnField(Team.third),
    ];

    final inFlightChaserId = (ball.isInFlight && ball.possessingTeamId == 'player')
        ? _findClosestToPoint(players, ball.x, ball.y)?.id
        : null;

    int holderPressure = 0;
    if (ball.holderId != null && ball.possessingTeamId == 'player') {
      final holder = gs.getPlayerById(ball.holderId!);
      if (holder != null) {
        for (final e in enemies) {
          final dx = e.x - holder.x; final dy = e.y - holder.y;
          if (dx * dx + dy * dy < _pressureRadiusSq) holderPressure++;
        }
      }
    }

    for (final p in players) {
      if (!p.isAlive || p.isStunned) { p.velX = 0; p.velY = 0; continue; }
      final avoid = _getAvoidance(gs, p);

      if (ball.possessingTeamId == 'player') {
        if (ball.holderId == p.id) {
          _threeTeamHolderBehavior(p, gs, avoid, players, enemies, holderPressure);
        } else if (inFlightChaserId == p.id) {
          _moveToward(p, ball.x, ball.y, avoid);
        } else {
          _moveToward3TeamSupport(p, gs, avoid, players, enemies);
        }
        _tryAttackNearest(gs, p, enemies, null);
      } else if (ball.holderId == null && !ball.isInFlight) {
        final nearest = _findClosestToPoint(players, ball.x, ball.y);
        if (nearest?.id == p.id) {
          _moveToward(p, ball.x, ball.y, avoid);
        } else {
          _moveToward(p, GameState.field3CX, GameState.field3CY, avoid);
        }
        _tryAttackNearest(gs, p, enemies, null);
      } else {
        final enemyHolder = gs.getPlayerById(ball.holderId ?? '');
        if (enemyHolder != null) {
          _moveToward(p, enemyHolder.x, enemyHolder.y, avoid);
          CombatSystem.tryAttack(gs, p, 'tackle');
        }
      }

      _tryUseSprint(gs, p);
      _tryUseHealing(gs, p);
      p.x = p.x.clamp(0.0, GameState.field3Size);
      p.y = p.y.clamp(0.0, GameState.field3Size);
    }
  }

  // ─── FRIENDLY AI ─────────────────────────────────────────────────────────

  static void _updateFriendlyAI(GameState gs, double dt) {
    final players   = gs.getTeamOnField(Team.player)
        .where((p) => !p.isPlayerControlled)
        .toList();
    final opponents = gs.getTeamOnField(Team.opponent);
    final ball      = gs.ball;
    final tactics   = gs.settings.homeTactics;
    final strategy  = gs.settings.homeStrategy;

    // Count enemy pressure on the friendly ball holder
    int holderPressure = 0;
    if (ball.holderId != null && ball.possessingTeamId == 'player') {
      final holder = gs.getPlayerById(ball.holderId!);
      if (holder != null) {
        for (final o in opponents) {
          if (!o.isAlive || o.isStunned) continue;
          final dx = o.x - holder.x;
          final dy = o.y - holder.y;
          if (dx * dx + dy * dy < _pressureRadiusSq) holderPressure++;
        }
      }
    }

    // Nearest AI player to in-flight ball chases it to catch
    String? inFlightChaserId;
    if (ball.isInFlight && ball.possessingTeamId == 'player') {
      inFlightChaserId = _findClosestToPoint(players, ball.x, ball.y)?.id;
    }

    // Pre-sort friendlies by distance to opponent holder for defense ranking
    final oppHolder = gs.getPlayerById(ball.holderId ?? '');
    Map<String, int> friendlyDefenseRankMap = {};
    if (ball.possessingTeamId == 'opponent' && oppHolder != null) {
      final sorted = players..sort((a, b) {
          final ax = (a.x - oppHolder.x).abs() + (a.y - oppHolder.y).abs();
          final bx = (b.x - oppHolder.x).abs() + (b.y - oppHolder.y).abs();
          return ax.compareTo(bx);
        });
      friendlyDefenseRankMap = {for (int i = 0; i < sorted.length; i++) sorted[i].id: i};
    }

    // Hero Ball: pre-select weakest opponent to focus-fire for protection
    UltraballPlayer? friendlyFocusTarget;
    if (tactics == AiTactics.focusFire) {
      friendlyFocusTarget = _findWeakestAlive(opponents);
    }

    for (final p in players) {
      if (!p.isAlive || p.isStunned) {
        p.velX = 0;
        p.velY = 0;
        continue;
      }

      // Confused: move erratically
      if (p.confusedTimer > 0) {
        p.velX = math.sin(p.confusedTimer * 7.3) * p.speed;
        p.velY = math.cos(p.confusedTimer * 5.1) * p.speed;
        continue;
      }

      final avoid = _getAvoidance(gs, p);

      if (ball.possessingTeamId == 'player') {
        final holder = gs.getPlayerById(ball.holderId ?? '');
        if (ball.holderId == p.id) {
          _friendlyHolderBehavior(
              p, gs, avoid, players, opponents, holderPressure, tactics, strategy);
        } else if (inFlightChaserId == p.id) {
          _moveToward(p, ball.x, ball.y, avoid);
        } else if (holder != null) {
          _friendlySupportBehavior(
              p, gs, avoid, holder, players, opponents, tactics, strategy);
        }
        _tryAttackNearest(gs, p, opponents, friendlyFocusTarget);

      } else if (ball.holderId == null && !ball.isInFlight) {
        final nearest = _findClosestToPoint(players, ball.x, ball.y);
        if (nearest?.id == p.id) {
          _moveToward(p, ball.x, ball.y, avoid);
        } else {
          final midX = 50.0 + (p.rosterIndex % 4) * 10.0;
          final midY = 5.0  + (p.rosterIndex % 5) * 7.0;
          _moveToward(p, midX.clamp(30.0, 110.0), midY.clamp(2.0, 38.0), avoid);
        }
        _tryAttackNearest(gs, p, opponents, friendlyFocusTarget);

      } else {
        // Opponent has ball — defend
        if (oppHolder != null) {
          final myRank = friendlyDefenseRankMap[p.id] ?? 0;
          _friendlyDefenseBehavior(
              p, gs, avoid, myRank, oppHolder, players, opponents, tactics);
        }
      }

      _tryUseSprint(gs, p);
      _tryUseHealing(gs, p);

      p.x = p.x.clamp(0.0, 140.0);
      p.y = p.y.clamp(0.0, 40.0);
    }
  }

  // ── Friendly holder ──────────────────────────────────────────────────────

  static void _friendlyHolderBehavior(
    UltraballPlayer p,
    GameState gs,
    _Vec2 avoid,
    List<UltraballPlayer> teammates,
    List<UltraballPlayer> opponents,
    int pressure,
    AiTactics tactics,
    AiStrategy strategy,
  ) {
    // Hero Ball: pass to the player character only when they're ahead toward scoring
    if (tactics == AiTactics.heroBall) {
      final hero = gs.selectedPlayer;
      if (hero != null && hero.id != p.id && hero.isAlive && !hero.isStunned) {
        // Only dump to hero if hero is meaningfully ahead (lower X = toward left endzone)
        if (hero.x < p.x - 3.0) {
          _aiPassTo(gs, p, hero);
          CombatSystem.tryAttack(gs, p, 'tackle');
          return;
        }
      }
    }

    final filteredTM = teammates
        .where((t) => t.id != p.id && t.isAlive && !t.isStunned)
        .toList();

    final chargeRatio  = gs.ball.chargeTimer / gs.ball.effectiveMaxCharge;
    final chargeDanger = chargeRatio > _chargeDangerFrac;

    // Player team scores at LOW X (left endzone x<=20), so "ahead" = lower X
    UltraballPlayer? bestPass;
    double bestScore = -double.infinity;

    for (final tm in filteredTM) {
      // Must be ahead toward endzone (lower X) by at least 3m, or charge critical
      if (!chargeDanger && tm.x > p.x - 3.0) continue;

      int nearOpp = 0;
      double closestOppDistSq = double.infinity;
      for (final o in opponents) {
        if (!o.isAlive || o.isStunned) continue;
        final dx = o.x - tm.x;
        final dy = o.y - tm.y;
        final dSq = dx * dx + dy * dy;
        if (dSq < 25.0) nearOpp++;
        if (dSq < closestOppDistSq) closestOppDistSq = dSq;
      }
      final maxNear = chargeDanger ? 1 : 0;
      if (nearOpp > maxNear) continue;

      // Higher score = more advanced + more open
      final advanceScore  = p.x - tm.x;
      final opennessScore = (math.sqrt(closestOppDistSq) / 10.0).clamp(0.0, 2.0);
      final score = advanceScore + opennessScore;
      if (score > bestScore) {
        bestScore = score;
        bestPass = tm;
      }
    }

    // Under heavy pressure, take any open teammate regardless of position
    if (bestPass == null && pressure >= 2) {
      for (final tm in filteredTM) {
        int nearOpp = 0;
        for (final o in opponents) {
          if (!o.isAlive) continue;
          final dx = o.x - tm.x;
          final dy = o.y - tm.y;
          if (dx * dx + dy * dy < 16.0) nearOpp++;
        }
        if (nearOpp == 0) { bestPass = tm; break; }
      }
    }

    // PossessionBleed: eagerly dump off even behind the line of scrimmage
    final targetX = (strategy == AiStrategy.possessionBleed) ? 5.0 : 10.0;

    if (bestPass != null) {
      _aiPassTo(gs, p, bestPass);
    } else {
      final laneY = pressure >= 2 ? _openLaneY(p, opponents) : 20.0;
      _moveToward(p, targetX, laneY, avoid);
    }

    CombatSystem.tryAttack(gs, p, 'tackle');
  }

  // ── Friendly support ─────────────────────────────────────────────────────

  static void _friendlySupportBehavior(
    UltraballPlayer p,
    GameState gs,
    _Vec2 avoid,
    UltraballPlayer holder,
    List<UltraballPlayer> teammates,
    List<UltraballPlayer> opponents,
    AiTactics tactics,
    AiStrategy strategy,
  ) {
    final laneY = 5.0 + (p.rosterIndex % 5) * 7.0;
    double targetX, targetY;

    switch (tactics) {
      case AiTactics.heroBall:
        // One in three players runs ahead as a scoring threat; others escort the hero
        final hero = gs.selectedPlayer;
        if (hero != null && hero.isAlive) {
          if (p.rosterIndex % 3 == 0 && hero.x > 22.0) {
            // Scoring runner: 20m ahead of hero (capped at x=8 deep in endzone)
            targetX = math.max(8.0, hero.x - 20.0);
            targetY = laneY;
          } else {
            // Remaining players escort tightly, biased forward (negative dx = toward endzone)
            const offsets = [
              (dx: -4.0, dy: -3.0),
              (dx: -4.0, dy:  3.0),
              (dx:  3.0, dy: -4.0),
              (dx:  3.0, dy:  4.0),
              (dx: -2.0, dy: -5.0),
              (dx: -2.0, dy:  5.0),
            ];
            final off = offsets[p.rosterIndex % offsets.length];
            targetX = hero.x + off.dx;
            targetY = hero.y + off.dy;
          }
        } else {
          targetX = holder.x - 10.0 - (p.rosterIndex % 3) * 8.0;
          targetY = laneY;
        }

      case AiTactics.wedgeRun:
        // Tight triangle moving left with the holder
        const offsets = [
          (dx: -5.0, dy:  0.0),
          (dx:  3.0, dy: -4.0),
          (dx:  3.0, dy:  4.0),
        ];
        final off = offsets[p.rosterIndex % 3];
        targetX = holder.x + off.dx;
        targetY = holder.y + off.dy;

      case AiTactics.quickRelease:
        // Wide spread ahead for chained passes
        final spread = 10.0 + (p.rosterIndex % 3) * 8.0;
        targetX = holder.x - spread;
        targetY = laneY;

      case AiTactics.pickAndScreen:
        // Some screen for holder; others run decoy routes ahead
        if (p.rosterIndex % 3 < 2) {
          final screen = _nearestEnemy(holder, opponents);
          if (screen != null) {
            targetX = (holder.x + screen.x) / 2.0;
            targetY = (holder.y + screen.y) / 2.0;
          } else {
            targetX = holder.x - 5.0;
            targetY = laneY;
          }
        } else {
          targetX = holder.x - 15.0;
          targetY = laneY;
        }

      case AiTactics.creatureFlank:
        // Opposite side of creature from holder
        final cY = gs.creature.y;
        final sideY = (holder.y < cY)
            ? laneY.clamp(22.0, 38.0)
            : laneY.clamp(2.0, 18.0);
        targetX = holder.x - 8.0 - (p.rosterIndex % 3) * 6.0;
        targetY = sideY;

      default: // focusFire: spread for passing options, attack when close
        targetX = holder.x - 10.0 - (p.rosterIndex % 3) * 8.0;
        targetY = laneY;
    }

    // PossessionBleed: support stays closer to holder for safe dump-off
    if (strategy == AiStrategy.possessionBleed && tactics != AiTactics.heroBall) {
      targetX = (targetX + holder.x) / 2.0;
    }

    // FloodEndzone: mirror of opponent behavior — pre-position one runner deep in left endzone
    if (strategy == AiStrategy.floodEndzone && p.rosterIndex % 3 == 0) {
      targetX = 5.0;
    }

    _moveToward(p, targetX.clamp(0.0, 110.0), targetY.clamp(2.0, 38.0), avoid);
  }

  // ── Friendly defense ─────────────────────────────────────────────────────

  static void _friendlyDefenseBehavior(
    UltraballPlayer p,
    GameState gs,
    _Vec2 avoid,
    int myRank,
    UltraballPlayer oppHolder,
    List<UltraballPlayer> teammates,
    List<UltraballPlayer> opponents,
    AiTactics tactics,
  ) {
    // Hero Ball: rally around the player character and swarm threats near them
    if (tactics == AiTactics.heroBall) {
      final hero = gs.selectedPlayer;
      if (hero != null && hero.isAlive) {
        final nearestToHero = _nearestEnemy(hero, opponents);
        if (nearestToHero != null) {
          _moveToward(p, nearestToHero.x, nearestToHero.y, avoid);
          CombatSystem.tryAttack(gs, p, 'tackle');
          if (p.redMana >= 20) CombatSystem.tryAttack(gs, p, 'slam');
          return;
        }
      }
    }

    // 2 closest rush holder; others cover opponent receivers
    final rushers = (tactics == AiTactics.focusFire) ? 4 : 2;
    if (myRank < rushers) {
      _moveToward(p, oppHolder.x, oppHolder.y, avoid);
      CombatSystem.tryAttack(gs, p, 'tackle');
      if (p.redMana >= 20) CombatSystem.tryAttack(gs, p, 'slam');
    } else {
      // Cover opponent support players (intercept potential passes)
      final oppTeam = gs.getTeamOnField(Team.opponent);
      final oppSupports = oppTeam
          .where((o) => o.isAlive && !o.isStunned && o.id != oppHolder.id)
          .toList();
      if (oppSupports.isNotEmpty) {
        final coverIdx = (myRank - rushers) % oppSupports.length;
        final target = oppSupports[coverIdx];
        _moveToward(p, target.x, target.y, avoid);
        CombatSystem.tryAttack(gs, p, 'tackle');
        if (p.redMana >= 20) CombatSystem.tryAttack(gs, p, 'slam');
      } else {
        _moveToward(p, oppHolder.x + (p.rosterIndex % 3 - 1) * 5.0,
                    oppHolder.y + (p.rosterIndex % 3 - 1) * 5.0, avoid);
        CombatSystem.tryAttack(gs, p, 'tackle');
      }
    }
  }

  // ─── SHARED UTILITIES ────────────────────────────────────────────────────

  /// Pass to a target with first-order position prediction so the ball meets
  /// the receiver rather than landing where they were when the pass was thrown.
  static void _aiPassTo(
    GameState gs,
    UltraballPlayer thrower,
    UltraballPlayer target,
  ) {
    final dx   = target.x - thrower.x;
    final dy   = target.y - thrower.y;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist == 0) return;

    // Predict where the target will be when ball arrives
    final flightTime = dist / BallSystem.ballSpeed;
    final maxField = gs.settings.matchMode == MatchMode.threeTeams
        ? GameState.field3Size : 140.0;
    final maxFieldY = gs.settings.matchMode == MatchMode.threeTeams
        ? GameState.field3Size : 40.0;
    final rawPredX = (target.x + target.velX * flightTime).clamp(0.0, maxField);
    final predX = gs.settings.matchMode == MatchMode.threeTeams
        ? rawPredX
        : (thrower.team == Team.opponent
            ? rawPredX.clamp(30.0, 140.0)
            : rawPredX.clamp(0.0, 110.0));
    final predY = (target.y + target.velY * flightTime).clamp(0.0, maxFieldY);

    BallSystem.tryPass(gs, thrower, predX, predY, false);
  }

  /// Attack any enemy within scan range. Cooldown and exact range are
  /// enforced inside CombatSystem; this is just a proximity gate.
  static void _tryAttackNearest(
    GameState gs,
    UltraballPlayer attacker,
    List<UltraballPlayer> enemies,
    UltraballPlayer? focusTarget,
  ) {
    // If a focus target is set and they're alive nearby, prioritise them
    if (focusTarget != null && focusTarget.isAlive && !focusTarget.isStunned) {
      final dx = focusTarget.x - attacker.x;
      final dy = focusTarget.y - attacker.y;
      if (dx * dx + dy * dy < _attackScanSq * 4) {
        attacker.currentTargetId = focusTarget.id;
        CombatSystem.tryAttack(gs, attacker, 'tackle');
        if (attacker.redMana >= 20) CombatSystem.tryAttack(gs, attacker, 'slam');
        return;
      }
    }

    for (final e in enemies) {
      if (!e.isAlive || e.isStunned) continue;
      final dx = e.x - attacker.x;
      final dy = e.y - attacker.y;
      if (dx * dx + dy * dy < _attackScanSq) {
        attacker.currentTargetId = e.id;
        CombatSystem.tryAttack(gs, attacker, 'tackle');
        if (attacker.redMana >= 20) CombatSystem.tryAttack(gs, attacker, 'slam');
        return;
      }
    }
  }

  /// Activate sprint when chasing a loose ball or when the holder's charge
  /// is approaching the danger zone.
  static void _tryUseSprint(GameState gs, UltraballPlayer p) {
    if (p.speedBoostTimer > 0 || p.sprintCooldown > 0) return;
    final ball = gs.ball;
    bool sprint = false;

    if (ball.holderId == null && !ball.isInFlight) {
      final dx = p.x - ball.x;
      final dy = p.y - ball.y;
      if (dx * dx + dy * dy < 100.0) sprint = true; // within 10 m of loose ball
    }

    if (ball.holderId == p.id) {
      final ratio = ball.chargeTimer / ball.effectiveMaxCharge;
      if (ratio > 0.45) sprint = true; // charge building — sprint to score/pass
    }

    if (sprint) {
      // Geomancer's sprint is Upheaval (slot 8); every other class uses slot 3
      final sprintSlot = p.playerClass == PlayerClass.geomancer ? 8 : 3;
      CombatSystem.useClassAbility(gs, p, sprintSlot);
    }
  }

  /// Use healing and protective abilities based on class role.
  static void _tryUseHealing(GameState gs, UltraballPlayer p) {
    final hp = p.health / p.maxHealth;

    switch (p.playerClass) {
      case PlayerClass.archon:
        final allies = gs.getTeamOnField(p.team);
        // Rally (slot 9): AoE heal if 2+ nearby allies are wounded
        if (p.ability9Cooldown <= 0 && p.blueMana >= 50) {
          int wounded = 0;
          for (final a in allies) {
            if (!a.isAlive) continue;
            final dx = a.x - p.x, dy = a.y - p.y;
            if (dx * dx + dy * dy <= 49.0 && a.health / a.maxHealth < 0.75) wounded++;
          }
          if (wounded >= 2) { CombatSystem.useClassAbility(gs, p, 9); return; }
        }
        // Mend (slot 5): heal nearest ally below 72% HP
        if (p.ability5Cooldown <= 0 && p.blueMana >= 30) {
          final hasWounded = allies.any((a) {
            if (a.id == p.id || !a.isAlive) return false;
            final dx = a.x - p.x, dy = a.y - p.y;
            return dx * dx + dy * dy <= 25.0 && a.health / a.maxHealth < 0.72;
          });
          if (hasWounded) { CombatSystem.useClassAbility(gs, p, 5); return; }
        }
        // Second Wind (slot 7): self-heal when self is low
        if (p.ability7Cooldown <= 0 && p.blueMana >= 35 && hp < 0.55) {
          CombatSystem.useClassAbility(gs, p, 7); return;
        }
        // Fortify (slot 8): shield nearby ally who is taking heavy damage
        if (p.ability8Cooldown <= 0 && p.blueMana >= 30) {
          final hasLow = allies.any((a) {
            if (a.id == p.id || !a.isAlive) return false;
            final dx = a.x - p.x, dy = a.y - p.y;
            return dx * dx + dy * dy <= 25.0 && a.health / a.maxHealth < 0.60;
          });
          if (hasLow) { CombatSystem.useClassAbility(gs, p, 8); return; }
        }
        // Bulwark (slot 4): self damage reduction when critically low
        if (p.ability4Cooldown <= 0 && p.blueMana >= 25 && hp < 0.40) {
          CombatSystem.useClassAbility(gs, p, 4); return;
        }
        // Cleanse (slot 6): remove CC from nearby stunned/snared ally
        if (p.ability6Cooldown <= 0 && p.blueMana >= 20) {
          final hasCCd = allies.any((a) {
            if (!a.isAlive) return false;
            if (a.snareTimer <= 0 && !a.isStunned) return false;
            final dx = a.x - p.x, dy = a.y - p.y;
            return dx * dx + dy * dy <= 25.0;
          });
          if (hasCCd) CombatSystem.useClassAbility(gs, p, 6);
        }

      case PlayerClass.warden:
        final allies = gs.getTeamOnField(p.team);
        // Trauma Pack (slot 7): emergency heal critical ally
        if (p.ability7Cooldown <= 0 && p.blueMana >= 45) {
          final hasCritical = allies.any((a) {
            if (a.id == p.id || !a.isAlive) return false;
            final dx = a.x - p.x, dy = a.y - p.y;
            return dx * dx + dy * dy <= 25.0 && a.health / a.maxHealth < 0.40;
          });
          if (hasCritical) { CombatSystem.useClassAbility(gs, p, 7); return; }
        }
        // Field Medic (slot 4): heal wounded ally below 68% HP
        if (p.ability4Cooldown <= 0 && p.blueMana >= 30) {
          final hasWounded = allies.any((a) {
            if (a.id == p.id || !a.isAlive) return false;
            final dx = a.x - p.x, dy = a.y - p.y;
            return dx * dx + dy * dy <= 25.0 && a.health / a.maxHealth < 0.68;
          });
          if (hasWounded) CombatSystem.useClassAbility(gs, p, 4);
        }

      case PlayerClass.geomancer:
        // Earthmend (slot 7): self-heal when below 55%
        if (p.ability7Cooldown <= 0 && p.blueMana >= 35 && hp < 0.55) {
          CombatSystem.useClassAbility(gs, p, 7);
        }
        // Raise Hill (slot 2): use occasionally when near enemies
        if (p.slamCooldown <= 0 && p.redMana >= 25) {
          bool nearEnemy = false;
          for (final e in gs.fieldPlayers) {
            if (e.team == p.team || !e.isAlive) continue;
            final dx = e.x - p.x, dy = e.y - p.y;
            if (dx * dx + dy * dy <= 100.0) { nearEnemy = true; break; }
          }
          if (nearEnemy) CombatSystem.useClassAbility(gs, p, 2);
        }
        // Open Sinkhole (slot 4): use near enemy ball carrier
        if (p.ability4Cooldown <= 0 && p.redMana >= 35) {
          final holder = gs.getPlayerById(gs.ball.holderId ?? '');
          if (holder != null && holder.team != p.team) {
            final dx = holder.x - p.x, dy = holder.y - p.y;
            if (dx * dx + dy * dy <= 225.0) { // 15m
              // Face toward holder then fire
              p.facing = math.atan2(dy, dx);
              CombatSystem.useClassAbility(gs, p, 4);
            }
          }
        }

      case PlayerClass.spectre:
        // Clear Out (slot 7): self-heal + cleanse when low or CC'd
        if (p.ability7Cooldown <= 0 && p.blueMana >= 40) {
          if (hp < 0.50 || p.snareTimer > 0 || p.isStunned) {
            CombatSystem.useClassAbility(gs, p, 7);
          }
        }

      case PlayerClass.corsair:
        break;

      case PlayerClass.trickster:
        // Jinx (slot 7): drain enemy mana when a target is in range
        if (p.ability7Cooldown <= 0 && p.blueMana >= 25) {
          CombatSystem.useClassAbility(gs, p, 7);
        }
        // Chaos Fumble (slot 9): use near ball carrier
        if (p.ability9Cooldown <= 0 && p.redMana >= 30) {
          final holder = gs.getPlayerById(gs.ball.holderId ?? '');
          if (holder != null && holder.team != p.team) {
            final dx = holder.x - p.x, dy = holder.y - p.y;
            if (dx * dx + dy * dy <= 16.0) {
              CombatSystem.useClassAbility(gs, p, 9);
            }
          }
        }
        // Befuddle (slot 4): confuse enemies near ball carrier
        if (p.ability4Cooldown <= 0 && p.redMana >= 25) {
          CombatSystem.useClassAbility(gs, p, 4);
        }

      case PlayerClass.wrecker:
        // Sledge (slot 2): stun nearby enemies
        if (p.slamCooldown <= 0 && p.redMana >= 20) {
          CombatSystem.useClassAbility(gs, p, 2);
          return;
        }
        // Crumple (slot 4): heavy damage + snare
        if (p.ability4Cooldown <= 0 && p.redMana >= 25) {
          CombatSystem.useClassAbility(gs, p, 4);
          return;
        }
        // Spine Breaker (slot 6): big damage + long stun
        if (p.ability6Cooldown <= 0 && p.redMana >= 30) {
          CombatSystem.useClassAbility(gs, p, 6);
          return;
        }
        // Death Blow (slot 9): maximum single-target damage
        if (p.ability9Cooldown <= 0 && p.redMana >= 35) {
          CombatSystem.useClassAbility(gs, p, 9);
          return;
        }
    }
  }

  /// Creature avoidance force vector.
  static _Vec2 _getCreatureAvoidance(GameState gs, UltraballPlayer p) {
    final c  = gs.creature;
    final dx = p.x - c.x;
    final dy = p.y - c.y;
    final sq = dx * dx + dy * dy;
    if (sq < _avoidRadiusSq && sq > 0) {
      final dist     = math.sqrt(sq);
      final strength = (1.0 - dist / avoidCreatureRadius) * 2.0;
      return _Vec2((dx / dist) * strength, (dy / dist) * strength);
    }
    return _Vec2.zero;
  }

  /// Soft separation force away from nearby players (same and opposing team).
  /// Keeps AI paths from clumping before the hard CollisionSystem pass fires.
  static const double _playerAvoidRadius   = 2.5;
  static const double _playerAvoidRadiusSq = _playerAvoidRadius * _playerAvoidRadius;

  static _Vec2 _getPlayerAvoidance(GameState gs, UltraballPlayer p) {
    var ax = 0.0, ay = 0.0;
    for (final other in gs.fieldPlayers) {
      if (other.id == p.id || !other.isAlive) continue;
      final dx = p.x - other.x;
      final dy = p.y - other.y;
      final sq = dx * dx + dy * dy;
      if (sq < _playerAvoidRadiusSq && sq > 0) {
        final dist     = math.sqrt(sq);
        final strength = (1.0 - dist / _playerAvoidRadius) * 1.5;
        ax += (dx / dist) * strength;
        ay += (dy / dist) * strength;
      }
    }
    return _Vec2(ax, ay);
  }

  static _Vec2 _getAvoidance(GameState gs, UltraballPlayer p) {
    final c = _getCreatureAvoidance(gs, p);
    final pl = _getPlayerAvoidance(gs, p);
    return _Vec2(c.x + pl.x, c.y + pl.y);
  }

  /// Set velocity toward (tx, ty) at full speed, blended with creature avoidance.
  static void _moveToward(UltraballPlayer p, double tx, double ty, _Vec2 avoid) {
    final dx   = tx - p.x;
    final dy   = ty - p.y;
    final dist = math.sqrt(dx * dx + dy * dy);

    if (dist < 0.5) {
      p.velX = avoid.x * p.speed;
      p.velY = avoid.y * p.speed;
      return;
    }

    var vx = (dx / dist) + avoid.x;
    var vy = (dy / dist) + avoid.y;
    final len = math.sqrt(vx * vx + vy * vy);
    if (len > 0) {
      p.velX = (vx / len) * p.speed;
      p.velY = (vy / len) * p.speed;
    }
  }

  /// Strategic midfield positioning when ball is loose.
  static void _moveToStrategicPosition(
    UltraballPlayer opp,
    GameState gs,
    _Vec2 avoid,
    AiStrategy strategy,
  ) {
    // TempoTrap / NumericalEdge: stay aggressive in mid-to-attacking third
    final baseX = (strategy == AiStrategy.possessionBleed) ? 70.0 : 60.0;
    final targetX = baseX + (opp.rosterIndex % 4) * 10.0;
    final targetY = 5.0  + (opp.rosterIndex % 5) * 7.0;
    _moveToward(opp, targetX, targetY, avoid);
  }

  /// Y lane with fewest nearby enemies for the holder to run through.
  static double _openLaneY(UltraballPlayer holder, List<UltraballPlayer> enemies) {
    const lanes = [5.0, 12.0, 20.0, 28.0, 35.0];
    double best = 20.0;
    int fewest  = 999;
    for (final ly in lanes) {
      int count = 0;
      for (final e in enemies) {
        if (!e.isAlive || e.isStunned) continue;
        if ((e.y - ly).abs() < 8.0) count++;
      }
      if (count < fewest) { fewest = count; best = ly; }
    }
    return best;
  }

  /// Nearest alive+unstunned enemy to [source].
  static UltraballPlayer? _nearestEnemy(
    UltraballPlayer source,
    List<UltraballPlayer> enemies,
  ) {
    UltraballPlayer? nearest;
    double nearestSq = double.infinity;
    for (final e in enemies) {
      if (!e.isAlive || e.isStunned) continue;
      final dx = e.x - source.x;
      final dy = e.y - source.y;
      final sq = dx * dx + dy * dy;
      if (sq < nearestSq) { nearestSq = sq; nearest = e; }
    }
    return nearest;
  }

  /// Weakest (lowest health) alive enemy — used for FocusFire / NumericalEdge.
  static UltraballPlayer? _findWeakestAlive(List<UltraballPlayer> enemies) {
    UltraballPlayer? weakest;
    for (final e in enemies) {
      if (!e.isAlive || e.isStunned) continue;
      if (weakest == null || e.health < weakest.health) weakest = e;
    }
    return weakest;
  }

  static UltraballPlayer? _findClosestToPoint(
    List<UltraballPlayer> players,
    double x,
    double y,
  ) {
    UltraballPlayer? closest;
    double closestSq = double.infinity;
    for (final p in players) {
      if (!p.isAlive) continue;
      final dx = p.x - x;
      final dy = p.y - y;
      final sq = dx * dx + dy * dy;
      if (sq < closestSq) { closestSq = sq; closest = p; }
    }
    return closest;
  }
}

class _Vec2 {
  final double x, y;
  const _Vec2(this.x, this.y);
  static const zero = _Vec2(0, 0);
}
