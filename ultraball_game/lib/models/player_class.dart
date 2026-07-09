enum PlayerClass { spectre, geomancer, archon, warden, corsair, trickster, wrecker }

extension PlayerClassInfo on PlayerClass {
  String get displayName => switch (this) {
    PlayerClass.spectre    => 'SPECTRE',
    PlayerClass.geomancer => 'GEOMANCER',
    PlayerClass.archon    => 'ARCHON',
    PlayerClass.warden   => 'WARDEN',
    PlayerClass.corsair  => 'CORSAIR',
    PlayerClass.trickster => 'TRICKSTER',
    PlayerClass.wrecker  => 'WRECKER',
  };

  String get description => switch (this) {
    PlayerClass.spectre    => 'Speed · Evasion · Ball Carrier',
    PlayerClass.geomancer => 'Terrain · Disruption · Geological Control',
    PlayerClass.archon   => 'Defense · Healing · Team Fortress',
    PlayerClass.warden   => 'Support · Field Control · Restoration',
    PlayerClass.corsair  => 'Disruption · Predation · Strip & Mark',
    PlayerClass.trickster => 'Confusion · Traps · Creature Manipulation',
    PlayerClass.wrecker  => 'Brutality · Close Combat · Maximum Damage',
  };

  double get baseSpeed => switch (this) {
    PlayerClass.spectre    => 10.0,
    PlayerClass.geomancer =>  7.0,
    PlayerClass.archon   =>  7.5,
    PlayerClass.warden   =>  8.0,
    PlayerClass.corsair  =>  8.5,
    PlayerClass.trickster =>  9.0,
    PlayerClass.wrecker  =>  8.0,
  };

  double get maxHealth => switch (this) {
    PlayerClass.spectre    =>  75.0,
    PlayerClass.geomancer => 115.0,
    PlayerClass.archon   => 120.0,
    PlayerClass.warden   =>  95.0,
    PlayerClass.corsair  => 105.0,
    PlayerClass.trickster =>  85.0,
    PlayerClass.wrecker  => 110.0,
  };

  // 9 regular abilities + 1 ultra = 10 slots (indices 0–9, slots 1–10)
  // Naming voice per class:
  //   VECTOR   — electricity & physics: fast, sharp, minimal
  //   RAVAGER  — geological & industrial: inevitable, crushing
  //   BASTION  — sacred & architectural: absolute, immovable
  //   MAESTRO  — strategy & orchestration: cold, deliberate, precise
  //   VIPER    — predatory & anatomical: stalking, surgical, final
  List<String> get abilityNames => switch (this) {
    PlayerClass.spectre   => [
      'Volt', 'Trip Line', 'Overdrive',
      'Phase', 'Ghost', 'Lights Out',
      'Surge', 'Cutback', 'Slipstream',
      'ULTRAVIOLET',
    ],
    PlayerClass.geomancer => [
      'Earth Fist', 'Raise Hill', 'Seismic Shove',
      'Open Sinkhole', 'Tremor', 'Stone Armor',
      'Earthmend', 'Upheaval', 'Fissure',
      'TERRA NOVA',
    ],
    PlayerClass.archon   => [
      'Stonefist', 'Fault Line', 'March',
      'Fortress', 'Field Stitch', 'Absolution',
      'Tenacity', 'Aegis', 'Salvation',
      'CITADEL',
    ],
    PlayerClass.warden  => [
      'One-Two', 'Ankle Lock', 'Tempo Shift',
      'Quick Fix', 'Jump Start', 'Suppress',
      'Lifeline', 'Resupply', 'Blindside',
      'SYMPHONY',
    ],
    PlayerClass.corsair  => [
      'Fang', 'Strip', 'Death Sprint',
      'Pounce', 'Bloodscent', 'Whiplash',
      'Condemn', 'Rout', 'Feed the Beast',
      'APEX',
    ],
    PlayerClass.trickster => [
      'Hex Strike', 'Phantom Step', 'Fox Sprint',
      'Befuddle', 'Creature Goad', 'Position Swap',
      'Jinx', 'Hex Nova', 'Chaos Fumble',
      'PANDEMONIUM',
    ],
    PlayerClass.wrecker  => [
      'Iron Fist', 'Sledge', 'Bull Rush',
      'Crumple', 'Shockwave', 'Spine Breaker',
      'Wrecking Ball', 'Ground Pound', 'Death Blow',
      'DEMOLISH',
    ],
  };

  // Effect-only descriptions (no mana/range/CD — those are in separate getters).
  List<String> get abilityDescriptions => switch (this) {
    PlayerClass.spectre   => [
      '12 dmg',
      '18 dmg · 1.5s snare (50% slow)',
      '1.5× speed for 3s',
      'Dash 6m forward',
      '1.5s full invulnerability',
      '15 dmg · 2s stun',
      '+25 HP · cleanse all CC',
      'Dash 4m back · 2s snare (40% slow)',
      '+20% speed · stun immunity 3s',
      '2.5× speed · stun immunity · 7s',
    ],
    PlayerClass.geomancer => [
      '18 dmg',
      'Raise 4m-high hill at targeted spot',
      '12 dmg · push 4m',
      'Open instant-death sinkhole at targeted spot',
      '15 dmg/target · 1.5s snare (40% slow)',
      '40% dmg reduction for 4s',
      '+35 HP',
      '+20% speed 4s · gain 30 Red Mana',
      'Dash 5m · fissure along path (2s pit strip)',
      'Raise hills across 30m · open pits under all enemies',
    ],
    PlayerClass.archon   => [
      '15 dmg · 2m push',
      '30 dmg · 1s stun',
      '1.5× speed for 3s',
      '50% dmg reduction 3s',
      '+35 HP to nearest ally',
      'Cleanse all CC from nearest ally',
      '+35 HP · restore 20 Blue Mana',
      '30% dmg reduction 4s to nearest ally',
      '+25 HP · snare cleanse to all allies',
      '50% dmg reduction · stun immunity · +8 HP/s · 6s',
    ],
    PlayerClass.warden  => [
      '10 dmg',
      '15 dmg · 2s snare (40% slow)',
      '1.5× speed for 3s',
      '+30 HP to nearest ally',
      '+35 Blue Mana to nearest ally',
      '20 dmg · 1s stun + 2s snare (50% slow)',
      '+60 HP · full CC cleanse to nearest ally',
      '+20 Blue Mana to all teammates',
      'Dash 5m · 1.5s stun to first enemy hit',
      '+35 HP · +40 Blue Mana · CC cleanse to all teammates',
    ],
    PlayerClass.corsair  => [
      '18 dmg',
      '25 dmg · 1.5s stun · forces fumble',
      '1.5× speed for 3s',
      'Dash 5m · 2s snare (50% slow) to first hit',
      '+20% dmg for 4s',
      '20 dmg · 4m knockback + 1.5s snare (50% slow)',
      'Mark target: +25% dmg taken for 5s',
      'Push all enemies 3m away',
      'Push target 4m toward creature · mark for 5s',
      '2× speed · +35% dmg · stun immune · attacks snare 2s · 7s',
    ],
    PlayerClass.trickster => [
      '10 dmg · Hex 3s (−20% dmg output)',
      'Teleport 7m; snare trap at origin (8s, 50% slow)',
      '1.5× speed for 3s',
      '2.5s confusion (controls reversed) · force fumble',
      'Reverse creature 5s · panic push nearby enemies',
      'Swap positions with target; steal ball if held',
      'Drain 25R + 20B from target; stun 1s if full red',
      'Spread hex to nearby hexed; or hex target + 3m for 3s',
      'Force fumble + 1.5s stun; else 20 dmg + Hex',
      'Mass confusion 3s · reverse creature · drain enemy red mana',
    ],
    PlayerClass.wrecker  => [
      '20 dmg',
      '25 dmg · 1s stun',
      'Dash 5m · 20 dmg · 2m knockback to first hit',
      '30 dmg · 2s snare (50% slow)',
      '10 dmg/target · 1m knockback',
      '30 dmg · 1.5s stun',
      'Dash 6m · 20 dmg · 2m knockback to all enemies hit',
      '30 dmg/target · 1.5s stun',
      '55 dmg · 3s stun',
      '35 dmg/target · 1.5s stun · +40% dmg for 5s',
    ],
  };

  // Mana cost per slot. Format: 'NR' = N Red, 'NB' = N Blue, 'NU' = N Ultra, '—' = free.
  List<String> get abilityManaCosts => switch (this) {
    PlayerClass.spectre    => ['—',  '20R', '15B', '20B', '25B', '30R', '40B', '25R', '20B', '5U'],
    PlayerClass.geomancer => ['—',  '25R', '15R', '35R', '25R', '30B', '35B', '20B', '30R', '5U'],
    PlayerClass.archon    => ['—',  '25R', '20B', '25B', '30B', '20B', '35B', '30B', '50B', '5U'],
    PlayerClass.warden   => ['—',  '20R', '15B', '30B', '25B', '30R', '45B', '40B', '25R', '5U'],
    PlayerClass.corsair   => ['—',  '25R', '15B', '20R', '20B', '30R', '20B', '25B', '25R', '5U'],
    PlayerClass.trickster => ['—',  '20B', '15B', '25R', '40R', '35B', '25B', '20B', '30R', '5U'],
    PlayerClass.wrecker  => ['—',  '20R', '25R', '25R', '15R', '25R', '25R', '30R', '35R', '5U'],
  };

  // Spatial extent / targeting range per slot.
  List<String> get abilityRanges => switch (this) {
    PlayerClass.spectre    => ['2.5m',    '2.5m',   'self',   '6m dash',  'self',    '2.5m',   'self',    '3m AoE',  'self',    'self'   ],
    PlayerClass.geomancer => ['2.5m',    'aimed',   '2.5m',  'aimed',    '5m AoE',  'self',    'self',    'self',    '5m dash', '30m AoE'],
    PlayerClass.archon    => ['2.5m',    '3m',      'self',  'self',     '5m',      '5m',      'self',    '5m',      '7m AoE',  '10m AoE'],
    PlayerClass.warden   => ['2.5m',    '3m',      'self',  '5m',       '5m',      '3m',      '5m',      '8m AoE',  '5m dash', 'global' ],
    PlayerClass.corsair   => ['2.5m',    '3m',      'self',  '5m dash',  'self',    '4m',      '20m',     '4m AoE',  '3.5m',    'self'   ],
    PlayerClass.trickster => ['2.5m',    '7m',      'self',  '3m',       'global',  '8m',      '5m',      '5m AoE',  '3m',      'global' ],
    PlayerClass.wrecker  => ['2.5m',    '2.5m',    '5m dash', '3m',     '4m AoE',  '2.5m',    '6m dash', '3m AoE',  '2.5m',    '6m AoE' ],
  };

  // Max cooldowns for slots 1–10 (indices 0–9).
  // Ultra slot (index 9) has no cooldown — gated by ultra mana only.
  List<double> get slotMaxCooldowns => switch (this) {
    PlayerClass.spectre   => [ 1.5,  5.0,  5.0,  7.0, 10.0, 20.0, 20.0, 10.0, 10.0, 0.0],
    PlayerClass.geomancer => [ 1.5, 20.0,  5.0, 20.0, 10.0, 10.0, 10.0,  5.0,  5.0, 0.0],
    PlayerClass.archon   => [ 1.5, 10.0,  5.0, 10.0,  5.0, 12.0, 10.0, 20.0, 20.0, 0.0],
    PlayerClass.warden  => [ 1.5,  5.0,  5.0, 10.0, 12.0, 10.0, 20.0, 20.0, 10.0, 0.0],
    PlayerClass.corsair  => [ 1.5, 20.0,  5.0,  5.0,  8.0, 10.0, 10.0, 10.0, 20.0, 0.0],
    PlayerClass.trickster => [ 1.5,  5.0,  5.0, 10.0, 10.0, 20.0, 10.0, 10.0, 20.0, 0.0],
    PlayerClass.wrecker  => [ 1.5,  5.0,  5.0, 10.0,  1.5, 10.0, 10.0, 20.0, 20.0, 0.0],
  };
}
