import 'package:flutter/material.dart';
import '../models/player.dart';
import '../models/act_state.dart';
import '../game/game_state.dart';

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
        .where((p) => p.isAlive)
        .toList()
      ..sort((a, b) => a.deploySlot.compareTo(b.deploySlot));
  }

  @override
  Widget build(BuildContext context) {
    final gs = widget.gs;
    final act = gs.actState;
    final dead = gs.playerRoster.where((p) => !p.isAlive).toList();
    final aliveCount = _ordered.length;
    final fieldCount = aliveCount < 7 ? aliveCount : 7;

    return Container(
      color: Colors.black.withValues(alpha: 0.96),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(act, gs),
            const Divider(color: Color(0xFF222244), height: 1),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Field label
                      _sectionLabel('ON FIELD  ($fieldCount/7)', const Color(0xFF44FF88)),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: (_ordered.length * 56.0).clamp(100.0, 520.0) + _expanded.length * 110.0,
                        child: ReorderableListView.builder(
                          buildDefaultDragHandles: false,
                          onReorder: (oldIdx, newIdx) {
                            setState(() {
                              if (newIdx > oldIdx) newIdx--;
                              final p = _ordered.removeAt(oldIdx);
                              _ordered.insert(newIdx, p);
                            });
                          },
                          itemCount: _ordered.length,
                          itemBuilder: (ctx, i) => _buildAliveRow(i, fieldCount),
                        ),
                      ),
                      if (dead.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _sectionLabel('ELIMINATED', const Color(0xFFFF4444)),
                        const SizedBox(height: 6),
                        for (final p in dead) _buildDeadRow(p),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            _buildConfirmBar(act),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ActState act, GameState gs) {
    final homeScore = act.playerScore;
    final awayScore = act.opponentScore;
    final homeColor = const Color(0xFF1E88E5);
    final awayColor = const Color(0xFFE53935);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      color: const Color(0xFF050510),
      child: Column(
        children: [
          Text(
            'ACT ${act.currentAct} COMPLETE',
            style: const TextStyle(
              color: Color(0xFFFFCC00),
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(gs.settings.homeTeamName,
                style: TextStyle(color: homeColor, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
              const SizedBox(width: 12),
              Text('$homeScore — $awayScore',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              Text(gs.settings.awayTeamName,
                style: TextStyle(color: awayColor, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'SET YOUR LINEUP FOR ACT ${act.currentAct + 1}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, Color color) {
    return Row(
      children: [
        Container(width: 3, height: 14, color: color),
        const SizedBox(width: 8),
        Text(text,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          )),
      ],
    );
  }

  static Color _classColor(PlayerClass cls) => switch (cls) {
    PlayerClass.runner   => const Color(0xFF44FFCC),
    PlayerClass.blitzer  => const Color(0xFFFF44AA),
    PlayerClass.geomancer => const Color(0xFFFF5544),
    PlayerClass.warden   => const Color(0xFF4488FF),
    PlayerClass.handler  => const Color(0xFFFFCC44),
    PlayerClass.trickster => const Color(0xFFAA44FF),
  };

  Widget _buildAliveRow(int index, int fieldCount) {
    final player = _ordered[index];
    final isField = index < 7;
    final isFirstReserve = index == 7;
    final slotLabel = isField
        ? 'FIELD ${index + 1}'
        : 'RES ${index - 6}';
    final slotColor = isField ? const Color(0xFF44FF88) : Colors.white.withValues(alpha: 0.35);
    final classEmoji = _classBadge(player.playerClass);
    final classBadgeColor = _classBadgeColor(player.playerClass);
    final isExpanded = _expanded.contains(player.id);

    return Column(
      key: ValueKey(player.id),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isFirstReserve)
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: _sectionLabel('RESERVE  (${_ordered.length - 7} available)', Colors.white.withValues(alpha: 0.4)),
          ),
        ReorderableDragStartListener(
          index: index,
          child: Container(
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: isField
                  ? const Color(0xFF0A1A0A)
                  : const Color(0xFF0A0A14),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isField
                    ? const Color(0xFF44FF88).withValues(alpha: 0.25)
                    : const Color(0xFF222244),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 8),
                // Slot label
                SizedBox(
                  width: 56,
                  child: Text(slotLabel,
                    style: TextStyle(
                      color: slotColor,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    )),
                ),
                // Class badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: classBadgeColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: classBadgeColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(classEmoji,
                    style: const TextStyle(fontSize: 10)),
                ),
                const SizedBox(width: 8),
                // Name
                Expanded(
                  child: Text(player.name,
                    style: TextStyle(
                      color: isField
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.55),
                      fontSize: 13,
                      fontWeight: isField ? FontWeight.w600 : FontWeight.normal,
                    )),
                ),
                // Ultra mana indicator
                if (player.ultraMana > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      '★' * player.ultraMana.floor(),
                      style: const TextStyle(color: Color(0xFFFFCC00), fontSize: 10),
                    ),
                  ),
                // Caret to toggle expansion
                GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isExpanded) {
                        _expanded.remove(player.id);
                      } else {
                        _expanded.add(player.id);
                      }
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: const Color(0xFF444466),
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) _buildPlayerInfoPanel(player),
      ],
    );
  }

  Widget _buildPlayerInfoPanel(UltraballPlayer player) {
    final cls = player.playerClass;
    final clsColor = _classColor(cls);
    final abilities = cls.abilityNames;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A1A),
        borderRadius: BorderRadius.circular(4),
        border: Border(left: BorderSide(color: clsColor.withValues(alpha: 0.6), width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats row
          Row(
            children: [
              Text(
                '${cls.baseSpeed} m/s  •  ${player.health.toInt()} / ${cls.maxHealth.toInt()} HP',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 8,
                ),
              ),
              const Spacer(),
              Text(
                cls.description,
                style: TextStyle(
                  color: clsColor.withValues(alpha: 0.7),
                  fontSize: 7,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // 3×3 ability grid (slots 1–9)
          for (int row = 0; row < 3; row++)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  for (int col = 0; col < 3; col++)
                    _abilityChip(row * 3 + col + 1, abilities[row * 3 + col]),
                ],
              ),
            ),
          // ULTRA line
          const SizedBox(height: 3),
          Row(
            children: [
              Text(
                '⚡ ULTRA (4 Ultra Mana)',
                style: TextStyle(
                  color: const Color(0xFFFFCC00).withValues(alpha: 0.9),
                  fontSize: 7,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  abilities[9],
                  style: const TextStyle(
                    color: Color(0xFFFFCC00),
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _abilityChip(int slot, String name) {
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
            Text(
              '$slot.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 7,
              ),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 8,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeadRow(UltraballPlayer player) {
    final classEmoji = _classBadge(player.playerClass);
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF080808),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF1A1A1A)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text('DEAD',
              style: TextStyle(
                color: const Color(0xFFFF4444).withValues(alpha: 0.6),
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              )),
          ),
          Text(classEmoji, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.3))),
          const SizedBox(width: 8),
          Text(player.name,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.25),
              fontSize: 13,
              decoration: TextDecoration.lineThrough,
              decorationColor: Colors.white.withValues(alpha: 0.15),
            )),
        ],
      ),
    );
  }

  Widget _buildConfirmBar(ActState act) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      color: const Color(0xFF050510),
      child: SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: () => widget.onConfirm(_ordered),
          style: TextButton.styleFrom(
            backgroundColor: const Color(0xFFFFCC00),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          child: Text(
            'CONFIRM LINEUP — BEGIN ACT ${act.currentAct + 1}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  String _classBadge(PlayerClass cls) => cls.displayName;

  Color _classBadgeColor(PlayerClass cls) => switch (cls) {
    PlayerClass.runner   => const Color(0xFF44FFCC),
    PlayerClass.geomancer => const Color(0xFFFF5544),
    PlayerClass.warden   => const Color(0xFF4488FF),
    PlayerClass.handler  => const Color(0xFFFFCC44),
    PlayerClass.blitzer  => const Color(0xFFFF44AA),
    PlayerClass.trickster => const Color(0xFFAA44FF),
  };
}
