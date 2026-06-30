enum CreatureType { kraken, dragon, hydra }

class Creature {
  double x, y;
  CreatureType type;
  double speed = 12.0; // m/s around the field
  double pathProgress = 0.0; // 0–1 around the circuit
  double size = 3.0; // radius in meters for collision
  String name;

  Creature({required this.type})
    : x = 115,
      y = -2.5,
      name = type.name[0].toUpperCase() + type.name.substring(1) {
    speed = switch (type) {
      CreatureType.kraken => 10.0,
      CreatureType.dragon => 14.0,
      CreatureType.hydra => 12.0,
    };
    size = switch (type) {
      CreatureType.kraken => 3.5,
      CreatureType.dragon => 3.0,
      CreatureType.hydra => 4.0,
    };
  }

  // The creature's circuit runs through both scoring channels (x=20–30 left,
  // x=110–120 right), connecting them via strips OUTSIDE the field at y=-2.5
  // (top) and y=42.5 (bottom). Players crossing a channel always face the
  // creature; the connecting paths are safely outside the playable y=0–40 area.
  static const double _ml = 25.0;   // left-leg x  — center of left channel (x=20–30)
  static const double _mr = 115.0;  // right-leg x — center of right channel (x=110–120)
  static const double _mt = -2.5;   // top connecting path y (outside field)
  static const double _mb = 42.5;   // bottom connecting path y (outside field)
  static const double _topLen  = _mr - _ml;          // 90 m across
  static const double _sideLen = _mb - _mt;          // 45 m through each channel
  static const double _perimeter = (_topLen + _sideLen) * 2; // 270 m

  // Counter-clockwise: top (right→left) → left channel (top→bottom) →
  //                    bottom (left→right) → right channel (bottom→top).
  void update(double dt) {
    pathProgress += (speed / _perimeter) * dt;
    if (pathProgress >= 1.0) pathProgress -= 1.0;

    final p = pathProgress * _perimeter;

    if (p < _topLen) {
      // Top connecting strip: right channel → left channel
      x = _mr - p;
      y = _mt;
    } else if (p < _topLen + _sideLen) {
      // Left leg: travels down through left scoring channel
      x = _ml;
      y = _mt + (p - _topLen);
    } else if (p < 2 * _topLen + _sideLen) {
      // Bottom connecting strip: left channel → right channel
      x = _ml + (p - _topLen - _sideLen);
      y = _mb;
    } else {
      // Right leg: travels up through right scoring channel
      x = _mr;
      y = _mb - (p - 2 * _topLen - _sideLen);
    }
  }
}
