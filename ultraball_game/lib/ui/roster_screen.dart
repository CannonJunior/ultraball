import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/player.dart';
import '../models/act_state.dart';
import '../models/game_settings.dart';
import '../game/game_state.dart';
import 'ui_assets.dart';
import 'stat_table.dart';

// ── Design palette ────────────────────────────────────────────────────────────
const _kDead = Color(0xFFFF3B53); // semantic "eliminated/dead" red
const _kGold = Color(0xFFFFCB3D);
const _kSurf = Color(0xFF0A0C14);
const _kDark = Color(0xFF06070D);

class RosterScreen extends StatefulWidget {
  final GameState gs;
  final void Function(List<UltraballPlayer> newOrder) onConfirm;

  const RosterScreen({required this.gs, required this.onConfirm, super.key});

  @override
  State<RosterScreen> createState() => _RosterScreenState();
}

class _RosterScreenState extends State<RosterScreen> {
  late List<UltraballPlayer> _ordered;
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _ordered = widget.gs.playerRoster
        .where((p) => p.isAlive && !p.isInactive)
        .toList()
      ..sort((a, b) => a.deploySlot.compareTo(b.deploySlot));
  }

  @override
  Widget build(BuildContext context) {
    final gs  = widget.gs;
    final act = gs.actState;
    final dead       = gs.playerRoster.where((p) => !p.isAlive).toList();
    final fieldCount = _ordered.length < 7 ? _ordered.length : 7;

    return Container(
      color: Colors.black.withValues(alpha: 0.96),
      child: SafeArea(
        child: Column(
          children: [
            _IntermissionHeader(gs: gs, act: act),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Stat table (standings)
                    StatTable(gs: gs),

                    // Lineup management section
                    _LineupSection(
                      ordered:    _ordered,
                      expanded:   _expanded,
                      dead:       dead,
                      fieldCount: fieldCount,
                      onReorder: (oldIdx, newIdx) {
                        setState(() {
                          if (newIdx > oldIdx) newIdx--;
                          final p = _ordered.removeAt(oldIdx);
                          _ordered.insert(newIdx, p);
                        });
                      },
                      onToggleExpand: (id) {
                        setState(() {
                          if (_expanded.contains(id)) {
                            _expanded.remove(id);
                          } else {
                            _expanded.add(id);
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            _ConfirmBar(act: act, onConfirm: () => widget.onConfirm(_ordered)),
          ],
        ),
      ),
    );
  }
}

// ── Intermission header ───────────────────────────────────────────────────────

class _IntermissionHeader extends StatelessWidget {
  final GameState gs;
  final ActState  act;

  const _IntermissionHeader({required this.gs, required this.act});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      decoration: BoxDecoration(
        color: _kDark,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
          colors: [_kGold.withValues(alpha: 0.10), Colors.transparent],
        ),
        border: const Border(
          bottom: BorderSide(color: Color(0xFF1A1A2A)),
        ),
      ),
      child: Row(
        children: [
          // Act + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ACT ${act.currentAct} — INTERMISSION',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 22, fontWeight: FontWeight.w700,
                    color: Colors.white, letterSpacing: 0.5),
                ),
                const SizedBox(height: 2),
                Text(
                  'LIVE STANDINGS  ·  SET LINEUP FOR ACT ${act.currentAct + 1}',
                  style: GoogleFonts.chakraPetch(
                    fontSize: 22, fontWeight: FontWeight.w600,
                    letterSpacing: 2.4, color: _kGold),
                ),
              ],
            ),
          ),
          // Score
          if (gs.settings.matchMode == MatchMode.threeTeams)
            Row(
              children: [
                Text(gs.settings.awayTeamName,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 22, fontWeight: FontWeight.w700,
                    color: Color(gs.settings.awayTeamPrimary))),
                const SizedBox(width: 12),
                Text(
                  '${act.opponentScore}  –  ${act.playerScore}  –  ${act.thirdScore}',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Text(gs.settings.homeTeamName,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 22, fontWeight: FontWeight.w700,
                    color: Color(gs.settings.homeTeamPrimary))),
                const SizedBox(width: 12),
                Text(gs.settings.thirdTeamName,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 22, fontWeight: FontWeight.w700,
                    color: Color(gs.settings.thirdTeamPrimary))),
              ],
            )
          else
            Row(
              children: [
                Text(gs.settings.awayTeamName,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 22, fontWeight: FontWeight.w700,
                    color: Color(gs.settings.awayTeamPrimary))),
                const SizedBox(width: 12),
                Text(
                  '${act.opponentScore}  –  ${act.playerScore}',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Text(gs.settings.homeTeamName,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 22, fontWeight: FontWeight.w700,
                    color: Color(gs.settings.homeTeamPrimary))),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Lineup section (reorderable list + dead list) ─────────────────────────────

class _LineupSection extends StatelessWidget {
  final List<UltraballPlayer> ordered;
  final Set<String>           expanded;
  final List<UltraballPlayer> dead;
  final int                   fieldCount;
  final void Function(int, int) onReorder;
  final void Function(String)   onToggleExpand;

  const _LineupSection({
    required this.ordered,
    required this.expanded,
    required this.dead,
    required this.fieldCount,
    required this.onReorder,
    required this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kSurf,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('LINEUP  ($fieldCount / 7 ON FIELD)', const Color(0xFF44FF88)),
          const SizedBox(height: 8),
          SizedBox(
            height: (ordered.length * 56.0).clamp(100.0, 480.0) +
                expanded.length * 110.0,
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              onReorder: onReorder,
              itemCount: ordered.length,
              itemBuilder: (ctx, i) => _AliveRow(
                key: ValueKey(ordered[i].id),
                index:      i,
                player:     ordered[i],
                fieldCount: fieldCount,
                isExpanded: expanded.contains(ordered[i].id),
                onToggle:   () => onToggleExpand(ordered[i].id),
              ),
            ),
          ),
          if (dead.isNotEmpty) ...[
            const SizedBox(height: 12),
            _sectionLabel('ELIMINATED', _kDead),
            const SizedBox(height: 6),
            for (final p in dead) _DeadRow(player: p),
          ],
        ],
      ),
    );
  }

  static Widget _sectionLabel(String text, Color color) {
    return Row(
      children: [
        Container(width: 3, height: 14, color: color),
        const SizedBox(width: 8),
        Text(text,
          style: GoogleFonts.chakraPetch(
            color: color, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
      ],
    );
  }
}

// ── Single alive player row ───────────────────────────────────────────────────

class _AliveRow extends StatelessWidget {
  final int              index;
  final UltraballPlayer  player;
  final int              fieldCount;
  final bool             isExpanded;
  final VoidCallback     onToggle;

  const _AliveRow({
    super.key,
    required this.index,
    required this.player,
    required this.fieldCount,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isField       = index < 7;
    final isFirstRes    = index == 7;
    final slotLabel     = isField ? 'FIELD ${index + 1}' : 'RES ${index - 6}';
    final slotColor     = isField ? const Color(0xFF44FF88) : Colors.white.withValues(alpha: 0.35);
    final clsColor      = UiAssets.classColor(player.playerClass);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isFirstRes)
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Row(children: [
              Container(width: 3, height: 14, color: Colors.white.withValues(alpha: 0.25)),
              const SizedBox(width: 8),
              Text('RESERVE', style: GoogleFonts.chakraPetch(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            ]),
          ),
        ReorderableDragStartListener(
          index: index,
          child: Container(
            margin: const EdgeInsets.only(bottom: 3),
            decoration: BoxDecoration(
              color: isField ? const Color(0xFF0A1A0A) : const Color(0xFF0A0A14),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isField
                    ? const Color(0xFF44FF88).withValues(alpha: 0.22)
                    : const Color(0xFF1A1A2E),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 10),
                SizedBox(
                  width: 58,
                  child: Text(slotLabel, style: GoogleFonts.chakraPetch(
                    color: slotColor, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: clsColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: clsColor.withValues(alpha: 0.45)),
                  ),
                  child: Center(child: UiAssets.classIcon(player.playerClass, size: 22, color: clsColor)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(player.name,
                    style: TextStyle(
                      color: isField ? Colors.white : Colors.white.withValues(alpha: 0.55),
                      fontSize: 22,
                      fontWeight: isField ? FontWeight.w600 : FontWeight.normal)),
                ),
                if (player.ultraMana > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text('★' * player.ultraMana.floor(),
                      style: const TextStyle(color: _kGold, fontSize: 22)),
                  ),
                GestureDetector(
                  onTap: onToggle,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: const Color(0xFF444466), size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) _PlayerInfoPanel(player: player),
      ],
    );
  }
}

// ── Expanded player info panel ────────────────────────────────────────────────

class _PlayerInfoPanel extends StatelessWidget {
  final UltraballPlayer player;
  const _PlayerInfoPanel({required this.player});

  @override
  Widget build(BuildContext context) {
    final cls      = player.playerClass;
    final clsColor = UiAssets.classColor(cls);
    final abilities = cls.abilityNames;

    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A1A),
        borderRadius: BorderRadius.circular(4),
        border: Border(left: BorderSide(color: clsColor.withValues(alpha: 0.6), width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${cls.baseSpeed} m/s  •  ${player.health.toInt()} / ${cls.maxHealth.toInt()} HP',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 22)),
              const Spacer(),
              Text(cls.description,
                style: TextStyle(color: clsColor.withValues(alpha: 0.7), fontSize: 22)),
            ],
          ),
          const SizedBox(height: 4),
          for (int row = 0; row < 3; row++)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  for (int col = 0; col < 3; col++)
                    _AbilityChip(slot: row * 3 + col + 1, name: abilities[row * 3 + col]),
                ],
              ),
            ),
          const SizedBox(height: 3),
          Row(
            children: [
              Text('⚡ ULTRA (4 Ultra Mana)',
                style: TextStyle(
                  color: _kGold.withValues(alpha: 0.9),
                  fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(abilities[9],
                  style: const TextStyle(
                    color: _kGold, fontSize: 22, fontWeight: FontWeight.bold,
                    overflow: TextOverflow.ellipsis)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AbilityChip extends StatelessWidget {
  final int    slot;
  final String name;
  const _AbilityChip({required this.slot, required this.name});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 2),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A1A),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: const Color(0xFF222244)),
        ),
        child: Row(
          children: [
            Text('$slot.', style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3), fontSize: 22)),
            const SizedBox(width: 2),
            Expanded(
              child: Text(name,
                style: const TextStyle(
                  color: Colors.white70, fontSize: 22, overflow: TextOverflow.ellipsis)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dead player row ───────────────────────────────────────────────────────────

class _DeadRow extends StatelessWidget {
  final UltraballPlayer player;
  const _DeadRow({required this.player});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF080810),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF1A1A24)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: Text('DEAD',
              style: GoogleFonts.chakraPetch(
                color: _kDead.withValues(alpha: 0.6),
                fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
          Text(player.playerClass.displayName,
            style: TextStyle(fontSize: 22, color: Colors.white.withValues(alpha: 0.3))),
          const SizedBox(width: 8),
          Text(player.name,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.25),
              fontSize: 22,
              decoration: TextDecoration.lineThrough,
              decorationColor: Colors.white.withValues(alpha: 0.15))),
        ],
      ),
    );
  }
}

// ── Confirm bar ───────────────────────────────────────────────────────────────

class _ConfirmBar extends StatelessWidget {
  final ActState    act;
  final VoidCallback onConfirm;

  const _ConfirmBar({required this.act, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        color: _kDark,
        border: Border(top: BorderSide(color: Color(0xFF1A1A2A))),
      ),
      child: SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: onConfirm,
          style: TextButton.styleFrom(
            backgroundColor: _kGold,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          child: Text(
            'CONFIRM LINEUP — BEGIN ACT ${act.currentAct + 1}',
            style: GoogleFonts.chakraPetch(
              fontWeight: FontWeight.w700, fontSize: 22, letterSpacing: 1.5,
              color: Colors.black),
          ),
        ),
      ),
    );
  }
}
