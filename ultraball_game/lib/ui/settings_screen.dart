import 'package:flutter/material.dart';
import '../models/creature.dart';
import '../models/game_settings.dart';
import '../models/player_class.dart';
import '../game/game_widget.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _homeController = TextEditingController(text: 'VIPERS');
  final _awayController = TextEditingController(text: 'REAPERS');
  CreatureType _creatureType = CreatureType.kraken;
  bool _fastMode = false;
  List<int> _homeRosterOrder = List.generate(15, (i) => i);

  int _teamIdxFor(String name) {
    final upper = name.toUpperCase();
    final idx = TeamDefinition.teams.indexWhere((t) => t.name == upper);
    return idx == -1 ? 0 : idx;
  }

  @override
  void dispose() {
    _homeController.dispose();
    _awayController.dispose();
    super.dispose();
  }

  void _startMatch() {
    final settings = GameSettings(
      homeTeamName: _homeController.text.isEmpty
          ? 'VIPERS'
          : _homeController.text.toUpperCase(),
      awayTeamName: _awayController.text.isEmpty
          ? 'REAPERS'
          : _awayController.text.toUpperCase(),
      creatureType: _creatureType,
      fastMode: _fastMode,
      homeRosterOrder: List.from(_homeRosterOrder),
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (ctx) => GameWidget(settings: settings),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020208),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF020210),
              Color(0xFF0A020A),
              Color(0xFF100202),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),

              // Main content
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 800;
                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 360,
                            child: _buildSettingsPanel(),
                          ),
                          const VerticalDivider(
                            color: Color(0xFF333355),
                            width: 1,
                          ),
                          Expanded(child: _buildRulesPanel()),
                        ],
                      );
                    } else {
                      return SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildSettingsPanel(),
                            const Divider(color: Color(0xFF333355)),
                            _buildRulesPanel(),
                          ],
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
      child: Column(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFFFCC00), Color(0xFFFF6600), Color(0xFFFF0044)],
            ).createShader(bounds),
            child: const Text(
              'ULTRABALL',
              style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w900,
                letterSpacing: 8,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'A COMPETITIVE RAPID CHAOTIC SPORTS COMBAT GAME',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
              letterSpacing: 3,
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(label: 'MATCH CONFIGURATION'),
          const SizedBox(height: 16),

          // Team names
          _SettingCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FieldLabel('HOME TEAM (Player)'),
                const SizedBox(height: 6),
                TextField(
                  controller: _homeController,
                  style: const TextStyle(
                    color: Color(0xFF88CCFF),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                  decoration: _inputDecoration('VIPERS', const Color(0xFF1E88E5)),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 16),
                _FieldLabel('AWAY TEAM (Opponent)'),
                const SizedBox(height: 6),
                TextField(
                  controller: _awayController,
                  style: const TextStyle(
                    color: Color(0xFFFF8888),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                  decoration: _inputDecoration('REAPERS', const Color(0xFFE53935)),
                  textCapitalization: TextCapitalization.characters,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Creature type
          _SettingCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FieldLabel('CREATURE TYPE'),
                const SizedBox(height: 10),
                ...CreatureType.values.map(
                  (type) => _CreatureRadio(
                    type: type,
                    selected: _creatureType == type,
                    onTap: () => setState(() => _creatureType = type),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Game speed
          _SettingCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FieldLabel('MATCH DURATION'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _SpeedButton(
                        label: 'NORMAL',
                        sublabel: '3min acts',
                        selected: !_fastMode,
                        onTap: () => setState(() => _fastMode = false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SpeedButton(
                        label: 'FAST',
                        sublabel: '1min acts',
                        selected: _fastMode,
                        onTap: () => setState(() => _fastMode = true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Controls cheat sheet
          _SettingCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FieldLabel('CONTROLS'),
                const SizedBox(height: 8),
                ...[
                  ('W / S', 'Move forward / backward'),
                  ('A / D', 'Turn left / right'),
                  ('Q / E', 'Strafe left / right'),
                  ('1', 'Tackle (basic attack)'),
                  ('2', 'Power Slam (25 Red Mana)'),
                  ('3', 'Sprint (20 Blue Mana)'),
                  ('F', 'Pass ball to teammate'),
                  ('SPACE', 'Jump (evades tackles while airborne)'),
                  ('SPACE ×2', 'Double-jump (costs 15 Blue Mana)'),
                  ('TAB', 'Cycle enemy target'),
                  ('SHIFT+TAB', 'Switch controlled player'),
                  ('ESC', 'Clear target / Pause'),
                ].map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF333355),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: const Color(0xFF556688),
                            ),
                          ),
                          child: Text(
                            entry.$1,
                            style: const TextStyle(
                              color: Color(0xFFCCDDFF),
                              fontSize: 11,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          entry.$2,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Start button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startMatch,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ).copyWith(
                backgroundColor: WidgetStateProperty.all(Colors.transparent),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFCC8800), Color(0xFFDD2200)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF4400).withValues(alpha: 0.4),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Text(
                  'START MATCH',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 4,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(label: 'GAME RULES'),
          const SizedBox(height: 12),
          _RosterEditor(
            homeTeamIdx: _teamIdxFor(_homeController.text),
            awayTeamIdx: _teamIdxFor(_awayController.text),
            homeRosterOrder: _homeRosterOrder,
            onHomeReorder: (newOrder) => setState(() => _homeRosterOrder = newOrder),
          ),
          const SizedBox(height: 12),
          _RuleSection(
            icon: '🏟',
            title: 'THE FIELD',
            rules: [
              'Total field: 140m × 40m',
              'Left & Right endzones: 20m deep — score here!',
              'Left & Right channels: 10m — patrolled by the creature',
              'Main field: 80m with 5 PHASE LINES at 20m intervals',
              'Phase lines reset ball charge when crossed',
            ],
          ),
          _RuleSection(
            icon: '🏆',
            title: 'SCORING',
            rules: [
              'ULTRA (7 pts) — Ball carrier walks/runs into enemy endzone',
              'META (3 pts) — Pass caught by player already in enemy endzone',
              'KILLA (1 pt) — Opposing player dies (combat, creature, explosion)',
            ],
          ),
          _RuleSection(
            icon: '⚡',
            title: 'THE ULTRABALL',
            rules: [
              'Holding the ball builds CHARGE — explodes after 7 seconds!',
              'Explosion kills holder, stuns teammates 1 second',
              'Passing resets charge: +1 second per meter thrown',
              'Crossing a PHASE LINE fully resets charge to 0',
              'Phase lines deactivate when crossed (reactivate on possession change)',
              'Failed pass: entire passing team stunned 1 second',
            ],
          ),
          _RuleSection(
            icon: '👹',
            title: 'THE CREATURE',
            rules: [
              'Circles the entire field counter-clockwise at moderate speed',
              'Instantly kills any player it touches — both teams!',
              'Awards 1 KILLA point to the opposite team on each kill',
              'Three creature types: Kraken, Dragon, or Hydra (cosmetic)',
            ],
          ),
          _RuleSection(
            icon: '⚔',
            title: 'COMBAT',
            rules: [
              'RED MANA: 0–100, gained by dealing damage (+5/hit), decays after 3s',
              'BLUE MANA: 0–100, auto-regens at 8/sec passively',
              'TACKLE (Q): 15 dmg, 0.8s cooldown — no mana cost',
              'POWER SLAM (E): 35 dmg + knockback, costs 25 Red Mana, 3s CD',
              'SPRINT (Shift): +50% speed for 3s, costs 20 Blue Mana, 6s CD',
              'POWER PASS (F+): +50% pass distance, costs 30 Blue Mana',
              '3-HIT COMBO: 3 attacks in 4s = COMBO! +30 red mana + knockback',
            ],
          ),
          _RuleSection(
            icon: '👥',
            title: 'TEAMS',
            rules: [
              '7 players per team on field, 15-player roster total',
              'Deaths are PERMANENT within a match',
              '1 substitution allowed per act when a player dies',
              'After 1st death: sub used; subsequent deaths = disadvantage',
              'Teams restock to 7 at the start of each new act',
              'All 15 players dead = FORFEIT',
            ],
          ),
          _RuleSection(
            icon: '📋',
            title: 'THE ACTS',
            rules: [
              'Acts 1–4: 3-minute countdown timer (1 min in Fast mode)',
              'Act 5: Ends when the leading team scores an ULTRA...',
              '...OR the trailing team comes back and scores an ULTRA',
              'Highest score at end of Act 5 wins the match!',
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, Color accentColor) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: Colors.white.withValues(alpha: 0.2),
        letterSpacing: 2,
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: accentColor.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(4),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: accentColor, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      filled: true,
      fillColor: Colors.black.withValues(alpha: 0.4),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          color: const Color(0xFFFFCC00),
          margin: const EdgeInsets.only(right: 8),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFFFCC00),
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.5,
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.5),
        fontSize: 9,
        letterSpacing: 1.5,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  final Widget child;
  const _SettingCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF222244), width: 1),
      ),
      child: child,
    );
  }
}

class _CreatureRadio extends StatelessWidget {
  final CreatureType type;
  final bool selected;
  final VoidCallback onTap;

  const _CreatureRadio({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (emoji, name, desc) = switch (type) {
      CreatureType.kraken => ('🐙', 'KRAKEN', 'Slow & deadly'),
      CreatureType.dragon => ('🐉', 'DRAGON', 'Fast & fierce'),
      CreatureType.hydra  => ('🐍', 'HYDRA',  'Large & relentless'),
      CreatureType.wraith => ('👻', 'WRAITH', 'Unpredictable & spectral'),
      CreatureType.chaos  => ('💀', 'CHAOS',  'Erratic & lethal'),
    };

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF1A1A2E)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected
                ? const Color(0xFFFFCC00)
                : const Color(0xFF333355),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFFFFCC00)
                        : Colors.white.withValues(alpha: 0.7),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  desc,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (selected)
              const Icon(Icons.check_circle, color: Color(0xFFFFCC00), size: 18),
          ],
        ),
      ),
    );
  }
}

class _SpeedButton extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool selected;
  final VoidCallback onTap;

  const _SpeedButton({
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1A1A2E) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? const Color(0xFFFFCC00) : const Color(0xFF333355),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? const Color(0xFFFFCC00)
                    : Colors.white.withValues(alpha: 0.6),
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 1,
              ),
            ),
            Text(
              sublabel,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleSection extends StatelessWidget {
  final String icon;
  final String title;
  final List<String> rules;

  const _RuleSection({
    required this.icon,
    required this.title,
    required this.rules,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF222244), width: 1),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: Text(icon, style: const TextStyle(fontSize: 20)),
          title: Text(
            title,
            style: const TextStyle(
              color: Color(0xFFCCDDFF),
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 1.5,
            ),
          ),
          iconColor: const Color(0xFFFFCC00),
          collapsedIconColor: Colors.white.withValues(alpha: 0.4),
          children: rules
              .map(
                (rule) => Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.only(top: 5, right: 8),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFFFCC00),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          rule,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 11.5,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

// ─── Team Roster Editor ──────────────────────────────────────────────────────

class _RosterEditor extends StatelessWidget {
  final int homeTeamIdx;
  final int awayTeamIdx;
  final List<int> homeRosterOrder;
  final ValueChanged<List<int>> onHomeReorder;

  const _RosterEditor({
    required this.homeTeamIdx,
    required this.awayTeamIdx,
    required this.homeRosterOrder,
    required this.onHomeReorder,
  });

  @override
  Widget build(BuildContext context) {
    final homeNames    = TeamDefinition.teams[homeTeamIdx].playerNames;
    final homeTeamName = TeamDefinition.teams[homeTeamIdx].name;
    final awayNames    = TeamDefinition.teams[awayTeamIdx].playerNames;
    final awayTeamName = TeamDefinition.teams[awayTeamIdx].name;

    return Container(
      margin: const EdgeInsets.only(bottom: 0),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF222244), width: 1),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: const Text('👥', style: TextStyle(fontSize: 20)),
          title: const Text(
            'TEAM ROSTERS',
            style: TextStyle(
              color: Color(0xFFCCDDFF),
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 1.5,
            ),
          ),
          subtitle: Text(
            'Drag to set home team lineup order',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 9),
          ),
          iconColor: const Color(0xFFFFCC00),
          collapsedIconColor: const Color(0x66FFFFFF),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _EditableTeamRoster(
                  teamName: homeTeamName,
                  color: const Color(0xFF1E88E5),
                  names: homeNames,
                  order: homeRosterOrder,
                  onReorder: onHomeReorder,
                )),
                const SizedBox(width: 12),
                Expanded(child: _ReadonlyTeamRoster(
                  teamName: awayTeamName,
                  color: const Color(0xFFE53935),
                  names: awayNames,
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EditableTeamRoster extends StatefulWidget {
  final String teamName;
  final Color color;
  final List<String> names;
  final List<int> order;
  final ValueChanged<List<int>> onReorder;

  const _EditableTeamRoster({
    required this.teamName,
    required this.color,
    required this.names,
    required this.order,
    required this.onReorder,
  });

  @override
  State<_EditableTeamRoster> createState() => _EditableTeamRosterState();
}

class _EditableTeamRosterState extends State<_EditableTeamRoster> {
  final Set<int> _expanded = {};

  static Color _classColor(int playerIdx) => switch (playerIdx % 5) {
    0 => const Color(0xFF44FFCC),
    1 => const Color(0xFFFF44AA),
    2 => const Color(0xFFFF5544),
    3 => const Color(0xFF4488FF),
    _ => const Color(0xFFFFCC44),
  };

  static String _classBadge(int playerIdx) => switch (playerIdx % 5) {
    0 => 'Runner',
    1 => 'Blitzer',
    2 => 'Enforcer',
    3 => 'Warden',
    _ => 'Handler',
  };

  static PlayerClass _playerClass(int playerIdx) => switch (playerIdx % 5) {
    0 => PlayerClass.runner,
    1 => PlayerClass.blitzer,
    2 => PlayerClass.enforcer,
    3 => PlayerClass.warden,
    _ => PlayerClass.handler,
  };

  Widget _buildInfoPanel(int playerIdx) {
    final cls      = _playerClass(playerIdx);
    final clsColor = _classColor(playerIdx);
    final abilities = cls.abilityNames;
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D1A),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
        border: Border(left: BorderSide(color: clsColor.withValues(alpha: 0.5), width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${cls.baseSpeed} m/s  •  ${cls.maxHealth.toInt()} HP',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
              ),
              const Spacer(),
              Text(
                cls.description,
                style: TextStyle(color: clsColor.withValues(alpha: 0.7), fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(children: [
            for (int col = 0; col < 5; col++)
              _abilityCell(col + 1, abilities[col]),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            for (int col = 0; col < 5; col++)
              _abilityCell(col + 6, abilities[col + 5]),
          ]),
        ],
      ),
    );
  }

  Widget _abilityCell(int slot, String name) {
    final isUltra = slot == 10;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 2),
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        decoration: BoxDecoration(
          color: isUltra
              ? const Color(0xFFFFCC00).withValues(alpha: 0.08)
              : const Color(0xFF0D0D1A),
          borderRadius: BorderRadius.circular(2),
          border: Border.all(
            color: isUltra
                ? const Color(0xFFFFCC00).withValues(alpha: 0.3)
                : const Color(0xFF222244),
          ),
        ),
        child: Row(
          children: [
            Text(
              isUltra ? '⚡' : '$slot.',
              style: TextStyle(
                color: isUltra ? const Color(0xFFFFCC00) : Colors.white.withValues(alpha: 0.3),
                fontSize: 10,
              ),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  color: isUltra ? const Color(0xFFFFCC00) : Colors.white70,
                  fontSize: 11,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.teamName,
          style: TextStyle(
            color: widget.color, fontSize: 14,
            fontWeight: FontWeight.bold, letterSpacing: 1.5,
          )),
        Text('HOME — drag to reorder',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10)),
        const SizedBox(height: 6),
        SizedBox(
          height: 700.0 + _expanded.length * 120.0,
          child: ReorderableListView.builder(
            padding: const EdgeInsets.only(right: 16),
            buildDefaultDragHandles: false,
            onReorder: (oldIdx, newIdx) {
              if (newIdx > oldIdx) newIdx--;
              final newOrder = List<int>.from(widget.order);
              newOrder.insert(newIdx, newOrder.removeAt(oldIdx));
              widget.onReorder(newOrder);
            },
            itemCount: 15,
            itemBuilder: (ctx, slot) {
              final playerIdx = widget.order[slot];
              final isField   = slot < 7;
              final clsColor  = _classColor(playerIdx);
              final clsBadge  = _classBadge(playerIdx);
              final slotColor = isField ? const Color(0xFF44FF88) : Colors.white.withValues(alpha: 0.3);
              final slotText  = isField ? 'FIELD ${slot + 1}' : 'RES ${slot - 6}';
              final isExpanded = _expanded.contains(slot);

              return Column(
                key: ValueKey('h_$slot'),
                children: [
                  if (slot == 7)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        Expanded(child: Container(height: 1, color: const Color(0xFF334466))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text('RESERVE',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                              fontSize: 9, letterSpacing: 1,
                            )),
                        ),
                        Expanded(child: Container(height: 1, color: const Color(0xFF334466))),
                      ]),
                    ),
                  ReorderableDragStartListener(
                    index: slot,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 2),
                      decoration: BoxDecoration(
                        color: isField ? const Color(0xFF0A140A) : const Color(0xFF0A0A12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: isField
                            ? const Color(0xFF44FF88).withValues(alpha: 0.2)
                            : const Color(0xFF1A1A2E)),
                      ),
                      child: Row(children: [
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 60,
                          child: Text(slotText,
                            style: TextStyle(
                              color: slotColor, fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                          decoration: BoxDecoration(
                            color: clsColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text(clsBadge,
                            style: TextStyle(
                              color: clsColor, fontSize: 10,
                              fontWeight: FontWeight.bold,
                            )),
                        ),
                        const SizedBox(width: 4),
                        Expanded(child: Text(widget.names[playerIdx],
                          style: TextStyle(
                            color: isField
                                ? Colors.white.withValues(alpha: 0.9)
                                : Colors.white.withValues(alpha: 0.45),
                            fontSize: 13,
                            fontWeight: isField ? FontWeight.w600 : FontWeight.normal,
                          ))),
                        GestureDetector(
                          onTap: () => setState(() {
                            if (isExpanded) { _expanded.remove(slot); }
                            else { _expanded.add(slot); }
                          }),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                            child: Icon(
                              isExpanded ? Icons.expand_less : Icons.expand_more,
                              size: 20,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  if (isExpanded) _buildInfoPanel(playerIdx),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ReadonlyTeamRoster extends StatefulWidget {
  final String teamName;
  final Color color;
  final List<String> names;

  const _ReadonlyTeamRoster({
    required this.teamName,
    required this.color,
    required this.names,
  });

  @override
  State<_ReadonlyTeamRoster> createState() => _ReadonlyTeamRosterState();
}

class _ReadonlyTeamRosterState extends State<_ReadonlyTeamRoster> {
  final Set<int> _expanded = {};

  static Color _classColor(int playerIdx) => switch (playerIdx % 5) {
    0 => const Color(0xFF44FFCC),
    1 => const Color(0xFFFF44AA),
    2 => const Color(0xFFFF5544),
    3 => const Color(0xFF4488FF),
    _ => const Color(0xFFFFCC44),
  };

  static String _classBadge(int playerIdx) => switch (playerIdx % 5) {
    0 => 'Runner',
    1 => 'Blitzer',
    2 => 'Enforcer',
    3 => 'Warden',
    _ => 'Handler',
  };

  static PlayerClass _playerClass(int playerIdx) => switch (playerIdx % 5) {
    0 => PlayerClass.runner,
    1 => PlayerClass.blitzer,
    2 => PlayerClass.enforcer,
    3 => PlayerClass.warden,
    _ => PlayerClass.handler,
  };

  Widget _buildInfoPanel(int playerIdx) {
    final cls       = _playerClass(playerIdx);
    final clsColor  = _classColor(playerIdx);
    final abilities = cls.abilityNames;
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D1A),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
        border: Border(left: BorderSide(color: clsColor.withValues(alpha: 0.5), width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${cls.baseSpeed} m/s  •  ${cls.maxHealth.toInt()} HP',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 9),
              ),
              const Spacer(),
              Text(
                cls.description,
                style: TextStyle(color: clsColor.withValues(alpha: 0.7), fontSize: 8),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(children: [
            for (int col = 0; col < 5; col++)
              _abilityCell(col + 1, abilities[col]),
          ]),
          const SizedBox(height: 2),
          Row(children: [
            for (int col = 0; col < 5; col++)
              _abilityCell(col + 6, abilities[col + 5]),
          ]),
        ],
      ),
    );
  }

  Widget _abilityCell(int slot, String name) {
    final isUltra = slot == 10;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 2),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        decoration: BoxDecoration(
          color: isUltra
              ? const Color(0xFFFFCC00).withValues(alpha: 0.08)
              : const Color(0xFF0D0D1A),
          borderRadius: BorderRadius.circular(2),
          border: Border.all(
            color: isUltra
                ? const Color(0xFFFFCC00).withValues(alpha: 0.3)
                : const Color(0xFF222244),
          ),
        ),
        child: Row(
          children: [
            Text(
              isUltra ? '⚡' : '$slot.',
              style: TextStyle(
                color: isUltra ? const Color(0xFFFFCC00) : Colors.white.withValues(alpha: 0.3),
                fontSize: 8,
              ),
            ),
            const SizedBox(width: 1),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  color: isUltra ? const Color(0xFFFFCC00) : Colors.white70,
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.teamName,
          style: TextStyle(
            color: widget.color, fontSize: 14,
            fontWeight: FontWeight.bold, letterSpacing: 1.5,
          )),
        Text('AWAY — AI controlled',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10)),
        const SizedBox(height: 6),
        for (int slot = 0; slot < 15; slot++) ...[
          if (slot == 7)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Expanded(child: Container(height: 1, color: const Color(0xFF334466))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text('RESERVE',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 9, letterSpacing: 1,
                    )),
                ),
                Expanded(child: Container(height: 1, color: const Color(0xFF334466))),
              ]),
            ),
          Builder(builder: (context) {
            final isField   = slot < 7;
            final clsColor  = _classColor(slot);
            final clsBadge  = _classBadge(slot);
            final slotColor = isField ? const Color(0xFF44FF88) : Colors.white.withValues(alpha: 0.3);
            final slotText  = isField ? 'FIELD ${slot + 1}' : 'RES ${slot - 6}';
            final isExpanded = _expanded.contains(slot);
            return Column(
              children: [
                GestureDetector(
                  onTap: () => setState(() {
                    if (isExpanded) { _expanded.remove(slot); }
                    else { _expanded.add(slot); }
                  }),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 2),
                    decoration: BoxDecoration(
                      color: isField ? const Color(0xFF0A140A) : const Color(0xFF0A0A12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: isField
                          ? const Color(0xFF44FF88).withValues(alpha: 0.2)
                          : const Color(0xFF1A1A2E)),
                    ),
                    child: Row(children: [
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 60,
                        child: Text(slotText,
                          style: TextStyle(
                            color: slotColor, fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                        decoration: BoxDecoration(
                          color: clsColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(clsBadge,
                          style: TextStyle(
                            color: clsColor, fontSize: 10,
                            fontWeight: FontWeight.bold,
                          )),
                      ),
                      const SizedBox(width: 4),
                      Expanded(child: Text(widget.names[slot],
                        style: TextStyle(
                          color: isField
                              ? Colors.white.withValues(alpha: 0.9)
                              : Colors.white.withValues(alpha: 0.45),
                          fontSize: 13,
                          fontWeight: isField ? FontWeight.w600 : FontWeight.normal,
                        ))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        child: Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                          size: 20,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ]),
                  ),
                ),
                if (isExpanded) _buildInfoPanel(slot),
              ],
            );
          }),
        ],
      ],
    );
  }
}

