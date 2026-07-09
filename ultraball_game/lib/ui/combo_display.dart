import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../game/game_state.dart';

/// Floating combo-streak counter that mirrors the "x{n} COMBO" tracker shown
/// in the Warchief QueuedAbilityLabelOverlay.  Renders as plain text — no box
/// or border — so it feels like a world-space annotation rather than a HUD panel.
class ComboDisplay extends StatelessWidget {
  final GameState gs;

  const ComboDisplay({super.key, required this.gs});

  @override
  Widget build(BuildContext context) {
    if (gs.comboMessage == null || gs.comboMessageTimer <= 0) {
      return const SizedBox.shrink();
    }

    // progress: 1.0 = just appeared, 0.0 = about to disappear
    final progress = (gs.comboMessageTimer / 2.0).clamp(0.0, 1.0);

    // Fade in during first 10%, hold, fade out during last 20%.
    final double opacity;
    if (progress > 0.9) {
      opacity = (1.0 - progress) / 0.1;
    } else if (progress < 0.2) {
      opacity = progress / 0.2;
    } else {
      opacity = 1.0;
    }

    // Slight scale pulse: rises from 0.85 at spawn, peaks at 1.0 mid-life,
    // back to 0.85 at fade — matches Warchief's combo tracker emphasis.
    final pulseCurve = math.sin(progress * math.pi); // 0→1→0
    final scale = (0.85 + 0.15 * pulseCurve).clamp(0.85, 1.0);

    return Center(
      child: Transform.scale(
        scale: scale,
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Text(
            gs.comboMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFFFAA00),
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              shadows: [
                Shadow(color: Colors.black, blurRadius: 3, offset: Offset(1, 1)),
                Shadow(color: Color(0x66FF6600), blurRadius: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
