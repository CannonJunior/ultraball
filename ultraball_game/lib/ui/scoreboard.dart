import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../game/game_state.dart';
import '../models/game_settings.dart';
import '../models/player.dart';
import '../models/ultraball.dart';

// ── Design palette ────────────────────────────────────────────────────────────
const _kGold  = Color(0xFFFFCB3D);
const _kCyan  = Color(0xFF19E3E3);
const _kBg    = Color(0xFF04050A);

// Fixed scoreboard height — matches 2-team layout: _MainBar(110) + _BallDivider(32) + _PlayerCardsRow(55).
const double _kScoreboardHeight = 197.0;

// ── Ball color (matches field_painter charge color logic) ─────────────────────
Color _ballColor(double chargePercent) {
  if (chargePercent < 0.5) {
    return Color.lerp(const Color(0xFFFFCC00), const Color(0xFFFF6600), chargePercent * 2)!;
  }
  if (chargePercent < 0.9) {
    return Color.lerp(const Color(0xFFFF6600), const Color(0xFFFF0044), (chargePercent - 0.5) / 0.4)!;
  }
  return const Color(0xFFFF0044);
}

// ── Public widget ─────────────────────────────────────────────────────────────

class Scoreboard extends StatefulWidget {
  final GameState gs;
  // In 3-team mode these are inserted between each team panel.
  final Widget? awayVideoPanel;
  final Widget? thirdVideoPanel;
  final Widget? homeVideoPanel;
  const Scoreboard({
    super.key,
    required this.gs,
    this.awayVideoPanel,
    this.thirdVideoPanel,
    this.homeVideoPanel,
  });

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
    _readHeights();
  }

  @override
  void dispose() {
    _pipCtrl.dispose();
    _blinkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gs  = widget.gs;
    final act = gs.actState;

    // Show all field-slot players (deploySlot < 7); dead ones will be greyed
    final awayPlayers = gs.opponentRoster.where((p) => p.deploySlot < 7).toList();
    final homePlayers = gs.playerRoster.where((p) => p.deploySlot < 7).toList();
    final isThreeTeam = gs.settings.matchMode == MatchMode.threeTeams;
    final thirdPlayers = isThreeTeam
        ? gs.thirdRoster.where((p) => p.deploySlot < 7).toList()
        : null;

    final actLabel = act.isAct5 ? 'FINAL ACT' : 'ACT ${act.currentAct}';

    final showDebug = gs.prefs.showScoreboardDebugHeights;

    final body = Container(
      color: _kBg,
      child: isThreeTeam
          ? _ThreeTeamLayout(
              gs:             gs,
              actLabel:       actLabel,
              actNum:         act.currentAct,
              actResults:     act.actResults.length,
              timerText:      act.timerDisplay,
              timerSecs:      act.timerSeconds,
              isAct5:         act.isAct5,
              playerScore:    act.playerScore,
              opponentScore:  act.opponentScore,
              thirdScore:     act.thirdScore,
              awayPlayers:    awayPlayers,
              homePlayers:    homePlayers,
              thirdPlayers:   thirdPlayers!,
              pipGlow:        _pipGlow,
              blinkCtrl:      _blinkCtrl,
              awayVideoPanel: widget.awayVideoPanel,
              thirdVideoPanel: widget.thirdVideoPanel,
              homeVideoPanel: widget.homeVideoPanel,
            )
          : Column(
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
                    awayColor:  Color(gs.settings.awayTeamPrimary),
                    homeColor:  Color(gs.settings.homeTeamPrimary),
                    thirdName:  null,
                    thirdScore: null,
                    thirdColor: null,
                  ),
                ),
                KeyedSubtree(
                  key: _ballDivKey,
                  child: _BallDivider(ball: gs.ball),
                ),
                KeyedSubtree(
                  key: _cardsKey,
                  child: _PlayerCardsRow(
                    awayPlayers:  awayPlayers,
                    homePlayers:  homePlayers,
                    thirdPlayers: null,
                    targetId:     gs.currentTargetId,
                    awayColor:    Color(gs.settings.awayTeamPrimary),
                    homeColor:    Color(gs.settings.homeTeamPrimary),
                    thirdColor:   null,
                  ),
                ),
              ],
            ),
    );

    if (!showDebug) return body;

    final mb = _mainBarH?.toStringAsFixed(1) ?? '?';
    final bd = _ballDivH?.toStringAsFixed(1) ?? '?';
    final cr = _cardsH?.toStringAsFixed(1)   ?? '?';
    final total = (_mainBarH != null && _ballDivH != null && _cardsH != null)
        ? (_mainBarH! + _ballDivH! + _cardsH!).toStringAsFixed(1)
        : '?';

    return Stack(
      children: [
        body,
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
  final Color awayColor, homeColor;
  final String? thirdName;
  final int? thirdScore;
  final Color? thirdColor;

  // Precomputed alpha variants — avoids allocating Color objects on every rebuild.
  final Color _awayGlow18;
  final Color _awayGrad28;
  final Color _awayGrad04;
  final Color _homeGlow18;
  final Color _homeGrad28;
  final Color _homeGrad04;

  _MainBar({
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
    required this.awayColor,
    required this.homeColor,
    this.thirdName,
    this.thirdScore,
    this.thirdColor,
  })  : _awayGlow18 = awayColor.withValues(alpha: 0.18),
        _awayGrad28 = awayColor.withValues(alpha: 0.28),
        _awayGrad04 = awayColor.withValues(alpha: 0.04),
        _homeGlow18 = homeColor.withValues(alpha: 0.18),
        _homeGrad28 = homeColor.withValues(alpha: 0.28),
        _homeGrad04 = homeColor.withValues(alpha: 0.04);

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
                    _awayGlow18,
                    Colors.transparent,
                    Colors.transparent,
                    _homeGlow18,
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
                        colors: [_awayGrad28, _awayGrad04],
                      ),
                    ),
                    child: _TeamPanel(
                      name:   awayName,
                      score:  awayScore,
                      color:  awayColor,
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
                      thirdName:  thirdName,
                      thirdScore: thirdScore,
                      thirdColor: thirdColor,
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
                        colors: [_homeGrad28, _homeGrad04],
                      ),
                    ),
                    child: _TeamPanel(
                      name:   homeName,
                      score:  homeScore,
                      color:  homeColor,
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
  final String? thirdName;
  final int?    thirdScore;
  final Color?  thirdColor;

  const _CenterPanel({
    required this.actLabel,
    required this.act,
    required this.actResults,
    required this.timerText,
    required this.timerSecs,
    required this.isAct5,
    required this.pipGlow,
    required this.blinkCtrl,
    this.thirdName,
    this.thirdScore,
    this.thirdColor,
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
        Row(
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
            AnimatedBuilder(
              animation: blinkCtrl,
              builder: (_, __) => Opacity(
                opacity: blinkCtrl.value < 0.5 ? 1.0 : 0.0,
                child: Text(':',
                  style: GoogleFonts.barlowCondensed(
                    fontSize:   38,
                    fontWeight: FontWeight.w700,
                    fontStyle:  FontStyle.italic,
                    color:      timerColor,
                  )),
              ),
            ),
            Text(secs,
              style: GoogleFonts.barlowCondensed(
                fontSize:   38,
                fontWeight: FontWeight.w700,
                fontStyle:  FontStyle.italic,
                color:      timerColor,
                letterSpacing: 1,
              )),
          ],
        ),
        const SizedBox(height: 4),
        AnimatedBuilder(
          animation: pipGlow,
          builder: (_, __) => _ActPips(
            currentAct: act, completedActs: actResults, glowAlpha: pipGlow.value),
        ),
        if (thirdName != null) ...[
          const SizedBox(height: 5),
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.08),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 8, height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  color: thirdColor!.withValues(alpha: 0.9))),
              const SizedBox(width: 5),
              Text(
                thirdName!,
                style: GoogleFonts.barlowCondensed(
                  fontSize:   11,
                  fontWeight: FontWeight.w700,
                  color:      Colors.white.withValues(alpha: 0.7),
                  letterSpacing: 0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(width: 6),
              Text(
                '${thirdScore ?? 0}',
                style: GoogleFonts.barlowCondensed(
                  fontSize:   15,
                  fontWeight: FontWeight.w700,
                  color:      thirdColor!,
                ),
              ),
            ],
          ),
        ],
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
  final List<UltraballPlayer>? thirdPlayers;
  final String? targetId;
  final Color awayColor, homeColor;
  final Color? thirdColor;
  const _PlayerCardsRow({
    required this.awayPlayers,
    required this.homePlayers,
    required this.targetId,
    required this.awayColor,
    required this.homeColor,
    this.thirdPlayers,
    this.thirdColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kBg,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Away team cards
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: awayPlayers.map((p) =>
                    _PlayerCard(
                      player:           p,
                      teamColor:        awayColor,
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
                      teamColor:        homeColor,
                      killBadgeOnRight: false,
                      isTargeted:       p.id == targetId || p.isSelected,
                    )
                  ).toList(),
                ),
              ),
            ],
          ),
          if (thirdPlayers != null && thirdColor != null) ...[
            const SizedBox(height: 4),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: thirdPlayers!.map((p) =>
                _PlayerCard(
                  player:           p,
                  teamColor:        thirdColor!,
                  killBadgeOnRight: false,
                  isTargeted:       false,
                )
              ).toList(),
            ),
          ],
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

// ── 3-Team horizontal layout ─────────────────────────────────────────────────

class _ThreeTeamLayout extends StatelessWidget {
  final GameState gs;
  final String actLabel, timerText;
  final double timerSecs;
  final int    actNum, actResults, playerScore, opponentScore, thirdScore;
  final bool   isAct5;
  final List<UltraballPlayer> awayPlayers, homePlayers, thirdPlayers;
  final Animation<double> pipGlow;
  final AnimationController blinkCtrl;
  final Widget? awayVideoPanel;
  final Widget? thirdVideoPanel;
  final Widget? homeVideoPanel;

  const _ThreeTeamLayout({
    required this.gs,
    required this.actLabel,
    required this.actNum,
    required this.actResults,
    required this.timerText,
    required this.timerSecs,
    required this.isAct5,
    required this.playerScore,
    required this.opponentScore,
    required this.thirdScore,
    required this.awayPlayers,
    required this.homePlayers,
    required this.thirdPlayers,
    required this.pipGlow,
    required this.blinkCtrl,
    this.awayVideoPanel,
    this.thirdVideoPanel,
    this.homeVideoPanel,
  });

  @override
  Widget build(BuildContext context) {
    final ball     = gs.ball;
    final settings = gs.settings;
    final awayColor  = Color(settings.awayTeamPrimary);
    final homeColor  = Color(settings.homeTeamPrimary);
    final thirdColor = Color(settings.thirdTeamPrimary);

    // possessingTeamId: 'player'=home, 'opponent'=away, 'third'=third, null=free
    final awayPossessing  = ball.possessingTeamId == 'opponent';
    final thirdPossessing = ball.possessingTeamId == 'third';
    final homePossessing  = ball.possessingTeamId == 'player';

    // phaseLineActive3 indices: 0-2 = player(home), 3-5 = opponent(away), 6-8 = third
    final homePhaseLines  = ball.phaseLineActive3.sublist(0, 3);
    final awayPhaseLines  = ball.phaseLineActive3.sublist(3, 6);
    final thirdPhaseLines = ball.phaseLineActive3.sublist(6, 9);

    final timerColor = isAct5
        ? const Color(0xFFFF8800)
        : timerSecs <= 30 ? const Color(0xFFFF4444)
        : timerSecs <= 60 ? const Color(0xFFFFAA00)
        : _kCyan;

    return SizedBox(
      height: _kScoreboardHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 1. Info section (act, timer, ball-if-free) ────────────────────
          SizedBox(
            width: 96,
            child: _InfoPanel3T(
              actLabel:   actLabel,
              actNum:     actNum,
              actResults: actResults,
              timerText:  timerText,
              timerSecs:  timerSecs,
              timerColor: timerColor,
              isAct5:     isAct5,
              pipGlow:    pipGlow,
              blinkCtrl:  blinkCtrl,
              ballFree:   ball.possessingTeamId == null,
              ball:       ball,
            ),
          ),
          // ── 2. Away video panel ───────────────────────────────────────────
          Expanded(
            flex: 2,
            child: awayVideoPanel ?? const SizedBox(),
          ),
          // ── 3. Away team (opponent) ───────────────────────────────────────
          Expanded(
            flex: 1,
            child: _TeamPanel3T(
              teamName:   settings.awayTeamName,
              score:      opponentScore,
              color:      awayColor,
              players:    awayPlayers,
              phaseLines: awayPhaseLines,
              possessing: awayPossessing,
              ball:       ball,
              targetId:   gs.currentTargetId,
            ),
          ),
          // ── 4. Third video panel ──────────────────────────────────────────
          Expanded(
            flex: 2,
            child: thirdVideoPanel ?? const SizedBox(),
          ),
          // ── 5. Third team ─────────────────────────────────────────────────
          Expanded(
            flex: 1,
            child: _TeamPanel3T(
              teamName:   settings.thirdTeamName,
              score:      thirdScore,
              color:      thirdColor,
              players:    thirdPlayers,
              phaseLines: thirdPhaseLines,
              possessing: thirdPossessing,
              ball:       ball,
              targetId:   gs.currentTargetId,
            ),
          ),
          // ── 6. Home video panel ───────────────────────────────────────────
          Expanded(
            flex: 2,
            child: homeVideoPanel ?? const SizedBox(),
          ),
          // ── 7. Home team (player) ─────────────────────────────────────────
          Expanded(
            flex: 1,
            child: _TeamPanel3T(
              teamName:   settings.homeTeamName,
              score:      playerScore,
              color:      homeColor,
              players:    homePlayers,
              phaseLines: homePhaseLines,
              possessing: homePossessing,
              ball:       ball,
              targetId:   gs.currentTargetId,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 3-Team info panel (left section) ─────────────────────────────────────────

class _InfoPanel3T extends StatelessWidget {
  final String actLabel, timerText;
  final double timerSecs;
  final Color  timerColor;
  final int    actNum, actResults;
  final bool   isAct5, ballFree;
  final Animation<double> pipGlow;
  final AnimationController blinkCtrl;
  final Ultraball ball;

  const _InfoPanel3T({
    required this.actLabel,
    required this.actNum,
    required this.actResults,
    required this.timerText,
    required this.timerSecs,
    required this.timerColor,
    required this.isAct5,
    required this.pipGlow,
    required this.blinkCtrl,
    required this.ballFree,
    required this.ball,
  });

  @override
  Widget build(BuildContext context) {
    final parts = timerText.split(':');
    final mins  = parts[0];
    final secs  = parts.length > 1 ? parts[1] : '00';

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Color(0xFF1A1A30), width: 1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            actLabel,
            style: GoogleFonts.chakraPetch(
              fontSize: 8, fontWeight: FontWeight.w600,
              letterSpacing: 2.5, color: _kGold,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(mins,
                style: GoogleFonts.barlowCondensed(
                  fontSize: 32, fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic, color: timerColor,
                  shadows: [Shadow(color: timerColor.withValues(alpha: 0.5), blurRadius: 12)],
                )),
              AnimatedBuilder(
                animation: blinkCtrl,
                builder: (_, __) => Opacity(
                  opacity: blinkCtrl.value < 0.5 ? 1.0 : 0.0,
                  child: Text(':', style: GoogleFonts.barlowCondensed(
                    fontSize: 32, fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic, color: timerColor,
                  )),
                ),
              ),
              Text(secs,
                style: GoogleFonts.barlowCondensed(
                  fontSize: 32, fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic, color: timerColor,
                )),
            ],
          ),
          const SizedBox(height: 4),
          AnimatedBuilder(
            animation: pipGlow,
            builder: (_, __) => _ActPips(
              currentAct: actNum, completedActs: actResults, glowAlpha: pipGlow.value),
          ),
          if (ballFree) ...[
            const SizedBox(height: 6),
            _FreeBall3T(ball: ball),
          ],
        ],
      ),
    );
  }
}

// ── Free-ball placeholder shown in info panel ─────────────────────────────────

class _FreeBall3T extends StatelessWidget {
  final Ultraball ball;
  const _FreeBall3T({required this.ball});

  @override
  Widget build(BuildContext context) {
    const sz = 24.0;
    final flash  = ball.explosionFlash;
    final bColor = flash > 0
        ? Color.lerp(_ballColor(ball.chargePercent), const Color(0xFFFF4400), flash)!
        : Colors.white.withValues(alpha: 0.4);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: sz, height: sz,
          decoration: BoxDecoration(
            shape:  BoxShape.circle,
            color:  _kBg,
            border: Border.all(color: bColor, width: 1.5),
            boxShadow: [BoxShadow(color: bColor.withValues(alpha: 0.3), blurRadius: 8)],
          ),
          child: Center(
            child: CustomPaint(
              size: Size(sz * 0.62, sz * 0.62),
              painter: _UltraballPainter(explosionFlash: flash),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text('FREE',
          style: GoogleFonts.chakraPetch(
            fontSize: 7, fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
            color: Colors.white.withValues(alpha: 0.30),
          )),
      ],
    );
  }
}

// ── 3-Team individual team panel ──────────────────────────────────────────────

class _TeamPanel3T extends StatelessWidget {
  final String  teamName;
  final int     score;
  final Color   color;
  final List<UltraballPlayer> players;
  final List<bool> phaseLines; // 3 values; false = line crossed (progress)
  final bool    possessing;
  final Ultraball ball;
  final String? targetId;

  const _TeamPanel3T({
    required this.teamName,
    required this.score,
    required this.color,
    required this.players,
    required this.phaseLines,
    required this.possessing,
    required this.ball,
    this.targetId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.fromLTRB(8, 8, 6, 8),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: color.withValues(alpha: 0.55), width: 2)),
        color:  color.withValues(alpha: 0.05),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name + score
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(teamName,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 15, fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic, color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Text('$score',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 28, fontWeight: FontWeight.w700,
                  color: Colors.white, height: 0.9,
                )),
            ],
          ),
          const SizedBox(height: 5),
          // Phase line pips
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('PL ',
                style: GoogleFonts.chakraPetch(
                  fontSize: 7, letterSpacing: 0.5,
                  color: Colors.white.withValues(alpha: 0.30))),
              ...List.generate(3, (i) {
                final crossed = !phaseLines[i]; // false=not yet crossed, true=crossed
                return Container(
                  width: 16, height: 4,
                  margin: const EdgeInsets.only(right: 3),
                  decoration: BoxDecoration(
                    color: crossed ? color : Colors.white.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: (crossed && possessing)
                        ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6)]
                        : null,
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 5),
          // Unit cards — Wrap prevents horizontal overflow on narrow panels
          Wrap(
            spacing: 2,
            runSpacing: 2,
            children: players.map((p) => _UnitCard3T(
              player:    p,
              teamColor: color,
              isTargeted: p.id == targetId || p.isSelected,
            )).toList(),
          ),
          // Possession indicator
          if (possessing) ...[
            const SizedBox(height: 5),
            _PossessionBar3T(ball: ball, teamColor: color),
          ],
        ],
      ),
    );
  }
}

// ── Mini unit card for team panels ────────────────────────────────────────────

class _UnitCard3T extends StatelessWidget {
  final UltraballPlayer player;
  final Color teamColor;
  final bool  isTargeted;

  const _UnitCard3T({
    required this.player,
    required this.teamColor,
    required this.isTargeted,
  });

  @override
  Widget build(BuildContext context) {
    final isDead  = !player.isAlive;
    final hpPct   = (player.health / player.maxHealth.clamp(1, double.infinity)).clamp(0.0, 1.0);
    final badge   = player.name.isNotEmpty ? player.name[0] : '?';
    final border  = isTargeted ? _kGold : Colors.white.withValues(alpha: isDead ? 0.07 : 0.18);

    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20, height: 20,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: isDead
                    ? [Colors.grey.shade800, Colors.grey.shade900]
                    : [teamColor, teamColor.withValues(alpha: 0.3)],
              ),
              border: Border.all(color: border, width: isTargeted ? 1.5 : 1.0),
              boxShadow: isTargeted
                  ? [BoxShadow(color: _kGold.withValues(alpha: 0.5), blurRadius: 4)]
                  : null,
            ),
            child: Center(
              child: Text(badge,
                style: GoogleFonts.barlowCondensed(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: isDead ? 0.28 : 1.0))),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: 18, height: 3,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(1.5),
            ),
            child: FractionallySizedBox(
              widthFactor: hpPct,
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  color: isDead ? Colors.grey.shade700 : teamColor,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ball possession bar (shown when team controls ball) ───────────────────────

class _PossessionBar3T extends StatelessWidget {
  final Ultraball ball;
  final Color     teamColor;
  const _PossessionBar3T({required this.ball, required this.teamColor});

  @override
  Widget build(BuildContext context) {
    final charge = ball.chargePercent;
    final flash  = ball.explosionFlash;
    final bColor = flash > 0
        ? Color.lerp(_ballColor(charge), const Color(0xFFFF4400), flash)!
        : _ballColor(charge);
    const sz = 18.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: sz, height: sz,
          decoration: BoxDecoration(
            shape: BoxShape.circle, color: _kBg,
            border: Border.all(color: bColor, width: 1.5),
            boxShadow: [BoxShadow(color: bColor.withValues(alpha: 0.5), blurRadius: 6)],
          ),
          child: Center(
            child: CustomPaint(
              size: Size(sz * 0.62, sz * 0.62),
              painter: _UltraballPainter(explosionFlash: flash),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('CHARGE',
                    style: GoogleFonts.chakraPetch(
                      fontSize: 6, color: _kGold.withValues(alpha: 0.8), letterSpacing: 1)),
                  Text('${(charge * 100).toInt()}%',
                    style: TextStyle(color: bColor, fontSize: 7, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 2),
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  widthFactor: charge,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      color: bColor,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [BoxShadow(color: bColor.withValues(alpha: 0.6), blurRadius: 4)],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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
