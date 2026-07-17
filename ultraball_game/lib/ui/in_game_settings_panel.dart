import 'package:flutter/material.dart';
import '../models/game_settings.dart';
import '../ai/ai_strategy.dart';
import '../game/game_state.dart';

// ── Color palette ─────────────────────────────────────────────────────────
const _kBg        = Color(0xFF08080F);
const _kCard      = Color(0xFF111125);
const _kBorder    = Color(0xFF222244);
const _kGold      = Color(0xFFFFCC00);
const _kGoldDim   = Color(0xFF7A6200);
const _kTabActive = Color(0xFF1A1A35);
const _kAccent    = Color(0xFF1E88E5); // section header accent
const _kDanger    = Color(0xFFE53935); // danger/forfeit action
const _kText      = Colors.white;
const _kTextDim   = Color(0xAAFFFFFF);
const _kTextFaint = Color(0x66FFFFFF);

// ── Enums ─────────────────────────────────────────────────────────────────
enum _Tab { display, ai, controls }

class InGameSettingsPanel extends StatefulWidget {
  final GameState gs;
  final VoidCallback onClose;
  /// Called when the view mode changes so GameWidget can update _fieldPainter.
  final void Function(ViewMode) onViewModeChanged;

  const InGameSettingsPanel({
    super.key,
    required this.gs,
    required this.onClose,
    required this.onViewModeChanged,
  });

  @override
  State<InGameSettingsPanel> createState() => _InGameSettingsPanelState();
}

class _InGameSettingsPanelState extends State<InGameSettingsPanel> {
  _Tab _activeTab = _Tab.display;

  GameState get _gs => widget.gs;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dark semi-transparent backdrop — tap to close
        GestureDetector(
          onTap: widget.onClose,
          child: Container(color: const Color(0xCC000000)),
        ),

        // Centered panel
        Center(
          child: GestureDetector(
            onTap: () {}, // swallow taps so backdrop doesn't close on panel click
            child: Container(
              width: 520,
              height: 470,
              decoration: BoxDecoration(
                color: _kBg,
                border: Border.all(color: _kBorder, width: 1.5),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(color: Color(0x99000000), blurRadius: 40, spreadRadius: 8),
                ],
              ),
              child: Column(
                children: [
                  _buildHeader(),
                  _buildTabBar(),
                  Expanded(child: _buildContent()),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: _kCard,
        border: Border(bottom: BorderSide(color: _kBorder)),
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(
        children: [
          const Icon(Icons.settings, color: _kGold, size: 18),
          const SizedBox(width: 8),
          const Text(
            'SETTINGS',
            style: TextStyle(
              color: _kGold,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          _IconBtn(icon: Icons.close, onTap: widget.onClose),
        ],
      ),
    );
  }

  // ── Tab bar ───────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      height: 38,
      decoration: const BoxDecoration(
        color: _kCard,
        border: Border(bottom: BorderSide(color: _kBorder)),
      ),
      child: Row(
        children: _Tab.values.map((t) => _buildTab(t)).toList(),
      ),
    );
  }

  Widget _buildTab(_Tab tab) {
    final active = _activeTab == tab;
    final (String label, IconData icon) = switch (tab) {
      _Tab.display  => ('DISPLAY',  Icons.visibility_outlined),
      _Tab.ai       => ('OPPONENT AI', Icons.smart_toy_outlined),
      _Tab.controls => ('CONTROLS', Icons.keyboard_outlined),
    };
    return GestureDetector(
      onTap: () => setState(() => _activeTab = tab),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: active ? _kTabActive : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: active ? _kGold : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: active ? _kGold : _kTextFaint),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? _kGold : _kTextFaint,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Content router ────────────────────────────────────────────────────────

  Widget _buildContent() {
    return switch (_activeTab) {
      _Tab.display  => _buildDisplayTab(),
      _Tab.ai       => _buildAiTab(),
      _Tab.controls => _buildControlsTab(),
    };
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DISPLAY TAB
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDisplayTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(label: 'VIEW MODE'),
          const SizedBox(height: 10),
          _buildViewModeSelector(),
          const SizedBox(height: 20),
          _SectionHeader(label: 'OVERLAYS'),
          const SizedBox(height: 10),
          _buildToggleTile(
            label: 'Show HP Bars',
            subtitle: 'Health bar above each player',
            value: _gs.prefs.showHpBars,
            onChanged: (v) => setState(() => _gs.prefs.showHpBars = v),
          ),
          _buildToggleTile(
            label: 'Show Player Numbers',
            subtitle: 'Roster index displayed on each unit',
            value: _gs.prefs.showPlayerNumbers,
            onChanged: (v) => setState(() => _gs.prefs.showPlayerNumbers = v),
          ),
          _buildToggleTile(
            label: 'Show Damage Indicators',
            subtitle: 'Floating text for damage, kills and events',
            value: _gs.prefs.showDamageIndicators,
            onChanged: (v) => setState(() => _gs.prefs.showDamageIndicators = v),
          ),
          _buildToggleTile(
            label: 'Show Phase Lines',
            subtitle: 'Vertical charge-reset lines across the field',
            value: _gs.prefs.showPhaseLines,
            onChanged: (v) => setState(() => _gs.prefs.showPhaseLines = v),
          ),
          _buildToggleTile(
            label: 'Show Queued Ability Range',
            subtitle: 'Draw the range circle for the next ability in queue',
            value: _gs.prefs.showNextQueuedAbilityRange,
            onChanged: (v) => setState(() => _gs.prefs.showNextQueuedAbilityRange = v),
          ),
          _buildToggleTile(
            label: 'Debug: Scoreboard Heights',
            subtitle: 'Show live MainBar / BallDivider / Cards px values',
            value: _gs.prefs.showScoreboardDebugHeights,
            onChanged: (v) => setState(() => _gs.prefs.showScoreboardDebugHeights = v),
          ),
          const SizedBox(height: 20),
          _SectionHeader(label: 'TARGET INDICATOR'),
          const SizedBox(height: 10),
          _buildSliderTile(
            label: 'Indicator Size',
            subtitle: 'Size of the rings and brackets drawn on targeted units',
            value: _gs.prefs.targetIndicatorSize,
            min: 0.5,
            max: 4.0,
            divisions: 14,
            displayValue: '${_gs.prefs.targetIndicatorSize.toStringAsFixed(1)}×',
            onChanged: (v) => setState(() => _gs.prefs.targetIndicatorSize = v),
          ),
          const SizedBox(height: 20),
          _SectionHeader(label: 'COMBAT TEXT'),
          const SizedBox(height: 10),
          _buildCombatTextSection(),
        ],
      ),
    );
  }

  Widget _buildCombatTextSection() {
    final prefs = _gs.prefs;

    const fontOptions = [
      (label: 'Bangers',  value: 'Bangers'),
      (label: 'Default',  value: null),
      (label: 'Mono',     value: 'monospace'),
    ];

    // Preset swatches for each color role
    const damageSwatches = [
      Color(0xFFFFDD00), Color(0xFFFFFFFF), Color(0xFFFF8800), Color(0xFF44EEFF),
    ];
    const healSwatches = [
      Color(0xFF44FF88), Color(0xFF19E3E3), Color(0xFFFFFFFF), Color(0xFF88FF44),
    ];
    const killSwatches = [
      Color(0xFFFF2222), Color(0xFFFF8800), Color(0xFFAA44FF), Color(0xFFFFDD00),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Font family
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _kCard,
              border: Border.all(color: _kBorder),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Font',
                    style: TextStyle(color: _kText, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                const Text('Typeface used for floating combat numbers and ability queue',
                    style: TextStyle(color: _kTextFaint, fontSize: 11)),
                const SizedBox(height: 8),
                Row(
                  children: fontOptions.map((opt) {
                    final active = prefs.combatFontFamily == opt.value;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () => setState(() => prefs.combatFontFamily = opt.value),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: active ? _kGoldDim : _kBg,
                            border: Border.all(color: active ? _kGold : _kBorder, width: active ? 1.5 : 1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            opt.label,
                            style: TextStyle(
                              fontFamily: opt.value,
                              color: active ? _kGold : _kTextFaint,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),

        // Scale slider
        _buildSliderTile(
          label: 'Text Size',
          subtitle: 'Scale for all combat floating text',
          value: prefs.combatFontScale,
          min: 0.5,
          max: 2.0,
          divisions: 15,
          displayValue: '${prefs.combatFontScale.toStringAsFixed(1)}×',
          onChanged: (v) => setState(() => prefs.combatFontScale = v),
        ),

        // Shadow toggle
        _buildToggleTile(
          label: 'Drop Shadow',
          subtitle: 'Outline shadow behind floating numbers',
          value: prefs.combatShadow,
          onChanged: (v) => setState(() => prefs.combatShadow = v),
        ),

        // Color rows
        _buildColorRow('Damage Color', damageSwatches, prefs.combatDamageColor,
            (c) => setState(() => prefs.combatDamageColor = c)),
        _buildColorRow('Heal Color', healSwatches, prefs.combatHealColor,
            (c) => setState(() => prefs.combatHealColor = c)),
        _buildColorRow('Kill Color', killSwatches, prefs.combatKillColor,
            (c) => setState(() => prefs.combatKillColor = c)),
      ],
    );
  }

  Widget _buildColorRow(String label, List<Color> swatches, Color current,
      ValueChanged<Color> onSelect) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _kCard,
          border: Border.all(color: _kBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(color: _kText, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            ...swatches.map((c) {
              final selected = c.toARGB32() == current.toARGB32();
              return Padding(
                padding: const EdgeInsets.only(left: 6),
                child: GestureDetector(
                  onTap: () => onSelect(c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: selected ? Colors.white : Colors.white.withValues(alpha: 0.2),
                        width: selected ? 2.5 : 1,
                      ),
                      boxShadow: selected
                          ? [BoxShadow(color: c.withValues(alpha: 0.7), blurRadius: 6)]
                          : null,
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildViewModeSelector() {
    final current = _gs.prefs.viewModeOverride ?? widget.gs.settings.viewMode;
    final isThreeTeam = _gs.settings.matchMode == MatchMode.threeTeams;
    return Row(
      children: [
        _ViewModeBtn(
          label: '2D',
          icon: Icons.grid_on,
          active: current == ViewMode.flat,
          onTap: () => _setViewMode(ViewMode.flat),
        ),
        const SizedBox(width: 8),
        _ViewModeBtn(
          label: '3/4',
          icon: Icons.view_in_ar_outlined,
          active: current == ViewMode.threeQuarter,
          onTap: isThreeTeam ? null : () => _setViewMode(ViewMode.threeQuarter),
        ),
        const SizedBox(width: 8),
        _ViewModeBtn(
          label: '3D',
          icon: Icons.threed_rotation,
          active: current == ViewMode.full3D,
          onTap: isThreeTeam ? null : () => _setViewMode(ViewMode.full3D),
        ),
      ],
    );
  }

  void _setViewMode(ViewMode mode) {
    setState(() => _gs.prefs.viewModeOverride = mode);
    widget.onViewModeChanged(mode);
  }

  Widget _buildToggleTile({
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _kCard,
          border: Border.all(color: _kBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(color: _kText, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(color: _kTextFaint, fontSize: 11)),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: _kGold,
              activeTrackColor: _kGoldDim,
              inactiveThumbColor: const Color(0xFF555566),
              inactiveTrackColor: const Color(0xFF222233),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderTile({
    required String label,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String displayValue,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
        decoration: BoxDecoration(
          color: _kCard,
          border: Border.all(color: _kBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: const TextStyle(color: _kText, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(color: _kTextFaint, fontSize: 11)),
                    ],
                  ),
                ),
                Text(displayValue,
                    style: const TextStyle(color: _kGold, fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: _kGold,
                inactiveTrackColor: _kBorder,
                thumbColor: _kGold,
                overlayColor: _kGoldDim.withValues(alpha: 0.3),
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                divisions: divisions,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // AI TAB
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildAiTab() {
    final effectiveStrategy = _gs.effectiveAiStrategy;
    final effectiveTactics  = _gs.effectiveAiTactics;
    final isDefaultStrategy = _gs.prefs.aiStrategyOverride == null;
    final isDefaultTactics  = _gs.prefs.aiTacticsOverride  == null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SectionHeader(label: 'OPPONENT STRATEGY'),
              const Spacer(),
              if (!isDefaultStrategy)
                _TextBtn(
                  label: 'RESET',
                  onTap: () => setState(() => _gs.prefs.aiStrategyOverride = null),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ...AiStrategy.values.map((s) => _buildStrategyTile(
            emoji: s.emoji, label: s.label, description: s.description,
            selected: effectiveStrategy == s,
            isDefault: isDefaultStrategy && s == _gs.settings.aiStrategy,
            onTap: () => setState(() =>
                _gs.prefs.aiStrategyOverride = s == _gs.settings.aiStrategy ? null : s),
          )),

          const SizedBox(height: 16),
          Row(
            children: [
              _SectionHeader(label: 'OPPONENT TACTICS'),
              const Spacer(),
              if (!isDefaultTactics)
                _TextBtn(
                  label: 'RESET',
                  onTap: () => setState(() => _gs.prefs.aiTacticsOverride = null),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ...AiTactics.values.map((t) => _buildStrategyTile(
            emoji: t.emoji, label: t.label, description: t.description,
            selected: effectiveTactics == t,
            isDefault: isDefaultTactics && t == _gs.settings.aiTactics,
            onTap: () => setState(() =>
                _gs.prefs.aiTacticsOverride = t == _gs.settings.aiTactics ? null : t),
          )),
        ],
      ),
    );
  }

  Widget _buildStrategyTile({
    required String emoji,
    required String label,
    required String description,
    required bool selected,
    required bool isDefault,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1A1A2E) : _kCard,
          border: Border.all(
            color: selected ? _kGold : _kBorder,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(label,
                          style: TextStyle(
                            color: selected ? _kGold : _kText,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          )),
                      if (isDefault) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF222244),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text('MATCH',
                              style: TextStyle(color: _kTextFaint, fontSize: 9, letterSpacing: 1)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(description,
                      style: const TextStyle(color: _kTextFaint, fontSize: 10)),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: selected ? _kGold : _kTextFaint,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CONTROLS TAB
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildControlsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildControlGroup('MOVEMENT', [
            ('W / ↑',          'Move forward'),
            ('S / ↓',          'Move backward'),
            ('A / ←',          'Turn left'),
            ('D / →',          'Turn right'),
            ('Q',              'Strafe left'),
            ('E',              'Strafe right'),
            ('Space',          'Jump  ·  Space (again) = Double-jump (15 💙)'),
          ]),
          const SizedBox(height: 14),
          _buildControlGroup('BALL', [
            ('Click (field)',  'Quick pass toward cursor'),
            ('Click (player)', 'Pass to teammate'),
            ('F (hold)',        'Charge arc throw'),
            ('F (release)',     'Launch arc throw'),
          ]),
          const SizedBox(height: 14),
          _buildControlGroup('TEAM', [
            ('TAB',            'Cycle enemy targets'),
            ('Shift + TAB',    'Switch controlled player'),
          ]),
          const SizedBox(height: 14),
          _buildControlGroup('ABILITIES', [
            ('1 – 0',          'Class ability slots 1–10'),
            ('2 (Geomancer)',   'Hold: aim Rise Mountain  ·  Release: place'),
            ('4 (Geomancer)',   'Hold: aim Open Pit  ·  Release: place'),
          ]),
          const SizedBox(height: 14),
          _buildControlGroup('CAMERA', [
            ('V',              'Toggle 3D camera mode (broadcast ↔ follow)'),
          ]),
          const SizedBox(height: 14),
          _buildControlGroup('GAME', [
            ('ESC',            'Pause / Resume'),
          ]),
        ],
      ),
    );
  }

  Widget _buildControlGroup(String title, List<(String, String)> bindings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(label: title),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: _kCard,
            border: Border.all(color: _kBorder),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            children: bindings.indexed.map(((int, (String, String)) entry) {
              final (i, (key, desc)) = entry;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  border: i == 0
                      ? null
                      : const Border(top: BorderSide(color: _kBorder, width: 0.5)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(
                        key,
                        style: const TextStyle(
                          color: _kGold,
                          fontSize: 12,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(desc,
                          style: const TextStyle(color: _kTextDim, fontSize: 12)),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ── View mode button ──────────────────────────────────────────────────────

class _ViewModeBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;

  const _ViewModeBtn({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: active ? _kGoldDim : _kCard,
          border: Border.all(color: active ? _kGold : _kBorder, width: active ? 1.5 : 1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Opacity(
          opacity: disabled ? 0.35 : 1.0,
          child: Column(
            children: [
              Icon(icon, size: 18, color: active ? _kGold : _kTextFaint),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                    color: active ? _kGold : _kTextFaint,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Small reusable widgets ────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: const TextStyle(
              color: _kAccent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            )),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: _kBorder)),
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, color: _kTextFaint, size: 18),
      ),
    );
  }
}

class _TextBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _TextBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(label,
          style: const TextStyle(
            color: _kDanger,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          )),
    );
  }
}
