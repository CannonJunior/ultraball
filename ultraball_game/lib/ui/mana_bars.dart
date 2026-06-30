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

    return Container(
      width: 220,
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
          // Player name
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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

          // Health bar
          _StatBar(
            label: 'HP',
            value: player.health,
            max: player.maxHealth,
            color: _healthColor(player.health / player.maxHealth),
          ),
          const SizedBox(height: 4),

          // Red mana
          _StatBar(
            label: 'RED',
            value: player.redMana,
            max: 100,
            color: const Color(0xFFFF3333),
          ),
          const SizedBox(height: 4),

          // Blue mana
          _StatBar(
            label: 'BLU',
            value: player.blueMana,
            max: 100,
            color: const Color(0xFF3388FF),
          ),

          const SizedBox(height: 8),

          // Abilities
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _AbilityIcon(
                keyLabel: '[1]',
                label: 'Tackle',
                cooldown: player.tackleCooldown,
                maxCooldown: 0.8,
                color: Colors.orange,
                available: player.tackleCooldown <= 0,
              ),
              _AbilityIcon(
                keyLabel: '[2]',
                label: 'Slam',
                cooldown: player.slamCooldown,
                maxCooldown: 3.0,
                color: const Color(0xFFFF4444),
                available: player.slamCooldown <= 0 && player.redMana >= 25,
              ),
              _AbilityIcon(
                keyLabel: '[3]',
                label: 'Sprint',
                cooldown: player.sprintCooldown,
                maxCooldown: 6.0,
                color: const Color(0xFF44CCFF),
                available: player.sprintCooldown <= 0 && player.blueMana >= 20,
              ),
              _AbilityIcon(
                keyLabel: '[F]',
                label: 'Pass',
                cooldown: player.passCooldown,
                maxCooldown: 4.0,
                color: const Color(0xFFFFCC00),
                available: player.passCooldown <= 0 && gs.ball.holderId == player.id,
              ),
            ],
          ),

          // Target frame
          if (gs.currentTarget != null) ...[
            const SizedBox(height: 8),
            _TargetFrame(target: gs.currentTarget!),
          ],

          const SizedBox(height: 6),

          const SizedBox(height: 4),

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

          if (gs.ball.holderId == player.id) ...[
            const SizedBox(height: 4),
            // Charge bar
            _ChargeBar(chargePercent: gs.ball.chargePercent),
          ],
        ],
      ),
    );
  }

  Color _healthColor(double frac) {
    if (frac > 0.5) return const Color(0xFF44FF44);
    if (frac > 0.25) return const Color(0xFFFFAA00);
    return const Color(0xFFFF2222);
  }
}

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
            '${value.toInt()}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 9,
              textBaseline: TextBaseline.alphabetic,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _AbilityIcon extends StatelessWidget {
  final String keyLabel;
  final String label;
  final double cooldown;
  final double maxCooldown;
  final Color color;
  final bool available;

  const _AbilityIcon({
    required this.keyLabel,
    required this.label,
    required this.cooldown,
    required this.maxCooldown,
    required this.color,
    required this.available,
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
          width: 36,
          height: 36,
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
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.black.withValues(alpha: 0.5 * cdFrac),
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: cdFrac,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
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
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 7,
          ),
        ),
      ],
    );
  }
}

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
        // First jump pip
        _jumpPip(
          active: airborne,
          color: const Color(0xFF88DDFF),
          label: '1',
        ),
        const SizedBox(width: 4),
        // Double jump pip
        _jumpPip(
          active: canDouble || usedDouble,
          color: usedDouble
              ? const Color(0xFF555555)
              : const Color(0xFF44AAFF),
          label: '2',
          mana: !airborne || canDouble ? null : '${UltraballPlayer.doubleJumpManaCost.toInt()}M',
        ),
        const SizedBox(width: 6),
        if (airborne)
          Text(
            usedDouble ? 'IN AIR' : canDouble ? 'SPACE to double-jump' : 'need ${UltraballPlayer.doubleJumpManaCost.toInt()} blue mana',
            style: TextStyle(
              color: canDouble
                  ? const Color(0xFF44AAFF)
                  : const Color(0xFF666666),
              fontSize: 8,
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }

  Widget _jumpPip(
      {required bool active, required Color color, required String label, String? mana}) {
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
                '#${target.rosterIndex + 1}',
                style: TextStyle(
                  color: const Color(0xFFFF4444).withValues(alpha: 0.6),
                  fontSize: 9,
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
