import 'ai_strategy.dart';
import 'game_record.dart';

/// Computes a scalar reward signal from a completed game, given the
/// AI's chosen strategy and tactics.
///
/// Reward design principles:
///  - Positive reward for actions aligned with the strategy
///  - Negative reward for actions that oppose the strategy
///  - Tactics provide bonus multipliers on top of the strategy reward
///  - Win/lose bonus applied on top to ensure outcome still matters
class RewardSystem {
  static const double _winBonus    =  20.0;
  static const double _lossPenalty = -10.0;

  static double compute(GameStats s, AiStrategy strategy, AiTactics tactics) {
    double r = _strategyReward(s, strategy) +
               _tacticsBonus(s, tactics) +
               _outcomeBonus(s);
    return r;
  }

  static double _strategyReward(GameStats s, AiStrategy strategy) {
    return switch (strategy) {

      // TEMPO TRAP — reward causing opponent explosions and winning on possession safety.
      // Own-team explosions are catastrophic (defeat your own strategy).
      AiStrategy.tempoTrap => () {
        double r = s.playerExplosions * 15.0;  // each forced explosion is the entire point
        r += s.aiPasses * 0.5;                 // passing = safe charge-timer resets
        r -= s.aiExplosions * 20.0;            // own explosions negate the strategy
        r += (s.aiFinalScore - s.playerFinalScore) * 0.2;
        return r;
      }(),

      // NUMBERS GAME — reward eliminating opponents early; bonus for kills on depleted fields.
      AiStrategy.numericalEdge => () {
        double r = (s.aiKillas - s.playerKillas) * 6.0;
        r += s.aiCreatureKills * 4.0;          // efficient creature-assisted kills
        r -= s.playerCreatureKills * 3.0;      // own-team losses undermine the advantage
        r += (s.aiFinalScore - s.playerFinalScore) * 0.4;
        r += s.aiTackles * 0.2;
        return r;
      }(),

      // CHANNEL CONTROL — reward creature-zone positioning, creature-assisted kills,
      // and scoring runs through the channels.
      AiStrategy.channelDominance => () {
        double r = s.aiCreatureKills * 8.0;    // using the creature is the whole strategy
        r -= s.playerCreatureKills * 5.0;      // opponent flipping the channel is very bad
        r += (s.aiUltras - s.playerUltras) * 7.0;  // carries through channel = ultras
        r += (s.aiFinalScore - s.playerFinalScore) * 0.3;
        r -= s.aiExplosions * 5.0;
        return r;
      }(),

      // FLOOD THE ZONE — reward metas (pass into endzone = flood working) and ultras;
      // passing is the mechanism that gets receivers into position.
      AiStrategy.floodEndzone => () {
        double r = (s.aiMetas - s.playerMetas) * 10.0;   // metas validate the flood
        r += (s.aiUltras - s.playerUltras) * 8.0;
        r += s.aiPasses * 0.4;                            // passes drive receivers into position
        r += (s.aiFinalScore - s.playerFinalScore) * 0.3;
        r -= s.aiExplosions * 6.0;
        return r;
      }(),

      // BLEED OUT — reward possession time (proxied by passes and low explosions)
      // and punish anything that surrenders the ball.
      AiStrategy.possessionBleed => () {
        double r = s.aiPasses * 1.0;                     // each pass = another safe reset
        r -= s.aiExplosions * 25.0;                      // explosion = catastrophic possession loss
        r += (s.aiFinalScore - s.playerFinalScore) * 0.6;
        r -= s.playerKillas * 0.5;                       // getting killed = losing a ball carrier option
        return r;
      }(),
    };
  }

  static double _tacticsBonus(GameStats s, AiTactics tactics) {
    return switch (tactics) {

      // FOCUS FIRE — reward concentrated kills; penalize spread damage (high kill count
      // with low tackles suggests efficient elimination rather than grazing hits).
      AiTactics.focusFire =>
        (s.aiKillas - s.playerKillas) * 3.0 +
        s.aiSlams * 0.5,

      // PICK & SCREEN — reward metas and ultras (receivers got open);
      // penalize explosions (screens broke down, carrier held too long).
      AiTactics.pickAndScreen =>
        s.aiMetas * 4.0 +
        s.aiUltras * 2.0 -
        s.aiExplosions * 4.0,

      // QUICK RELEASE — reward raw pass count (chained passes = tactic working);
      // penalize explosions hard (holding = tactic failure).
      AiTactics.quickRelease =>
        s.aiPasses * 0.8 -
        s.aiExplosions * 8.0,

      // CREATURE FLANK — reward opponent creature deaths; reward flanking producing
      // open lanes (metas/ultras); penalize own-team creature deaths.
      AiTactics.creatureFlank =>
        s.aiCreatureKills * 6.0 -
        s.playerCreatureKills * 4.0 +
        s.aiUltras * 1.5,

      // WEDGE RUN — reward clean endzone carries (ultras); tight cohesion means
      // fewer explosions; penalize turnovers and explosions.
      AiTactics.wedgeRun =>
        s.aiUltras * 3.0 -
        s.aiExplosions * 5.0 +
        s.aiTackles * 0.15,

      // HERO BALL — reward the star carrier scoring (ultras); teammates killing
      // threats around the hero (killas); penalize losing the hero's ball.
      AiTactics.heroBall =>
        s.aiUltras * 4.0 +
        s.aiKillas * 1.0 -
        s.aiExplosions * 6.0,
    };
  }

  static double _outcomeBonus(GameStats s) {
    if (s.aiWon) return _winBonus;
    if (!s.aiWon && s.aiFinalScore < s.playerFinalScore) return _lossPenalty;
    return 0; // draw
  }
}
