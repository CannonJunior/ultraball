import 'package:flutter_test/flutter_test.dart';
import 'package:ultraball_game/game/systems/combat_system.dart';
import 'package:ultraball_game/models/player.dart';
import 'package:ultraball_game/game/game_state.dart';
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
      p.playerClass = PlayerClass.spectre;
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
      p.playerClass = PlayerClass.spectre;
      p.redMana = 10; // insufficient (needs 20)

      CombatSystem.useClassAbility(gs, p, 2);

      // redMana should be unchanged if the ability was gated
      expect(p.redMana, equals(10.0),
          reason: 'Slide Tackle must not deduct mana when gated by insufficient red mana');
    });
  });

  // ── Wrecker abilities ─────────────────────────────────────────────────────

  group('Wrecker abilities', () {
    GameState makeWreckerGs() {
      final wrecker = makePlayer(id: 'w1', team: Team.player, x: 70.0, y: 20.0,
          playerClass: PlayerClass.wrecker);
      wrecker.maxHealth = PlayerClass.wrecker.maxHealth;
      wrecker.health    = PlayerClass.wrecker.maxHealth;
      final enemy = makePlayer(id: 'e1', team: Team.opponent, x: 72.0, y: 20.0);
      enemy.maxHealth = PlayerClass.spectre.maxHealth;
      enemy.health    = PlayerClass.spectre.maxHealth;
      return makeGs(
        players:   [wrecker],
        opponents: [enemy],
      );
    }

    test('Iron Fist (slot 1): deals 20 damage, sets tackleCooldown, increments totalDamageDealt', () {
      final gs = makeWreckerGs();
      final p  = gs.playerRoster.first;
      final e  = gs.opponentRoster.first;
      p.redMana = 0;

      CombatSystem.useClassAbility(gs, p, 1);

      expect(e.health, lessThan(e.maxHealth), reason: 'Iron Fist should deal damage');
      expect(p.tackleCooldown, greaterThan(0), reason: 'tackleCooldown should be set');
      expect(p.totalDamageDealt, greaterThan(0), reason: 'totalDamageDealt should increment');
    });

    test('Sledge (slot 2): fails when red mana < 20', () {
      final gs = makeWreckerGs();
      final p  = gs.playerRoster.first;
      final e  = gs.opponentRoster.first;
      p.redMana = 10;
      final startHealth = e.health;

      CombatSystem.useClassAbility(gs, p, 2);

      expect(e.health, equals(startHealth), reason: 'Sledge must not fire without 20 red mana');
      expect(p.slamCooldown, equals(0.0), reason: 'slamCooldown must not be set if gated');
    });

    test('Sledge (slot 2): deals damage, applies stun, sets slamCooldown', () {
      final gs = makeWreckerGs();
      final p  = gs.playerRoster.first;
      final e  = gs.opponentRoster.first;
      p.redMana = 50;

      CombatSystem.useClassAbility(gs, p, 2);

      expect(e.health, lessThan(e.maxHealth), reason: 'Sledge should deal damage');
      expect(e.isStunned, isTrue, reason: 'Sledge should apply stun');
      expect(p.slamCooldown, greaterThan(0), reason: 'slamCooldown should be set');
    });

    test('Shockwave (slot 5): AoE damages enemies in 4m, spends 15 red, sets 1.5s CD', () {
      final wrecker = makePlayer(id: 'w1', team: Team.player, x: 70.0, y: 20.0,
          playerClass: PlayerClass.wrecker);
      wrecker.maxHealth = PlayerClass.wrecker.maxHealth;
      wrecker.health    = PlayerClass.wrecker.maxHealth;
      final e1 = makePlayer(id: 'e1', team: Team.opponent, x: 73.0, y: 20.0);
      e1.maxHealth = 100; e1.health = 100;
      final e2 = makePlayer(id: 'e2', team: Team.opponent, x: 70.0, y: 23.0);
      e2.maxHealth = 100; e2.health = 100;
      final gs = makeGs(players: [wrecker], opponents: [e1, e2]);
      final p = gs.playerRoster.first;
      p.redMana = 50;
      final startRed = p.redMana;

      CombatSystem.useClassAbility(gs, p, 5);

      expect(e1.health, lessThan(100), reason: 'e1 in 4m range should take damage');
      expect(e2.health, lessThan(100), reason: 'e2 in 4m range should take damage');
      // applyDamage grants attacker +5 red per hit; 2 hits = +10 → net spend = 5
      expect(p.redMana, closeTo(startRed - 5, 0.001), reason: 'Net red cost: 15 spent − 10 gained (2 hits × 5)');
      expect(p.ability5Cooldown, closeTo(1.5, 0.001), reason: 'ability5Cooldown should be 1.5s');
    });

    test('Ground Pound (slot 8): AoE stuns enemies in 3m, spends 30 red, sets 20s CD', () {
      final wrecker = makePlayer(id: 'w1', team: Team.player, x: 70.0, y: 20.0,
          playerClass: PlayerClass.wrecker);
      wrecker.maxHealth = PlayerClass.wrecker.maxHealth;
      wrecker.health    = PlayerClass.wrecker.maxHealth;
      final enemy = makePlayer(id: 'e1', team: Team.opponent, x: 72.0, y: 20.0);
      enemy.maxHealth = 200; enemy.health = 200;
      final gs = makeGs(players: [wrecker], opponents: [enemy]);
      final p = gs.playerRoster.first;
      p.redMana = 60;
      final startRed = p.redMana;

      CombatSystem.useClassAbility(gs, p, 8);

      expect(enemy.isStunned, isTrue, reason: 'Ground Pound should stun enemies in 3m');
      expect(enemy.stunTimer, closeTo(1.5, 0.001), reason: 'Stun duration should be 1.5s');
      // applyDamage grants attacker +5 red per hit; 1 hit = +5 → net spend = 25
      expect(p.redMana, closeTo(startRed - 25, 0.001), reason: 'Net red cost: 30 spent − 5 gained (1 hit × 5)');
      expect(p.ability8Cooldown, closeTo(20.0, 0.001), reason: 'ability8Cooldown should be 20s');
    });

    test('Death Blow (slot 9): 55 damage + 3s stun, fails when red < 35', () {
      final gs = makeWreckerGs();
      final p  = gs.playerRoster.first;
      final e  = gs.opponentRoster.first;
      e.maxHealth = 300; e.health = 300;
      p.redMana = 20;

      CombatSystem.useClassAbility(gs, p, 9);
      expect(e.health, equals(300), reason: 'Death Blow should not fire with < 35 red');

      p.redMana = 50;
      CombatSystem.useClassAbility(gs, p, 9);
      expect(e.health, lessThan(300), reason: 'Death Blow should deal damage with 35+ red');
      expect(e.isStunned, isTrue, reason: 'Death Blow should stun');
      expect(e.stunTimer, closeTo(3.0, 0.001), reason: 'Stun should be 3s');
    });

    test('DEMOLISH ultra (slot 10): AoE damage + dmg boost, fails when ultra < 5', () {
      final gs = makeWreckerGs();
      final p  = gs.playerRoster.first;
      final e  = gs.opponentRoster.first;
      e.maxHealth = 300; e.health = 300;
      p.ultraMana = 3.0;

      CombatSystem.useClassAbility(gs, p, 10);
      expect(e.health, equals(300), reason: 'DEMOLISH should not fire with < 5 ultra');

      p.ultraMana = 5.0;
      CombatSystem.useClassAbility(gs, p, 10);
      expect(e.health, lessThan(300), reason: 'DEMOLISH should deal AoE damage');
      expect(p.damageBoostFactor, greaterThan(1.0), reason: 'DEMOLISH should give damage boost');
    });
  });

  // ── Stat tracking ─────────────────────────────────────────────────────────

  group('Stat tracking', () {
    test('totalDamageDealt increments by the final damage on attacker', () {
      final gs = makeGs();
      final attacker = gs.playerRoster.first;
      final victim   = gs.opponentRoster.first;
      attacker.totalDamageDealt = 0;

      CombatSystem.applyDamage(gs, victim, 30.0, attacker);

      expect(attacker.totalDamageDealt, closeTo(30.0, 0.001));
    });

    test('totalDamageDealt does NOT increment on victim', () {
      final gs = makeGs();
      final attacker = gs.playerRoster.first;
      final victim   = gs.opponentRoster.first;
      victim.totalDamageDealt = 0;

      CombatSystem.applyDamage(gs, victim, 30.0, attacker);

      expect(victim.totalDamageDealt, equals(0.0));
    });

    test('killsThisMatch equals 1 after a kill', () {
      final gs = makeGs();
      final attacker = gs.playerRoster.first;
      final victim   = gs.opponentRoster.first;
      victim.health  = 1.0;
      attacker.killsThisMatch = 0;

      CombatSystem.applyDamage(gs, victim, 10.0, attacker);

      expect(attacker.killsThisMatch, equals(1));
    });

    test('Archon Mend (slot 5): caster.totalHealingDone equals actual healed, overheal not tracked', () {
      final archon = makePlayer(id: 'a1', team: Team.player, x: 70.0, y: 20.0,
          playerClass: PlayerClass.archon);
      archon.maxHealth = PlayerClass.archon.maxHealth;
      archon.health    = PlayerClass.archon.maxHealth;
      final ally = makePlayer(id: 'p2', team: Team.player, x: 72.0, y: 20.0,
          playerClass: PlayerClass.spectre);
      ally.maxHealth = 100; ally.health = 60; // 40 HP missing
      final gs = makeGs(players: [archon, ally], opponents: [
        makePlayer(id: 'o1', team: Team.opponent, x: 50.0, y: 20.0),
      ]);
      archon.blueMana = 100;
      archon.ability5Cooldown = 0;
      archon.totalHealingDone = 0;

      CombatSystem.useClassAbility(gs, archon, 5);

      // ally had 40 missing; Mend heals 35, so actual heal = 35
      expect(archon.totalHealingDone, closeTo(35.0, 0.001),
          reason: 'caster should be credited for the healed amount');
      expect(ally.health, closeTo(95.0, 0.001), reason: 'ally health should increase by 35');
    });

    test('passive regen does NOT increment totalHealingDone', () {
      final gs = makeGs();
      final p  = gs.playerRoster.first;
      p.health = p.maxHealth - 20; // partial HP
      p.hotTimer = 0; // no HoT
      p.totalHealingDone = 0;

      p.update(0.1);

      expect(p.totalHealingDone, equals(0.0),
          reason: 'passive regen should not count as healing done');
    });
  });

  // ── HoT healing attribution ───────────────────────────────────────────────

  group('HoT healing', () {
    test('applyHoT credits totalHealingDone to the caster via callback', () {
      final gs = makeGs();
      final caster = gs.playerRoster.first;
      final target = gs.playerRoster[1];
      target.health = target.maxHealth - 30; // needs healing
      caster.totalHealingDone = 0;

      target.applyHoT(2.0, 10.0, casterCredit: (amt) => caster.totalHealingDone += amt);
      target.update(0.5); // tick: 5 HP healed

      expect(caster.totalHealingDone, greaterThan(0),
          reason: 'caster should be credited for HoT healing');
      expect(target.totalHealingDone, equals(0.0),
          reason: 'recipient should NOT be credited for HoT healing');
    });

    test('passive regen does NOT increment totalHealingDone (HoT variant)', () {
      final gs = makeGs();
      final p  = gs.playerRoster.first;
      p.health = p.maxHealth - 10;
      p.hotTimer = 0;
      p.totalHealingDone = 0;

      p.update(0.1);

      expect(p.totalHealingDone, equals(0.0));
    });
  });
}
