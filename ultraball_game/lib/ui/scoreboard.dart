import 'package:flutter/material.dart';
import '../game/game_state.dart';
import '../models/act_state.dart';
import '../models/player.dart';
import '../models/ultraball.dart';
import 'ui_theme.dart';
import 'ui_assets.dart';

class Scoreboard extends StatelessWidget {
  final GameState gs;
  const Scoreboard({super.key, required this.gs});

  @override
  Widget build(BuildContext context) {
    final act = gs.actState;
    final t   = UiTheme.instance;

    final isAct5     = act.isAct5;
    final bgOpacity  = t.scoreboardBackgroundOpacity;
    final brdOpacity = t.scoreboardBorderOpacity;

    // Act 5 gets an animated pulsing orange border via a regular Container +
    // AnimatedContainer. Since this is a StatelessWidget we use a constant
    // high-contrast border instead — the _Act5Border wrapper below handles it.
    Widget content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: bgOpacity),
            Colors.black.withValues(alpha: (bgOpacity - 0.2).clamp(0.0, 1.0)),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: brdOpacity),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Away team (left)
          Expanded(
            child: _TeamColumn(
              teamName:    gs.settings.awayTeamName,
              score:       act.opponentScore,
              kills:       act.opponentKills,
              roster:      gs.opponentRoster,
              actResults:  act.actResults,
              isHome:      false,
              gs:          gs,
            ),
          ),

          // Center: act + timer + phase lines
          Expanded(
            flex: 2,
            child: _CenterColumn(gs: gs),
          ),

          // Home team (right)
          Expanded(
            child: _TeamColumn(
              teamName:    gs.settings.homeTeamName,
              score:       act.playerScore,
              kills:       act.playerKills,
              roster:      gs.playerRoster,
              actResults:  act.actResults,
              isHome:      true,
              gs:          gs,
            ),
          ),
        ],
      ),
    );

    if (isAct5) {
      content = _Act5Border(child: content);
    }

    return content;
  }
}

// ── Act 5 animated border ─────────────────────────────────────────────────────

class _Act5Border extends StatefulWidget {
  final Widget child;
  const _Act5Border({required this.child});

  @override
  State<_Act5Border> createState() => _Act5BorderState();
}

class _Act5BorderState extends State<_Act5Border>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, child) => DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top:    BorderSide(color: const Color(0xFFFF6600).withValues(alpha: _pulse.value), width: 2),
            bottom: BorderSide(color: const Color(0xFFFF6600).withValues(alpha: _pulse.value), width: 2),
          ),
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

// ── Team column (left or right) ────────────────────────────────────────────────

class _TeamColumn extends StatelessWidget {
  final String teamName;
  final int score;
  final int kills;
  final List<UltraballPlayer> roster;
  final List<ActResult> actResults;
  final bool isHome;
  final GameState gs;

  const _TeamColumn({
    required this.teamName,
    required this.score,
    required this.kills,
    required this.roster,
    required this.actResults,
    required this.isHome,
    required this.gs,
  });

  @override
  Widget build(BuildContext context) {
    final t     = UiTheme.instance;
    final color = isHome ? t.homeTeamColor : t.awayTeamColor;
    final align = isHome ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    // Alive / dead counts
    final alive = roster.where((p) => p.isAlive && p.isOnField).length;
    final dead  = roster.where((p) => !p.isAlive).length;

    final killaCount = kills;

    return Padding(
      padding: EdgeInsets.only(
        left:  isHome ? 16 : 0,
        right: isHome ? 0  : 16,
      ),
      child: Column(
        mainAxisSize:    MainAxisSize.min,
        crossAxisAlignment: align,
        children: [
          // Team name
          Text(
            teamName,
            style: TextStyle(
              color:        color,
              fontSize:     t.scoreboardTeamNameSize,
              fontWeight:   FontWeight.bold,
              letterSpacing: 1.2,
            ),
            overflow: TextOverflow.ellipsis,
          ),

          // Score (dominant numeral)
          Text(
            '$score',
            style: TextStyle(
              color:       Colors.white,
              fontSize:    t.scoreboardScoreSize,
              fontWeight:  FontWeight.w900,
              height:      1.0,
            ),
          ),

          // Score breakdown + act history pips
          if (t.scoreboardShowScoreBreakdown || t.scoreboardShowActHistory)
            _ScoreSubline(
              kills:      killaCount,
              actResults: actResults,
              isHome:     isHome,
              color:      color,
            ),

          // Alive / dead count
          if (t.scoreboardShowAliveCount)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isHome) ...[
                  Text(
                    '$alive',
                    style: TextStyle(color: t.aliveColor, fontSize: t.scoreboardSubInfoSize, fontWeight: FontWeight.bold),
                  ),
                  Text(' alive  ', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: t.scoreboardSubInfoSize)),
                  Text(
                    '$dead',
                    style: TextStyle(color: t.deadColor, fontSize: t.scoreboardSubInfoSize, fontWeight: FontWeight.bold),
                  ),
                  Text(' dead', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: t.scoreboardSubInfoSize)),
                ] else ...[
                  Text('dead ', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: t.scoreboardSubInfoSize)),
                  Text(
                    '$dead',
                    style: TextStyle(color: t.deadColor, fontSize: t.scoreboardSubInfoSize, fontWeight: FontWeight.bold),
                  ),
                  Text('  alive ', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: t.scoreboardSubInfoSize)),
                  Text(
                    '$alive',
                    style: TextStyle(color: t.aliveColor, fontSize: t.scoreboardSubInfoSize, fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _ScoreSubline extends StatelessWidget {
  final int kills;
  final List<ActResult> actResults;
  final bool isHome;
  final Color color;

  const _ScoreSubline({
    required this.kills,
    required this.actResults,
    required this.isHome,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = UiTheme.instance;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Killa count with skull icon
        if (t.scoreboardShowScoreBreakdown) ...[
          UiAssets.scoreIcon('killa', size: 10, color: t.scoreKillaColor),
          const SizedBox(width: 2),
          Text(
            '$kills',
            style: TextStyle(color: t.scoreKillaColor, fontSize: t.scoreboardSubInfoSize, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
        ],

        // Act history pips
        if (t.scoreboardShowActHistory)
          _ActHistoryPips(actResults: actResults, isHome: isHome),
      ],
    );
  }
}

class _ActHistoryPips extends StatelessWidget {
  final List<ActResult> actResults;
  final bool isHome;

  const _ActHistoryPips({required this.actResults, required this.isHome});

  @override
  Widget build(BuildContext context) {
    final t = UiTheme.instance;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (i >= actResults.length) {
          // Not yet played
          return Container(
            width: 8, height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1A1A2E),
              border: Border.all(color: const Color(0xFF333355), width: 1),
            ),
          );
        }
        final r = actResults[i];
        final homeWon = r.playerScore > r.opponentScore;
        final awayWon = r.opponentScore > r.playerScore;
        // For this team's pip: green if won this act, red if lost, gray if tied
        Color pipColor;
        if (isHome) {
          pipColor = homeWon ? t.homeTeamColor : awayWon ? t.deadColor : Colors.grey;
        } else {
          pipColor = awayWon ? t.awayTeamColor : homeWon ? t.deadColor : Colors.grey;
        }
        return Container(
          width: 8, height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: pipColor.withValues(alpha: 0.85),
            boxShadow: [BoxShadow(color: pipColor.withValues(alpha: 0.5), blurRadius: 3)],
          ),
        );
      }),
    );
  }
}

// ── Center column ─────────────────────────────────────────────────────────────

class _CenterColumn extends StatelessWidget {
  final GameState gs;
  const _CenterColumn({required this.gs});

  @override
  Widget build(BuildContext context) {
    final act = gs.actState;
    final t   = UiTheme.instance;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Act label
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              act.isAct5 ? 'FINAL ACT' : 'ACT ${act.currentAct}',
              style: TextStyle(
                color:         act.isAct5 ? const Color(0xFFFF6600) : t.accentColor,
                fontSize:      11,
                fontWeight:    FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),

        // Timer / Act5 prompt
        if (act.isAct5)
          const Text(
            'SCORE AN ULTRA',
            style: TextStyle(
              color:         Color(0xFFFF8800),
              fontSize:      13,
              fontWeight:    FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        if (!act.isAct5)
          Text(
            act.timerDisplay,
            style: TextStyle(
              color:      _timerColor(act.timerSeconds, act.isAct5),
              fontSize:   t.scoreboardTimerSize,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
            ),
          ),
        const SizedBox(height: 4),

        // Phase line mini-field indicator
        _PhaseFieldIndicator(ball: gs.ball),
      ],
    );
  }

  Color _timerColor(double seconds, bool isAct5) {
    if (isAct5) return const Color(0xFFFF8800);
    if (seconds <= 30) return const Color(0xFFFF3333);
    if (seconds <= 60) return const Color(0xFFFFAA00);
    return Colors.white;
  }
}

// ── Phase field indicator ─────────────────────────────────────────────────────

class _PhaseFieldIndicator extends StatelessWidget {
  final Ultraball ball;
  const _PhaseFieldIndicator({required this.ball});

  @override
  Widget build(BuildContext context) {
    final t = UiTheme.instance;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'PHASE',
          style: TextStyle(
            color:         Colors.white.withValues(alpha: 0.35),
            fontSize:      7,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: 120,
          height: 16,
          child: CustomPaint(
            painter: _PhaseFieldPainter(
              ball:            ball,
              activeColor:     t.phaseActiveColor,
              inactiveColor:   t.phaseInactiveColor,
              showBallPos:     t.phaseLineShowBallPosition,
              awayEndzoneColor: t.awayTeamColor,
              homeEndzoneColor: t.homeTeamColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _PhaseFieldPainter extends CustomPainter {
  final double ballX;
  final List<bool> phaseSnapshot;
  final Color activeColor;
  final Color inactiveColor;
  final bool showBallPos;
  final Color awayEndzoneColor;
  final Color homeEndzoneColor;

  _PhaseFieldPainter({
    required Ultraball ball,
    required this.activeColor,
    required this.inactiveColor,
    required this.showBallPos,
    this.awayEndzoneColor = const Color(0xFFE53935),
    this.homeEndzoneColor = const Color(0xFF1E88E5),
  })  : ballX = ball.x,
        phaseSnapshot = List.of(ball.phaseLineActive);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Field background strip (endzone + main + endzone, 20m : 100m : 20m = 140m total)
    final bgPaint = Paint()..color = const Color(0xFF111122);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), const Radius.circular(3)),
      bgPaint,
    );

    // Endzone tints (left = away attacks, right = home attacks)
    final leftEndW  = w * (20 / 140);
    final rightEndW = w * (20 / 140);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, leftEndW, h), const Radius.circular(3)),
      Paint()..color = awayEndzoneColor.withValues(alpha: 0.15),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w - rightEndW, 0, rightEndW, h), const Radius.circular(3)),
      Paint()..color = homeEndzoneColor.withValues(alpha: 0.15),
    );

    // Phase lines at authoritative world positions — normalize to [0,140]
    for (int i = 0; i < 5; i++) {
      final px    = Ultraball.phaseLineXPositions[i] / 140.0 * w;
      final color = phaseSnapshot[i] ? activeColor : inactiveColor;
      final paint = Paint()
        ..color       = color
        ..strokeWidth = 1.0;

      // Glow for active lines
      if (phaseSnapshot[i]) {
        canvas.drawLine(
          Offset(px, 0), Offset(px, h),
          Paint()
            ..color       = color.withValues(alpha: 0.3)
            ..strokeWidth = 3.0,
        );
      }
      canvas.drawLine(Offset(px, 0), Offset(px, h), paint);

      // Line number
      final tp = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: TextStyle(
            color:    color.withValues(alpha: 0.7),
            fontSize: 6,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(px - tp.width / 2, h - tp.height - 1));
    }

    // Ball position dot
    if (showBallPos) {
      final bx = (ballX.clamp(0.0, 140.0) / 140.0 * w);
      canvas.drawCircle(
        Offset(bx, h / 2),
        3,
        Paint()..color = const Color(0xFFFFCC00),
      );
      canvas.drawCircle(
        Offset(bx, h / 2),
        3,
        Paint()
          ..color   = const Color(0xFFFFCC00).withValues(alpha: 0.4)
          ..strokeWidth = 2
          ..style   = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_PhaseFieldPainter old) {
    if (old.ballX != ballX) return true;
    for (int i = 0; i < 5; i++) {
      if (old.phaseSnapshot[i] != phaseSnapshot[i]) return true;
    }
    return false;
  }
}
