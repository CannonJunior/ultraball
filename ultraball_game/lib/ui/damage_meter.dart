import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../game/game_state.dart';
import '../models/player.dart';
import 'ui_theme.dart';
import 'ui_assets.dart';

enum DamageMeterTab { damage, healing, dps }

/// WoW-Recount-style in-game stat meter.
///
/// Shows all players ranked by the selected stat. Toggle visibility with [M].
/// The tab strip and all colors are driven by [UiTheme].
class DamageMeter extends StatefulWidget {
  final GameState gs;
  const DamageMeter({super.key, required this.gs});

  @override
  State<DamageMeter> createState() => _DamageMeterState();
}

class _DamageMeterState extends State<DamageMeter> {
  late DamageMeterTab _tab;

  @override
  void initState() {
    super.initState();
    _tab = switch (UiTheme.instance.damageMeterDefaultTab) {
      'healing' => DamageMeterTab.healing,
      'dps'     => DamageMeterTab.dps,
      _         => DamageMeterTab.damage,
    };
  }

  @override
  Widget build(BuildContext context) {
    final t      = UiTheme.instance;
    final gs     = widget.gs;
    final all    = [...gs.playerRoster, ...gs.opponentRoster];
    final elapsed = math.max(1.0, gs.matchTimeElapsed);

    double valueOf(UltraballPlayer p) => switch (_tab) {
      DamageMeterTab.damage  => p.totalDamageDealt,
      DamageMeterTab.healing => p.totalHealingDone,
      DamageMeterTab.dps     => p.totalDamageDealt / elapsed,
    };

    final sorted = [...all]..sort((a, b) => valueOf(b).compareTo(valueOf(a)));
    final maxVal = sorted.isEmpty ? 1.0 : math.max(1.0, valueOf(sorted.first));

    double homeTotal = 0, awayTotal = 0;
    for (final p in gs.playerRoster)   homeTotal += valueOf(p);
    for (final p in gs.opponentRoster) awayTotal += valueOf(p);

    String fmt(double v) {
      if (_tab == DamageMeterTab.dps) return v.toStringAsFixed(1);
      if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
      return v.toInt().toString();
    }

    return Container(
      width: t.damageMeterWidth,
      decoration: BoxDecoration(
        color: t.backgroundColor.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: t.borderSubtleColor, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tab strip
          _TabStrip(
            current:  _tab,
            onSelect: (tab) => setState(() => _tab = tab),
          ),

          // Home team rows (globally ranked order, filtered to home)
          ..._buildRows(gs.playerRoster, sorted, maxVal, valueOf, fmt,
              teamColor: Color(gs.settings.homeTeamPrimary)),

          // Team separator
          _TeamSeparator(),

          // Away team rows
          ..._buildRows(gs.opponentRoster, sorted, maxVal, valueOf, fmt,
              teamColor: Color(gs.settings.awayTeamPrimary)),

          // Totals footer
          _TotalsFooter(
            homeLabel: gs.settings.homeTeamName,
            awayLabel: gs.settings.awayTeamName,
            homeVal:   fmt(homeTotal),
            awayVal:   fmt(awayTotal),
            tab:       _tab,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRows(
    List<UltraballPlayer> teamRoster,
    List<UltraballPlayer> globalRanking,
    double maxVal,
    double Function(UltraballPlayer) valueOf,
    String Function(double) fmt, {
    required Color teamColor,
  }) {
    final rows = globalRanking.where(teamRoster.contains).toList();
    return rows.map((p) {
      final rank = globalRanking.indexOf(p) + 1;
      final val  = valueOf(p);
      final frac = maxVal > 0 ? (val / maxVal).clamp(0.0, 1.0) : 0.0;
      return _PlayerRow(
        player:      p,
        rank:        rank,
        barFraction: frac,
        valueLabel:  fmt(val),
        teamColor:   teamColor,
      );
    }).toList();
  }
}

// ── Tab strip ─────────────────────────────────────────────────────────────────

class _TabStrip extends StatelessWidget {
  final DamageMeterTab current;
  final ValueChanged<DamageMeterTab> onSelect;
  const _TabStrip({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final t = UiTheme.instance;
    return Container(
      decoration: BoxDecoration(
        color: t.surfaceColor,
        border: Border(bottom: BorderSide(color: t.borderSubtleColor)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
      ),
      child: Row(
        children: [
          _Tab(label: 'DMG',  tab: DamageMeterTab.damage,  current: current, onSelect: onSelect),
          _Tab(label: 'HEAL', tab: DamageMeterTab.healing, current: current, onSelect: onSelect),
          _Tab(label: 'DPS',  tab: DamageMeterTab.dps,     current: current, onSelect: onSelect),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final DamageMeterTab tab;
  final DamageMeterTab current;
  final ValueChanged<DamageMeterTab> onSelect;
  const _Tab({required this.label, required this.tab, required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final t        = UiTheme.instance;
    final selected = tab == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelect(tab),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? t.accentColor : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color:       selected ? t.accentColor : Colors.white.withValues(alpha: 0.4),
              fontSize:    9,
              fontWeight:  selected ? FontWeight.bold : FontWeight.normal,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Player row ─────────────────────────────────────────────────────────────────

class _PlayerRow extends StatelessWidget {
  final UltraballPlayer player;
  final int rank;
  final double barFraction;
  final String valueLabel;
  final Color  teamColor;

  const _PlayerRow({
    required this.player,
    required this.rank,
    required this.barFraction,
    required this.valueLabel,
    required this.teamColor,
  });

  @override
  Widget build(BuildContext context) {
    final classCol  = UiAssets.classColor(player.playerClass);
    final isDead    = !player.isAlive;

    return Opacity(
      opacity: isDead ? 0.45 : 1.0,
      child: SizedBox(
        height: 18,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Stack(
            children: [
              // Bar fill behind content
              FractionallySizedBox(
                widthFactor: barFraction,
                child: Container(
                  height: 18,
                  decoration: BoxDecoration(
                    color: classCol.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Content over bar
              Row(
                children: [
                  SizedBox(
                    width: 16,
                    child: Text(
                      '$rank',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 8),
                    ),
                  ),
                  UiAssets.classIcon(player.playerClass, size: 10, color: classCol),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      player.name,
                      style: TextStyle(
                        color:      teamColor,
                        fontSize:   9,
                        fontWeight: FontWeight.w600,
                        decoration: isDead ? TextDecoration.lineThrough : null,
                        decorationColor: teamColor.withValues(alpha: 0.6),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    valueLabel,
                    style: TextStyle(
                      color:     Colors.white.withValues(alpha: 0.85),
                      fontSize:  9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

}

// ── Team separator ─────────────────────────────────────────────────────────────

class _TeamSeparator extends StatelessWidget {
  const _TeamSeparator();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 1),
      color: UiTheme.instance.borderAccentColor,
    );
  }
}

// ── Totals footer ─────────────────────────────────────────────────────────────

class _TotalsFooter extends StatelessWidget {
  final String homeLabel;
  final String awayLabel;
  final String homeVal;
  final String awayVal;
  final DamageMeterTab tab;

  const _TotalsFooter({
    required this.homeLabel,
    required this.awayLabel,
    required this.homeVal,
    required this.awayVal,
    required this.tab,
  });

  @override
  Widget build(BuildContext context) {
    final t      = UiTheme.instance;
    final suffix = switch (tab) {
      DamageMeterTab.damage  => 'dmg',
      DamageMeterTab.healing => 'heal',
      DamageMeterTab.dps     => 'dps',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: t.surfaceColor,
        border: Border(top: BorderSide(color: t.borderSubtleColor)),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
      ),
      child: Row(
        children: [
          Text(homeLabel, style: TextStyle(color: t.homeTeamColor, fontSize: 8, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Text(homeVal,   style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 8)),
          const Spacer(),
          Text(awayLabel, style: TextStyle(color: t.awayTeamColor, fontSize: 8, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Text(awayVal,   style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 8)),
          const SizedBox(width: 4),
          Text(suffix,    style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 7)),
        ],
      ),
    );
  }
}
