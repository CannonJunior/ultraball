import 'dart:math' as math;

enum IndicatorType { damage, kill, heal, combo, event }

class DamageIndicator {
  final double worldX;
  final double worldY;
  final String text;
  final IndicatorType type;
  double age = 0;
  final double maxAge;
  final double xJitter;

  DamageIndicator({
    required this.worldX,
    required this.worldY,
    required this.text,
    required this.type,
    double? lifespan,
  }) : maxAge = lifespan ?? (type == IndicatorType.combo ? 2.0 : 1.5),
       xJitter = (math.Random().nextDouble() - 0.5) * 1.5;

  bool get isExpired => age >= maxAge;
  double get progress => (age / maxAge).clamp(0.0, 1.0);

  void update(double dt) {
    age += dt;
  }
}
