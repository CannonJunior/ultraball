import 'package:flutter/material.dart';
import '../models/creature.dart';
import '../models/game_settings.dart';
import '../models/player_class.dart';
import '../game/game_widget.dart';
import '../ai/ai_strategy.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _homeTeamIdx = 0;
  int _awayTeamIdx = 1;
  bool _isNeutralSite = false;
  CreatureType _neutralCreatureType = CreatureType.chaos;
  bool _fastMode = false;
  ViewMode _viewMode = ViewMode.flat;
  bool _useCubeModels = true;
  AiStrategy _homeStrategy = AiStrategy.numericalEdge;
  AiTactics  _homeTactics  = AiTactics.heroBall;
  AiStrategy _aiStrategy   = AiStrategy.tempoTrap;
  AiTactics  _aiTactics    = AiTactics.focusFire;
  List<int> _homeRosterOrder = List.generate(15, (i) => i);
  bool _testMode = false;

  void _startMatch() {
    final home = TeamDefinition.teams[_homeTeamIdx];
    final away = TeamDefinition.teams[_awayTeamIdx];
    final creatureType = _isNeutralSite
        ? _neutralCreatureType
        : home.creatureType;
    final settings = GameSettings(
      homeTeamName: home.name,
      awayTeamName: away.name,
      homePlayerNames: home.playerNames,
      awayPlayerNames: away.playerNames,
      creatureType: creatureType,
      fastMode: _fastMode,
      viewMode: _viewMode,
      useCubeModels: _useCubeModels,
      homeStrategy: _homeStrategy,
      homeTactics:  _homeTactics,
      aiStrategy:   _aiStrategy,
      aiTactics:    _aiTactics,
      homeRosterOrder: List.from(_homeRosterOrder),
      testMode: _testMode,
    );

    Navigator.of(context).push(
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
                            width: 560,
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

          // Teams side by side
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Home column ──────────────────────────────────
              Expanded(
                child: _SettingCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FieldLabel('HOME TEAM (Player)'),
                      const SizedBox(height: 6),
                      _TeamDropdown(
                        selected: _homeTeamIdx,
                        excludeIdx: _awayTeamIdx,
                        onChanged: (i) => setState(() {
                          _homeTeamIdx = i;
                          _homeRosterOrder = List.generate(15, (j) => j);
                        }),
                        accentColor: const Color(0xFF1E88E5),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // ── Away column ──────────────────────────────────
              Expanded(
                child: _SettingCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FieldLabel('AWAY TEAM (Opponent)'),
                      const SizedBox(height: 6),
                      _TeamDropdown(
                        selected: _awayTeamIdx,
                        excludeIdx: _homeTeamIdx,
                        onChanged: (i) => setState(() => _awayTeamIdx = i),
                        accentColor: const Color(0xFFE53935),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Creature (full width, with neutral site toggle)
          _SettingCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _FieldLabel('CREATURE'),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _isNeutralSite = !_isNeutralSite),
                      child: Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _isNeutralSite
                                    ? const Color(0xFFFFCC00)
                                    : const Color(0xFF556688),
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(3),
                              color: _isNeutralSite
                                  ? const Color(0xFFFFCC00).withValues(alpha: 0.2)
                                  : Colors.transparent,
                            ),
                            child: _isNeutralSite
                                ? const Icon(Icons.check, size: 11, color: Color(0xFFFFCC00))
                                : null,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'NEUTRAL SITE',
                            style: TextStyle(
                              color: _isNeutralSite
                                  ? const Color(0xFFFFCC00)
                                  : Colors.white.withValues(alpha: 0.5),
                              fontSize: 10,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (!_isNeutralSite)
                  _CreatureDisplay(
                    type: TeamDefinition.teams[_homeTeamIdx].creatureType,
                  )
                else
                  _NeutralCreatureDropdown(
                    value: _neutralCreatureType,
                    onChanged: (t) => setState(() => _neutralCreatureType = t),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Strategies side by side
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Home strategy + tactics ───────────────────────
              Expanded(
                child: _SettingCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FieldLabel('HOME STRATEGY'),
                      const SizedBox(height: 4),
                      Text(
                        'How AI teammates approach the game',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 9),
                      ),
                      const SizedBox(height: 10),
                      ...AiStrategy.values.map((s) => _ChoiceRadio(
                        emoji: s.emoji,
                        label: s.label,
                        description: s.description,
                        selected: _homeStrategy == s,
                        onTap: () => setState(() => _homeStrategy = s),
                      )),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Container(height: 1, color: const Color(0xFF1A1A33)),
                      ),
                      _FieldLabel('HOME TACTICS'),
                      const SizedBox(height: 4),
                      Text(
                        'How AI teammates behave moment-to-moment',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 9),
                      ),
                      const SizedBox(height: 10),
                      ...AiTactics.values.map((t) => _ChoiceRadio(
                        emoji: t.emoji,
                        label: t.label,
                        description: t.description,
                        selected: _homeTactics == t,
                        onTap: () => setState(() => _homeTactics = t),
                      )),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // ── Opponent strategy + tactics ───────────────────
              Expanded(
                child: _SettingCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FieldLabel('OPPONENT STRATEGY'),
                      const SizedBox(height: 4),
                      Text(
                        'The computer team\'s theory of victory',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 9),
                      ),
                      const SizedBox(height: 10),
                      ...AiStrategy.values.map((s) => _ChoiceRadio(
                        emoji: s.emoji,
                        label: s.label,
                        description: s.description,
                        selected: _aiStrategy == s,
                        onTap: () => setState(() => _aiStrategy = s),
                      )),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Container(height: 1, color: const Color(0xFF1A1A33)),
                      ),
                      _FieldLabel('OPPONENT TACTICS'),
                      const SizedBox(height: 4),
                      Text(
                        'The computer team\'s moment-to-moment behavior',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 9),
                      ),
                      const SizedBox(height: 10),
                      ...AiTactics.values.map((t) => _ChoiceRadio(
                        emoji: t.emoji,
                        label: t.label,
                        description: t.description,
                        selected: _aiTactics == t,
                        onTap: () => setState(() => _aiTactics = t),
                      )),
                    ],
                  ),
                ),
              ),
            ],
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

          const SizedBox(height: 12),

          // View mode
          _SettingCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FieldLabel('VIEW MODE'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _SpeedButton(
                        label: '2D',
                        sublabel: 'Top-down',
                        selected: _viewMode == ViewMode.flat,
                        onTap: () => setState(() => _viewMode = ViewMode.flat),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SpeedButton(
                        label: '3/4',
                        sublabel: 'Isometric',
                        selected: _viewMode == ViewMode.threeQuarter,
                        onTap: () => setState(() => _viewMode = ViewMode.threeQuarter),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SpeedButton(
                        label: '3D',
                        sublabel: 'Perspective',
                        selected: _viewMode == ViewMode.full3D,
                        onTap: () => setState(() => _viewMode = ViewMode.full3D),
                      ),
                    ),
                  ],
                ),
                if (_viewMode == ViewMode.full3D) ...[
                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFF2A2A3A), height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CHARACTER MODELS',
                              style: TextStyle(
                                color: Color(0xFF8888AA),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _useCubeModels ? 'Default cubes' : 'Character rigs',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _useCubeModels,
                        onChanged: (v) => setState(() => _useCubeModels = v),
                        activeColor: const Color(0xFF4488FF),
                        inactiveThumbColor: const Color(0xFF6666AA),
                        inactiveTrackColor: const Color(0xFF1A1A2E),
                      ),
                    ],
                  ),
                ],
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
                  ('M', 'Toggle damage / healing meter'),
                  ('C', 'Cycle player class (Test Mode only)'),
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

          const SizedBox(height: 12),

          // Test Mode toggle
          _SettingCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TEST MODE',
                        style: TextStyle(
                          color: Color(0xFF8888AA),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _testMode
                            ? '1v1 dummy — C key cycles class'
                            : 'Full match (7v7)',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _testMode,
                  onChanged: (v) => setState(() => _testMode = v),
                  activeColor: const Color(0xFF44FF88),
                  inactiveThumbColor: const Color(0xFF6666AA),
                  inactiveTrackColor: const Color(0xFF1A1A2E),
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
            homeTeamIdx: _homeTeamIdx,
            awayTeamIdx: _awayTeamIdx,
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
          const _ClassesSection(),
        ],
      ),
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

class _TeamDropdown extends StatelessWidget {
  final int selected;
  final int excludeIdx;
  final ValueChanged<int> onChanged;
  final Color accentColor;

  const _TeamDropdown({
    required this.selected,
    required this.excludeIdx,
    required this.onChanged,
    required this.accentColor,
  });

  static (String, String) _creatureInfo(CreatureType t) => switch (t) {
    CreatureType.kraken => ('🐙', 'Kraken'),
    CreatureType.dragon => ('🐉', 'Dragon'),
    CreatureType.hydra  => ('🐍', 'Hydra'),
    CreatureType.wraith => ('👻', 'Wraith'),
    CreatureType.chaos  => ('⚡', 'Chaos Monster'),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: accentColor.withValues(alpha: 0.5)),
      ),
      child: DropdownButton<int>(
        value: selected,
        isExpanded: true,
        dropdownColor: const Color(0xFF0D0D1A),
        underline: const SizedBox(),
        onChanged: (v) { if (v != null) onChanged(v); },
        items: List.generate(TeamDefinition.teams.length, (i) {
          if (i == excludeIdx) return null;
          final team = TeamDefinition.teams[i];
          final (emoji, _) = _creatureInfo(team.creatureType);
          return DropdownMenuItem(
            value: i,
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(
                  team.name,
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          );
        }).whereType<DropdownMenuItem<int>>().toList(),
      ),
    );
  }
}

class _CreatureDisplay extends StatelessWidget {
  final CreatureType type;
  const _CreatureDisplay({required this.type});

  @override
  Widget build(BuildContext context) {
    final (emoji, name, desc) = switch (type) {
      CreatureType.kraken => ('🐙', 'KRAKEN',        'Slow & deadly'),
      CreatureType.dragon => ('🐉', 'DRAGON',        'Fast & fierce'),
      CreatureType.hydra  => ('🐍', 'HYDRA',         'Large & relentless'),
      CreatureType.wraith => ('👻', 'WRAITH',         'Blindingly fast & ethereal'),
      CreatureType.chaos  => ('⚡', 'CHAOS MONSTER', 'Unpredictable & terrifying'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF333355)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(
                color: Color(0xFFCCDDFF),
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1,
              )),
              Text(desc, style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 10,
              )),
            ],
          ),
          const Spacer(),
          Text('HOME TEAM', style: TextStyle(
            color: Colors.white.withValues(alpha: 0.25),
            fontSize: 8,
            letterSpacing: 1,
          )),
        ],
      ),
    );
  }
}

class _NeutralCreatureDropdown extends StatelessWidget {
  final CreatureType value;
  final ValueChanged<CreatureType> onChanged;
  const _NeutralCreatureDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFFFCC00).withValues(alpha: 0.5)),
      ),
      child: DropdownButton<CreatureType>(
        value: value,
        isExpanded: true,
        dropdownColor: const Color(0xFF0D0D1A),
        underline: const SizedBox(),
        onChanged: (v) { if (v != null) onChanged(v); },
        items: CreatureType.values.map((t) {
          final (emoji, name, desc) = switch (t) {
            CreatureType.kraken => ('🐙', 'KRAKEN',        'Slow & deadly'),
            CreatureType.dragon => ('🐉', 'DRAGON',        'Fast & fierce'),
            CreatureType.hydra  => ('🐍', 'HYDRA',         'Large & relentless'),
            CreatureType.wraith => ('👻', 'WRAITH',         'Blindingly fast & ethereal'),
            CreatureType.chaos  => ('⚡', 'CHAOS MONSTER', 'Unpredictable & terrifying'),
          };
          return DropdownMenuItem(
            value: t,
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(name, style: const TextStyle(
                      color: Color(0xFFFFCC00),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1,
                    )),
                    Text(desc, style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 9,
                    )),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ChoiceRadio extends StatelessWidget {
  final String emoji;
  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceRadio({
    required this.emoji,
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1A1A2E) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? const Color(0xFFFFCC00) : const Color(0xFF333355),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: selected
                          ? const Color(0xFFFFCC00)
                          : Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: selected ? 1.0 : 0.0,
              child: const Icon(Icons.check_circle, color: Color(0xFFFFCC00), size: 16),
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

  static Color _classColor(int playerIdx) => switch (playerIdx % 7) {
    0 => const Color(0xFF44FFCC),
    1 => const Color(0xFFFF44AA),
    2 => const Color(0xFFFF5544),
    3 => const Color(0xFF4488FF),
    4 => const Color(0xFFFFCC44),
    5 => const Color(0xFFAA44FF),
    _ => const Color(0xFFFF7700),
  };

  static String _classBadge(int playerIdx) => _playerClass(playerIdx).displayName;

  static PlayerClass _playerClass(int playerIdx) => switch (playerIdx % 7) {
    0 => PlayerClass.spectre,
    1 => PlayerClass.corsair,
    2 => PlayerClass.geomancer,
    3 => PlayerClass.archon,
    4 => PlayerClass.warden,
    5 => PlayerClass.trickster,
    _ => PlayerClass.wrecker,
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

  static Color _classColor(int playerIdx) => switch (playerIdx % 7) {
    0 => const Color(0xFF44FFCC),
    1 => const Color(0xFFFF44AA),
    2 => const Color(0xFFFF5544),
    3 => const Color(0xFF4488FF),
    4 => const Color(0xFFFFCC44),
    5 => const Color(0xFFAA44FF),
    _ => const Color(0xFFFF7700),
  };

  static String _classBadge(int playerIdx) => _playerClass(playerIdx).displayName;

  static PlayerClass _playerClass(int playerIdx) => switch (playerIdx % 7) {
    0 => PlayerClass.spectre,
    1 => PlayerClass.corsair,
    2 => PlayerClass.geomancer,
    3 => PlayerClass.archon,
    4 => PlayerClass.warden,
    5 => PlayerClass.trickster,
    _ => PlayerClass.wrecker,
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


// ─── Classes Section ─────────────────────────────────────────────────────────

class _ClassesSection extends StatelessWidget {
  const _ClassesSection();

  static const _entries = [
    (PlayerClass.spectre,    Color(0xFF44FFCC)),
    (PlayerClass.corsair,   Color(0xFFFF44AA)),
    (PlayerClass.geomancer, Color(0xFFFF5544)),
    (PlayerClass.archon,    Color(0xFF4488FF)),
    (PlayerClass.warden,   Color(0xFFFFCC44)),
    (PlayerClass.trickster, Color(0xFFAA44FF)),
    (PlayerClass.wrecker,  Color(0xFFFF7700)),
  ];

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
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: const Text('🧬', style: TextStyle(fontSize: 20)),
          title: const Text(
            'CLASSES',
            style: TextStyle(
              color: Color(0xFFCCDDFF),
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 1.5,
            ),
          ),
          iconColor: const Color(0xFFFFCC00),
          collapsedIconColor: Color.fromRGBO(255, 255, 255, 0.4),
          children: _entries
              .map((e) => _ClassCard(cls: e.$1, color: e.$2))
              .toList(),
        ),
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  final PlayerClass cls;
  final Color color;

  const _ClassCard({required this.cls, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
            ),
            child: Row(
              children: [
                Text(
                  cls.displayName,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    cls.description,
                    style: TextStyle(
                      color: color.withValues(alpha: 0.7),
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: Row(
              children: [
                _StatPill(label: 'SPD', value: '${cls.baseSpeed.toStringAsFixed(1)} m/s', color: color),
                const SizedBox(width: 8),
                _StatPill(label: 'HP', value: '${cls.maxHealth.toInt()}', color: color),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 2, 10, 10),
            child: _AbilityTable(cls: cls, color: color),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatPill({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label  ',
            style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 9, letterSpacing: 1),
          ),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _AbilityTable extends StatelessWidget {
  final PlayerClass cls;
  final Color color;

  const _AbilityTable({required this.cls, required this.color});

  static String _cdLabel(double cd) {
    if (cd <= 0) return '—';
    return cd == cd.truncateToDouble() ? '${cd.toInt()}s' : '${cd}s';
  }

  TableRow _headerRow() {
    const style = TextStyle(
      color: Color(0xFF6688AA),
      fontSize: 8.5,
      letterSpacing: 1,
      fontWeight: FontWeight.bold,
    );
    return TableRow(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.3), width: 1)),
      ),
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(2, 3, 2, 5), child: Text('#',      style: style, textAlign: TextAlign.center)),
        Padding(padding: const EdgeInsets.fromLTRB(4, 3, 4, 5), child: Text('ABILITY', style: style)),
        Padding(padding: const EdgeInsets.fromLTRB(2, 3, 2, 5), child: Text('MANA',    style: style)),
        Padding(padding: const EdgeInsets.fromLTRB(4, 3, 4, 5), child: Text('RANGE',   style: style)),
        Padding(padding: const EdgeInsets.fromLTRB(2, 3, 4, 5), child: Text('CD',      style: style)),
        Padding(padding: const EdgeInsets.fromLTRB(4, 3, 2, 5), child: Text('EFFECT',  style: style)),
      ],
    );
  }

  TableRow _abilityRow(int i, String name, String desc, String cost, String range, double cd) {
    final isUltra = i == 9;
    final slot    = i + 1;
    final rowBg   = isUltra
        ? const Color(0xFFFFCC00).withValues(alpha: 0.06)
        : (i.isEven ? color.withValues(alpha: 0.04) : Colors.transparent);

    final nameStyle = TextStyle(
      color: isUltra ? const Color(0xFFFFCC00) : Colors.white.withValues(alpha: 0.9),
      fontSize: 10,
      fontWeight: FontWeight.bold,
    );
    final descStyle = TextStyle(
      color: isUltra
          ? const Color(0xFFFFCC00).withValues(alpha: 0.75)
          : Colors.white.withValues(alpha: 0.55),
      fontSize: 9.5,
      height: 1.35,
    );
    final rangeStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.5),
      fontSize: 9.5,
    );
    final cdStyle = TextStyle(
      color: isUltra ? const Color(0xFFFFCC00) : color.withValues(alpha: 0.75),
      fontSize: 9,
      fontWeight: FontWeight.bold,
    );

    return TableRow(
      decoration: BoxDecoration(
        color: rowBg,
        border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.08), width: 1)),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 5, 2, 5),
          child: Text(
            isUltra ? '⚡' : '$slot',
            style: TextStyle(
              color: isUltra ? const Color(0xFFFFCC00) : Colors.white.withValues(alpha: 0.3),
              fontSize: isUltra ? 12 : 9,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 5, 4, 5),
          child: Text(name, style: nameStyle),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 5, 2, 5),
          child: _ManaBadge(cost),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 5, 4, 5),
          child: Text(range, style: rangeStyle),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 5, 4, 5),
          child: Text(_cdLabel(cd), style: cdStyle),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 5, 2, 5),
          child: Text(desc, style: descStyle),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final names     = cls.abilityNames;
    final descs     = cls.abilityDescriptions;
    final costs     = cls.abilityManaCosts;
    final ranges    = cls.abilityRanges;
    final cooldowns = cls.slotMaxCooldowns;

    return Table(
      columnWidths: const {
        0: FixedColumnWidth(20),
        1: FixedColumnWidth(90),
        2: FixedColumnWidth(42),
        3: FixedColumnWidth(60),
        4: FixedColumnWidth(32),
        5: FlexColumnWidth(1),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      children: [
        _headerRow(),
        for (int i = 0; i < 10; i++)
          _abilityRow(i, names[i], descs[i], costs[i], ranges[i], cooldowns[i]),
      ],
    );
  }
}

class _ManaBadge extends StatelessWidget {
  final String cost;
  const _ManaBadge(this.cost);

  @override
  Widget build(BuildContext context) {
    if (cost == '—') {
      return Text('—', style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 9));
    }
    final isRed  = cost.endsWith('R');
    final isBlue = cost.endsWith('B');
    final badgeColor = isRed
        ? const Color(0xFFFF5566)
        : isBlue
            ? const Color(0xFF4499FF)
            : const Color(0xFFFFCC00);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        cost,
        style: TextStyle(
          color: badgeColor,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
