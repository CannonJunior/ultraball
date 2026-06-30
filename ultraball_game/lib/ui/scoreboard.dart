import 'package:flutter/material.dart';
import '../game/game_state.dart';
import '../models/ultraball.dart';

class Scoreboard extends StatelessWidget {
  final GameState gs;

  const Scoreboard({super.key, required this.gs});

  @override
  Widget build(BuildContext context) {
    final act = gs.actState;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.9),
            Colors.black.withValues(alpha: 0.7),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Left team
          Expanded(
            child: _TeamScore(
              teamName: gs.settings.awayTeamName,
              score: act.opponentScore,
              kills: act.opponentKills,
              color: const Color(0xFFE53935),
              isLeft: true,
            ),
          ),

          // Center: act + timer + phase lines
          Expanded(
            flex: 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'ACT ${act.currentAct}${act.isAct5 ? ' — FINAL ACT' : ''}',
                      style: const TextStyle(
                        color: Color(0xFFFFCC00),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  act.isAct5 ? 'SCORE AN ULTRA TO WIN' : act.timerDisplay,
                  style: TextStyle(
                    color: _timerColor(act.timerSeconds, act.isAct5),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 4),
                // Phase line indicators
                _PhaseLineIndicators(ball: gs.ball),
              ],
            ),
          ),

          // Right team
          Expanded(
            child: _TeamScore(
              teamName: gs.settings.homeTeamName,
              score: act.playerScore,
              kills: act.playerKills,
              color: const Color(0xFF1E88E5),
              isLeft: false,
            ),
          ),
        ],
      ),
    );
  }

  Color _timerColor(double seconds, bool isAct5) {
    if (isAct5) return const Color(0xFFFF8800);
    if (seconds <= 30) return const Color(0xFFFF3333);
    if (seconds <= 60) return const Color(0xFFFFAA00);
    return Colors.white;
  }
}

class _TeamScore extends StatelessWidget {
  final String teamName;
  final int score;
  final int kills;
  final Color color;
  final bool isLeft;

  const _TeamScore({
    required this.teamName,
    required this.score,
    required this.kills,
    required this.color,
    required this.isLeft,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Text(
          teamName,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        Text(
          '$score',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            height: 1.0,
          ),
        ),
        Text(
          '$kills KILLAS',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 9,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
    return Padding(
      padding: EdgeInsets.only(
        left: isLeft ? 0 : 16,
        right: isLeft ? 16 : 0,
      ),
      child: content,
    );
  }
}

class _PhaseLineIndicators extends StatelessWidget {
  final Ultraball ball;

  const _PhaseLineIndicators({required this.ball});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'PHASE: ',
          style: TextStyle(
            color: Color(0xFF888888),
            fontSize: 8,
            letterSpacing: 1,
          ),
        ),
        ...List.generate(
          5,
          (i) => Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ball.phaseLineActive[i]
                  ? const Color(0xFF00FFFF)
                  : const Color(0xFF333333),
              boxShadow: ball.phaseLineActive[i]
                  ? [
                      BoxShadow(
                        color: const Color(0xFF00FFFF).withValues(alpha: 0.6),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}
