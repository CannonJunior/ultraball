import 'dart:math' as math;
import '../game_state.dart';

/// Post-move player-to-player collision resolution.
///
/// Called each frame after all player.update(dt) and AI velocity writes, but
/// before BallSystem. Runs 3 successive separation passes over all alive field
/// players; each pass pushes overlapping circle pairs apart along their
/// centre-to-centre axis by half the penetration depth.  3 passes resolve
/// pile-ups of 3+ converging players without instability.
///
/// Players with active dodge frames (dodgeTimer > 0) are exempt — they are
/// mid-phase/blink and should pass through.
class CollisionSystem {
  static const double playerRadius = 1.0;
  static const double _minDist     = playerRadius * 2.0;
  static const double _minDistSq   = _minDist * _minDist;
  static const int    _passes      = 3;

  static void resolvePlayerCollisions(GameState gs) {
    final players = gs.fieldPlayers;

    for (int pass = 0; pass < _passes; pass++) {
      for (int i = 0; i < players.length; i++) {
        final a = players[i];
        if (!a.isAlive) continue;

        for (int j = i + 1; j < players.length; j++) {
          final b = players[j];
          if (!b.isAlive) continue;

          // Dodge frames = phase-through exemption
          if (a.dodgeTimer > 0 || b.dodgeTimer > 0) continue;

          final dx = b.x - a.x;
          final dy = b.y - a.y;
          final distSq = dx * dx + dy * dy;
          if (distSq >= _minDistSq) continue;

          final dist = distSq > 0.0001 ? math.sqrt(distSq) : 0.001;
          final overlap = _minDist - dist;
          final nx = dx / dist;
          final ny = dy / dist;
          final push = overlap * 0.5;

          a.x -= nx * push;
          a.y -= ny * push;
          b.x += nx * push;
          b.y += ny * push;

          // Re-clamp to field bounds after push
          a.x = a.x.clamp(0.0, GameState.fieldWidth);
          a.y = a.y.clamp(0.0, GameState.fieldHeight);
          b.x = b.x.clamp(0.0, GameState.fieldWidth);
          b.y = b.y.clamp(0.0, GameState.fieldHeight);
        }
      }
    }
  }
}
