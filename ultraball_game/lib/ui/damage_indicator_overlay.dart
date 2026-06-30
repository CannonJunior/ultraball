import 'package:flutter/material.dart';
import '../models/damage_indicator.dart';
import '../game/game_state.dart';

class DamageIndicatorOverlay extends StatelessWidget {
  final GameState gs;
  final double scale;
  final double offsetX;
  final double offsetY;

  const DamageIndicatorOverlay({
    super.key,
    required this.gs,
    required this.scale,
    required this.offsetX,
    required this.offsetY,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: gs.indicators.map((ind) => _buildIndicator(ind)).toList(),
    );
  }

  Widget _buildIndicator(DamageIndicator ind) {
    final screenX = ind.worldX * scale + offsetX + ind.xJitter * scale;
    final screenY =
        ind.worldY * scale + offsetY - ind.progress * 60; // rise up
    final opacity = (1.0 - ind.progress * ind.progress).clamp(0.0, 1.0);

    Color textColor;
    double fontSize;
    bool hasShadow;

    switch (ind.type) {
      case IndicatorType.damage:
        textColor = const Color(0xFFFFFF44);
        fontSize = 14;
        hasShadow = false;
      case IndicatorType.kill:
        textColor = const Color(0xFFFF2222);
        fontSize = 18;
        hasShadow = true;
      case IndicatorType.heal:
        textColor = const Color(0xFF44FF88);
        fontSize = 14;
        hasShadow = false;
      case IndicatorType.combo:
        textColor = const Color(0xFFFFAA00);
        fontSize = 22;
        hasShadow = true;
      case IndicatorType.event:
        textColor = const Color(0xFFFFFFFF);
        fontSize = 15;
        hasShadow = true;
    }

    return Positioned(
      left: screenX - 40,
      top: screenY - fontSize / 2,
      child: Opacity(
        opacity: opacity,
        child: Text(
          ind.text,
          style: TextStyle(
            color: textColor,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            shadows: hasShadow
                ? [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.8),
                      blurRadius: 4,
                      offset: const Offset(1, 1),
                    ),
                  ]
                : null,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
