import 'package:flutter/material.dart';
import '../game/game_state.dart';
import '../models/act_state.dart';
import '../models/player.dart';
import 'ui_theme.dart';
import 'ui_assets.dart';

/// Full-screen post-game summary overlay.
///
/// Header: final score, winner headline, per-act delta history.
/// Tab 1 SUMMARY:  side-by-side team comparison bars (damage / healing / kills / scoring breakdown).
/// Tab 2 SCOREBOARD: WoW-battleground-style per-player table.
class GameSummaryScreen extends StatefulWidget {
  final GameState gs;
  final VoidCallback onBack;

  const GameSummaryScreen({super.key, required this.gs, required this.onBack});

  @override
  State<GameSummaryScreen> createState() => _GameSummaryScreenState();
}

enum _SummaryTab { summary, scoreboard }
enum _SortColumn { pts, kills, damage, healing }

class _GameSummaryScreenState extends State<GameSummaryScreen> {
  late _SummaryTab  _tab;
  _SortColumn _sort = _SortColumn.damage;
  bool _sortDesc    = true;

  @override
  void initState() {
    super.initState();
    _tab = UiTheme.instance.summaryDefaultTab == 'summary'
        ? _SummaryTab.summary
        : _SummaryTab.scoreboard;
  }

  @override
  Widget build(BuildContext context) {
    final t   = UiTheme.instance;
    final gs  = widget.gs;
    final act = gs.actState;

    final playerWon = act.playerScore > act.opponentScore;
    final tied      = act.playerScore == act.opponentScore;

    String headline;
    Color headlineColor;
    if (act.playerForfeit) {
      headline      = '${gs.settings.awayTeamName} WINS BY FORFEIT';
      headlineColor = t.awayTeamColor;
    } else if (act.opponentForfeit) {
      headline      = '${gs.settings.homeTeamName} WINS BY FORFEIT';
      headlineColor = t.homeTeamColor;
    } else if (tied) {
      headline      = 'DRAW';
      headlineColor = t.accentColor;
    } else if (playerWon) {
      headline      = '${gs.settings.homeTeamName} WINS';
      headlineColor = t.homeTeamColor;
    } else {
      headline      = '${gs.settings.awayTeamName} WINS';
      headlineColor = t.awayTeamColor;
    }

    return Container(
      color: Colors.black.withValues(alpha: 0.92),
      child: SafeArea(
        child: Column(
          children: [
            // ── Fixed header ───────────────────────────────────────────────
            _Header(
              gs:            gs,
              headline:      headline,
              headlineColor: headlineColor,
              onBack:        widget.onBack,
            ),

            // ── Tab bar ────────────────────────────────────────────────────
            _SummaryTabBar(
              current:  _tab,
              onSelect: (t) => setState(() => _tab = t),
            ),

            // ── Tab body ───────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _tab == _SummaryTab.summary
                    ? _SummaryTab1(gs: gs)
                    : _SummaryTab2(
                        gs:       gs,
                        sort:     _sort,
                        sortDesc: _sortDesc,
                        onSort:   (col) => setState(() {
                          if (_sort == col) {
                            _sortDesc = !_sortDesc;
                          } else {
                            _sort    = col;
                            _sortDesc = true;
                          }
                        }),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final GameState gs;
  final String headline;
  final Color headlineColor;
  final VoidCallback onBack;

  const _Header({
    required this.gs,
    required this.headline,
    required this.headlineColor,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final t   = UiTheme.instance;
    final act = gs.actState;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: t.surfaceColor,
        border: Border(bottom: BorderSide(color: t.borderSubtleColor)),
      ),
      child: Column(
        children: [
          // Score row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Away
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      gs.settings.awayTeamName,
                      style: TextStyle(color: t.awayTeamColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${act.opponentScore}',
                      style: TextStyle(color: t.awayTeamColor, fontSize: 48, fontWeight: FontWeight.w900, height: 1.0),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Text('FINAL', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 9, letterSpacing: 2)),
                    Text('–', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 24)),
                  ],
                ),
              ),

              // Home
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gs.settings.homeTeamName,
                      style: TextStyle(color: t.homeTeamColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${act.playerScore}',
                      style: TextStyle(color: t.homeTeamColor, fontSize: 48, fontWeight: FontWeight.w900, height: 1.0),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Winner headline
          Text(
            headline,
            style: TextStyle(color: headlineColor, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 3),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          // Per-act delta history
          _ActHistory(actResults: act.actResults, gs: gs),

          const SizedBox(height: 8),

          // Back button
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: onBack,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: t.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: t.accentColor.withValues(alpha: 0.6)),
                ),
                child: Text(
                  'BACK TO MENU',
                  style: TextStyle(color: t.accentColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Per-act history ────────────────────────────────────────────────────────────

class _ActHistory extends StatelessWidget {
  final List<ActResult> actResults;
  final GameState gs;
  const _ActHistory({required this.actResults, required this.gs});

  @override
  Widget build(BuildContext context) {
    if (actResults.isEmpty) return const SizedBox.shrink();
    final t = UiTheme.instance;

    // Compute per-act deltas
    final deltas = <(int, int)>[];
    for (int i = 0; i < actResults.length; i++) {
      final prev = i == 0 ? (0, 0) : (actResults[i - 1].playerScore, actResults[i - 1].opponentScore);
      deltas.add((
        actResults[i].playerScore - prev.$1,
        actResults[i].opponentScore - prev.$2,
      ));
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < deltas.length; i++) ...[
          if (i > 0) Container(width: 1, height: 24, color: t.borderSubtleColor, margin: const EdgeInsets.symmetric(horizontal: 8)),
          Column(
            children: [
              Text(
                'ACT ${i + 1}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 7, letterSpacing: 1),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    '${deltas[i].$2}',
                    style: TextStyle(
                      color: deltas[i].$2 > deltas[i].$1 ? t.awayTeamColor : Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text('–', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11)),
                  Text(
                    '${deltas[i].$1}',
                    style: TextStyle(
                      color: deltas[i].$1 > deltas[i].$2 ? t.homeTeamColor : Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ── Tab bar ────────────────────────────────────────────────────────────────────

class _SummaryTabBar extends StatelessWidget {
  final _SummaryTab current;
  final ValueChanged<_SummaryTab> onSelect;
  const _SummaryTabBar({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final t = UiTheme.instance;
    return Container(
      decoration: BoxDecoration(
        color: t.surfaceColor,
        border: Border(bottom: BorderSide(color: t.borderSubtleColor)),
      ),
      child: Row(
        children: [
          _SummaryTabItem(label: 'SUMMARY',    tab: _SummaryTab.summary,    current: current, onSelect: onSelect),
          _SummaryTabItem(label: 'SCOREBOARD', tab: _SummaryTab.scoreboard, current: current, onSelect: onSelect),
        ],
      ),
    );
  }
}

class _SummaryTabItem extends StatelessWidget {
  final String label;
  final _SummaryTab tab;
  final _SummaryTab current;
  final ValueChanged<_SummaryTab> onSelect;
  const _SummaryTabItem({required this.label, required this.tab, required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final t   = UiTheme.instance;
    final sel = tab == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelect(tab),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: sel ? t.accentColor : Colors.transparent, width: 2)),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: sel ? t.accentColor : Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
              fontWeight: sel ? FontWeight.bold : FontWeight.normal,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Tab 1: Summary ─────────────────────────────────────────────────────────────

class _SummaryTab1 extends StatelessWidget {
  final GameState gs;
  const _SummaryTab1({required this.gs});

  @override
  Widget build(BuildContext context) {
    final t   = UiTheme.instance;
    final act = gs.actState;

    double homeDmg  = 0, awayDmg  = 0;
    double homeHeal = 0, awayHeal = 0;
    for (final p in gs.playerRoster)   { homeDmg += p.totalDamageDealt; homeHeal += p.totalHealingDone; }
    for (final p in gs.opponentRoster) { awayDmg += p.totalDamageDealt; awayHeal += p.totalHealingDone; }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ComparisonBar(
          label:    'DAMAGE DEALT',
          homeVal:  homeDmg,
          awayVal:  awayDmg,
          homeColor: t.homeTeamColor,
          awayColor: t.awayTeamColor,
          fmt:      _fmtLarge,
        ),
        const SizedBox(height: 12),
        if (t.summaryShowHealingColumn) ...[
          _ComparisonBar(
            label:    'HEALING DONE',
            homeVal:  homeHeal,
            awayVal:  awayHeal,
            homeColor: t.homeTeamColor,
            awayColor: t.awayTeamColor,
            fmt:      _fmtLarge,
          ),
          const SizedBox(height: 12),
        ],
        _ComparisonBar(
          label:    'KILLS',
          homeVal:  act.playerKills.toDouble(),
          awayVal:  act.opponentKills.toDouble(),
          homeColor: t.homeTeamColor,
          awayColor: t.awayTeamColor,
          fmt:      (v) => v.toInt().toString(),
        ),
        const SizedBox(height: 12),
        _ScoringBreakdown(gs: gs),
      ],
    );
  }

  static String _fmtLarge(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toInt().toString();
  }
}

class _ComparisonBar extends StatelessWidget {
  final String label;
  final double homeVal;
  final double awayVal;
  final Color homeColor;
  final Color awayColor;
  final String Function(double) fmt;

  const _ComparisonBar({
    required this.label,
    required this.homeVal,
    required this.awayVal,
    required this.homeColor,
    required this.awayColor,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final t       = UiTheme.instance;
    final total   = (homeVal + awayVal).clamp(1.0, double.infinity);
    final awayFrac = awayVal / total;
    final homeFrac = homeVal / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 9, letterSpacing: 1.5)),
        const SizedBox(height: 4),
        Row(
          children: [
            // Away value
            SizedBox(
              width: 48,
              child: Text(
                fmt(awayVal),
                textAlign: TextAlign.right,
                style: TextStyle(color: awayColor, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            // Bars (center-out split)
            Expanded(
              child: LayoutBuilder(
                builder: (_, c) {
                  final half = c.maxWidth / 2;
                  return SizedBox(
                    height: 14,
                    child: Stack(
                      children: [
                        // Background
                        Container(
                          height: 14,
                          decoration: BoxDecoration(
                            color: t.borderSubtleColor,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        // Away bar (grows left from center)
                        Positioned(
                          right: half,
                          child: Container(
                            width: (half * awayFrac * 2).clamp(0.0, half),
                            height: 14,
                            decoration: BoxDecoration(
                              color: awayColor.withValues(alpha: 0.75),
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(3)),
                            ),
                          ),
                        ),
                        // Home bar (grows right from center)
                        Positioned(
                          left: half,
                          child: Container(
                            width: (half * homeFrac * 2).clamp(0.0, half),
                            height: 14,
                            decoration: BoxDecoration(
                              color: homeColor.withValues(alpha: 0.75),
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(3)),
                            ),
                          ),
                        ),
                        // Center line
                        Positioned(
                          left: half - 0.5,
                          child: Container(width: 1, height: 14, color: Colors.black.withValues(alpha: 0.5)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            // Home value
            SizedBox(
              width: 48,
              child: Text(
                fmt(homeVal),
                style: TextStyle(color: homeColor, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ScoringBreakdown extends StatelessWidget {
  final GameState gs;
  const _ScoringBreakdown({required this.gs});

  @override
  Widget build(BuildContext context) {
    final t   = UiTheme.instance;
    final act = gs.actState;

    // Derive ultra/meta counts from per-player pointsThisMatch and kills
    // ultra = floor((pts - kills) / 7) — approximate but accurate when meta=0
    // Better: just show total pts by type using kills already tracked in ActState.
    // We display: total score by team + kills count (killa pts = kills count)
    final homeKillapts = act.playerKills;
    final awayKillapts = act.opponentKills;
    final homeOtherpts = act.playerScore   - homeKillapts;
    final awayOtherpts = act.opponentScore - awayKillapts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SCORING BREAKDOWN', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 9, letterSpacing: 1.5)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _ScoringBreakdownTeam(
              pts:        act.opponentScore,
              killapts:   awayKillapts,
              otherpts:   awayOtherpts,
              color:      t.awayTeamColor,
              killaColor: t.scoreKillaColor,
              ultraColor: t.scoreUltraColor,
              label:      gs.settings.awayTeamName,
            )),
            Container(width: 1, height: 50, color: t.borderSubtleColor, margin: const EdgeInsets.symmetric(horizontal: 12)),
            Expanded(child: _ScoringBreakdownTeam(
              pts:        act.playerScore,
              killapts:   homeKillapts,
              otherpts:   homeOtherpts,
              color:      t.homeTeamColor,
              killaColor: t.scoreKillaColor,
              ultraColor: t.scoreUltraColor,
              label:      gs.settings.homeTeamName,
            )),
          ],
        ),
      ],
    );
  }
}

class _ScoringBreakdownTeam extends StatelessWidget {
  final int pts;
  final int killapts;
  final int otherpts;
  final Color color;
  final Color killaColor;
  final Color ultraColor;
  final String label;

  const _ScoringBreakdownTeam({
    required this.pts,
    required this.killapts,
    required this.otherpts,
    required this.color,
    required this.killaColor,
    required this.ultraColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Row(
          children: [
            UiAssets.scoreIcon('ultra', size: 12, color: ultraColor),
            const SizedBox(width: 3),
            Text('$otherpts pts', style: TextStyle(color: ultraColor, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(width: 10),
            UiAssets.scoreIcon('killa', size: 12, color: killaColor),
            const SizedBox(width: 3),
            Text('$killapts pts', style: TextStyle(color: killaColor, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}

// ── Tab 2: Scoreboard ─────────────────────────────────────────────────────────

class _SummaryTab2 extends StatelessWidget {
  final GameState gs;
  final _SortColumn sort;
  final bool sortDesc;
  final ValueChanged<_SortColumn> onSort;

  const _SummaryTab2({
    required this.gs,
    required this.sort,
    required this.sortDesc,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    final t = UiTheme.instance;
    return Column(
      children: [
        _ScoreboardSection(
          gs:       gs,
          roster:   gs.playerRoster,
          teamName: gs.settings.homeTeamName,
          teamColor: t.homeTeamColor,
          score:    gs.actState.playerScore,
          sort:     sort,
          sortDesc: sortDesc,
          onSort:   onSort,
          showHeading: true,
        ),
        const SizedBox(height: 16),
        _ScoreboardSection(
          gs:       gs,
          roster:   gs.opponentRoster,
          teamName: gs.settings.awayTeamName,
          teamColor: t.awayTeamColor,
          score:    gs.actState.opponentScore,
          sort:     sort,
          sortDesc: sortDesc,
          onSort:   onSort,
          showHeading: false,
        ),
      ],
    );
  }
}

class _ScoreboardSection extends StatelessWidget {
  final GameState gs;
  final List<UltraballPlayer> roster;
  final String teamName;
  final Color teamColor;
  final int score;
  final _SortColumn sort;
  final bool sortDesc;
  final ValueChanged<_SortColumn> onSort;
  final bool showHeading;

  const _ScoreboardSection({
    required this.gs,
    required this.roster,
    required this.teamName,
    required this.teamColor,
    required this.score,
    required this.sort,
    required this.sortDesc,
    required this.onSort,
    required this.showHeading,
  });

  @override
  Widget build(BuildContext context) {
    final t = UiTheme.instance;

    double totalDmg   = 0, totalHeal = 0;
    int    totalKills = 0, totalPts  = 0;
    for (final p in roster) {
      totalDmg   += p.totalDamageDealt;
      totalHeal  += p.totalHealingDone;
      totalKills += p.killsThisMatch;
      totalPts   += p.pointsThisMatch;
    }

    double valueOf(UltraballPlayer p) => switch (sort) {
      _SortColumn.pts     => p.pointsThisMatch.toDouble(),
      _SortColumn.kills   => p.killsThisMatch.toDouble(),
      _SortColumn.damage  => p.totalDamageDealt,
      _SortColumn.healing => p.totalHealingDone,
    };

    final sorted = [...roster]..sort((a, b) =>
        sortDesc ? valueOf(b).compareTo(valueOf(a)) : valueOf(a).compareTo(valueOf(b)));

    return Container(
      decoration: BoxDecoration(
        color: t.backgroundColor.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: teamColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // Section header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: teamColor.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
            ),
            child: Row(
              children: [
                Text(
                  teamName,
                  style: TextStyle(color: teamColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                ),
                const Spacer(),
                Text(
                  '$score pts',
                  style: TextStyle(color: teamColor, fontSize: 14, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),

          // Column headings (first team only to avoid repetition)
          if (showHeading)
            _ScoreboardHeading(
              sort:    sort,
              sortDesc: sortDesc,
              onSort:  onSort,
              showHeal: t.summaryShowHealingColumn,
            ),

          // Player rows
          ...sorted.map((p) => _ScoreboardRow(player: p, teamColor: teamColor, showHeal: t.summaryShowHealingColumn)),

          // Totals row
          _ScoreboardTotals(
            teamColor: teamColor,
            pts:       totalPts,
            kills:     totalKills,
            damage:    totalDmg,
            healing:   totalHeal,
            showHeal:  t.summaryShowHealingColumn,
          ),
        ],
      ),
    );
  }
}

class _ScoreboardHeading extends StatelessWidget {
  final _SortColumn sort;
  final bool sortDesc;
  final ValueChanged<_SortColumn> onSort;
  final bool showHeal;

  const _ScoreboardHeading({required this.sort, required this.sortDesc, required this.onSort, required this.showHeal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      color: const Color(0xFF0A0A14),
      child: Row(
        children: [
          const SizedBox(width: 120), // name+class
          _ColHead(label: 'PTS',    col: _SortColumn.pts,     sort: sort, desc: sortDesc, onSort: onSort, width: 40),
          _ColHead(label: 'KILLS',  col: _SortColumn.kills,   sort: sort, desc: sortDesc, onSort: onSort, width: 44),
          _ColHead(label: 'DAMAGE', col: _SortColumn.damage,  sort: sort, desc: sortDesc, onSort: onSort, width: 60),
          if (showHeal)
            _ColHead(label: 'HEAL', col: _SortColumn.healing, sort: sort, desc: sortDesc, onSort: onSort, width: 56),
          const SizedBox(width: 44), // status
        ],
      ),
    );
  }
}

class _ColHead extends StatelessWidget {
  final String label;
  final _SortColumn col;
  final _SortColumn sort;
  final bool desc;
  final ValueChanged<_SortColumn> onSort;
  final double width;

  const _ColHead({required this.label, required this.col, required this.sort, required this.desc, required this.onSort, required this.width});

  @override
  Widget build(BuildContext context) {
    final active = col == sort;
    return GestureDetector(
      onTap: () => onSort(col),
      child: SizedBox(
        width: width,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: active ? UiTheme.instance.accentColor : Colors.white.withValues(alpha: 0.4),
                fontSize: 8,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                letterSpacing: 0.8,
              ),
            ),
            if (active) ...[
              const SizedBox(width: 2),
              Icon(
                desc ? Icons.arrow_downward : Icons.arrow_upward,
                size: 8,
                color: UiTheme.instance.accentColor,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScoreboardRow extends StatelessWidget {
  final UltraballPlayer player;
  final Color teamColor;
  final bool showHeal;

  const _ScoreboardRow({required this.player, required this.teamColor, required this.showHeal});

  @override
  Widget build(BuildContext context) {
    final t      = UiTheme.instance;
    final isDead = !player.isAlive;

    String status;
    Color statusColor;
    if (isDead) {
      status      = 'DEAD';
      statusColor = t.deadColor;
    } else if (!player.isOnField) {
      status      = 'RESERVE';
      statusColor = Colors.white.withValues(alpha: 0.35);
    } else {
      status      = 'ALIVE';
      statusColor = t.aliveColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.borderSubtleColor.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          // Class icon
          UiAssets.classIcon(player.playerClass, size: 14),
          const SizedBox(width: 5),
          // Name
          SizedBox(
            width: 101,
            child: Text(
              player.name,
              style: TextStyle(
                color:      teamColor,
                fontSize:   11,
                fontWeight: FontWeight.w600,
                decoration: isDead ? TextDecoration.lineThrough : null,
                decorationColor: teamColor.withValues(alpha: 0.5),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // PTS
          SizedBox(
            width: 40,
            child: Text('${player.pointsThisMatch}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          // KILLS
          SizedBox(
            width: 44,
            child: Text('${player.killsThisMatch}', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
          ),
          // DAMAGE
          SizedBox(
            width: 60,
            child: Text(_fmt(player.totalDamageDealt), style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11)),
          ),
          // HEAL
          if (showHeal)
            SizedBox(
              width: 56,
              child: Text(_fmt(player.totalHealingDone), style: TextStyle(color: t.aliveColor.withValues(alpha: 0.75), fontSize: 11)),
            ),
          // STATUS
          SizedBox(
            width: 44,
            child: Text(status, style: TextStyle(color: statusColor, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          ),
        ],
      ),
    );
  }

  static String _fmt(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toInt().toString();
  }
}

class _ScoreboardTotals extends StatelessWidget {
  final Color teamColor;
  final int pts;
  final int kills;
  final double damage;
  final double healing;
  final bool showHeal;

  const _ScoreboardTotals({
    required this.teamColor,
    required this.pts,
    required this.kills,
    required this.damage,
    required this.healing,
    required this.showHeal,
  });

  @override
  Widget build(BuildContext context) {
    final t = UiTheme.instance;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: teamColor.withValues(alpha: 0.07),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(5)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text('TOTAL', style: TextStyle(color: teamColor.withValues(alpha: 0.7), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
          SizedBox(width: 40, child: Text('$pts',           style: TextStyle(color: teamColor, fontSize: 11, fontWeight: FontWeight.bold))),
          SizedBox(width: 44, child: Text('$kills',         style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11))),
          SizedBox(width: 60, child: Text(_fmt(damage),     style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11))),
          if (showHeal)
            SizedBox(width: 56, child: Text(_fmt(healing),  style: TextStyle(color: t.aliveColor.withValues(alpha: 0.6), fontSize: 11))),
        ],
      ),
    );
  }

  static String _fmt(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toInt().toString();
  }
}
