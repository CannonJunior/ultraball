class ActResult {
  final int act;
  final int playerScore;
  final int opponentScore;
  final int thirdScore;
  ActResult(this.act, this.playerScore, this.opponentScore, [this.thirdScore = 0]);
}

class ActState {
  int currentAct = 1;
  double timerSeconds = 180.0; // 3 minutes
  bool isActive = false;
  bool actEnded = false;

  // Scores
  int playerScore = 0;
  int opponentScore = 0;

  // Kill counts
  int playerKills = 0;
  int opponentKills = 0;

  // Per-act substitution tracking
  bool playerSubUsed = false;
  bool opponentSubUsed = false;

  // Act 5 tracking
  int act5LeadingScore = 0; // score of leading team at start of act 5
  String act5LeadingTeam = ''; // 'player' or 'opponent' or 'tied'
  int act5UltraTarget = 0; // score needed to trigger act 5 end

  // History
  List<ActResult> actResults = [];

  // Forfeits
  bool playerForfeit = false;
  bool opponentForfeit = false;

  // Third team (3-team mode only)
  int thirdScore = 0;
  int thirdKills = 0;
  bool thirdSubUsed = false;
  bool thirdForfeit = false;

  // Set to true when initialized in 3-team mode so gameOver requires 2 forfeits
  bool isThreeTeams = false;

  bool get isAct5 => currentAct == 5;
  bool get gameOver {
    if (isThreeTeams) {
      final forfeits = (playerForfeit ? 1 : 0)
          + (opponentForfeit ? 1 : 0)
          + (thirdForfeit ? 1 : 0);
      return forfeits >= 2 || (actEnded && currentAct >= 5);
    }
    return playerForfeit || opponentForfeit || (actEnded && currentAct >= 5);
  }

  String get timerDisplay {
    final mins = (timerSeconds / 60).floor();
    final secs = (timerSeconds % 60).floor();
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void startAct5() {
    if (playerScore > opponentScore) {
      act5LeadingTeam = 'player';
      act5LeadingScore = playerScore;
    } else if (opponentScore > playerScore) {
      act5LeadingTeam = 'opponent';
      act5LeadingScore = opponentScore;
    } else {
      act5LeadingTeam = 'tied';
      act5LeadingScore = playerScore;
    }
    act5UltraTarget = act5LeadingScore + 7;
  }
}
