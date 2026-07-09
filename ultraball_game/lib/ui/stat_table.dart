import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../game/game_state.dart';
import '../models/player.dart';

// ── Design palette ────────────────────────────────────────────────────────────
const _kRed  = Color(0xFFFF3B53);
const _kBlue = Color(0xFF2F83FF);
const _kGold = Color(0xFFFFCB3D);
const _kCyan = Color(0xFF19E3E3);
const _kDark = Color(0xFF06070D);
const _kHeal = Color(0xFF6EE7B7);

// ── Sort column enum ──────────────────────────────────────────────────────────

enum StatSortKey { name, damage, healing, points, kills }

// ── Row data ──────────────────────────────────────────────────────────────────

class _Row {
  final UltraballPlayer player;
  final bool isHome;

  _Row(this.player, {required this.isHome});

  Color get color => isHome ? _kBlue : _kRed;
  String get badge => player.name.isNotEmpty ? player.name[0] : '?';
  String get cls => player.playerClass.displayName.toUpperCase();
  double get dmg => player.totalDamageDealt;
  double get heal => player.totalHealingDone;
  int get kills => player.killsThisMatch;
  int get pts => player.pointsThisMatch;
}

// ── Sortable stat table ───────────────────────────────────────────────────────

/// Combined sortable stat table for all players in both rosters.
class StatTable extends StatefulWidget {
  final GameState gs;
  final StatSortKey initialSort;

  const StatTable({super.key, required this.gs, this.initialSort = StatSortKey.points});

  @override
  State<StatTable> createState() => _StatTableState();
}

class _StatTableState extends State<StatTable> {
  late StatSortKey _key;
  bool _desc = true;

  @override
  void initState() {
    super.initState();
    _key = widget.initialSort;
  }

  void _setSort(StatSortKey k) {
    setState(() {
      if (_key == k) {
        _desc = !_desc;
      } else {
        _key  = k;
        _desc = k != StatSortKey.name;
      }
    });
  }

  String _arrow(StatSortKey k) {
    if (_key != k) return ' ⇅';
    return _desc ? ' ▼' : ' ▲';
  }

  @override
  Widget build(BuildContext context) {
    final gs = widget.gs;

    final rows = [
      ...gs.playerRoster.map((p) => _Row(p, isHome: true)),
      ...gs.opponentRoster.map((p) => _Row(p, isHome: false)),
    ];

    rows.sort((a, b) {
      final cmp = switch (_key) {
        StatSortKey.name    => a.player.name.compareTo(b.player.name),
        StatSortKey.damage  => a.dmg.compareTo(b.dmg),
        StatSortKey.healing => a.heal.compareTo(b.heal),
        StatSortKey.points  => a.pts.compareTo(b.pts),
        StatSortKey.kills   => a.kills.compareTo(b.kills),
      };
      return _desc ? -cmp : cmp;
    });

    final maxDmg  = rows.fold(1.0, (m, r) => math.max(m, r.dmg));
    final maxHeal = rows.fold(1.0, (m, r) => math.max(m, r.heal));
    final leader  = rows.isNotEmpty ? rows.first.player.name : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _TableHeader(sortKey: _key, onSort: _setSort, arrow: _arrow),
        for (int i = 0; i < rows.length; i++)
          _StatRow(
            rank:     i + 1,
            row:      rows[i],
            isLeader: rows[i].player.name == leader && i == 0,
            maxDmg:   maxDmg,
            maxHeal:  maxHeal,
          ),
        _Legend(),
      ],
    );
  }
}

// ── Column header ─────────────────────────────────────────────────────────────

class _TableHeader extends StatelessWidget {
  final StatSortKey sortKey;
  final void Function(StatSortKey) onSort;
  final String Function(StatSortKey) arrow;

  const _TableHeader({required this.sortKey, required this.onSort, required this.arrow});

  @override
  Widget build(BuildContext context) {
    TextStyle lbl(StatSortKey k) => GoogleFonts.chakraPetch(
      fontSize:      9,
      fontWeight:    FontWeight.w600,
      letterSpacing: 1.2,
      color: sortKey == k ? Colors.white : Colors.white.withValues(alpha: 0.42),
    );

    GestureDetector col(String text, StatSortKey k, {TextAlign align = TextAlign.start}) =>
      GestureDetector(
        onTap: () => onSort(k),
        child: Text('$text${arrow(k)}', style: lbl(k), textAlign: align),
      );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: _kDark,
      child: Row(
        children: [
          const SizedBox(width: 26),
          Expanded(flex: 4, child: col('PLAYER',  StatSortKey.name)),
          Expanded(flex: 3, child: col('DAMAGE',  StatSortKey.damage)),
          Expanded(flex: 3, child: col('HEALING', StatSortKey.healing)),
          Expanded(flex: 3, child: col('POINTS',  StatSortKey.points,  align: TextAlign.center)),
          Expanded(flex: 2, child: col('KILLS',   StatSortKey.kills,   align: TextAlign.center)),
        ],
      ),
    );
  }
}

// ── Individual stat row ───────────────────────────────────────────────────────

class _StatRow extends StatelessWidget {
  final int    rank;
  final _Row   row;
  final bool   isLeader;
  final double maxDmg, maxHeal;

  const _StatRow({
    required this.rank,
    required this.row,
    required this.isLeader,
    required this.maxDmg,
    required this.maxHeal,
  });

  @override
  Widget build(BuildContext context) {
    final rowBg = isLeader
      ? _kGold.withValues(alpha: 0.09)
      : row.isHome
        ? _kBlue.withValues(alpha: 0.05)
        : _kRed.withValues(alpha: 0.05);
    final rankColor = isLeader ? _kGold : Colors.white.withValues(alpha: 0.5);
    final dmgPct  = (row.dmg  / maxDmg) .clamp(0.0, 1.0);
    final healPct = (row.heal / maxHeal).clamp(0.0, 1.0);

    return Container(
      padding:   const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color:  rowBg,
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.03))),
      ),
      child: SizedBox(
        height: 48,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Rank
            SizedBox(
              width: 26,
              child: Text(
                rank.toString().padLeft(2, '0'),
                style: TextStyle(fontFamily: 'monospace', fontSize: 12,
                    fontWeight: FontWeight.w700, color: rankColor),
              ),
            ),
            // Player badge + name + class
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: row.color,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Center(
                      child: Text(row.badge,
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment:  MainAxisAlignment.center,
                      children: [
                        Text(row.player.name,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.chakraPetch(
                            fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                        Text(row.cls,
                          style: GoogleFonts.chakraPetch(
                            fontSize: 9, fontWeight: FontWeight.w500, letterSpacing: 0.8,
                            color: Colors.white.withValues(alpha: 0.4))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Damage
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment:  MainAxisAlignment.center,
                  children: [
                    Text(_fmt(row.dmg),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12,
                          fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 3),
                    _Bar(fraction: dmgPct, color: row.color),
                  ],
                ),
              ),
            ),
            // Healing
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment:  MainAxisAlignment.center,
                  children: [
                    Text(row.heal > 0 ? _fmt(row.heal) : '—',
                      style: TextStyle(fontFamily: 'monospace', fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: row.heal > 0 ? _kHeal : Colors.white.withValues(alpha: 0.3))),
                    const SizedBox(height: 3),
                    _Bar(fraction: healPct, color: const Color(0xFF34D399)),
                  ],
                ),
              ),
            ),
            // Points
            Expanded(
              flex: 3,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${row.pts}',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 22, fontWeight: FontWeight.w700, color: _kGold, height: 1)),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Kill icon
                      Transform.rotate(
                        angle: math.pi / 4,
                        child: Container(width: 8, height: 8, color: _kRed)),
                      const SizedBox(width: 3),
                      Text('${row.kills}',
                        style: const TextStyle(fontFamily: 'monospace',
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: Color(0xFFCCCCCC))),
                    ],
                  ),
                ],
              ),
            ),
            // Kills column
            Expanded(
              flex: 2,
              child: Center(
                child: Text('${row.kills}',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 18, fontWeight: FontWeight.w700, color: _kCyan)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toInt().toString();
  }
}

// ── Progress bar ──────────────────────────────────────────────────────────────

class _Bar extends StatelessWidget {
  final double fraction;
  final Color  color;
  const _Bar({required this.fraction, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(2),
      ),
      child: FractionallySizedBox(
        widthFactor: fraction,
        alignment:   Alignment.centerLeft,
        child: Container(
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
      ),
    );
  }
}

// ── Legend footer ─────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      color: _kDark,
      child: Wrap(
        spacing:    18,
        runSpacing:  5,
        alignment:  WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _LegendChip(
            icon: Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_kGold, Colors.white, Color(0xFF1A1C22)],
                  stops: [0.0, 0.42, 0.58],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              ),
            ),
            label: 'ULTRABALL',
          ),
          _LegendChip(
            icon: Container(
              width: 9, height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _kCyan, width: 2),
              ),
            ),
            label: 'CATCH',
          ),
          _LegendChip(
            icon: Transform.rotate(
              angle: math.pi / 4,
              child: Container(width: 8, height: 8, color: _kRed),
            ),
            label: 'KILLING BLOW',
          ),
          Text('·', style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 12)),
          Text(
            'RANKED BY POINTS SCORED',
            style: GoogleFonts.chakraPetch(
              fontSize: 9, fontWeight: FontWeight.w500, letterSpacing: 0.8,
              color: Colors.white.withValues(alpha: 0.4)),
          ),
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  final Widget icon;
  final String label;
  const _LegendChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 5),
        Text(label,
          style: GoogleFonts.chakraPetch(
            fontSize: 9, fontWeight: FontWeight.w500, letterSpacing: 0.8,
            color: Colors.white.withValues(alpha: 0.4))),
      ],
    );
  }
}
