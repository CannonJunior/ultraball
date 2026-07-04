import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../game/game_state.dart';
import '../models/player.dart';

class ManaBars extends StatelessWidget {
  final GameState gs;

  const ManaBars({super.key, required this.gs});

  @override
  Widget build(BuildContext context) {
    final player = gs.selectedPlayer;
    if (player == null || !player.isAlive) {
      return const SizedBox.shrink();
    }

    final cls = player.playerClass;
    final names = cls.abilityNames;
    final maxCDs = cls.slotMaxCooldowns;

    return Container(
      width: 240,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Player name + class badge + roster index
          Row(
            children: [
              Text(
                player.name.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF88CCFF),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(width: 6),
              _ClassBadge(cls: cls),
              const Spacer(),
              Text(
                '#${player.rosterIndex + 1}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // HP / RED / BLU / ULT bars
          _StatBar(
            label: 'HP',
            value: player.health,
            max: player.maxHealth,
            color: _healthColor(player.health / player.maxHealth),
          ),
          const SizedBox(height: 4),
          _StatBar(
            label: 'RED',
            value: player.redMana,
            max: 100,
            color: const Color(0xFFFF3333),
          ),
          const SizedBox(height: 4),
          _StatBar(
            label: 'BLU',
            value: player.blueMana,
            max: 100,
            color: const Color(0xFF3388FF),
          ),
          const SizedBox(height: 4),
          _StatBar(
            label: 'ULT',
            value: player.ultraMana,
            max: UltraballPlayer.maxUltraMana,
            color: const Color(0xFFFFCC00),
          ),

          // Active buff indicators
          const SizedBox(height: 6),
          _BuffRow(player: player),

          const SizedBox(height: 6),

          // Ability row 1: slots 1–5
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _AbilityIcon(
                keyLabel: '[1]',
                label: _abbrev(names[0]),
                cooldown: player.tackleCooldown,
                maxCooldown: maxCDs[0],
                color: const Color(0xFFFF8844),
                available: player.tackleCooldown <= 0,
                size: 30,
              ),
              _AbilityIcon(
                keyLabel: '[2]',
                label: _abbrev(names[1]),
                cooldown: player.slamCooldown,
                maxCooldown: maxCDs[1],
                color: const Color(0xFFFF4444),
                available: player.slamCooldown <= 0,
                size: 30,
              ),
              _AbilityIcon(
                keyLabel: '[3]',
                label: _abbrev(names[2]),
                cooldown: player.sprintCooldown,
                maxCooldown: maxCDs[2],
                color: const Color(0xFF44CCFF),
                available: player.sprintCooldown <= 0,
                size: 30,
              ),
              _AbilityIcon(
                keyLabel: '[4]',
                label: _abbrev(names[3]),
                cooldown: player.ability4Cooldown,
                maxCooldown: maxCDs[3],
                color: const Color(0xFF4488FF),
                available: player.ability4Cooldown <= 0,
                size: 30,
              ),
              _AbilityIcon(
                keyLabel: '[5]',
                label: _abbrev(names[4]),
                cooldown: player.ability5Cooldown,
                maxCooldown: maxCDs[4],
                color: const Color(0xFFAA44FF),
                available: player.ability5Cooldown <= 0,
                size: 30,
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Ability row 2: slots 6–9
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _AbilityIcon(
                keyLabel: '[6]',
                label: _abbrev(names[5]),
                cooldown: player.ability6Cooldown,
                maxCooldown: maxCDs[5],
                color: const Color(0xFF44FF88),
                available: player.ability6Cooldown <= 0,
                size: 30,
              ),
              _AbilityIcon(
                keyLabel: '[7]',
                label: _abbrev(names[6]),
                cooldown: player.ability7Cooldown,
                maxCooldown: maxCDs[6],
                color: const Color(0xFF88DDFF),
                available: player.ability7Cooldown <= 0,
                size: 30,
              ),
              _AbilityIcon(
                keyLabel: '[8]',
                label: _abbrev(names[7]),
                cooldown: player.ability8Cooldown,
                maxCooldown: maxCDs[7],
                color: const Color(0xFFFFAA44),
                available: player.ability8Cooldown <= 0,
                size: 30,
              ),
              _AbilityIcon(
                keyLabel: '[9]',
                label: _abbrev(names[8]),
                cooldown: player.ability9Cooldown,
                maxCooldown: maxCDs[8],
                color: const Color(0xFFFF6688),
                available: player.ability9Cooldown <= 0,
                size: 30,
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Ability row 3: ultra (slot 10) + pass
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _AbilityIcon(
                keyLabel: '[0]',
                label: _abbrev(names[9]),
                cooldown: 0,
                maxCooldown: 0,
                color: const Color(0xFFFFCC00),
                available: player.ultraMana >= 5,
                size: 30,
              ),
              _AbilityIcon(
                keyLabel: '[F]',
                label: 'Pass',
                cooldown: player.passCooldown,
                maxCooldown: 4.0,
                color: const Color(0xFFFFDD44),
                available: player.passCooldown <= 0 && gs.ball.holderId == player.id,
                size: 30,
              ),
            ],
          ),

          // Target frame
          if (gs.currentTarget != null) ...[
            const SizedBox(height: 8),
            _TargetFrame(target: gs.currentTarget!),
          ],

          const SizedBox(height: 6),

          // Jump state indicator
          _JumpIndicator(player: player),

          const SizedBox(height: 4),

          // Combo counter
          Row(
            children: [
              const Text(
                'COMBO: ',
                style: TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 9,
                  letterSpacing: 1,
                ),
              ),
              ...List.generate(3, (i) {
                final filled = i < player.comboCount;
                return Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(right: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled
                        ? const Color(0xFFFFAA00)
                        : const Color(0xFF333333),
                    boxShadow: filled
                        ? [
                            BoxShadow(
                              color: const Color(0xFFFFAA00).withValues(alpha: 0.6),
                              blurRadius: 3,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
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
    );
  }

  static String _abbrev(String name) {
    if (name.length <= 8) return name;
    // Break at first space if possible
    final space = name.indexOf(' ');
    if (space > 0 && space <= 8) return name.substring(0, space);
    return '${name.substring(0, 7)}…';
  }

  Color _healthColor(double frac) {
    if (frac > 0.5) return const Color(0xFF44FF44);
    if (frac > 0.25) return const Color(0xFFFFAA00);
    return const Color(0xFFFF2222);
  }
}

// ─── Class badge ─────────────────────────────────────────────────────────────

class _ClassBadge extends StatelessWidget {
  final PlayerClass cls;
  const _ClassBadge({required this.cls});

  Color get _color => switch (cls) {
    PlayerClass.runner   => const Color(0xFF44FFCC),
    PlayerClass.geomancer => const Color(0xFFFF5544),
    PlayerClass.warden   => const Color(0xFF4488FF),
    PlayerClass.handler  => const Color(0xFFFFCC44),
    PlayerClass.blitzer  => const Color(0xFFFF44AA),
    PlayerClass.trickster => const Color(0xFFAA44FF),
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
        style: TextStyle(
          color: _color,
          fontSize: 7,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─── Active buff row ──────────────────────────────────────────────────────────

class _BuffRow extends StatelessWidget {
  final UltraballPlayer player;
  const _BuffRow({required this.player});

  @override
  Widget build(BuildContext context) {
    final buffs = <(String, Color)>[];
    if (player.speedMultiplierTimer > 0) buffs.add(('HASTE', const Color(0xFF44FFCC)));
    if (player.damageBoostTimer > 0) buffs.add(('+DMG', const Color(0xFFFF5544)));
    if (player.damageReductionTimer > 0) buffs.add(('SHIELD', const Color(0xFF4488FF)));
    if (player.stunImmune) buffs.add(('IMMUNE', const Color(0xFFFFCC00)));
    if (player.dodgeTimer > 0) buffs.add(('DODGE', const Color(0xFF00FFEE)));
    if (player.hotTimer > 0) buffs.add(('REGEN', const Color(0xFF44FF88)));
    if (player.attacksApplySnareTimer > 0) buffs.add(('APEX', const Color(0xFFFF44CC)));
    if (player.snareTimer > 0) buffs.add(('SNARE', const Color(0xFFAAAAFF)));
    if (player.markedTimer > 0) buffs.add(('MARKED', const Color(0xFFFF8800)));

    if (buffs.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          for (final (label, color) in buffs)
            Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: color.withValues(alpha: 0.7), width: 0.5),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 7,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Stat bar ─────────────────────────────────────────────────────────────────

class _StatBar extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final Color color;

  const _StatBar({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final frac = (value / max).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 28,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 9,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFF222222),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              FractionallySizedBox(
                widthFactor: frac,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 28,
          child: Text(
            max == UltraballPlayer.maxUltraMana
                ? '${value.toInt()}/${max.toInt()}'
                : '${value.toInt()}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 9,
            ),
            textAlign: TextAlign.right,
          ),
        ),
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
  final Color color;
  final bool available;
  final double size;

  const _AbilityIcon({
    required this.keyLabel,
    required this.label,
    required this.cooldown,
    required this.maxCooldown,
    required this.color,
    required this.available,
    this.size = 34,
  });

  @override
  Widget build(BuildContext context) {
    final cdFrac = maxCooldown > 0
        ? (cooldown / maxCooldown).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: available
                ? color.withValues(alpha: 0.2)
                : const Color(0xFF111111),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: available ? color : Colors.grey.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (cdFrac > 0)
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: cdFrac,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(4),
                            bottomRight: Radius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Text(
                keyLabel,
                style: TextStyle(
                  color: available ? color : Colors.grey,
                  fontSize: 7,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: size + 4,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 6.5,
            ),
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
    final airborne = player.isAirborne;
    final canDouble = airborne && !player.hasDoubleJumped &&
        player.blueMana >= UltraballPlayer.doubleJumpManaCost;
    final usedDouble = airborne && player.hasDoubleJumped;

    return Row(
      children: [
        const SizedBox(
          width: 28,
          child: Text(
            'JUMP',
            style: TextStyle(
              color: Color(0xFF888888),
              fontSize: 9,
              letterSpacing: 0.5,
            ),
          ),
        ),
        _jumpPip(active: airborne, color: const Color(0xFF88DDFF), label: '1'),
        const SizedBox(width: 4),
        _jumpPip(
          active: canDouble || usedDouble,
          color: usedDouble ? const Color(0xFF555555) : const Color(0xFF44AAFF),
          label: '2',
        ),
        const SizedBox(width: 6),
        if (airborne)
          Text(
            usedDouble
                ? 'IN AIR'
                : canDouble
                    ? 'SPACE to double-jump'
                    : 'need ${UltraballPlayer.doubleJumpManaCost.toInt()} blue',
            style: TextStyle(
              color: canDouble ? const Color(0xFF44AAFF) : const Color(0xFF666666),
              fontSize: 8,
              fontStyle: FontStyle.italic,
            ),
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
        border: Border.all(
          color: active ? color : const Color(0xFF333333),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: active ? color : const Color(0xFF444444),
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// ─── Target frame ─────────────────────────────────────────────────────────────

class _TargetFrame extends StatelessWidget {
  final UltraballPlayer target;
  const _TargetFrame({required this.target});

  @override
  Widget build(BuildContext context) {
    final hpFrac = (target.health / target.maxHealth).clamp(0.0, 1.0);
    final hpColor = hpFrac > 0.5
        ? const Color(0xFFFF4444)
        : hpFrac > 0.25
            ? const Color(0xFFFF8800)
            : const Color(0xFFFF2222);

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF330000).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFFF3333).withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '▶ ${target.name.toUpperCase()}',
                style: const TextStyle(
                  color: Color(0xFFFF6666),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              Text(
                target.playerClass.displayName,
                style: TextStyle(
                  color: const Color(0xFFFF4444).withValues(alpha: 0.7),
                  fontSize: 8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Stack(
            children: [
              Container(
                height: 7,
                decoration: BoxDecoration(
                  color: const Color(0xFF222222),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              FractionallySizedBox(
                widthFactor: hpFrac,
                child: Container(
                  height: 7,
                  decoration: BoxDecoration(
                    color: hpColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${target.health.toInt()} / ${target.maxHealth.toInt()}  HP',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Charge bar ───────────────────────────────────────────────────────────────

class _ChargeBar extends StatelessWidget {
  final double chargePercent;
  const _ChargeBar({required this.chargePercent});

  @override
  Widget build(BuildContext context) {
    Color chargeColor;
    if (chargePercent < 0.5) {
      chargeColor = const Color(0xFF44FF44);
    } else if (chargePercent < 0.75) {
      chargeColor = const Color(0xFFFFFF00);
    } else if (chargePercent < 0.9) {
      chargeColor = const Color(0xFFFF8800);
    } else {
      chargeColor = const Color(0xFFFF0000);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'CHARGE',
              style: TextStyle(
                color: Color(0xFFFFCC00),
                fontSize: 9,
                letterSpacing: 1,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${(chargePercent * 100).toInt()}%',
              style: TextStyle(
                color: chargeColor,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Stack(
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: const Color(0xFF222222),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            FractionallySizedBox(
              widthFactor: chargePercent,
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: chargeColor,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: chargeColor.withValues(alpha: 0.6),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (chargePercent > 0.9)
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text(
              '⚠ PASS OR CROSS PHASE LINE!',
              style: TextStyle(
                color: Color(0xFFFF3333),
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}
