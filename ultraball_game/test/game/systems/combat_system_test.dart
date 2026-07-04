import 'package:flutter_test/flutter_test.dart';
import 'package:ultraball_game/game/systems/combat_system.dart';
import 'package:ultraball_game/models/player.dart';
import '../../helpers/game_state_factory.dart';

void main() {
  // ── applyDamage — core formula ───────────────────────────────────────────

  group('CombatSystem.applyDamage — base formula', () {
    test('reduces victim health by the raw damage amount (no modifiers)', () {
      final gs = makeGs();
      final attacker = gs.playerRoster.first;
      final victim   = gs.opponentRoster.first;

      CombatSystem.applyDamage(gs, victim, 30.0, attacker);

      expect(victim.health, closeTo(victim.maxHealth - 30.0, 0.001));
    });

    test('damageReductionFactor halves incoming damage', () {
      final gs = makeGs();
      final attacker = gs.playerRoster.first;
      final victim   = gs.opponentRoster.first;
      victim.damageReductionFactor = 0.5;

      CombatSystem.applyDamage(gs, victim, 30.0, attacker);

      expect(victim.health, closeTo(victim.maxHealth - 15.0, 0.001));
    });

    test('damageBoostFactor amplifies outgoing damage', () {
      final gs = makeGs();
      final attacker = gs.playerRoster.first;
      final victim   = gs.opponentRoster.first;
      attacker.damageBoostFactor = 1.5;

      CombatSystem.applyDamage(gs, victim, 20.0, attacker);

      expect(victim.health, closeTo(victim.maxHealth - 30.0, 0.001));
    });

    test('mark debuff adds 25% to incoming damage', () {
      final gs = makeGs();
      final attacker = gs.playerRoster.first;
      final victim   = gs.opponentRoster.first;
      victim.markedTimer = 5.0; // actively marked

      CombatSystem.applyDamage(gs, victim, 20.0, attacker);

      expect(victim.health, closeTo(victim.maxHealth - 25.0, 0.001));
    });

    test('grants 5 red mana to attacker per hit', () {
      final gs = makeGs();
      final attacker = gs.playerRoster.first;
      final victim   = gs.opponentRoster.first;
      attacker.redMana = 0;

      CombatSystem.applyDamage(gs, victim, 10.0, attacker);

      expect(attacker.redMana, closeTo(5.0, 0.001));
    });
  });

  // ── applyDamage — dodge frames ───────────────────────────────────────────

  group('CombatSystem.applyDamage — dodge frames', () {
    test('active dodge absorbs all damage', () {
      final gs = makeGs();
      final attacker = gs.playerRoster.first;
      final victim   = gs.opponentRoster.first;
      victim.dodgeTimer = 1.0;
      final startHealth = victim.health;

      CombatSystem.applyDamage(gs, victim, 50.0, attacker);

      expect(victim.health, equals(startHealth),
          reason: 'dodge frames must negate all damage');
    });
  });

  // ── applyDamage — death path ─────────────────────────────────────────────

  group('CombatSystem.applyDamage — death', () {
    test('victim is killed when health drops to zero', () {
      final gs = makeGs();
      final attacker = gs.playerRoster.first;
      final victim   = gs.opponentRoster.first;
      victim.health = 10.0;

      CombatSystem.applyDamage(gs, victim, 10.0, attacker);

      expect(victim.isAlive, isFalse);
    });

    test('ball drops when holder dies', () {
      final gs = makeGs();
      final attacker = gs.playerRoster.first;
      final holder   = gs.opponentRoster.first;
      holder.health  = 1.0;
      gs.ball.holderId = holder.id;

      CombatSystem.applyDamage(gs, holder, 10.0, attacker);

      expect(gs.ball.holderId, isNull,
          reason: 'ball must drop when the holder is killed');
    });

    test('killa point is awarded to attacker team on kill', () {
      final gs = makeGs();
      final attacker = gs.playerRoster.first;
      final victim   = gs.opponentRoster.first;
      victim.health  = 1.0;
      gs.actState.isActive = true;

      CombatSystem.applyDamage(gs, victim, 10.0, attacker);

      expect(gs.actState.playerScore, equals(1),
          reason: 'killing an opponent should award 1 Killa point to the player team');
    });
  });

  // ── checkCombo ───────────────────────────────────────────────────────────

  group('CombatSystem.checkCombo', () {
    test('increments comboCount when below threshold', () {
      final gs = makeGs();
      final p  = gs.playerRoster.first;
      p.comboCount = 1;

      CombatSystem.checkCombo(gs, p);

      expect(p.comboCount, equals(2));
    });

    test('awards 30 red mana and resets counter at 3 hits', () {
      final gs = makeGs();
      final p  = gs.playerRoster.first;
      p.comboCount = 2;
      p.redMana    = 0;

      CombatSystem.checkCombo(gs, p);

      expect(p.comboCount, equals(0),
          reason: 'combo counter must reset after the third hit');
      expect(p.redMana, closeTo(30.0, 0.001),
          reason: '30 red mana is awarded on a 3-hit combo');
    });
  });

  // ── ability gating ───────────────────────────────────────────────────────

  group('CombatSystem.useClassAbility — ability gating', () {
    test('Quick Strike (slot 1) is blocked when tackleCooldown > 0', () {
      final gs = makeGs();
      final p  = gs.playerRoster.first;
      p.playerClass = PlayerClass.runner;
      final enemy = gs.opponentRoster.first;
      // Position enemy in range
      enemy.x = p.x + 2.0;
      enemy.y = p.y;
      final startHealth = enemy.health;

      p.tackleCooldown = 0.5; // on cooldown

      CombatSystem.useClassAbility(gs, p, 1);

      expect(enemy.health, equals(startHealth),
          reason: 'Quick Strike must not fire while tackleCooldown > 0');
    });

    test('Slide Tackle (slot 2) is blocked when redMana < 20', () {
      final gs = makeGs();
      final p  = gs.playerRoster.first;
      p.playerClass = PlayerClass.runner;
      p.redMana = 10; // insufficient (needs 20)

      CombatSystem.useClassAbility(gs, p, 2);

      // redMana should be unchanged if the ability was gated
      expect(p.redMana, equals(10.0),
          reason: 'Slide Tackle must not deduct mana when gated by insufficient red mana');
    });
  });
}
