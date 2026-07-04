import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:ultraball_game/game/systems/ball_system.dart';
import 'package:ultraball_game/models/player.dart';
import '../../helpers/game_state_factory.dart';

void main() {
  // ── tryChargedThrow ──────────────────────────────────────────────────────

  group('BallSystem.tryChargedThrow', () {
    test('sets ball physics correctly on release', () {
      final gs = makeGs();
      final p = gs.playerRoster.first;
      gs.ball.holderId = p.id;
      gs.ball.possessingTeamId = 'player';
      p.facing = 0.0;

      BallSystem.tryChargedThrow(gs, p);

      expect(gs.ball.isChargedThrow, isTrue);
      expect(gs.ball.isInFlight, isTrue);
      expect(gs.ball.holderId, isNull);
      expect(gs.ball.flightAge, equals(0.0));
      expect(gs.ball.velX,
          closeTo(math.cos(0.0) * BallSystem.throwHorizontalSpeed, 0.001));
      expect(gs.ball.velY,
          closeTo(math.sin(0.0) * BallSystem.throwHorizontalSpeed, 0.001));
    });

    test('is blocked when passCooldown > 0', () {
      final gs = makeGs();
      final p = gs.playerRoster.first;
      gs.ball.holderId = p.id;
      p.passCooldown = 0.5;

      BallSystem.tryChargedThrow(gs, p);

      expect(gs.ball.holderId, equals(p.id));
    });
  });

  // ── self-catch timing ────────────────────────────────────────────────────

  group('BallSystem.update — charged throw catch timing', () {
    test('self-catch is blocked for the first 0.2s', () {
      final gs = makeGs();
      final thrower = gs.playerRoster.first;
      gs.ball.holderId = thrower.id;
      gs.ball.possessingTeamId = 'player';
      thrower.facing = 0.0;

      BallSystem.tryChargedThrow(gs, thrower);
      expect(gs.ball.isChargedThrow, isTrue);

      // Place thrower on top of ball — within catchRadius=2.5
      thrower.x = gs.ball.x;
      thrower.y = gs.ball.y;

      // Advance 0.1s: flightAge < 0.2, catch must be blocked
      BallSystem.update(gs, 0.1);

      expect(gs.ball.holderId, isNull,
          reason: 'thrower must not self-catch before flightAge reaches 0.2s');
    });

    test('friendly catch is allowed once flightAge > 0.2 and zHeight < 1.5', () {
      final gs = makeGs();
      final thrower = gs.playerRoster.first;
      final receiver = gs.playerRoster.last; // same team
      gs.ball.holderId = thrower.id;
      gs.ball.possessingTeamId = 'player';
      thrower.facing = 0.0;

      BallSystem.tryChargedThrow(gs, thrower);

      // Fast-forward past the self-catch block window
      gs.ball.flightAge = 0.3;
      gs.ball.zHeight = 0.5; // below the 1.5-unit airborne threshold

      // Move thrower well away from the ball so it doesn't self-catch
      thrower.x = 110;
      thrower.y = 20;

      // Move receiver on top of the ball
      receiver.x = gs.ball.x;
      receiver.y = gs.ball.y;

      BallSystem.update(gs, 0.016);

      expect(gs.ball.holderId, equals(receiver.id),
          reason: 'receiver should catch the ball once time and height windows are met');
    });
  });

  // ── tryPickup ────────────────────────────────────────────────────────────

  group('BallSystem.tryPickup', () {
    test('player within pickup radius picks up loose ball', () {
      final gs = makeGs();
      final p = gs.playerRoster.first;
      gs.ball.x = 70;
      gs.ball.y = 20;
      p.x = 70.5; // 0.5 < pickupRadius=1.0
      p.y = 20.0;

      BallSystem.tryPickup(gs, p);

      expect(gs.ball.holderId, equals(p.id));
    });

    test('player beyond pickup radius does not pick up ball', () {
      final gs = makeGs();
      final p = gs.playerRoster.first;
      gs.ball.x = 70;
      gs.ball.y = 20;
      p.x = 72.0; // dist=2 > pickupRadius=1.0
      p.y = 20.0;

      BallSystem.tryPickup(gs, p);

      expect(gs.ball.holderId, isNull);
    });

    test('meta-score fires when player team catches in own endzone', () {
      final gs = makeGs();
      final p = makePlayer(id: 'scorer', team: Team.player, x: 15, y: 20);
      gs.playerRoster.add(p);
      gs.ball.x = 15;
      gs.ball.y = 20;
      gs.actState.isActive = true;

      BallSystem.tryPickup(gs, p);

      expect(gs.actState.playerScore, equals(3),
          reason: 'catching ball in own endzone (x<=20) should score a Meta (+3)');
    });
  });

  // ── handlePhaseLineCrossing ──────────────────────────────────────────────

  group('BallSystem.handlePhaseLineCrossing', () {
    test('deactivates the crossed line and resets charge', () {
      final gs = makeGs();
      gs.ball.chargeTimer = 5.0;
      gs.ball.cooldownBonus = 1.0;
      gs.ball.phaseLineActive[2] = true;

      BallSystem.handlePhaseLineCrossing(gs, 2);

      expect(gs.ball.chargeTimer, equals(0.0));
      expect(gs.ball.cooldownBonus, equals(0.0));
      expect(gs.ball.phaseLineActive[2], isFalse);
    });
  });

  // ── ball explosion ───────────────────────────────────────────────────────

  group('BallSystem.update — explosion', () {
    test('holder is killed when chargeTimer reaches maxCharge', () {
      final gs = makeGs();
      final holder = gs.playerRoster.first;
      gs.ball.holderId = holder.id;
      gs.ball.possessingTeamId = 'player';
      gs.ball.chargeTimer = gs.ball.maxCharge - 0.01;
      gs.actState.isActive = true;

      BallSystem.update(gs, 0.05); // pushes chargeTimer past maxCharge

      expect(holder.isAlive, isFalse,
          reason: 'holder must die when the ball explodes');
      expect(gs.ball.holderId, isNull,
          reason: 'ball must drop on explosion');
    });
  });

  // ── own-endzone phase line exception ─────────────────────────────────────

  group('BallSystem.update — own-endzone phase line', () {
    test('crossing line 0 toward player endzone does not reset charge', () {
      final gs = makeGs();
      final holder = gs.playerRoster.first;
      gs.ball.holderId = holder.id;
      gs.ball.possessingTeamId = 'player';
      gs.ball.chargeTimer = 3.0;
      gs.ball.phaseLineActive[0] = true;

      // Holder is just right of line 0 (x=30), moving left into own endzone
      holder.x = 29.9;
      holder.velX = -5.0;
      gs.ball.x = holder.x;
      gs.ball.y = holder.y;

      BallSystem.update(gs, 0.1);

      // chargeTimer should be 3.0 + 0.1 (incremented), not reset to 0
      expect(gs.ball.chargeTimer, greaterThan(1.0),
          reason: 'entering own endzone must not reset charge timer');
    });
  });

  // ── boundary bounce ──────────────────────────────────────────────────────

  group('BallSystem.update — field boundary', () {
    test('ball reverses X direction on right boundary (with 0.5 damping)', () {
      final gs = makeGs();
      gs.ball.isInFlight = true;
      gs.ball.isChargedThrow = false;
      gs.ball.x = 139.9;
      gs.ball.velX = 20.0;
      gs.ball.velY = 0.0;
      gs.ball.flightDistance = 200.0;

      BallSystem.update(gs, 0.016);

      expect(gs.ball.velX, lessThan(0),
          reason: 'velX must reverse sign after bouncing off the right boundary');
    });
  });

  // ── regular pass stops at flightDistance ────────────────────────────────

  group('BallSystem.tryPass / regular flight', () {
    test('pass stops at target distance when uncaught', () {
      final gs = makeGs();
      final thrower = gs.playerRoster.first;
      gs.ball.holderId = thrower.id;
      gs.ball.possessingTeamId = 'player';

      // Move all players away so no one catches the ball
      for (final p in gs.playerRoster) { p.x = 70; p.y = 0; }
      for (final p in gs.opponentRoster) { p.x = 70; p.y = 0; }

      BallSystem.tryPass(gs, thrower, 80, 20, false); // 10-unit pass
      expect(gs.ball.isInFlight, isTrue);

      // Tick until flightDistance runs out
      for (int i = 0; i < 100; i++) {
        if (!gs.ball.isInFlight) break;
        BallSystem.update(gs, 0.016);
      }

      expect(gs.ball.isInFlight, isFalse,
          reason: 'regular pass must stop at the target distance');
    });
  });
}
