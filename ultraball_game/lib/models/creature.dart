import 'dart:math' as math;

enum CreatureType { kraken, dragon, hydra, wraith, chaos }

enum ChaosAction { stop, reverse, burst, teleport }

enum _ChaosPhase { patrol, telegraph, action }

class Creature {
  double x, y;
  CreatureType type;
  double speed;
  double pathProgress = 0.0;
  double size;
  String name;

  // Normal circuit constants
  static const double _ml = 25.0;
  static const double _mr = 115.0;
  static const double _mt = -2.5;
  static const double _mb = 42.5;
  static const double _topLen    = _mr - _ml;
  static const double _sideLen   = _mb - _mt;
  static const double _perimeter = (_topLen + _sideLen) * 2;

  // Chaos state
  _ChaosPhase _chaosPhase = _ChaosPhase.patrol;
  ChaosAction _nextAction = ChaosAction.stop;
  double _phaseTimer = 3.0;
  int _chaosChannel = 1; // 0=left(x=_ml), 1=right(x=_mr)
  double _chaosDir = 1.0; // +1 = moving toward _mb, -1 = toward _mt
  final _rng = math.Random();

  // Telegraph visual data — read by the painter
  bool get isTelegraphing => _chaosPhase == _ChaosPhase.telegraph;
  ChaosAction get telegraphAction => _nextAction;
  final List<double> chaosRings = []; // each value 0..1 = expansion progress
  double _ringSpawnTimer = 0.0;
  double reversedTimer = 0.0;

  // 3-team star-perimeter patrol
  List<(double, double)> starPatrolPath = const [];
  int _starWptIdx = 0;
  int _starWptStep = 1; // +1 = CW, -1 = CCW

  static const double _chaosMinY = -2.0;
  static const double _chaosMaxY = 42.0;

  Creature({required this.type})
    : x = 115,
      y = type == CreatureType.chaos ? 20.0 : -2.5,
      speed = _initSpeed(type),
      size  = _initSize(type),
      name  = type == CreatureType.chaos
          ? 'Chaos Monster'
          : type.name[0].toUpperCase() + type.name.substring(1);

  static double _initSpeed(CreatureType t) => switch (t) {
    CreatureType.kraken => 10.0,
    CreatureType.dragon => 14.0,
    CreatureType.hydra  => 12.0,
    CreatureType.wraith => 18.0,
    CreatureType.chaos  =>  9.0,
  };

  static double _initSize(CreatureType t) => switch (t) {
    CreatureType.kraken => 3.5,
    CreatureType.dragon => 3.0,
    CreatureType.hydra  => 4.0,
    CreatureType.wraith => 2.5,
    CreatureType.chaos  => 3.0,
  };

  void setStarPatrol(List<(double, double)> path, {bool reversed = false}) {
    starPatrolPath = path;
    _starWptStep = reversed ? -1 : 1;
    _starWptIdx  = reversed ? path.length - 1 : 0;
    if (path.isNotEmpty) {
      x = path[_starWptIdx].$1;
      y = path[_starWptIdx].$2;
    }
  }

  void update(double dt) {
    if (starPatrolPath.isNotEmpty) {
      _updateStarPatrol(dt);
    } else if (type == CreatureType.chaos) {
      _updateChaos(dt);
    } else {
      _updateNormal(dt);
    }
  }

  void reverseDirection(double duration) {
    reversedTimer = duration;
    // Chaos: flip direction on cast; _updateChaos re-flips when timer expires
    if (type == CreatureType.chaos) _chaosDir = -_chaosDir;
  }

  void _updateStarPatrol(double dt) {
    final n = starPatrolPath.length;
    if (n == 0) return;
    final (tx, ty) = starPatrolPath[_starWptIdx];
    final dx = tx - x; final dy = ty - y;
    final dist = math.sqrt(dx * dx + dy * dy);
    final step = reversedTimer > 0 ? -_starWptStep : _starWptStep;
    if (dist < speed * dt + 0.1) {
      x = tx; y = ty;
      _starWptIdx = (_starWptIdx + step + n) % n;
      if (reversedTimer > 0) reversedTimer -= dt;
    } else {
      if (reversedTimer > 0) reversedTimer -= dt;
      x += (dx / dist) * speed * dt;
      y += (dy / dist) * speed * dt;
    }
  }

  void _updateNormal(double dt) {
    if (reversedTimer > 0) {
      reversedTimer -= dt;
      pathProgress -= (speed / _perimeter) * dt;
      if (pathProgress < 0.0) pathProgress += 1.0;
    } else {
      pathProgress += (speed / _perimeter) * dt;
      if (pathProgress >= 1.0) pathProgress -= 1.0;
    }
    final p = pathProgress * _perimeter;
    if (p < _topLen) {
      x = _mr - p;
      y = _mt;
    } else if (p < _topLen + _sideLen) {
      x = _ml;
      y = _mt + (p - _topLen);
    } else if (p < 2 * _topLen + _sideLen) {
      x = _ml + (p - _topLen - _sideLen);
      y = _mb;
    } else {
      x = _mr;
      y = _mb - (p - 2 * _topLen - _sideLen);
    }
  }

  void _updateChaos(double dt) {
    if (reversedTimer > 0) {
      reversedTimer -= dt;
      // Timer just expired: flip _chaosDir back to cancel the reversal
      if (reversedTimer <= 0) _chaosDir = -_chaosDir;
    }
    // Advance and cull ring animations
    for (int i = chaosRings.length - 1; i >= 0; i--) {
      chaosRings[i] += dt * 0.65;
      if (chaosRings[i] >= 1.0) chaosRings.removeAt(i);
    }

    switch (_chaosPhase) {
      case _ChaosPhase.patrol:
        _phaseTimer -= dt;
        final cx = _chaosChannel == 0 ? _ml : _mr;
        y += speed * _chaosDir * dt;
        x = cx;
        if (y <= _chaosMinY) { y = _chaosMinY; _chaosDir =  1.0; }
        if (y >= _chaosMaxY) { y = _chaosMaxY; _chaosDir = -1.0; }
        if (_phaseTimer <= 0) _startTelegraph();

      case _ChaosPhase.telegraph:
        _phaseTimer -= dt;
        _ringSpawnTimer -= dt;
        if (_ringSpawnTimer <= 0) {
          chaosRings.add(0.0);
          _ringSpawnTimer = 0.35;
        }
        if (_phaseTimer <= 0) _executeAction();

      case _ChaosPhase.action:
        _phaseTimer -= dt;
        if (_nextAction == ChaosAction.burst) {
          final cx = _chaosChannel == 0 ? _ml : _mr;
          y += speed * 3.0 * _chaosDir * dt;
          x = cx;
          if (y <= _chaosMinY) { y = _chaosMinY; _chaosDir =  1.0; }
          if (y >= _chaosMaxY) { y = _chaosMaxY; _chaosDir = -1.0; }
        }
        if (_phaseTimer <= 0) {
          _chaosPhase = _ChaosPhase.patrol;
          _phaseTimer = 2.5 + _rng.nextDouble() * 3.5;
        }
    }
  }

  void _startTelegraph() {
    final roll = _rng.nextDouble();
    _nextAction = roll < 0.30 ? ChaosAction.stop
                : roll < 0.55 ? ChaosAction.reverse
                : roll < 0.80 ? ChaosAction.burst
                :               ChaosAction.teleport;
    _chaosPhase = _ChaosPhase.telegraph;
    _phaseTimer = 1.5;
    chaosRings.clear();
    _ringSpawnTimer = 0.0;
  }

  void _executeAction() {
    chaosRings.clear();
    _chaosPhase = _ChaosPhase.action;
    switch (_nextAction) {
      case ChaosAction.stop:
        _phaseTimer = 2.0 + _rng.nextDouble() * 2.0;
      case ChaosAction.reverse:
        _chaosDir = -_chaosDir;
        _phaseTimer = 0.5;
      case ChaosAction.burst:
        _phaseTimer = 0.8 + _rng.nextDouble() * 0.8;
      case ChaosAction.teleport:
        if (_rng.nextBool()) _chaosChannel = 1 - _chaosChannel;
        x = _chaosChannel == 0 ? _ml : _mr;
        y = _chaosMinY + _rng.nextDouble() * (_chaosMaxY - _chaosMinY);
        _phaseTimer = 0.3;
    }
  }
}
