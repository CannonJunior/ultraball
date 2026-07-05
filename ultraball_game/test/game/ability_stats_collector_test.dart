import 'package:flutter_test/flutter_test.dart';
import 'package:ultraball_game/game/ability_stats_collector.dart';
import 'package:ultraball_game/models/player.dart';
import '../helpers/game_state_factory.dart';

void main() {
  group('AbilityStatsCollector.snap', () {
    test('returns correct enemyHpSum, enemyCCCount, opponentHasBall', () {
      final gs = makeGs();
      // Give one opponent a stun
      final opp1 = gs.opponentRoster.first;
      opp1.stunTimer = 1.0;
      final opp2 = gs.opponentRoster[1];

      final snap = AbilityStatsCollector.snap(gs, Team.player);

      expect(snap.enemyHpSum,
          closeTo(opp1.health + opp2.health, 0.001));
      expect(snap.enemyCCCount, equals(1));
      expect(snap.opponentHasBall, isFalse);
    });

    test('opponentHasBall is true when opponent holds the ball', () {
      final gs = makeGs();
      gs.ball.holderId = gs.opponentRoster.first.id;

      final snap = AbilityStatsCollector.snap(gs, Team.player);

      expect(snap.opponentHasBall, isTrue);
    });
  });

  group('AbilityStatsCollector.recordUse', () {
    test('populates statsPerAbility and _log after a use', () {
      final gs = makeGs();
      final collector = AbilityStatsCollector();
      final player = gs.playerRoster.first;
      player.playerClass = PlayerClass.spectre;

      final before = AbilityStatsCollector.snap(gs, Team.player);
      final after  = AbilityStatsCollector.snap(gs, Team.player);

      collector.recordUse(
        player: player,
        slot: 1,
        before: before,
        after: after,
        gameTimeRemaining: 120.0,
      );

      expect(collector.totalUses, equals(1));
      expect(collector.statsPerAbility.isNotEmpty, isTrue);
    });

    test('statsPerAbility accumulates damage across uses', () {
      final gs = makeGs();
      final collector = AbilityStatsCollector();
      final player = gs.playerRoster.first;
      player.playerClass = PlayerClass.spectre;

      // Simulate enemy HP going down = damage dealt
      final opp = gs.opponentRoster.first;
      final highHpSnap = AbilityStatsCollector.snap(gs, Team.player);
      opp.health -= 30;
      final lowHpSnap = AbilityStatsCollector.snap(gs, Team.player);

      collector.recordUse(
        player: player,
        slot: 1,
        before: highHpSnap,
        after: lowHpSnap,
        gameTimeRemaining: 120.0,
      );

      final stats = collector.statsPerAbility;
      expect(stats.isNotEmpty, isTrue);
      final entry = stats.values.first;
      expect(entry.totalDamage, closeTo(30.0, 0.001));
    });
  });

  group('PerAbilityStats.impactScore', () {
    test('impactScore formula: avgDamage + fumbleRate*40 + ccRate*15', () {
      final stats = PerAbilityStats(
        key: 'test/TestAbility',
        abilityName: 'TestAbility',
        playerClass: PlayerClass.spectre,
        slot: 1,
      );
      stats.uses = 4;
      stats.hits = 4;
      stats.totalDamage = 40; // avgDamage = 10
      stats.fumbles = 2;       // fumbleRate = 0.5 → 0.5*40 = 20
      stats.ccApplications = 4; // ccRate = 1.0 → 1.0*15 = 15

      // Expected: 10 + 20 + 15 = 45
      expect(stats.impactScore, closeTo(45.0, 0.001));
    });
  });

  group('AbilityStatsCollector.recordKill / killCorrelation', () {
    test('killCorrelation returns > 0 when kill is within the window', () {
      final gs = makeGs();
      final collector = AbilityStatsCollector();
      final player = gs.playerRoster.first;
      player.playerClass = PlayerClass.spectre;

      final snap = AbilityStatsCollector.snap(gs, Team.player);
      collector.recordUse(
        player: player,
        slot: 1,
        before: snap,
        after: snap,
        gameTimeRemaining: 100.0,
      );
      // Record a kill 5 seconds after the ability (time counts down, so kill at 95)
      collector.recordKill(Team.player, 95.0);

      final corr = collector.killCorrelation(windowSeconds: 10.0);
      expect(corr.values.first, greaterThan(0),
          reason: 'kill within 10s window should show positive correlation');
    });

    test('killCorrelation returns 0 when kill is outside the window', () {
      final gs = makeGs();
      final collector = AbilityStatsCollector();
      final player = gs.playerRoster.first;
      player.playerClass = PlayerClass.spectre;

      final snap = AbilityStatsCollector.snap(gs, Team.player);
      collector.recordUse(
        player: player,
        slot: 1,
        before: snap,
        after: snap,
        gameTimeRemaining: 100.0,
      );
      // Kill happened 20 seconds before (outside 10s window)
      collector.recordKill(Team.player, 80.0);

      final corr = collector.killCorrelation(windowSeconds: 10.0);
      expect(corr.values.first, equals(0.0),
          reason: 'kill outside 10s window should show zero correlation');
    });
  });

  group('AbilityStatsCollector.reset', () {
    test('reset clears all recorded data', () {
      final gs = makeGs();
      final collector = AbilityStatsCollector();
      final player = gs.playerRoster.first;
      player.playerClass = PlayerClass.spectre;

      final snap = AbilityStatsCollector.snap(gs, Team.player);
      collector.recordUse(
        player: player,
        slot: 1,
        before: snap,
        after: snap,
        gameTimeRemaining: 100.0,
      );
      collector.recordKill(Team.player, 90.0);

      collector.reset();

      expect(collector.totalUses, equals(0));
      expect(collector.statsPerAbility.isEmpty, isTrue);
      expect(collector.killCorrelation().isEmpty, isTrue);
    });
  });
}
