import 'package:flutter/material.dart';
import '../game/game_state.dart';

class ComboDisplay extends StatelessWidget {
  final GameState gs;

  const ComboDisplay({super.key, required this.gs});

  @override
  Widget build(BuildContext context) {
    if (gs.comboMessage == null || gs.comboMessageTimer <= 0) {
      return const SizedBox.shrink();
    }

    final progress = (gs.comboMessageTimer / 2.0).clamp(0.0, 1.0);
    // Fade in then fade out
    double opacity;
    if (progress > 0.8) {
      opacity = (1.0 - progress) / 0.2; // fade in at start (high progress = early in display)
    } else if (progress < 0.2) {
      opacity = progress / 0.2; // fade out at end
    } else {
      opacity = 1.0;
    }
    opacity = opacity.clamp(0.0, 1.0);

    // Scale animation
    final scale = 0.7 + 0.3 * (1.0 - (progress - 0.5).abs() * 2).clamp(0.0, 1.0);

    return Align(
      alignment: const Alignment(0.0, 0.5),
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFFFAA00).withValues(alpha: 0.8),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFAA00).withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Text(
              gs.comboMessage!,
              style: const TextStyle(
                color: Color(0xFFFFCC00),
                fontSize: 36,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
                shadows: [
                  Shadow(
                    color: Color(0xFFFF6600),
                    blurRadius: 12,
                    offset: Offset(2, 2),
                  ),
                  Shadow(
                    color: Colors.black,
                    blurRadius: 4,
                    offset: Offset(1, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
