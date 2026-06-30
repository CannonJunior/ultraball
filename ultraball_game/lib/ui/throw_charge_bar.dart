import 'package:flutter/material.dart';
import '../game/game_state.dart';

class ThrowChargeBar extends StatelessWidget {
  final GameState gs;

  const ThrowChargeBar({super.key, required this.gs});

  @override
  Widget build(BuildContext context) {
    final player = gs.selectedPlayer;
    if (player == null || !player.isChargingThrow) {
      return const SizedBox.shrink();
    }

    final pct = player.throwChargePercent;
    final dist = player.throwDistance;
    final rangeLabel = pct < 0.3
        ? 'SHORT'
        : pct < 0.7
            ? 'MEDIUM'
            : 'LONG RANGE';

    return Container(
      width: 240,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFFFFDD00).withValues(alpha: 0.55),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFDD00).withValues(alpha: 0.18),
            blurRadius: 14,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'CHARGING THROW',
                style: TextStyle(
                  color: Color(0xFFFFDD00),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                '${dist.toStringAsFixed(0)}m',
                style: const TextStyle(
                  color: Color(0xFFFFEE66),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 12,
              child: Stack(
                children: [
                  // Background
                  Container(
                    decoration: const BoxDecoration(color: Color(0xFF1A1A1A)),
                  ),
                  // Fill with gradient
                  FractionallySizedBox(
                    widthFactor: pct,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFFAA6600),
                            Color(0xFFDDAA00),
                            Color(0xFFFFDD00),
                            Color(0xFFFFEE66),
                          ],
                          stops: [0.0, 0.4, 0.8, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // Shimmer at the leading edge
                  if (pct > 0.03)
                    FractionallySizedBox(
                      widthFactor: pct,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          width: 16,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.white.withValues(alpha: 0.55),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                rangeLabel,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 8,
                  letterSpacing: 1,
                ),
              ),
              Text(
                'RELEASE [F]',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 8,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
