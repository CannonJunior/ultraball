import 'dart:math' as math;
import 'ai_strategy.dart';

/// Behavioral weights for a specific strategy+tactics pairing.
/// All weights are in [0.0, 1.0].
class AiPolicy {
  /// How aggressively the team attacks enemies (0=passive, 1=combat-first).
  double aggression;

  /// How tightly the team stays grouped (0=spread wide, 1=tight pack).
  double cohesion;

  /// How much the team routes opponents toward the creature (0=ignore, 1=herd).
  double creatureHerding;

  /// Eagerness to pass the ball (0=run with it, 1=pass at every chance).
  double passEagerness;

  /// How directly the ball carrier charges the endzone (0=cautious, 1=direct).
  double endzonePressure;

  /// Learning state — exponential moving average of recent episode rewards.
  double meanReward;

  /// How many games this policy has been trained on.
  int episodeCount;

  /// Exploration rate: probability of applying a random perturbation this game.
  double explorationRate;

  AiPolicy({
    required this.aggression,
    required this.cohesion,
    required this.creatureHerding,
    required this.passEagerness,
    required this.endzonePressure,
    this.meanReward = 0.0,
    this.episodeCount = 0,
    this.explorationRate = 0.3,
  });

  /// Returns a copy of this policy with small random noise applied (for
  /// exploration). Keeps all weights clamped to [0, 1].
  AiPolicy withExploration(math.Random rng) {
    double perturb(double v) =>
        (v + (rng.nextDouble() - 0.5) * 0.2).clamp(0.0, 1.0);
    return AiPolicy(
      aggression:       perturb(aggression),
      cohesion:         perturb(cohesion),
      creatureHerding:  perturb(creatureHerding),
      passEagerness:    perturb(passEagerness),
      endzonePressure:  perturb(endzonePressure),
      meanReward:       meanReward,
      episodeCount:     episodeCount,
      explorationRate:  explorationRate,
    );
  }

  /// Hill-climb update: if this episode's reward beat the mean, nudge weights
  /// toward the direction that produced them; otherwise perturb to explore.
  void update(double reward, AiPolicy usedPolicy, math.Random rng) {
    const alpha = 0.15; // EMA learning rate
    episodeCount++;
    final prevMean = meanReward;
    meanReward = alpha * reward + (1 - alpha) * meanReward;

    // Anneal exploration rate: 0.3 → 0.05 over ~50 episodes
    explorationRate = math.max(0.05, explorationRate * 0.97);

    if (reward >= prevMean) {
      // This policy direction worked — move current weights toward usedPolicy
      const step = 0.05;
      aggression      = _nudge(aggression,      usedPolicy.aggression,      step);
      cohesion        = _nudge(cohesion,         usedPolicy.cohesion,        step);
      creatureHerding = _nudge(creatureHerding,  usedPolicy.creatureHerding, step);
      passEagerness   = _nudge(passEagerness,    usedPolicy.passEagerness,   step);
      endzonePressure = _nudge(endzonePressure,  usedPolicy.endzonePressure, step);
    }
    // If reward < prevMean, keep current weights (the used variant was worse).
  }

  double _nudge(double current, double target, double step) =>
      (current + (target - current) * step).clamp(0.0, 1.0);

  Map<String, dynamic> toJson() => {
    'aggression':       aggression,
    'cohesion':         cohesion,
    'creatureHerding':  creatureHerding,
    'passEagerness':    passEagerness,
    'endzonePressure':  endzonePressure,
    'meanReward':       meanReward,
    'episodeCount':     episodeCount,
    'explorationRate':  explorationRate,
  };

  factory AiPolicy.fromJson(Map<String, dynamic> j) => AiPolicy(
    aggression:       (j['aggression']      as num).toDouble(),
    cohesion:         (j['cohesion']        as num).toDouble(),
    creatureHerding:  (j['creatureHerding'] as num).toDouble(),
    passEagerness:    (j['passEagerness']   as num).toDouble(),
    endzonePressure:  (j['endzonePressure'] as num).toDouble(),
    meanReward:       (j['meanReward']      as num? ?? 0).toDouble(),
    episodeCount:     (j['episodeCount']    as int? ?? 0),
    explorationRate:  (j['explorationRate'] as num? ?? 0.3).toDouble(),
  );

  /// Sensible defaults for every strategy+tactics combination.
  static AiPolicy defaultFor(AiStrategy strategy, AiTactics tactics) {
    return switch ((strategy, tactics)) {

      // ── TEMPO TRAP ────────────────────────────────────────────────────────
      // Deny phase lines, bait the opponent into exploding; own team passes
      // frequently to reset their own charge timer safely.
      (AiStrategy.tempoTrap, AiTactics.focusFire) => AiPolicy(
          aggression: 0.70, cohesion: 0.60, creatureHerding: 0.30,
          passEagerness: 0.75, endzonePressure: 0.30),
      (AiStrategy.tempoTrap, AiTactics.pickAndScreen) => AiPolicy(
          aggression: 0.45, cohesion: 0.65, creatureHerding: 0.25,
          passEagerness: 0.85, endzonePressure: 0.35),
      (AiStrategy.tempoTrap, AiTactics.quickRelease) => AiPolicy(
          aggression: 0.35, cohesion: 0.45, creatureHerding: 0.20,
          passEagerness: 0.95, endzonePressure: 0.25),
      (AiStrategy.tempoTrap, AiTactics.creatureFlank) => AiPolicy(
          aggression: 0.55, cohesion: 0.50, creatureHerding: 0.90,
          passEagerness: 0.70, endzonePressure: 0.25),
      (AiStrategy.tempoTrap, AiTactics.wedgeRun) => AiPolicy(
          aggression: 0.50, cohesion: 0.80, creatureHerding: 0.30,
          passEagerness: 0.65, endzonePressure: 0.40),

      // ── NUMBERS GAME ─────────────────────────────────────────────────────
      // Kill 2–3 opponents early; once the field tips 7v5 or better, score at will.
      (AiStrategy.numericalEdge, AiTactics.focusFire) => AiPolicy(
          aggression: 0.95, cohesion: 0.75, creatureHerding: 0.30,
          passEagerness: 0.10, endzonePressure: 0.30),
      (AiStrategy.numericalEdge, AiTactics.pickAndScreen) => AiPolicy(
          aggression: 0.75, cohesion: 0.70, creatureHerding: 0.20,
          passEagerness: 0.25, endzonePressure: 0.50),
      (AiStrategy.numericalEdge, AiTactics.quickRelease) => AiPolicy(
          aggression: 0.65, cohesion: 0.50, creatureHerding: 0.15,
          passEagerness: 0.55, endzonePressure: 0.40),
      (AiStrategy.numericalEdge, AiTactics.creatureFlank) => AiPolicy(
          aggression: 0.80, cohesion: 0.55, creatureHerding: 0.85,
          passEagerness: 0.10, endzonePressure: 0.25),
      (AiStrategy.numericalEdge, AiTactics.wedgeRun) => AiPolicy(
          aggression: 0.85, cohesion: 0.85, creatureHerding: 0.25,
          passEagerness: 0.15, endzonePressure: 0.60),

      // ── CHANNEL CONTROL ───────────────────────────────────────────────────
      // Own the creature corridors; use channel position to funnel opponents
      // into the creature while making protected scoring runs.
      (AiStrategy.channelDominance, AiTactics.focusFire) => AiPolicy(
          aggression: 0.60, cohesion: 0.55, creatureHerding: 0.85,
          passEagerness: 0.20, endzonePressure: 0.60),
      (AiStrategy.channelDominance, AiTactics.pickAndScreen) => AiPolicy(
          aggression: 0.40, cohesion: 0.70, creatureHerding: 0.80,
          passEagerness: 0.45, endzonePressure: 0.65),
      (AiStrategy.channelDominance, AiTactics.quickRelease) => AiPolicy(
          aggression: 0.30, cohesion: 0.45, creatureHerding: 0.75,
          passEagerness: 0.80, endzonePressure: 0.55),
      (AiStrategy.channelDominance, AiTactics.creatureFlank) => AiPolicy(
          aggression: 0.50, cohesion: 0.55, creatureHerding: 0.95,
          passEagerness: 0.30, endzonePressure: 0.60),
      (AiStrategy.channelDominance, AiTactics.wedgeRun) => AiPolicy(
          aggression: 0.55, cohesion: 0.85, creatureHerding: 0.75,
          passEagerness: 0.20, endzonePressure: 0.75),

      // ── FLOOD THE ZONE ────────────────────────────────────────────────────
      // Get 3–4 players into/near the endzone simultaneously; overload coverage.
      (AiStrategy.floodEndzone, AiTactics.focusFire) => AiPolicy(
          aggression: 0.50, cohesion: 0.30, creatureHerding: 0.20,
          passEagerness: 0.60, endzonePressure: 0.95),
      (AiStrategy.floodEndzone, AiTactics.pickAndScreen) => AiPolicy(
          aggression: 0.35, cohesion: 0.40, creatureHerding: 0.15,
          passEagerness: 0.75, endzonePressure: 0.90),
      (AiStrategy.floodEndzone, AiTactics.quickRelease) => AiPolicy(
          aggression: 0.25, cohesion: 0.30, creatureHerding: 0.10,
          passEagerness: 0.90, endzonePressure: 0.85),
      (AiStrategy.floodEndzone, AiTactics.creatureFlank) => AiPolicy(
          aggression: 0.45, cohesion: 0.35, creatureHerding: 0.65,
          passEagerness: 0.65, endzonePressure: 0.90),
      (AiStrategy.floodEndzone, AiTactics.wedgeRun) => AiPolicy(
          aggression: 0.55, cohesion: 0.75, creatureHerding: 0.20,
          passEagerness: 0.50, endzonePressure: 0.95),

      // ── BLEED OUT ────────────────────────────────────────────────────────
      // Never give up the ball; pass constantly to reset the charge timer;
      // score only when a lane opens cleanly.
      (AiStrategy.possessionBleed, AiTactics.focusFire) => AiPolicy(
          aggression: 0.30, cohesion: 0.65, creatureHerding: 0.15,
          passEagerness: 0.80, endzonePressure: 0.20),
      (AiStrategy.possessionBleed, AiTactics.pickAndScreen) => AiPolicy(
          aggression: 0.20, cohesion: 0.75, creatureHerding: 0.10,
          passEagerness: 0.85, endzonePressure: 0.25),
      (AiStrategy.possessionBleed, AiTactics.quickRelease) => AiPolicy(
          aggression: 0.10, cohesion: 0.50, creatureHerding: 0.05,
          passEagerness: 0.95, endzonePressure: 0.15),
      (AiStrategy.possessionBleed, AiTactics.creatureFlank) => AiPolicy(
          aggression: 0.20, cohesion: 0.60, creatureHerding: 0.70,
          passEagerness: 0.80, endzonePressure: 0.15),
      (AiStrategy.possessionBleed, AiTactics.wedgeRun) => AiPolicy(
          aggression: 0.25, cohesion: 0.90, creatureHerding: 0.10,
          passEagerness: 0.70, endzonePressure: 0.30),

      // ── HERO BALL ─────────────────────────────────────────────────────────
      // All units converge on the star player/carrier; maximize cohesion and
      // protection; low pass eagerness (ball goes to the hero, not around).
      (AiStrategy.tempoTrap, AiTactics.heroBall) => AiPolicy(
          aggression: 0.65, cohesion: 0.90, creatureHerding: 0.20,
          passEagerness: 0.25, endzonePressure: 0.65),
      (AiStrategy.numericalEdge, AiTactics.heroBall) => AiPolicy(
          aggression: 0.80, cohesion: 0.85, creatureHerding: 0.20,
          passEagerness: 0.15, endzonePressure: 0.70),
      (AiStrategy.channelDominance, AiTactics.heroBall) => AiPolicy(
          aggression: 0.60, cohesion: 0.85, creatureHerding: 0.55,
          passEagerness: 0.20, endzonePressure: 0.75),
      (AiStrategy.floodEndzone, AiTactics.heroBall) => AiPolicy(
          aggression: 0.50, cohesion: 0.80, creatureHerding: 0.15,
          passEagerness: 0.30, endzonePressure: 0.90),
      (AiStrategy.possessionBleed, AiTactics.heroBall) => AiPolicy(
          aggression: 0.35, cohesion: 0.90, creatureHerding: 0.10,
          passEagerness: 0.55, endzonePressure: 0.45),
    };
  }
}
