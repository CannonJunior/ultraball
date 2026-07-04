enum PlayerClass { runner, enforcer, warden, handler, blitzer }

extension PlayerClassInfo on PlayerClass {
  String get displayName => switch (this) {
    PlayerClass.runner   => 'SPECTRE',
    PlayerClass.enforcer => 'JUGGERNAUT',
    PlayerClass.warden   => 'ARCHON',
    PlayerClass.handler  => 'WARDEN',
    PlayerClass.blitzer  => 'CORSAIR',
  };

  String get description => switch (this) {
    PlayerClass.runner   => 'Speed · Evasion · Ball Carrier',
    PlayerClass.enforcer => 'Power · Destruction · Crowd Control',
    PlayerClass.warden   => 'Defense · Healing · Team Fortress',
    PlayerClass.handler  => 'Support · Field Control · Restoration',
    PlayerClass.blitzer  => 'Disruption · Predation · Strip & Mark',
  };

  double get baseSpeed => switch (this) {
    PlayerClass.runner   => 10.0,
    PlayerClass.enforcer =>  6.5,
    PlayerClass.warden   =>  7.5,
    PlayerClass.handler  =>  8.0,
    PlayerClass.blitzer  =>  8.5,
  };

  double get maxHealth => switch (this) {
    PlayerClass.runner   =>  75.0,
    PlayerClass.enforcer => 145.0,
    PlayerClass.warden   => 120.0,
    PlayerClass.handler  =>  95.0,
    PlayerClass.blitzer  => 105.0,
  };

  // 9 regular abilities + 1 ultra = 10 slots (indices 0–9, slots 1–10)
  // Naming voice per class:
  //   VECTOR   — electricity & physics: fast, sharp, minimal
  //   RAVAGER  — geological & industrial: inevitable, crushing
  //   BASTION  — sacred & architectural: absolute, immovable
  //   MAESTRO  — strategy & orchestration: cold, deliberate, precise
  //   VIPER    — predatory & anatomical: stalking, surgical, final
  List<String> get abilityNames => switch (this) {
    PlayerClass.runner   => [
      'Volt', 'Trip Line', 'Overdrive',
      'Phase', 'Ghost', 'Lights Out',
      'Surge', 'Cutback', 'Slipstream',
      'ULTRAVIOLET',
    ],
    PlayerClass.enforcer => [
      'Hammer', 'Shatter', 'Warpath',
      'Brain Rattle', 'Quake', 'Dead Ahead',
      'Iron Hide', 'Berserk', 'Torpedo',
      'RAMPAGE',
    ],
    PlayerClass.warden   => [
      'Stonefist', 'Fault Line', 'March',
      'Fortress', 'Field Stitch', 'Absolution',
      'Tenacity', 'Aegis', 'Salvation',
      'CITADEL',
    ],
    PlayerClass.handler  => [
      'One-Two', 'Ankle Lock', 'Tempo Shift',
      'Quick Fix', 'Jump Start', 'Suppress',
      'Lifeline', 'Resupply', 'Blindside',
      'SYMPHONY',
    ],
    PlayerClass.blitzer  => [
      'Fang', 'Strip', 'Death Sprint',
      'Pounce', 'Bloodscent', 'Whiplash',
      'Condemn', 'Rout', 'Feed the Beast',
      'APEX',
    ],
  };

  // One-line description per ability slot (indices 0–9).
  List<String> get abilityDescriptions => switch (this) {
    PlayerClass.runner   => [
      '12 dmg · 2.5m · basic attack',
      '18 dmg · 1.5s snare (50% slow) · 20 Red Mana',
      '1.5× speed for 3s · 15 Blue Mana',
      'Dash 6m forward · 20 Blue Mana',
      '1.5s full invulnerability (blocks all dmg & CC) · 25 Blue Mana',
      '15 dmg · 2.0s stun · 2.5m · 30 Red Mana',
      '+25 HP · removes all CC from self · 40 Blue Mana',
      'Dash 4m back · 3m AoE 2s snare (40% slow) · 25 Red Mana',
      '+20% speed · stun immunity for 3s · 20 Blue Mana',
      '2.5× speed · stun immunity · 7s · 5 Ultra Mana',
    ],
    PlayerClass.enforcer => [
      '22 dmg · 2.5m · basic attack',
      '40 dmg · 6m knockback · 3.5m · 25 Red Mana',
      '1.5× speed for 3s · 20 Blue Mana',
      '20 dmg · 2.0s stun · 2.5m · 25 Red Mana',
      '20 dmg/target · 4m AoE · 1.5s snare (40% slow) · 35 Red Mana',
      'Dash 7m forward · 1.0s stun to first enemy hit · 20 Red Mana',
      '+40 HP instant · 40 Blue Mana',
      '+30% dmg for 5s · gain 25 Red Mana · costs 20 Blue Mana',
      'Dash 5m · 3m knockback to all enemies along path · 30 Red Mana',
      '+50% dmg · 30% dmg reduction · stun immunity · 8s · 5 Ultra Mana',
    ],
    PlayerClass.warden   => [
      '15 dmg · 2m push · 2.5m · basic attack',
      '30 dmg · 1.0s stun · 3m · 25 Red Mana',
      '1.5× speed for 3s · 20 Blue Mana',
      '50% dmg reduction for 3s · self only · 25 Blue Mana',
      '+35 HP to nearest ally · 5m range · 30 Blue Mana',
      'Removes all CC from nearest ally · 5m range · 20 Blue Mana',
      '+35 HP · restore 20 Blue Mana · self only · 35 Blue Mana',
      '30% dmg reduction for 4s to nearest ally · 5m range · 30 Blue Mana',
      '+25 HP + snare cleanse to all allies · 7m AoE · 50 Blue Mana',
      '10m AoE: 50% dmg reduction + stun immunity + 8 HP/s · 6s · 5 Ultra Mana',
    ],
    PlayerClass.handler  => [
      '10 dmg · 2.5m · basic attack',
      '15 dmg · 2.0s snare (40% slow) · 3m · 20 Red Mana',
      '1.5× speed for 3s · 15 Blue Mana',
      '+30 HP to nearest ally · 5m range · 30 Blue Mana',
      '+35 Blue Mana to nearest ally · 5m range · 25 Blue Mana',
      '20 dmg · 1.0s stun + 2.0s snare (50% slow) · 30 Red Mana',
      '+60 HP + full CC cleanse to nearest ally · 5m range · 45 Blue Mana',
      '+20 Blue Mana to all teammates · 8m AoE · 40 Blue Mana',
      'Dash 5m · 1.5s stun to first enemy hit · 25 Red Mana',
      'All teammates: +35 HP + 40 Blue Mana + full CC cleanse · 5 Ultra Mana',
    ],
    PlayerClass.blitzer  => [
      '18 dmg · 2.5m · basic attack',
      '25 dmg · 1.5s stun · forces fumble if target holds ball · 3m · 25 Red Mana',
      '1.5× speed for 3s · 15 Blue Mana',
      'Dash 5m · 2.0s snare (50% slow) to first enemy hit · 20 Red Mana',
      '+20% dmg for 4s · self only · 20 Blue Mana',
      '20 dmg · 4m knockback + 1.5s snare (50% slow) · 30 Red Mana',
      'Mark target: +25% dmg taken for 5s · 20m range · 20 Blue Mana',
      'Push all enemies 3m away · 4m AoE · 25 Blue Mana',
      'Push target 4m toward creature + mark for 5s · 3.5m · 25 Red Mana',
      '2× speed + 35% dmg + stun immunity + attacks snare (2s) · 7s · 5 Ultra Mana',
    ],
  };

  // Max cooldowns for slots 1–10 (indices 0–9).
  // Ultra slot (index 9) has no cooldown — gated by ultra mana only.
  List<double> get slotMaxCooldowns => switch (this) {
    PlayerClass.runner   => [ 0.5,  3.0,  5.0,  7.0,  8.0, 10.0, 15.0, 12.0, 12.0, 0.0],
    PlayerClass.enforcer => [ 1.0,  3.0,  6.0,  8.0,  8.0, 10.0, 15.0, 12.0, 12.0, 0.0],
    PlayerClass.warden   => [ 0.8,  3.0,  6.0, 10.0, 10.0, 12.0, 18.0, 14.0, 20.0, 0.0],
    PlayerClass.handler  => [ 0.6,  3.0,  5.0, 10.0, 12.0, 10.0, 18.0, 18.0, 12.0, 0.0],
    PlayerClass.blitzer  => [ 0.7,  3.0,  5.0,  8.0,  8.0, 10.0, 12.0, 10.0, 14.0, 0.0],
  };
}
