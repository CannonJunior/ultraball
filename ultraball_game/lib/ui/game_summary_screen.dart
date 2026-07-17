import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../game/game_state.dart';
import '../models/game_settings.dart';
import '../models/player.dart';
import 'stat_table.dart';

// ── Design palette ────────────────────────────────────────────────────────────
const _kGold = Color(0xFFFFCB3D);
const _kSurf = Color(0xFF0A0C14);
const _kHeal = Color(0xFF6EE7B7);

// ── Public widget ─────────────────────────────────────────────────────────────

class GameSummaryScreen extends StatelessWidget {
  final GameState gs;
  final VoidCallback onBack;

  const GameSummaryScreen({super.key, required this.gs, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final act = gs.actState;
    final isThreeTeam = gs.settings.matchMode == MatchMode.threeTeams;

    final homeColor  = Color(gs.settings.homeTeamPrimary);
    final awayColor  = Color(gs.settings.awayTeamPrimary);
    final thirdColor = isThreeTeam ? Color(gs.settings.thirdTeamPrimary) : null;

    // Determine winner
    String winnerName;
    Color  winnerColor;
    bool   tied;

    if (isThreeTeam) {
      final pf = act.playerForfeit;
      final of = act.opponentForfeit;
      final tf = act.thirdForfeit;
      if (pf && of) {
        winnerName = gs.settings.thirdTeamName; winnerColor = thirdColor!; tied = false;
      } else if (pf && tf) {
        winnerName = gs.settings.awayTeamName; winnerColor = awayColor; tied = false;
      } else if (of && tf) {
        winnerName = gs.settings.homeTeamName; winnerColor = homeColor; tied = false;
      } else {
        final maxScore = [act.playerScore, act.opponentScore, act.thirdScore].reduce(math.max);
        final leaders = [
          if (act.playerScore   == maxScore) (gs.settings.homeTeamName,  homeColor),
          if (act.opponentScore == maxScore) (gs.settings.awayTeamName,  awayColor),
          if (act.thirdScore    == maxScore) (gs.settings.thirdTeamName, thirdColor!),
        ];
        if (leaders.length == 1) {
          winnerName = leaders[0].$1; winnerColor = leaders[0].$2; tied = false;
        } else {
          winnerName = 'DRAW'; winnerColor = _kGold; tied = true;
        }
      }
    } else {
      final playerWon = act.playerScore > act.opponentScore;
      tied = act.playerScore == act.opponentScore;
      if (act.playerForfeit) {
        winnerName = gs.settings.awayTeamName; winnerColor = awayColor;
      } else if (act.opponentForfeit) {
        winnerName = gs.settings.homeTeamName; winnerColor = homeColor;
      } else if (tied) {
        winnerName = 'DRAW'; winnerColor = _kGold;
      } else if (playerWon) {
        winnerName = gs.settings.homeTeamName; winnerColor = homeColor;
      } else {
        winnerName = gs.settings.awayTeamName; winnerColor = awayColor;
      }
    }

    // Match duration
    final totalSecs = gs.matchTimeElapsed.isFinite ? gs.matchTimeElapsed.toInt() : 0;
    final mins      = (totalSecs ~/ 60).toString().padLeft(2, '0');
    final secs      = (totalSecs % 60).toString().padLeft(2, '0');
    final fmtDur    = '$mins:$secs';

    // Derive headline stats
    final all = [
      ...gs.playerRoster.map((p) => (p, true)),
      ...gs.opponentRoster.map((p) => (p, false)),
      if (isThreeTeam) ...gs.thirdRoster.map((p) => (p, false)),
    ];
    final mvp     = all.reduce((a, b) => a.$1.pointsThisMatch  >= b.$1.pointsThisMatch  ? a : b).$1;
    final topDmg  = all.reduce((a, b) => a.$1.totalDamageDealt >= b.$1.totalDamageDealt ? a : b).$1;
    final topHeal = all.reduce((a, b) => a.$1.totalHealingDone >= b.$1.totalHealingDone ? a : b).$1;

    return Container(
      color: Colors.black.withValues(alpha: 0.93),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: _kSurf,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 48, spreadRadius: 4)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _HeroHeader(
                        winnerName:  winnerName,
                        winnerColor: winnerColor,
                        homeTeam:    gs.settings.homeTeamName,
                        awayTeam:    gs.settings.awayTeamName,
                        homeScore:   act.playerScore,
                        awayScore:   act.opponentScore,
                        fmtDur:      fmtDur,
                        tied:        tied,
                        onBack:      onBack,
                        thirdTeam:   isThreeTeam ? gs.settings.thirdTeamName : null,
                        thirdScore:  isThreeTeam ? act.thirdScore : null,
                      ),
                      _StatCards(
                        mvp:        mvp,
                        topDmg:     topDmg,
                        topHeal:    topHeal,
                        homeKills:  act.playerKills,
                        awayKills:  act.opponentKills,
                        thirdKills: isThreeTeam ? act.thirdKills : null,
                      ),
                      StatTable(gs: gs),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Hero header ───────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  final String     winnerName, homeTeam, awayTeam, fmtDur;
  final String?    thirdTeam;
  final Color      winnerColor;
  final int        homeScore, awayScore;
  final int?       thirdScore;
  final bool       tied;
  final VoidCallback onBack;

  const _HeroHeader({
    required this.winnerName,
    required this.winnerColor,
    required this.homeTeam,
    required this.awayTeam,
    required this.homeScore,
    required this.awayScore,
    required this.fmtDur,
    required this.tied,
    required this.onBack,
    this.thirdTeam,
    this.thirdScore,
  });

  @override
  Widget build(BuildContext context) {
    final isThreeTeam = thirdTeam != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end:   Alignment.bottomCenter,
          colors: [winnerColor.withValues(alpha: 0.16), Colors.transparent],
        ),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              Text(
                'FINAL · $fmtDur',
                style: GoogleFonts.chakraPetch(
                  fontSize:      11,
                  fontWeight:    FontWeight.w600,
                  letterSpacing: 4.5,
                  color:         _kGold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: tied ? 'DRAW' : '$winnerName ',
                      style: GoogleFonts.barlowCondensed(
                        fontSize:   40,
                        fontWeight: FontWeight.w700,
                        fontStyle:  FontStyle.italic,
                        color:      Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                    if (!tied)
                      TextSpan(
                        text: 'VICTORY',
                        style: GoogleFonts.barlowCondensed(
                          fontSize:   40,
                          fontWeight: FontWeight.w700,
                          fontStyle:  FontStyle.italic,
                          color:      winnerColor,
                          letterSpacing: 1,
                        ),
                      ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              if (isThreeTeam)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$homeScore $homeTeam',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 26, fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.85))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('·', style: TextStyle(fontSize: 20, color: Colors.white.withValues(alpha: 0.3))),
                    ),
                    Text('$awayScore $awayTeam',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 26, fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.85))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('·', style: TextStyle(fontSize: 20, color: Colors.white.withValues(alpha: 0.3))),
                    ),
                    Text('${thirdScore ?? 0} $thirdTeam',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 26, fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.85))),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$awayScore',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 26, fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.85))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('–', style: TextStyle(fontSize: 20, color: Colors.white.withValues(alpha: 0.3))),
                    ),
                    Text('$homeScore',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 26, fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.85))),
                  ],
                ),
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: onBack,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color:        Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border:       Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Text('BACK TO MENU',
                  style: GoogleFonts.chakraPetch(
                    fontSize:      9,
                    fontWeight:    FontWeight.w700,
                    letterSpacing: 2,
                    color:         Colors.white.withValues(alpha: 0.7))),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 4 stat cards ──────────────────────────────────────────────────────────────

class _StatCards extends StatelessWidget {
  final UltraballPlayer mvp, topDmg, topHeal;
  final int  homeKills, awayKills;
  final int? thirdKills;

  const _StatCards({
    required this.mvp,
    required this.topDmg,
    required this.topHeal,
    required this.homeKills,
    required this.awayKills,
    this.thirdKills,
  });

  @override
  Widget build(BuildContext context) {
    final killsValue = thirdKills != null
        ? '$homeKills / $awayKills / $thirdKills'
        : '$homeKills / $awayKills';
    return Container(
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _StatCard(
              value:    '${mvp.pointsThisMatch}',
              valueColor: _kGold,
              label:    '★ MVP  ${mvp.name}',
              labelColor: _kGold,
            )),
            _Divider(),
            Expanded(child: _StatCard(
              value:    _fmt(topDmg.totalDamageDealt),
              valueColor: const Color(0xFFFF8A99),
              label:    'TOP DAMAGE · ${topDmg.name}',
            )),
            _Divider(),
            Expanded(child: _StatCard(
              value:    _fmt(topHeal.totalHealingDone),
              valueColor: _kHeal,
              label:    'TOP HEALING · ${topHeal.name}',
            )),
            _Divider(),
            Expanded(child: _StatCard(
              value:    killsValue,
              valueColor: Colors.white,
              label:    'TEAM KILLS',
            )),
          ],
        ),
      ),
    );
  }

  static String _fmt(double v) {
    if (!v.isFinite) return '0';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toInt().toString();
  }
}

class _StatCard extends StatelessWidget {
  final String value, label;
  final Color  valueColor;
  final Color? labelColor;

  const _StatCard({required this.value, required this.valueColor, required this.label, this.labelColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0C14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value,
            style: TextStyle(fontFamily: 'monospace', fontSize: 18,
                fontWeight: FontWeight.w700, color: valueColor)),
          const SizedBox(height: 3),
          Text(label,
            style: GoogleFonts.chakraPetch(
              fontSize:      9,
              fontWeight:    FontWeight.w500,
              letterSpacing: 1.4,
              color:         labelColor ?? Colors.white.withValues(alpha: 0.4)),
            textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
    Container(width: 1, color: Colors.white.withValues(alpha: 0.06));
}
