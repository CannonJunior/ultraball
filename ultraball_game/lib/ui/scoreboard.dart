import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../game/game_state.dart';
import '../models/player.dart';
import '../models/ultraball.dart';

// ── Design palette ────────────────────────────────────────────────────────────
const _kRed   = Color(0xFFFF3B53);
const _kBlue  = Color(0xFF2F83FF);
const _kGold  = Color(0xFFFFCB3D);
const _kCyan  = Color(0xFF19E3E3);
const _kBg    = Color(0xFF04050A);

// ── Ball color (matches field_painter charge color logic) ─────────────────────
Color _ballColor(double chargePercent) {
  if (chargePercent < 0.5) {
    return Color.lerp(const Color(0xFF88FF88), const Color(0xFFFFFF00), chargePercent * 2)!;
  }
  if (chargePercent < 0.75) {
    return Color.lerp(const Color(0xFFFFFF00), const Color(0xFFFF8800), (chargePercent - 0.5) * 4)!;
  }
  if (chargePercent < 0.9) {
    return Color.lerp(const Color(0xFFFF8800), const Color(0xFFFF2200), (chargePercent - 0.75) * 6.67)!;
  }
  return const Color(0xFFFF0000);
}

// ── Public widget ─────────────────────────────────────────────────────────────

class Scoreboard extends StatefulWidget {
  final GameState gs;
  const Scoreboard({super.key, required this.gs});

  @override
  State<Scoreboard> createState() => _ScoreboardState();
}

class _ScoreboardState extends State<Scoreboard>
    with TickerProviderStateMixin {
  late final AnimationController _pipCtrl;
  late final AnimationController _blinkCtrl;
  late final Animation<double>   _pipGlow;

  // ── Debug height measurement ──────────────────────────────────────────────
  final _mainBarKey = GlobalKey();
  final _ballDivKey = GlobalKey();
  final _cardsKey   = GlobalKey();
  double? _mainBarH, _ballDivH, _cardsH;

  void _readHeights() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      double? h(GlobalKey k) =>
          (k.currentContext?.findRenderObject() as RenderBox?)?.size.height;
      final mb = h(_mainBarKey);
      final bd = h(_ballDivKey);
      final cr = h(_cardsKey);
      if (mb != _mainBarH || bd != _ballDivH || cr != _cardsH) {
        setState(() { _mainBarH = mb; _ballDivH = bd; _cardsH = cr; });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _pipCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _pipGlow = Tween<double>(begin: 0.25, end: 1.0)
        .animate(CurvedAnimation(parent: _pipCtrl, curve: Curves.easeInOut));
    _blinkCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat();
  }

  @override
  void dispose() {
    _pipCtrl.dispose();
    _blinkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _readHeights();

    final gs  = widget.gs;
    final act = gs.actState;

    // Show all field-slot players (deploySlot < 7); dead ones will be greyed
    final awayPlayers = gs.opponentRoster.where((p) => p.deploySlot < 7).toList();
    final homePlayers = gs.playerRoster.where((p) => p.deploySlot < 7).toList();

    final actLabel = act.isAct5 ? 'FINAL ACT' : 'ACT ${act.currentAct}';

    final mb = _mainBarH?.toStringAsFixed(1) ?? '?';
    final bd = _ballDivH?.toStringAsFixed(1) ?? '?';
    final cr = _cardsH?.toStringAsFixed(1)   ?? '?';
    final total = (_mainBarH != null && _ballDivH != null && _cardsH != null)
        ? (_mainBarH! + _ballDivH! + _cardsH!).toStringAsFixed(1)
        : '?';

    return Stack(
      children: [
        Container(
          color: _kBg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              KeyedSubtree(
                key: _mainBarKey,
                child: _MainBar(
                  awayName:   gs.settings.awayTeamName,
                  homeName:   gs.settings.homeTeamName,
                  awayScore:  act.opponentScore,
                  homeScore:  act.playerScore,
                  actLabel:   actLabel,
                  act:        act.currentAct,
                  actResults: act.actResults.length,
                  timerSecs:  act.timerSeconds,
                  timerText:  act.timerDisplay,
                  isAct5:     act.isAct5,
                  pipGlow:    _pipGlow,
                  blinkCtrl:  _blinkCtrl,
                ),
              ),
              KeyedSubtree(
                key: _ballDivKey,
                child: _BallDivider(ball: gs.ball),
              ),
              KeyedSubtree(
                key: _cardsKey,
                child: _PlayerCardsRow(
                  awayPlayers: awayPlayers,
                  homePlayers: homePlayers,
                  targetId:    gs.currentTargetId,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 4,
          right: 8,
          child: IgnorePointer(
            child: Text(
              'MainBar:${mb}  BallDiv:${bd}  Cards:${cr}  Total:${total}',
              style: const TextStyle(
                color: Color(0xFFFFFF00),
                fontSize: 10,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                shadows: [Shadow(color: Colors.black, blurRadius: 4)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Main bar (team names + scores + center timer) ─────────────────────────────

class _MainBar extends StatelessWidget {
  final String awayName, homeName;
  final int awayScore, homeScore, act, actResults;
  final String actLabel, timerText;
  final double timerSecs;
  final bool isAct5;
  final Animation<double> pipGlow;
  final AnimationController blinkCtrl;

  const _MainBar({
    required this.awayName,
    required this.homeName,
    required this.awayScore,
    required this.homeScore,
    required this.actLabel,
    required this.act,
    required this.actResults,
    required this.timerText,
    required this.timerSecs,
    required this.isAct5,
    required this.pipGlow,
    required this.blinkCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF111122), width: 1)),
      ),
      child: Stack(
        children: [
          // Ambient team-color glow
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _kRed.withValues(alpha: 0.18),
                    Colors.transparent,
                    Colors.transparent,
                    _kBlue.withValues(alpha: 0.18),
                  ],
                  stops: const [0, 0.36, 0.64, 1],
                ),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Away (left) panel
              Expanded(
                child: ClipPath(
                  clipper: _LeftPanelClipper(),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_kRed.withValues(alpha: 0.28), _kRed.withValues(alpha: 0.04)],
                      ),
                    ),
                    child: _TeamPanel(
                      name:   awayName,
                      score:  awayScore,
                      color:  _kRed,
                      isHome: false,
                    ),
                  ),
                ),
              ),
              // Center panel
              SizedBox(
                width: 150,
                child: ClipPath(
                  clipper: _CenterClipper(),
                  child: ColoredBox(
                    color: Colors.black,
                    child: _CenterPanel(
                      actLabel:   actLabel,
                      act:        act,
                      actResults: actResults,
                      timerText:  timerText,
                      timerSecs:  timerSecs,
                      isAct5:     isAct5,
                      pipGlow:    pipGlow,
                      blinkCtrl:  blinkCtrl,
                    ),
                  ),
                ),
              ),
              // Home (right) panel
              Expanded(
                child: ClipPath(
                  clipper: _RightPanelClipper(),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [_kBlue.withValues(alpha: 0.28), _kBlue.withValues(alpha: 0.04)],
                      ),
                    ),
                    child: _TeamPanel(
                      name:   homeName,
                      score:  homeScore,
                      color:  _kBlue,
                      isHome: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Team panel (name + score) ─────────────────────────────────────────────────

class _TeamPanel extends StatelessWidget {
  final String name;
  final int    score;
  final Color  color;
  final bool   isHome;

  const _TeamPanel({required this.name, required this.score, required this.color, required this.isHome});

  @override
  Widget build(BuildContext context) {
    final nameW = Text(
      name,
      style: GoogleFonts.barlowCondensed(
        fontSize:   26,
        fontWeight: FontWeight.w700,
        fontStyle:  FontStyle.italic,
        color:      Colors.white,
        letterSpacing: 0.5,
        shadows: [Shadow(color: color.withValues(alpha: 0.6), blurRadius: 0, offset: const Offset(0, 2))],
      ),
      overflow: TextOverflow.ellipsis,
    );
    final scoreW = Text(
      '$score',
      style: GoogleFonts.barlowCondensed(
        fontSize:   36,
        fontWeight: FontWeight.w700,
        color:      Colors.white,
        height:     0.85,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: isHome
          ? [scoreW, const SizedBox(width: 10), nameW]
          : [nameW, const SizedBox(width: 10), scoreW],
      ),
    );
  }
}

// ── Center panel (act label + timer + pips) ───────────────────────────────────

class _CenterPanel extends StatelessWidget {
  final String actLabel, timerText;
  final double timerSecs;
  final int    act, actResults;
  final bool   isAct5;
  final Animation<double> pipGlow;
  final AnimationController blinkCtrl;

  const _CenterPanel({
    required this.actLabel,
    required this.act,
    required this.actResults,
    required this.timerText,
    required this.timerSecs,
    required this.isAct5,
    required this.pipGlow,
    required this.blinkCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final parts = timerText.split(':');
    final mins  = parts[0];
    final secs  = parts.length > 1 ? parts[1] : '00';

    final timerColor = isAct5
      ? const Color(0xFFFF8800)
      : timerSecs <= 30 ? const Color(0xFFFF4444)
      : timerSecs <= 60 ? const Color(0xFFFFAA00)
      : _kCyan;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          actLabel,
          style: GoogleFonts.chakraPetch(
            fontSize:   9,
            fontWeight: FontWeight.w600,
            letterSpacing: 3,
            color:      _kGold,
          ),
        ),
        const SizedBox(height: 2),
        AnimatedBuilder(
          animation: blinkCtrl,
          builder: (_, __) {
            final colonVisible = blinkCtrl.value < 0.5;
            return Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(mins,
                  style: GoogleFonts.barlowCondensed(
                    fontSize:   38,
                    fontWeight: FontWeight.w700,
                    fontStyle:  FontStyle.italic,
                    color:      timerColor,
                    letterSpacing: 1,
                    shadows: [Shadow(color: timerColor.withValues(alpha: 0.55), blurRadius: 16)],
                  )),
                Text(':',
                  style: GoogleFonts.barlowCondensed(
                    fontSize:   38,
                    fontWeight: FontWeight.w700,
                    fontStyle:  FontStyle.italic,
                    color:      timerColor.withValues(alpha: colonVisible ? 1.0 : 0.0),
                  )),
                Text(secs,
                  style: GoogleFonts.barlowCondensed(
                    fontSize:   38,
                    fontWeight: FontWeight.w700,
                    fontStyle:  FontStyle.italic,
                    color:      timerColor,
                    letterSpacing: 1,
                  )),
              ],
            );
          },
        ),
        const SizedBox(height: 4),
        AnimatedBuilder(
          animation: pipGlow,
          builder: (_, __) => _ActPips(
            currentAct: act, completedActs: actResults, glowAlpha: pipGlow.value),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}

// ── Act pips ──────────────────────────────────────────────────────────────────

class _ActPips extends StatelessWidget {
  final int    currentAct, completedActs;
  final double glowAlpha;
  const _ActPips({required this.currentAct, required this.completedActs, required this.glowAlpha});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final actNum   = i + 1;
        final isCurrent = actNum == currentAct;

        Color bg;
        List<BoxShadow>? shadow;
        if (actNum < currentAct) {
          bg = _kCyan;
          shadow = null;
        } else if (isCurrent) {
          bg = _kCyan.withValues(alpha: 0.4 + glowAlpha * 0.6);
          shadow = [BoxShadow(color: _kCyan.withValues(alpha: glowAlpha * 0.7), blurRadius: 8)];
        } else {
          bg = Colors.white.withValues(alpha: 0.14);
          shadow = null;
        }

        return Container(
          width:  18,
          height: 4,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color:        bg,
            borderRadius: BorderRadius.circular(2),
            boxShadow:    shadow,
          ),
        );
      }),
    );
  }
}

// ── Ball divider (replaces old charge bar) ────────────────────────────────────

class _BallDivider extends StatelessWidget {
  final Ultraball ball;
  const _BallDivider({required this.ball});

  @override
  Widget build(BuildContext context) {
    final charge  = ball.chargePercent;
    final flash   = ball.explosionFlash;
    final bColor  = flash > 0
        ? Color.lerp(_ballColor(charge), const Color(0xFFFF4400), flash)!
        : _ballColor(charge);

    const divH    = 32.0;
    const iconSz  = 32.0;

    final glowRadius = flash > 0 ? 12.0 + flash * 24.0 : 8.0;
    final glowAlpha  = flash > 0 ? 0.35 + flash * 0.55 : 0.28;
    final iconScale  = flash > 0 ? 1.0 + flash * 0.45 : 1.0;

    return SizedBox(
      height: divH,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Full-width colored divider line with charge fill
          Positioned.fill(
            child: CustomPaint(
              painter: _DividerLinePainter(ballColor: bColor, chargeFrac: charge),
            ),
          ),
          // Ultraball icon floating on the divider
          Transform.scale(
            scale: iconScale,
            child: Container(
              width:  iconSz,
              height: iconSz,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kBg,
                border: Border.all(
                  color: bColor,
                  width: flash > 0 ? 2.5 : 1.5),
                boxShadow: [
                  BoxShadow(
                    color: bColor.withValues(alpha: glowAlpha),
                    blurRadius: glowRadius,
                  ),
                ],
              ),
              child: Center(
                child: CustomPaint(
                  size: Size(iconSz * 0.62, iconSz * 0.62),
                  painter: _UltraballPainter(explosionFlash: flash),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Divider line painter ──────────────────────────────────────────────────────

class _DividerLinePainter extends CustomPainter {
  final Color  ballColor;
  final double chargeFrac;

  const _DividerLinePainter({required this.ballColor, required this.chargeFrac});

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;

    // Background track
    canvas.drawLine(
      Offset(0, cy),
      Offset(size.width, cy),
      Paint()..color = Colors.white.withValues(alpha: 0.09)..strokeWidth = 2,
    );

    // Charge fill (left side)
    if (chargeFrac > 0) {
      canvas.drawLine(
        Offset(0, cy),
        Offset(size.width * chargeFrac, cy),
        Paint()..color = ballColor..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_DividerLinePainter old) =>
      old.ballColor != ballColor || old.chargeFrac != chargeFrac;
}

// ── Ultraball icon painter (with explosion burst) ─────────────────────────────

class _UltraballPainter extends CustomPainter {
  final double explosionFlash;
  const _UltraballPainter({this.explosionFlash = 0});

  @override
  void paint(Canvas canvas, Size sz) {
    final r  = sz.width / 2;
    final cx = r, cy = r;

    // Explosion burst spikes
    if (explosionFlash > 0) {
      const numSpikes = 8;
      final spikePaint = Paint()
        ..color = const Color(0xFFFF4400).withValues(alpha: explosionFlash * 0.9)
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round;
      for (int i = 0; i < numSpikes; i++) {
        final angle  = (i / numSpikes) * math.pi * 2 + math.pi / numSpikes;
        final innerR = r * 1.15;
        final outerR = r * (1.6 + explosionFlash * 2.2);
        canvas.drawLine(
          Offset(cx + math.cos(angle) * innerR, cy + math.sin(angle) * innerR),
          Offset(cx + math.cos(angle) * outerR, cy + math.sin(angle) * outerR),
          spikePaint,
        );
      }
    }

    // Gold top segment
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -math.pi, math.pi * 0.42, true,
        Paint()..color = _kGold);
    // White middle band
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -math.pi + math.pi * 0.42, math.pi * 0.16, true,
        Paint()..color = Colors.white);
    // Dark bottom segment
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -math.pi + math.pi * 0.58, math.pi * 1.42, true,
        Paint()..color = const Color(0xFF1A1C22));
    // Border
    canvas.drawCircle(Offset(cx, cy), r,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(_UltraballPainter old) => old.explosionFlash != explosionFlash;
}

// ── Player cards row ──────────────────────────────────────────────────────────

class _PlayerCardsRow extends StatelessWidget {
  final List<UltraballPlayer> awayPlayers, homePlayers;
  final String? targetId;
  const _PlayerCardsRow({
    required this.awayPlayers,
    required this.homePlayers,
    required this.targetId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kBg,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Away team cards
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: awayPlayers.map((p) =>
                _PlayerCard(
                  player:           p,
                  teamColor:        _kRed,
                  killBadgeOnRight: true,
                  isTargeted:       p.id == targetId,
                )
              ).toList(),
            ),
          ),
          const SizedBox(width: 18),
          // Home team cards
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: homePlayers.map((p) =>
                _PlayerCard(
                  player:           p,
                  teamColor:        _kBlue,
                  killBadgeOnRight: false,
                  isTargeted:       p.id == targetId || p.isSelected,
                )
              ).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final UltraballPlayer player;
  final Color teamColor;
  final bool  killBadgeOnRight;
  final bool  isTargeted;

  const _PlayerCard({
    required this.player,
    required this.teamColor,
    required this.killBadgeOnRight,
    required this.isTargeted,
  });

  @override
  Widget build(BuildContext context) {
    final hpPct  = (player.health / player.maxHealth.clamp(1, double.infinity)).clamp(0.0, 1.0);
    final isDead = !player.isAlive;
    final badge  = player.name.isNotEmpty ? player.name[0] : '?';
    final kills  = player.killsThisMatch;

    final textAlpha   = isDead ? 0.35 : 1.0;
    final hpBarColor  = isDead ? Colors.grey.shade700 : teamColor;

    final borderColor = isTargeted
        ? _kGold
        : Colors.white.withValues(alpha: isDead ? 0.07 : 0.14);
    final borderWidth = isTargeted ? 1.5 : 1.0;
    final glowShadow  = isTargeted
        ? [BoxShadow(color: _kGold.withValues(alpha: 0.55), blurRadius: 6)]
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar
          SizedBox(
            width: 30,
            height: 30,
            child: Stack(
              children: [
                Container(
                  width: 29,
                  height: 29,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDead
                        ? [Colors.grey.shade800, Colors.grey.shade900]
                        : [teamColor, teamColor.withValues(alpha: 0.3)],
                    ),
                    border: Border.all(color: borderColor, width: borderWidth),
                    boxShadow: glowShadow,
                  ),
                  child: Center(
                    child: Text(
                      badge,
                      style: GoogleFonts.barlowCondensed(
                        fontSize:   14,
                        fontWeight: FontWeight.w700,
                        color:      Colors.white.withValues(alpha: textAlpha)),
                    ),
                  ),
                ),
                if (kills > 0)
                  Positioned(
                    bottom: 0,
                    right: killBadgeOnRight ? 0 : null,
                    left:  killBadgeOnRight ? null : 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text('$kills',
                        style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 7,
                          fontWeight: FontWeight.w700, color: _kGold)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          // HP bar
          Container(
            width:  26,
            height: 4,
            decoration: BoxDecoration(
              color:        Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              widthFactor: hpPct,
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  color:        hpBarColor,
                  borderRadius: BorderRadius.circular(2)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Clippers ──────────────────────────────────────────────────────────────────

const _kCut = 26.0;

class _LeftPanelClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..moveTo(0, 0)
    ..lineTo(s.width, 0)
    ..lineTo(s.width - _kCut, s.height)
    ..lineTo(0, s.height)
    ..close();
  @override bool shouldReclip(_) => false;
}

class _CenterClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..moveTo(_kCut, 0)
    ..lineTo(s.width - _kCut, 0)
    ..lineTo(s.width, s.height)
    ..lineTo(0, s.height)
    ..close();
  @override bool shouldReclip(_) => false;
}

class _RightPanelClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..moveTo(_kCut, 0)
    ..lineTo(s.width, 0)
    ..lineTo(s.width, s.height)
    ..lineTo(0, s.height)
    ..close();
  @override bool shouldReclip(_) => false;
}
