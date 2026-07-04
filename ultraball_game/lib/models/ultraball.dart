class Ultraball {
  double x, y;
  double velX = 0, velY = 0;

  // Charge mechanic
  double chargeTimer = 0; // counts up while held; resets on pass/phase line
  double cooldownBonus = 0; // bonus seconds from pass distance
  double maxCharge = 7.0; // explodes at this value

  // Possession
  String? holderId; // player id holding the ball, null if loose
  String? possessingTeamId; // 'player' or 'opponent'

  // In-flight
  bool isInFlight = false;
  double flightDistance = 0;
  bool isPowerPass = false;
  bool isChargedThrow = false;

  // 3D arc for charged throws
  double zHeight = 0.0;
  double zVelocity = 0.0;
  double flightAge = 0.0; // seconds since this flight began

  // Phase line state (5 lines, indexed 0–4 at x=30,50,70,90,110 in field coords)
  List<bool> phaseLineActive = [true, true, true, true, true];

  Ultraball({required this.x, required this.y});

  double get effectiveMaxCharge => maxCharge + cooldownBonus;

  double get chargePercent =>
      (chargeTimer / effectiveMaxCharge).clamp(0.0, 1.0);

  bool get isHeld => holderId != null;
  bool get isLoose => holderId == null && !isInFlight;

  // Phase line X positions in absolute field coords
  static const List<double> phaseLineXPositions = [30, 50, 70, 90, 110];

  // Returns the index of a phase line if ball is crossing it, -1 otherwise
  int checkPhaseLineCrossing(double prevX, double newX) {
    for (int i = 0; i < phaseLineXPositions.length; i++) {
      final lineX = phaseLineXPositions[i];
      if ((prevX < lineX && newX >= lineX) ||
          (prevX > lineX && newX <= lineX)) {
        return i;
      }
    }
    return -1;
  }

  void resetPhaseLines() {
    for (int i = 0; i < phaseLineActive.length; i++) {
      phaseLineActive[i] = true;
    }
  }

  void changePossession(String? newTeamId) {
    possessingTeamId = newTeamId;
    resetPhaseLines();
    chargeTimer = 0;
    cooldownBonus = 0;
  }
}
