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

  // 3-team mode: 9 phase lines (3 per team: indices 0-2 player, 3-5 opponent, 6-8 third)
  List<bool> phaseLineActive3 = List.filled(9, true);

  // UI explosion flash: set to 1.0 on explosion, decremented by game loop over ~0.6s
  double explosionFlash = 0.0;

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

  void resetPhaseLines3() {
    for (int i = 0; i < 9; i++) phaseLineActive3[i] = true;
  }

  // 3-team mode: check if ball crossed any of the 9 phase lines
  // normals: [(nx,ny), ...] for each team; dists: [d1,d2,d3] phase line distances
  // Returns index 0-8, or -1
  int checkPhaseLineCrossing3(double prevX, double prevY, double newX, double newY,
      double cx, double cy, List<(double, double)> normals, List<double> dists) {
    const halfW = 20.0; // field3ArmHalfWidth
    for (int t = 0; t < 3; t++) {
      final (nx, ny) = normals[t];
      final px = -ny; final py = nx;
      for (int i = 0; i < 3; i++) {
        final idx = t * 3 + i;
        if (!phaseLineActive3[idx]) continue;
        final d = dists[i];
        final prevDot = (prevX - cx) * nx + (prevY - cy) * ny;
        final newDot  = (newX  - cx) * nx + (newY  - cy) * ny;
        if ((prevDot < d && newDot >= d) || (prevDot > d && newDot <= d)) {
          // Only trigger if ball is within this arm's width
          final perpDot = (newX - cx) * px + (newY - cy) * py;
          if (perpDot.abs() <= halfW) {
            return idx;
          }
        }
      }
    }
    return -1;
  }

  void changePossession(String? newTeamId) {
    possessingTeamId = newTeamId;
    resetPhaseLines();
    resetPhaseLines3();
    chargeTimer = 0;
    cooldownBonus = 0;
  }
}
