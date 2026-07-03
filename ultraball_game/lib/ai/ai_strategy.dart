/// Strategy = structural theory of WHY you win — the long-game advantage you build.
/// Tactics  = specific moment-to-moment decision rules and formations — HOW units act RIGHT NOW.
enum AiStrategy {
  tempoTrap,        // Force opponent ball explosions; the charge timer is the weapon
  numericalEdge,    // Kill 2–3 opponents early; score freely against a depleted field
  channelDominance, // Own the creature channels; funnel opponents into the kill zone
  floodEndzone,     // Flood 3–4 players into/near the endzone; someone is always open
  possessionBleed,  // Hold the ball indefinitely; drain the clock; score only when safe
}

enum AiTactics {
  focusFire,      // All attackers converge on one target simultaneously; never split damage
  pickAndScreen,  // Two players screen for the carrier; others run decoy routes into endzone
  quickRelease,   // Pass at the first opportunity; chain passes; never hold ball >2–3 seconds
  creatureFlank,  // Stay opposite the creature from the carrier; push them into it
  wedgeRun,       // Three players form a tight triangle around the carrier; move as one unit
  heroBall,       // All units rally around and protect the star player; get the ball to them
}

extension AiStrategyLabel on AiStrategy {
  String get label => switch (this) {
    AiStrategy.tempoTrap        => 'TEMPO TRAP',
    AiStrategy.numericalEdge    => 'NUMBERS GAME',
    AiStrategy.channelDominance => 'CHANNEL CONTROL',
    AiStrategy.floodEndzone     => 'FLOOD THE ZONE',
    AiStrategy.possessionBleed  => 'BLEED OUT',
  };
  String get description => switch (this) {
    AiStrategy.tempoTrap        => 'Deny phase lines; force opponent to hold the ball until it explodes',
    AiStrategy.numericalEdge    => 'Eliminate 2–3 opponents early; exploit the field numbers edge to score freely',
    AiStrategy.channelDominance => 'Control creature channels for protected scoring corridors; funnel opponents into the kill zone',
    AiStrategy.floodEndzone     => 'Flood 3–4 players simultaneously into/near the endzone; defense can\'t cover everyone',
    AiStrategy.possessionBleed  => 'Never surrender the ball; drain the clock; only score when the lane is completely safe',
  };
  String get emoji => switch (this) {
    AiStrategy.tempoTrap        => '💣',
    AiStrategy.numericalEdge    => '🔢',
    AiStrategy.channelDominance => '🦅',
    AiStrategy.floodEndzone     => '🌊',
    AiStrategy.possessionBleed  => '🩸',
  };
}

extension AiTacticsLabel on AiTactics {
  String get label => switch (this) {
    AiTactics.focusFire     => 'FOCUS FIRE',
    AiTactics.pickAndScreen => 'PICK & SCREEN',
    AiTactics.quickRelease  => 'QUICK RELEASE',
    AiTactics.creatureFlank => 'CREATURE FLANK',
    AiTactics.wedgeRun      => 'WEDGE RUN',
    AiTactics.heroBall      => 'HERO BALL',
  };
  String get description => switch (this) {
    AiTactics.focusFire     => 'All attackers lock onto one target at once; eliminate before moving on',
    AiTactics.pickAndScreen => 'Two players set hard screens for the carrier; others sprint decoy routes to the endzone',
    AiTactics.quickRelease  => 'Pass at the first open window; chain passes to advance; never hold the ball more than 2–3 seconds',
    AiTactics.creatureFlank => 'Position on the opposite side of the carrier from the creature; herd the opponent into it',
    AiTactics.wedgeRun      => 'Three players form a tight triangle around the carrier and move as one unit toward the endzone',
    AiTactics.heroBall      => 'All units rally around and protect the star player; immediately pass the ball to them',
  };
  String get emoji => switch (this) {
    AiTactics.focusFire     => '🎯',
    AiTactics.pickAndScreen => '🏀',
    AiTactics.quickRelease  => '⚡',
    AiTactics.creatureFlank => '👹',
    AiTactics.wedgeRun      => '🔺',
    AiTactics.heroBall      => '⭐',
  };
}
