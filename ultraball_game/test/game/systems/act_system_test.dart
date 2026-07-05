import 'package:flutter_test/flutter_test.dart';
import 'package:ultraball_game/game/systems/act_system.dart';
import '../../helpers/game_state_factory.dart';

void main() {
  // ── scoring ──────────────────────────────────────────────────────────────

  group('ActSystem — scoring', () {
    test('scoreUltra adds 7 to the player score', () {
      final gs = makeGs();
      ActSystem.scoreUltra(gs, 'player');
      expect(gs.actState.playerScore, equals(7));
    });

    test('scoreUltra adds 7 to the opponent score', () {
      final gs = makeGs();
      ActSystem.scoreUltra(gs, 'opponent');
      expect(gs.actState.opponentScore, equals(7));
    });

    test('scoreMeta adds 3 to the player score', () {
      final gs = makeGs();
      ActSystem.scoreMeta(gs, 'player');
      expect(gs.actState.playerScore, equals(3));
    });

    test('scoreKilla adds 1 point and 1 kill to the scoring team', () {
      final gs = makeGs();
      ActSystem.scoreKilla(gs, 'player');
      expect(gs.actState.playerScore, equals(1));
      expect(gs.actState.playerKills,  equals(1));
    });

    test('scoreKilla awards 1 ultra mana to the scorer', () {
      final gs = makeGs();
      final scorer = gs.playerRoster.first;
      scorer.ultraMana = 0;

      ActSystem.scoreKilla(gs, 'player', scorer);

      expect(scorer.ultraMana, closeTo(1.0, 0.001));
    });
  });

  // ── endAct ───────────────────────────────────────────────────────────────

  group('ActSystem.endAct', () {
    test('sets actEnded and clears isActive', () {
      final gs = makeGs();
      gs.actState.isActive = true;
      gs.actState.actEnded = false;

      ActSystem.endAct(gs);

      expect(gs.actState.actEnded, isTrue);
      expect(gs.actState.isActive, isFalse);
    });

    test('awards 5 ultra mana to field players on the act-winning team', () {
      final gs = makeGs();
      gs.actState.isActive = true;
      gs.actState.playerScore   = 10;
      gs.actState.opponentScore = 3;

      final winner = gs.playerRoster.first;
      winner.ultraMana = 0;

      ActSystem.endAct(gs);

      expect(winner.ultraMana, closeTo(5.0, 0.001),
          reason: 'field players on the act-winning team get 5 ultra mana');
    });

    test('is idempotent — calling twice has no second effect', () {
      final gs = makeGs();
      gs.actState.isActive = true;

      ActSystem.endAct(gs);
      final scoreAfterFirst = gs.actState.playerScore;
      ActSystem.endAct(gs); // second call — guarded by actEnded flag

      expect(gs.actState.playerScore, equals(scoreAfterFirst));
    });
  });

  // ── act timer ────────────────────────────────────────────────────────────

  group('ActSystem.update — timer', () {
    test('timer expiry triggers endAct', () {
      final gs = makeGs();
      gs.actState.isActive = true;
      gs.actState.actEnded = false;
      gs.actState.currentAct = 1; // acts 1–4 use the timer
      gs.actState.timerSeconds = 0.05;

      ActSystem.update(gs, 0.1);

      expect(gs.actState.actEnded, isTrue,
          reason: 'act must end when timerSeconds reaches 0');
    });

    test('timer does not run during pause', () {
      final gs = makeGs();
      gs.actState.isActive = true;
      gs.paused = true;
      gs.actState.timerSeconds = 60.0;

      ActSystem.update(gs, 1.0);

      expect(gs.actState.timerSeconds, equals(60.0),
          reason: 'timer must not tick while game is paused');
    });
  });

  // ── pointsThisMatch tracking ─────────────────────────────────────────────

  group('ActSystem — pointsThisMatch', () {
    test('scoreUltra adds 7 to scorer.pointsThisMatch', () {
      final gs = makeGs();
      final scorer = gs.playerRoster.first;
      scorer.pointsThisMatch = 0;

      ActSystem.scoreUltra(gs, 'player', scorer);

      expect(scorer.pointsThisMatch, equals(7));
    });

    test('scoreMeta adds 3 to scorer.pointsThisMatch', () {
      final gs = makeGs();
      final scorer = gs.playerRoster.first;
      scorer.pointsThisMatch = 0;

      ActSystem.scoreMeta(gs, 'player', scorer);

      expect(scorer.pointsThisMatch, equals(3));
    });

    test('scoreKilla adds 1 to scorer.pointsThisMatch', () {
      final gs = makeGs();
      final scorer = gs.playerRoster.first;
      scorer.pointsThisMatch = 0;

      ActSystem.scoreKilla(gs, 'player', scorer);

      expect(scorer.pointsThisMatch, equals(1));
    });
  });

  // ── Act 5 end conditions ─────────────────────────────────────────────────

  group('ActSystem.scoreUltra — Act 5', () {
    test('ends when player (leading) team scores Ultra past the target', () {
      final gs = makeGs();
      gs.actState.currentAct    = 5;
      gs.actState.isActive      = true;
      gs.actState.playerScore   = 14;
      gs.actState.opponentScore = 7;
      gs.actState.startAct5();   // sets act5LeadingTeam + act5UltraTarget

      ActSystem.scoreUltra(gs, 'player'); // player now at 21 >= target

      expect(gs.actState.actEnded, isTrue,
          reason: 'Act 5 must end when the leading team scores an Ultra past the target');
    });

    test('ends immediately when tied at Act 5 start and any team scores Ultra', () {
      final gs = makeGs();
      gs.actState.currentAct    = 5;
      gs.actState.isActive      = true;
      gs.actState.playerScore   = 7;
      gs.actState.opponentScore = 7; // tied
      gs.actState.startAct5();       // act5LeadingTeam == 'tied'

      ActSystem.scoreUltra(gs, 'opponent');

      expect(gs.actState.actEnded, isTrue,
          reason: 'Act 5 must end on the first Ultra when scores are tied at the start');
    });
  });
}
