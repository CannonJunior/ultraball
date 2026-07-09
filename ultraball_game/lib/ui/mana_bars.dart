import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../game/game_state.dart';
import '../models/player.dart';
import 'ui_assets.dart';

// ─── UiEffect data class ──────────────────────────────────────────────────────

class UiEffect {
  final String name;
  final Color color;
  final IconData icon;
  final double remaining;
  final double total;
  final bool isBuff;
  const UiEffect({
    required this.name,
    required this.color,
    required this.icon,
    required this.remaining,
    required this.total,
    required this.isBuff,
  });
  double get progress => total > 0 ? (remaining / total).clamp(0.0, 1.0) : 1.0;
}

// ─── Build UiEffect list from a player ───────────────────────────────────────

List<UiEffect> _playerEffects(UltraballPlayer p) {
  final effects = <UiEffect>[];
  // Buffs
  if (p.speedMultiplierTimer > 0) effects.add(UiEffect(name: 'Haste', color: const Color(0xFF44FFCC), icon: Icons.speed, remaining: p.speedMultiplierTimer, total: p.speedMultiplierMax > 0 ? p.speedMultiplierMax : 7.0, isBuff: true));
  if (p.speedBoostTimer > 0) effects.add(UiEffect(name: 'Sprint', color: const Color(0xFF88FFDD), icon: Icons.directions_run, remaining: p.speedBoostTimer, total: p.speedBoostMax > 0 ? p.speedBoostMax : 4.0, isBuff: true));
  if (p.damageBoostTimer > 0) effects.add(UiEffect(name: '+Damage', color: const Color(0xFFFF5544), icon: Icons.whatshot, remaining: p.damageBoostTimer, total: p.damageBoostMax > 0 ? p.damageBoostMax : 5.0, isBuff: true));
  if (p.damageReductionTimer > 0) effects.add(UiEffect(name: 'Shield', color: const Color(0xFF4488FF), icon: Icons.shield, remaining: p.damageReductionTimer, total: p.damageReductionMax > 0 ? p.damageReductionMax : 6.0, isBuff: true));
  if (p.stunImmune) effects.add(UiEffect(name: 'Immune', color: const Color(0xFFFFCC00), icon: Icons.star, remaining: p.stunImmuneTimer > 0 ? p.stunImmuneTimer : 1.0, total: p.stunImmuneMax > 0 ? p.stunImmuneMax : 6.0, isBuff: true));
  if (p.dodgeTimer > 0) effects.add(UiEffect(name: 'Dodge', color: const Color(0xFF00FFEE), icon: Icons.flash_on, remaining: p.dodgeTimer, total: p.dodgeMax > 0 ? p.dodgeMax : 1.5, isBuff: true));
  if (p.hotTimer > 0) effects.add(UiEffect(name: 'Regen', color: const Color(0xFF44FF88), icon: Icons.favorite, remaining: p.hotTimer, total: p.hotMax > 0 ? p.hotMax : 5.0, isBuff: true));
  if (p.attacksApplySnareTimer > 0) effects.add(UiEffect(name: 'Blood Rush', color: const Color(0xFFFF44CC), icon: Icons.gas_meter, remaining: p.attacksApplySnareTimer, total: p.attacksApplySnareMax > 0 ? p.attacksApplySnareMax : 7.0, isBuff: true));
  // Debuffs
  if (p.stunTimer > 0) effects.add(UiEffect(name: 'Stun', color: const Color(0xFFFFFF44), icon: Icons.bolt, remaining: p.stunTimer, total: p.stunMax > 0 ? p.stunMax : 2.0, isBuff: false));
  if (p.snareTimer > 0) effects.add(UiEffect(name: 'Snare', color: const Color(0xFFAAAAFF), icon: Icons.anchor, remaining: p.snareTimer, total: p.snareMax > 0 ? p.snareMax : 2.0, isBuff: false));
  if (p.markedTimer > 0) effects.add(UiEffect(name: 'Marked', color: const Color(0xFFFF8800), icon: Icons.gps_fixed, remaining: p.markedTimer, total: p.markedMax > 0 ? p.markedMax : 6.0, isBuff: false));
  if (p.hexedTimer > 0) effects.add(UiEffect(name: 'Hex', color: const Color(0xFFCC44FF), icon: Icons.auto_fix_high, remaining: p.hexedTimer, total: p.hexedMax > 0 ? p.hexedMax : 4.0, isBuff: false));
  if (p.confusedTimer > 0) effects.add(UiEffect(name: 'Confused', color: const Color(0xFFFF88CC), icon: Icons.help, remaining: p.confusedTimer, total: p.confusedMax > 0 ? p.confusedMax : 3.0, isBuff: false));
  return effects;
}

// ─── Player unit frame (ManaBars) ─────────────────────────────────────────────

class ManaBars extends StatelessWidget {
  final GameState gs;
  const ManaBars({super.key, required this.gs});

  @override
  Widget build(BuildContext context) {
    final player = gs.selectedPlayer;
    if (player == null || !player.isAlive) return const SizedBox.shrink();

    final cls    = player.playerClass;
    final names  = cls.abilityNames;
    final maxCDs = cls.slotMaxCooldowns;

    return Container(
      width: 310,
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a2e).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF4cc9f0), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Unit frame header: portrait | bars ──────────────────────────
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PortraitBox(player: player, isPlayer: true),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(6, 6, 8, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Name + class badge
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                player.name.toUpperCase(),
                                style: const TextStyle(
                                  color:       Color(0xFF4cc9f0),
                                  fontSize:    11,
                                  fontWeight:  FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 5),
                            _ClassBadge(cls: cls),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Health bar — 16 px, gradient fill, text overlay
                        _WarcHealthBar(value: player.health, max: player.maxHealth),
                        const SizedBox(height: 3),
                        _MiniBar(value: player.redMana,  max: 100,                           color: const Color(0xFFDD3333), label: 'R'),
                        const SizedBox(height: 2),
                        _MiniBar(value: player.blueMana, max: 100,                           color: const Color(0xFF2277EE), label: 'B'),
                        const SizedBox(height: 2),
                        _MiniBar(value: player.ultraMana, max: UltraballPlayer.maxUltraMana, color: const Color(0xFFFFCC00), label: 'U'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Container(height: 1, color: const Color(0xFF4cc9f0).withValues(alpha: 0.2)),

          // ── Action section ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Buff icons row
                _EffectIcons(effects: _playerEffects(player).where((e) => e.isBuff).toList()),
                // Debuff icons row
                _EffectIcons(effects: _playerEffects(player).where((e) => !e.isBuff).toList()),
                const SizedBox(height: 2),
                // Queue display (combat text + queued abilities)
                _QueueDisplay(player: player),
                const SizedBox(height: 2),
                // Ability row 1: slots 1–5
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _AbilityIcon(keyLabel: '[1]', label: _abbrev(names[0]), cooldown: player.tackleCooldown,   maxCooldown: maxCDs[0], color: const Color(0xFFFF8844), available: player.tackleCooldown   <= 0, gcdRemaining: player.gcdRemaining, gcdMax: player.gcdMax),
                    _AbilityIcon(keyLabel: '[2]', label: _abbrev(names[1]), cooldown: player.slamCooldown,     maxCooldown: maxCDs[1], color: const Color(0xFFFF4444), available: player.slamCooldown     <= 0, gcdRemaining: player.gcdRemaining, gcdMax: player.gcdMax),
                    _AbilityIcon(keyLabel: '[3]', label: _abbrev(names[2]), cooldown: player.sprintCooldown,   maxCooldown: maxCDs[2], color: const Color(0xFF44CCFF), available: player.sprintCooldown   <= 0, gcdRemaining: player.gcdRemaining, gcdMax: player.gcdMax),
                    _AbilityIcon(keyLabel: '[4]', label: _abbrev(names[3]), cooldown: player.ability4Cooldown, maxCooldown: maxCDs[3], color: const Color(0xFF4488FF), available: player.ability4Cooldown <= 0, gcdRemaining: player.gcdRemaining, gcdMax: player.gcdMax),
                    _AbilityIcon(keyLabel: '[5]', label: _abbrev(names[4]), cooldown: player.ability5Cooldown, maxCooldown: maxCDs[4], color: const Color(0xFFAA44FF), available: player.ability5Cooldown <= 0, gcdRemaining: player.gcdRemaining, gcdMax: player.gcdMax),
                  ],
                ),
                // Ability row 2: slots 6–9 + ultra (no gap between rows)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _AbilityIcon(keyLabel: '[6]', label: _abbrev(names[5]), cooldown: player.ability6Cooldown, maxCooldown: maxCDs[5], color: const Color(0xFF44FF88), available: player.ability6Cooldown <= 0, gcdRemaining: player.gcdRemaining, gcdMax: player.gcdMax),
                    _AbilityIcon(keyLabel: '[7]', label: _abbrev(names[6]), cooldown: player.ability7Cooldown, maxCooldown: maxCDs[6], color: const Color(0xFF88DDFF), available: player.ability7Cooldown <= 0, gcdRemaining: player.gcdRemaining, gcdMax: player.gcdMax),
                    _AbilityIcon(keyLabel: '[8]', label: _abbrev(names[7]), cooldown: player.ability8Cooldown, maxCooldown: maxCDs[7], color: const Color(0xFFFFAA44), available: player.ability8Cooldown <= 0, gcdRemaining: player.gcdRemaining, gcdMax: player.gcdMax),
                    _AbilityIcon(keyLabel: '[9]', label: _abbrev(names[8]), cooldown: player.ability9Cooldown, maxCooldown: maxCDs[8], color: const Color(0xFFFF6688), available: player.ability9Cooldown <= 0, gcdRemaining: player.gcdRemaining, gcdMax: player.gcdMax),
                    _AbilityIcon(keyLabel: '[0]', label: _abbrev(names[9]), cooldown: 0, maxCooldown: 0, color: const Color(0xFFFFCC00), available: player.ultraMana >= 5, gcdRemaining: player.gcdRemaining, gcdMax: player.gcdMax),
                  ],
                ),
                const SizedBox(height: 6),
                _JumpIndicator(player: player),
                const SizedBox(height: 4),
                // Combo counter
                Row(
                  children: [
                    const Text('COMBO: ', style: TextStyle(color: Color(0xFF888888), fontSize: 9, letterSpacing: 1)),
                    ...List.generate(3, (i) {
                      final filled = i < player.comboCount;
                      return Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(right: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: filled ? const Color(0xFFFFAA00) : const Color(0xFF333333),
                          boxShadow: filled ? [BoxShadow(color: const Color(0xFFFFAA00).withValues(alpha: 0.6), blurRadius: 3, spreadRadius: 1)] : null,
                        ),
                      );
                    }),
                  ],
                ),
                if (gs.ball.isHeld) ...[
                  const SizedBox(height: 4),
                  _ChargeBar(chargePercent: gs.ball.chargePercent),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _abbrev(String name) {
    if (name.length <= 8) return name;
    final space = name.indexOf(' ');
    if (space > 0 && space <= 8) return name.substring(0, space);
    return '${name.substring(0, 7)}…';
  }
}

// ─── Target unit frame ────────────────────────────────────────────────────────

class TargetFrame extends StatelessWidget {
  final GameState gs;
  const TargetFrame({super.key, required this.gs});

  @override
  Widget build(BuildContext context) {
    final target = gs.currentTarget;
    if (target == null) return const SizedBox.shrink();

    double? dist;
    final sel = gs.selectedPlayer;
    if (sel != null) {
      final dx = target.x - sel.x;
      final dy = target.y - sel.y;
      dist = math.sqrt(dx * dx + dy * dy);
    }

    final effects = _playerEffects(target);

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a2e).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFF6B6B), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Bars (left / center)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Name + class badge + distance
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '▶ ${target.name.toUpperCase()}',
                            style: const TextStyle(
                              color:       Color(0xFFFF6B6B),
                              fontSize:    11,
                              fontWeight:  FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 5),
                        _ClassBadge(cls: target.playerClass),
                        const Spacer(),
                        if (dist != null)
                          Text(
                            '${dist.toStringAsFixed(1)}m',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 8),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _WarcHealthBar(value: target.health, max: target.maxHealth),
                    if (effects.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _EffectIcons(effects: effects),
                    ],
                  ],
                ),
              ),
            ),
            // Portrait (right side — mirrored)
            _PortraitBox(player: target, isPlayer: false),
          ],
        ),
      ),
    );
  }
}

// ─── Target-of-target frame ───────────────────────────────────────────────────

class TargetOfTargetFrame extends StatelessWidget {
  final GameState gs;
  const TargetOfTargetFrame({super.key, required this.gs});

  @override
  Widget build(BuildContext context) {
    final target = gs.currentTarget;
    if (target == null) return const SizedBox.shrink();

    // Who is the target currently targeting?
    final totId = target.currentTargetId;
    if (totId == null) return const SizedBox.shrink();
    final tot = gs.getPlayerById(totId);
    if (tot == null || !tot.isAlive) return const SizedBox.shrink();

    final isAlly = tot.team == Team.player;
    final borderColor = isAlly ? const Color(0xFF4cc9f0) : const Color(0xFFFF6B6B);

    return Container(
      width: 180,
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a2e).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor.withValues(alpha: 0.7), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 4, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Text('▶▶ ', style: TextStyle(color: Color(0xFF888888), fontSize: 8)),
                        Flexible(
                          child: Text(
                            tot.name.toUpperCase(),
                            style: TextStyle(color: borderColor, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 3),
                        _ClassBadge(cls: tot.playerClass),
                      ],
                    ),
                    const SizedBox(height: 3),
                    _WarcHealthBar(value: tot.health, max: tot.maxHealth),
                  ],
                ),
              ),
            ),
            _PortraitBox(player: tot, isPlayer: false),
          ],
        ),
      ),
    );
  }
}

// ─── Portrait box ─────────────────────────────────────────────────────────────

class _PortraitBox extends StatelessWidget {
  final UltraballPlayer player;
  final bool isPlayer;
  const _PortraitBox({required this.player, required this.isPlayer});

  static Color _classColor(PlayerClass cls) => switch (cls) {
    PlayerClass.spectre   => const Color(0xFF44FFCC),
    PlayerClass.geomancer => const Color(0xFFFF5544),
    PlayerClass.archon    => const Color(0xFF4488FF),
    PlayerClass.warden    => const Color(0xFFFFCC44),
    PlayerClass.corsair   => const Color(0xFFFF44AA),
    PlayerClass.trickster => const Color(0xFFAA44FF),
    PlayerClass.wrecker   => const Color(0xFFFF7700),
  };

  @override
  Widget build(BuildContext context) {
    final classColor  = _classColor(player.playerClass);
    final borderColor = isPlayer ? const Color(0xFF4cc9f0) : const Color(0xFFFF6B6B);

    return Container(
      width: 52,
      decoration: BoxDecoration(
        color: const Color(0xFF252542),
        border: Border(
          right: isPlayer  ? BorderSide(color: borderColor.withValues(alpha: 0.45), width: 1.5) : BorderSide.none,
          left:  !isPlayer ? BorderSide(color: borderColor.withValues(alpha: 0.45), width: 1.5) : BorderSide.none,
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: UiAssets.classIcon(player.playerClass, size: 30, color: classColor),
          ),
          Positioned(
            bottom: 0,
            left:  isPlayer  ? 0 : null,
            right: !isPlayer ? 0 : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.only(
                  topRight: isPlayer  ? const Radius.circular(3) : Radius.zero,
                  topLeft:  !isPlayer ? const Radius.circular(3) : Radius.zero,
                ),
              ),
              child: Text(
                '#${player.rosterIndex + 1}',
                style: const TextStyle(color: Color(0xFFFFD700), fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Warchief-style health bar (16 px, gradient fill, text overlay) ──────────

class _WarcHealthBar extends StatelessWidget {
  final double value;
  final double max;
  const _WarcHealthBar({required this.value, required this.max});

  Color get _color {
    final frac = value / max;
    if (frac > 0.5)  return const Color(0xFF4CAF50);
    if (frac > 0.25) return const Color(0xFFFFA726);
    return const Color(0xFFEF5350);
  }

  @override
  Widget build(BuildContext context) {
    final frac  = (value / max).clamp(0.0, 1.0);
    final color = _color;

    return Container(
      height: 16,
      decoration: BoxDecoration(
        color: const Color(0xFF0d0d14),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: Colors.black.withValues(alpha: 0.5), width: 1),
      ),
      child: Stack(
        children: [
          FractionallySizedBox(
            widthFactor: frac,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end:   Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: 0.9),
                    color,
                    color.withValues(alpha: 0.65),
                  ],
                ),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          Center(
            child: Text(
              '${value.toInt()} / ${max.toInt()}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(color: Colors.black, blurRadius: 2)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Mini resource bar (10 px, gradient fill) ────────────────────────────────

class _MiniBar extends StatelessWidget {
  final double value;
  final double max;
  final Color  color;
  final String label;
  const _MiniBar({required this.value, required this.max, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final frac = (value / max).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 10,
          child: Text(label, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 7, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: Container(
            height: 10,
            decoration: BoxDecoration(
              color: const Color(0xFF0d0d14),
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: Colors.black.withValues(alpha: 0.4), width: 0.5),
            ),
            child: FractionallySizedBox(
              widthFactor: frac,
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end:   Alignment.bottomCenter,
                    colors: [color.withValues(alpha: 0.88), color.withValues(alpha: 0.6)],
                  ),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Class badge ──────────────────────────────────────────────────────────────

class _ClassBadge extends StatelessWidget {
  final PlayerClass cls;
  const _ClassBadge({required this.cls});

  Color get _color => switch (cls) {
    PlayerClass.spectre   => const Color(0xFF44FFCC),
    PlayerClass.geomancer => const Color(0xFFFF5544),
    PlayerClass.archon    => const Color(0xFF4488FF),
    PlayerClass.warden    => const Color(0xFFFFCC44),
    PlayerClass.corsair   => const Color(0xFFFF44AA),
    PlayerClass.trickster => const Color(0xFFAA44FF),
    PlayerClass.wrecker   => const Color(0xFFFF7700),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: _color.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Text(
        cls.displayName,
        style: TextStyle(color: _color, fontSize: 7, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }
}

// ─── Effect icons with progress rings ────────────────────────────────────────

class _EffectIcons extends StatelessWidget {
  final List<UiEffect> effects;
  const _EffectIcons({required this.effects});

  static const double _iconSize = 18.0;

  @override
  Widget build(BuildContext context) {
    if (effects.isEmpty) return const SizedBox.shrink();

    final buffs   = effects.where((e) =>  e.isBuff).toList();
    final debuffs = effects.where((e) => !e.isBuff).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (buffs.isNotEmpty) _buildRow(buffs),
        if (buffs.isNotEmpty && debuffs.isNotEmpty) const SizedBox(height: 2),
        if (debuffs.isNotEmpty) _buildRow(debuffs),
      ],
    );
  }

  Widget _buildRow(List<UiEffect> row) {
    return Wrap(
      spacing: 2,
      runSpacing: 2,
      children: row.map(_buildIcon).toList(),
    );
  }

  Widget _buildIcon(UiEffect effect) {
    return Tooltip(
      message: '${effect.name} (${effect.remaining.toStringAsFixed(1)}s)',
      waitDuration: const Duration(milliseconds: 200),
      child: SizedBox(
        width: _iconSize,
        height: _iconSize,
        child: Stack(
          children: [
            Container(
              width: _iconSize,
              height: _iconSize,
              decoration: BoxDecoration(
                color: effect.color.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: effect.color.withValues(alpha: 0.7), width: 0.5),
              ),
              child: Center(
                child: Icon(effect.icon, color: effect.color, size: _iconSize * 0.6),
              ),
            ),
            CustomPaint(
              size: Size(_iconSize, _iconSize),
              painter: _ProgressRingPainter(progress: effect.progress),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  const _ProgressRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress >= 1.0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 0.5;
    final expiredSweep = (1.0 - progress) * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      expiredSweep,
      true,
      Paint()..color = Colors.black.withValues(alpha: 0.55)..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_ProgressRingPainter old) => (progress - old.progress).abs() > 0.01;
}

// ─── Queue display (combat text + queued abilities) ───────────────────────────

class _QueueDisplay extends StatelessWidget {
  final UltraballPlayer player;
  const _QueueDisplay({required this.player});

  // Dissolve-upward progress for the executing label (0 = just fired, 1 = gone).
  double get _execProgress =>
      (1.0 - (player.lastExecutedTimer / 1.2)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final queue     = player.abilityQueue;
    final executing = player.lastExecutedAbility;

    if (queue.isEmpty && executing == null) return const SizedBox.shrink();

    final names = player.playerClass.abilityNames;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Executing ability: gold, dissolves upward as it fades — mirrors the
        // Warchief QueuedAbilityLabelOverlay executing-label treatment.
        if (executing != null)
          Transform.translate(
            offset: Offset(0, -_execProgress * 12.0),
            child: Opacity(
              opacity: (1.0 - _execProgress).clamp(0.0, 1.0),
              child: Text(
                executing.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFFFFDD00),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  shadows: [
                    Shadow(color: Colors.black, blurRadius: 3, offset: Offset(1, 1)),
                    Shadow(color: Colors.black, blurRadius: 6),
                  ],
                ),
              ),
            ),
          ),
        // Queue line: "Slot1Name > Slot2Name > ..." matching Warchief RichText style.
        if (queue.isNotEmpty)
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(color: Color(0xB3000000), blurRadius: 2, offset: Offset(1, 1)),
                ],
              ),
              children: [
                for (int i = 0; i < queue.length; i++) ...[
                  if (i > 0) const TextSpan(text: ' > ', style: TextStyle(color: Colors.white70)),
                  TextSpan(
                    text: queue[i] >= 1 && queue[i] <= names.length
                        ? names[queue[i] - 1]
                        : 'Slot ${queue[i]}',
                    style: TextStyle(
                      // Dimmed when on cooldown — mirrors Colors.white38 used on
                      // ability buttons during their cooldown sweep (Warchief convention).
                      color: player.getSlotCooldown(queue[i]) > 0
                          ? Colors.white38
                          : Colors.white70,
                    ),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 2),
      ],
    );
  }
}

// ─── Ability icon ─────────────────────────────────────────────────────────────

class _AbilityIcon extends StatelessWidget {
  final String keyLabel;
  final String label;
  final double cooldown;
  final double maxCooldown;
  final Color  color;
  final bool   available;
  final double gcdRemaining;
  final double gcdMax;

  static const double size = 50;

  const _AbilityIcon({
    required this.keyLabel,
    required this.label,
    required this.cooldown,
    required this.maxCooldown,
    required this.color,
    required this.available,
    required this.gcdRemaining,
    required this.gcdMax,
  });

  @override
  Widget build(BuildContext context) {
    // Show whichever is greater: slot CD or active GCD
    final effectiveCd  = math.max(cooldown, gcdRemaining);
    final showingGcd   = gcdRemaining > cooldown && gcdRemaining > 0;
    final effectiveMax = showingGcd
        ? (gcdMax > 0 ? gcdMax : 1.0)
        : (maxCooldown > 0 ? maxCooldown : 1.0);
    final cdFrac = effectiveMax > 0 ? (effectiveCd / effectiveMax).clamp(0.0, 1.0) : 0.0;

    // GCD sweep uses a lighter color to distinguish from ability CD
    final sweepColor = showingGcd
        ? Colors.white.withValues(alpha: 0.45)
        : Colors.black.withValues(alpha: 0.65);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: available ? color.withValues(alpha: 0.2) : const Color(0xFF111111),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: available ? color : Colors.grey.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (cdFrac > 0)
                  CustomPaint(size: Size(size, size), painter: _ClockSweepPainter(cdFrac, sweepColor)),
                Text(
                  keyLabel,
                  style: TextStyle(color: available ? color : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                if (cdFrac > 0)
                  Positioned(
                    top: 1,
                    left: 2,
                    child: Text(
                      effectiveCd >= 10 ? '${effectiveCd.toInt()}s' : '${effectiveCd.toStringAsFixed(1)}s',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 2)]),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: size + 4,
          child: Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

// ─── Jump indicator ───────────────────────────────────────────────────────────

class _JumpIndicator extends StatelessWidget {
  final UltraballPlayer player;
  const _JumpIndicator({required this.player});

  @override
  Widget build(BuildContext context) {
    final airborne   = player.isAirborne;
    final canDouble  = airborne && !player.hasDoubleJumped && player.blueMana >= UltraballPlayer.doubleJumpManaCost;
    final usedDouble = airborne && player.hasDoubleJumped;

    return Row(
      children: [
        const SizedBox(
          width: 28,
          child: Text('JUMP', style: TextStyle(color: Color(0xFF888888), fontSize: 9, letterSpacing: 0.5)),
        ),
        _jumpPip(active: airborne,              color: const Color(0xFF88DDFF), label: '1'),
        const SizedBox(width: 4),
        _jumpPip(active: canDouble || usedDouble, color: usedDouble ? const Color(0xFF555555) : const Color(0xFF44AAFF), label: '2'),
        const SizedBox(width: 6),
        if (airborne)
          Text(
            usedDouble ? 'IN AIR' : canDouble ? 'SPACE to double-jump' : 'need ${UltraballPlayer.doubleJumpManaCost.toInt()} blue',
            style: TextStyle(color: canDouble ? const Color(0xFF44AAFF) : const Color(0xFF666666), fontSize: 8, fontStyle: FontStyle.italic),
          ),
      ],
    );
  }

  Widget _jumpPip({required bool active, required Color color, required String label}) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? color.withValues(alpha: 0.25) : const Color(0xFF1A1A1A),
        border: Border.all(color: active ? color : const Color(0xFF333333), width: 1.5),
      ),
      child: Center(
        child: Text(label, style: TextStyle(color: active ? color : const Color(0xFF444444), fontSize: 8, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ─── Clock-sweep cooldown painter ─────────────────────────────────────────────

class _ClockSweepPainter extends CustomPainter {
  final double fraction;
  final Color  sweepColor;
  const _ClockSweepPainter(this.fraction, this.sweepColor);

  @override
  void paint(Canvas canvas, Size size) {
    if (fraction <= 0) return;
    final paint = Paint()
      ..color = sweepColor
      ..style = PaintingStyle.fill;
    final center     = Offset(size.width / 2, size.height / 2);
    final radius     = math.max(size.width, size.height);
    final sweepAngle = fraction * 2 * math.pi;
    final path = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(Rect.fromCenter(center: center, width: radius * 2, height: radius * 2), -math.pi / 2, sweepAngle, false)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ClockSweepPainter old) => old.fraction != fraction || old.sweepColor != sweepColor;
}

// ─── Charge bar ───────────────────────────────────────────────────────────────

class _ChargeBar extends StatelessWidget {
  final double chargePercent;
  const _ChargeBar({required this.chargePercent});

  @override
  Widget build(BuildContext context) {
    final Color chargeColor;
    if (chargePercent < 0.5)       chargeColor = const Color(0xFF44FF44);
    else if (chargePercent < 0.75) chargeColor = const Color(0xFFFFFF00);
    else if (chargePercent < 0.9)  chargeColor = const Color(0xFFFF8800);
    else                           chargeColor = const Color(0xFFFF0000);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('CHARGE', style: TextStyle(color: Color(0xFFFFCC00), fontSize: 9, letterSpacing: 1, fontWeight: FontWeight.bold)),
            Text('${(chargePercent * 100).toInt()}%', style: TextStyle(color: chargeColor, fontSize: 9, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 2),
        Stack(
          children: [
            Container(height: 6, decoration: BoxDecoration(color: const Color(0xFF222222), borderRadius: BorderRadius.circular(2))),
            FractionallySizedBox(
              widthFactor: chargePercent,
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: chargeColor,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [BoxShadow(color: chargeColor.withValues(alpha: 0.6), blurRadius: 4)],
                ),
              ),
            ),
          ],
        ),
        if (chargePercent > 0.9)
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text('⚠ PASS OR CROSS PHASE LINE!', style: TextStyle(color: Color(0xFFFF3333), fontSize: 8, fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }
}
