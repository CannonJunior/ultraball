enum PlayerClass { runner, geomancer, warden, handler, blitzer, trickster }

extension PlayerClassInfo on PlayerClass {
  String get displayName => switch (this) {
    PlayerClass.runner    => 'SPECTRE',
    PlayerClass.geomancer => 'GEOMANCER',
    PlayerClass.warden    => 'ARCHON',
    PlayerClass.handler  => 'WARDEN',
    PlayerClass.blitzer  => 'CORSAIR',
    PlayerClass.trickster => 'TRICKSTER',
  };

  String get description => switch (this) {
    PlayerClass.runner    => 'Speed · Evasion · Ball Carrier',
    PlayerClass.geomancer => 'Terrain · Disruption · Geological Control',
    PlayerClass.warden   => 'Defense · Healing · Team Fortress',
    PlayerClass.handler  => 'Support · Field Control · Restoration',
    PlayerClass.blitzer  => 'Disruption · Predation · Strip & Mark',
    PlayerClass.trickster => 'Confusion · Traps · Creature Manipulation',
  };

  double get baseSpeed => switch (this) {
    PlayerClass.runner    => 10.0,
    PlayerClass.geomancer =>  7.0,
    PlayerClass.warden   =>  7.5,
    PlayerClass.handler  =>  8.0,
    PlayerClass.blitzer  =>  8.5,
    PlayerClass.trickster =>  9.0,
  };

  double get maxHealth => switch (this) {
    PlayerClass.runner    =>  75.0,
    PlayerClass.geomancer => 115.0,
    PlayerClass.warden   => 120.0,
    PlayerClass.handler  =>  95.0,
    PlayerClass.blitzer  => 105.0,
    PlayerClass.trickster =>  85.0,
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
    PlayerClass.geomancer => [
      'Earth Fist', 'Raise Hill', 'Seismic Shove',
      'Open Sinkhole', 'Tremor', 'Stone Armor',
      'Earthmend', 'Upheaval', 'Fissure',
      'TERRA NOVA',
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
    PlayerClass.trickster => [
      'Hex Strike', 'Phantom Step', 'Fox Sprint',
      'Befuddle', 'Creature Goad', 'Position Swap',
      'Jinx', 'Hex Nova', 'Chaos Fumble',
      'PANDEMONIUM',
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
    PlayerClass.geomancer => [
      '18 dmg · 2.5m · basic attack',
      'Hold to aim: raise hill (4m high) at target spot · 25 Red Mana',
      '12 dmg · push 4m · 1.5s CD · 15 Red Mana',
      'Hold to aim: open sinkhole (instant death) at target spot · 35 Red Mana',
      '15 dmg/target · 5m AoE snare (1.5s, 40% slow) · 10s CD · 25 Red Mana',
      '40% dmg reduction for 4s · self only · 10s CD · 30 Blue Mana',
      '+35 HP self · 10s CD · 35 Blue Mana',
      '+20% speed for 4s · gain 30 Red Mana · 5s CD · 20 Blue Mana',
      'Dash 5m · creates fissure along path (2s pit strip) · 5s CD · 30 Red Mana',
      'Rise 5m hills across 30m radius + open pits under all enemies · 5 Ultra Mana',
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
    PlayerClass.trickster => [
      '10 dmg + Hex 3s (−20% dmg output) · 2.5m',
      'Teleport 7m forward; leave snare trap at origin (8s, 50% slow) · 10s CD · 20 Blue Mana',
      '1.5× speed for 3s · 5s CD · 15 Blue Mana',
      '2.5s confusion (controls reversed) · force fumble if target has ball · 10s CD · 25 Red Mana',
      'Reverse creature direction 5s; panic push nearby enemies · 20s CD · 40 Red Mana',
      'Teleport-swap positions with target (8m range); steal ball if they hold it · 20s CD · 35 Blue Mana',
      'Drain 25 Red + 20 Blue from target; give self half; stun 1s if they had full red · 10s CD · 25 Blue Mana',
      'If target hexed: spread 4s hex to all enemies within 5m. If not: hex target + enemies within 3m for 3s · 5s CD · 20 Blue Mana',
      'Force fumble + 1.5s stun if target has ball; else 20 dmg + Hex · 1.5s CD · 30 Red Mana',
      'Mass confusion 3s on all enemies; reverse creature + drain enemy red mana · 5 Ultra Mana',
    ],
  };

  // Max cooldowns for slots 1–10 (indices 0–9).
  // Ultra slot (index 9) has no cooldown — gated by ultra mana only.
  List<double> get slotMaxCooldowns => switch (this) {
    PlayerClass.runner   => [ 1.5,  1.5,  5.0,  5.0, 10.0, 10.0, 20.0, 10.0, 20.0, 0.0],
    PlayerClass.geomancer => [ 1.5, 20.0,  1.5, 20.0, 10.0, 10.0, 10.0,  5.0,  5.0, 0.0],
    PlayerClass.warden   => [ 1.5,  5.0,  5.0, 10.0, 10.0,  1.5, 10.0, 20.0, 20.0, 0.0],
    PlayerClass.handler  => [ 1.5,  1.5,  5.0,  5.0, 10.0, 10.0, 20.0, 20.0, 10.0, 0.0],
    PlayerClass.blitzer  => [ 1.5,  5.0,  1.5,  5.0, 10.0, 10.0, 10.0, 20.0, 20.0, 0.0],
    PlayerClass.trickster => [ 1.5, 10.0,  5.0, 10.0, 20.0, 20.0, 10.0,  5.0,  1.5, 0.0],
  };
}
