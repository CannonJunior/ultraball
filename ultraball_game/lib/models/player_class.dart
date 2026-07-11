enum PlayerClass { spectre, geomancer, archon, warden, corsair, trickster, wrecker }

extension PlayerClassInfo on PlayerClass {
  String get displayName => switch (this) {
    PlayerClass.spectre    => 'SPECTRE',
    PlayerClass.geomancer  => 'GEOMANCER',
    PlayerClass.archon     => 'ARCHON',
    PlayerClass.warden     => 'WARDEN',
    PlayerClass.corsair    => 'CORSAIR',
    PlayerClass.trickster  => 'TRICKSTER',
    PlayerClass.wrecker    => 'WRECKER',
  };

  String get description => switch (this) {
    PlayerClass.spectre    => 'Speed · Evasion · Ball Carrier',
    PlayerClass.geomancer  => 'Terrain · Disruption · Geological Control',
    PlayerClass.archon     => 'Defense · Healing · Team Fortress',
    PlayerClass.warden     => 'Support · Field Control · Restoration',
    PlayerClass.corsair    => 'Disruption · Predation · Strip & Mark',
    PlayerClass.trickster  => 'Confusion · Traps · Creature Manipulation',
    PlayerClass.wrecker    => 'Brutality · Close Combat · Maximum Damage',
  };

  double get baseSpeed => switch (this) {
    PlayerClass.spectre    => 10.0,
    PlayerClass.geomancer  =>  7.0,
    PlayerClass.archon     =>  7.5,
    PlayerClass.warden     =>  8.0,
    PlayerClass.corsair    =>  8.5,
    PlayerClass.trickster  =>  9.0,
    PlayerClass.wrecker    =>  8.0,
  };

  double get maxHealth => switch (this) {
    PlayerClass.spectre    =>  75.0,
    PlayerClass.geomancer  => 115.0,
    PlayerClass.archon     => 120.0,
    PlayerClass.warden     =>  95.0,
    PlayerClass.corsair    => 105.0,
    PlayerClass.trickster  =>  85.0,
    PlayerClass.wrecker    => 110.0,
  };

  // Ability layout (all classes):
  //  1 (1.5s) — light attack / heal, free
  //  2 (1.5s) — heavier class-indicative strike, moderate mana
  //  3 (5s)   — main spam: heavy hit, big heal, speed boost, etc.
  //  4 (5s)   — combo extender
  //  5 (5s)   — combo extender, increasing benefit
  //  6 (10s)  — combo ender / major benefit
  //  7 (10s)  — ranged utility: charge, snare, pull-ally-and-heal, etc.
  //  8 (20s)  — major CC: AoE, knockback, long stun, pull enemy, terrain hole
  //  9 (20s)  — powerful but mana-intensive class finisher
  // 10 (APEX) — ultra ability, no cooldown, gated by ultra mana

  List<String> get abilityNames => switch (this) {
    // ── SPECTRE ─────────────────────────────────────────────────────────────
    // Play pattern: speed boost → dash in → ghost through → stun → charge down → AoE snare → kill
    PlayerClass.spectre => [
      'Volt',           // 1  light jab
      'Trip Line',      // 2  snare strike
      'Overdrive',      // 3  speed boost (spam)
      'Phase',          // 4  dash forward
      'Ghost',          // 5  invulnerability
      'Lights Out',     // 6  stun melee
      'Surge',          // 7  charge toward enemy
      'Cutback',        // 8  AoE snare
      'Slipstream',     // 9  kill-shot finisher
      'ULTRAVIOLET',    // 10 ultra
    ],
    // ── GEOMANCER ───────────────────────────────────────────────────────────
    // Play pattern: shove → armor → AoE CC → raise terrain → pull ally → open pit → fissure
    PlayerClass.geomancer => [
      'Earth Fist',     // 1  heavy melee
      'Tremor Strike',  // 2  snare punch
      'Seismic Shove',  // 3  knockback (spam)
      'Stone Armor',    // 4  damage reduction
      'Tremor',         // 5  AoE snare
      'Raise Hill',     // 6  terrain: hill
      'Earthmend',      // 7  pull ally + heal
      'Open Sinkhole',  // 8  terrain: instant-death pit
      'Fissure',        // 9  dash + pit strip
      'TERRA NOVA',     // 10 ultra
    ],
    // ── ARCHON ──────────────────────────────────────────────────────────────
    // Play pattern: tank up → heal ally → cleanse → speed burst → pull ally → stomp → mass heal
    PlayerClass.archon => [
      'Stonefist',      // 1  melee knockback
      'Fault Line',     // 2  stun strike
      'Field Stitch',   // 3  heal ally (spam)
      'Fortress',       // 4  self damage reduction
      'Absolution',     // 5  cleanse ally CC
      'March',          // 6  speed burst
      'Tenacity',       // 7  pull ally + heal
      'Aegis Stomp',    // 8  stun + AoE knockback
      'Salvation',      // 9  mass heal
      'CITADEL',        // 10 ultra
    ],
    // ── WARDEN ──────────────────────────────────────────────────────────────
    // Play pattern: heal → restore mana → speed → suppress → pull ally → chain enemy → mass restore
    PlayerClass.warden => [
      'One-Two',        // 1  light jab
      'Ankle Lock',     // 2  snare strike
      'Quick Fix',      // 3  heal ally (spam)
      'Jump Start',     // 4  restore ally mana
      'Tempo Shift',    // 5  speed boost
      'Suppress',       // 6  stun + snare
      'Lifeline',       // 7  pull ally + big heal + cleanse
      'Blindside',      // 8  pull enemy + stun
      'Resupply',       // 9  mass heal + mana restore
      'SYMPHONY',       // 10 ultra
    ],
    // ── CORSAIR ─────────────────────────────────────────────────────────────
    // Play pattern: sprint → pounce → strip → whiplash → mark → yank → feed creature
    PlayerClass.corsair => [
      'Fang',           // 1  quick strike
      'Bloodscent',     // 2  hit + dmg self-buff
      'Death Sprint',   // 3  speed boost (spam)
      'Pounce',         // 4  gap-close + snare
      'Strip',          // 5  stun + force fumble
      'Whiplash',       // 6  knockback + snare
      'Condemn',        // 7  ranged mark
      'Rout',           // 8  pull enemy + stun
      'Feed the Beast', // 9  push enemy toward creature + mark
      'APEX',           // 10 ultra
    ],
    // ── TRICKSTER ───────────────────────────────────────────────────────────
    // Play pattern: hex → teleport + trap → confuse → swap → goad creature → drain → AoE hex → chaos fumble
    PlayerClass.trickster => [
      'Hex Strike',     // 1  hex on hit
      'Phantom Step',   // 2  teleport + trap
      'Fox Sprint',     // 3  speed boost (spam)
      'Befuddle',       // 4  confusion + fumble
      'Position Swap',  // 5  swap + steal ball
      'Creature Goad',  // 6  redirect creature
      'Jinx',           // 7  ranged mana drain
      'Hex Nova',       // 8  AoE hex + fumble
      'Chaos Fumble',   // 9  hard CC + fumble finisher
      'PANDEMONIUM',    // 10 ultra
    ],
    // ── WRECKER ─────────────────────────────────────────────────────────────
    // Play pattern: rush → crumple → shockwave → spine break → charge → ground pound → death blow
    PlayerClass.wrecker => [
      'Iron Fist',      // 1  hard jab
      'Sledge',         // 2  stun strike
      'Bull Rush',      // 3  dash + knockback (spam)
      'Crumple',        // 4  heavy hit + snare
      'Shockwave',      // 5  AoE knockback
      'Spine Breaker',  // 6  stun + heavy damage
      'Wrecking Ball',  // 7  charge + AoE knockback
      'Ground Pound',   // 8  AoE stun
      'Death Blow',     // 9  kill-shot finisher
      'DEMOLISH',       // 10 ultra
    ],
  };

  List<String> get abilityDescriptions => switch (this) {
    PlayerClass.spectre => [
      '12 dmg',
      '18 dmg · 1.5s snare (50% slow)',
      '1.5× speed for 3s',
      'Dash 6m forward',
      '1.5s full invulnerability',
      '20 dmg · 2s stun',
      'Charge 10m toward target · 15 dmg on hit',
      '15 dmg · 2.5s snare (50% slow) to all enemies in 4m AoE',
      '45 dmg · 3s stun · forces fumble',
      '2.5× speed · stun immunity · 7s',
    ],
    PlayerClass.geomancer => [
      '18 dmg',
      '22 dmg · 1.5s snare (40% slow)',
      '12 dmg · push 4m',
      '40% dmg reduction for 4s',
      '12 dmg/target · 1.5s snare (40% slow) in 5m AoE',
      'Raise 4m-high hill at targeted spot',
      'Pull nearest ally 7m toward self · +35 HP',
      'Open instant-death sinkhole at targeted spot',
      'Dash 5m · fissure along path (2s pit strip · 20 dmg to all hit)',
      'Raise hills across 30m · open pits under all enemies',
    ],
    PlayerClass.archon => [
      '15 dmg · 2m push',
      '22 dmg · 1s stun',
      '+35 HP to nearest ally',
      '50% dmg reduction for 3s',
      'Cleanse all CC from nearest ally',
      '1.5× speed for 3s',
      'Pull nearest ally 7m toward self · +25 HP',
      '25 dmg · 2s stun to nearest enemy · 3m AoE knockback',
      '+55 HP · CC cleanse to all allies in 10m',
      '50% dmg reduction · stun immunity · +8 HP/s · 6s',
    ],
    PlayerClass.warden => [
      '10 dmg',
      '15 dmg · 1.5s snare (40% slow)',
      '+30 HP to nearest ally',
      '+35 Blue Mana to nearest ally',
      '1.5× speed for 3s',
      '20 dmg · 1.5s stun + 1.5s snare (50% slow)',
      'Pull nearest ally 5m toward self · +60 HP · CC cleanse',
      'Pull target enemy 7m toward self · 2s stun',
      '+35 HP · +40 Blue Mana · CC cleanse to all teammates',
      '+35 HP · +40 Blue Mana · CC cleanse · speed aura to all teammates',
    ],
    PlayerClass.corsair => [
      '18 dmg',
      '20 dmg · +20% dmg for 3s',
      '1.5× speed for 3s',
      'Dash 5m · 15 dmg · 1.5s snare (50% slow) to first hit',
      '25 dmg · 1.5s stun · forces fumble',
      '20 dmg · 4m knockback · 1.5s snare (50% slow)',
      'Mark target: +25% dmg taken for 5s',
      'Pull target enemy 4m toward self · 2s stun',
      '30 dmg · push target 5m toward creature · mark for 5s',
      '2× speed · +35% dmg · stun immune · attacks snare 2s · 7s',
    ],
    PlayerClass.trickster => [
      '10 dmg · Hex 3s (−20% dmg output)',
      'Teleport 7m; snare trap at origin (8s, 50% slow)',
      '1.5× speed for 3s',
      '2.5s confusion (controls reversed) · force fumble',
      'Swap positions with target; steal ball if held',
      'Redirect creature toward targeted enemy for 5s',
      'Drain 25R + 20B from target · stun 1s if target had full red',
      'AoE 5m: hex all enemies 3s + force fumble on ball carrier',
      'Force fumble + 2s stun; else 25 dmg + Hex 4s',
      'Mass confusion 3s · reverse creature · drain enemy red mana',
    ],
    PlayerClass.wrecker => [
      '20 dmg',
      '28 dmg · 1s stun',
      'Dash 5m · 20 dmg · 2m knockback to first hit',
      '30 dmg · 2s snare (50% slow)',
      '15 dmg/target · 1m knockback in 4m AoE',
      '35 dmg · 1.5s stun',
      'Charge 8m toward target · 20 dmg · 2m knockback to all hit',
      '30 dmg/target · 1.5s stun in 4m AoE',
      '60 dmg · 3s stun · +40% dmg for 5s',
      '35 dmg/target · 1.5s stun · +40% dmg for 5s in 6m AoE',
    ],
  };

  // Mana cost per slot. Format: 'NR' = N Red, 'NB' = N Blue, 'NU' = N Ultra, '—' = free.
  List<String> get abilityManaCosts => switch (this) {
    //                  1     2     3     4     5     6     7     8     9    10
    PlayerClass.spectre    => ['—', '20R', '15B', '20B', '25R', '30R', '30B', '25B', '40R', '5U'],
    PlayerClass.geomancer  => ['—', '20R', '15R', '20B', '25R', '30B', '35B', '35R', '30R', '5U'],
    PlayerClass.archon     => ['—', '20R', '20B', '25B', '20B', '25B', '35B', '30R', '50B', '5U'],
    PlayerClass.warden     => ['—', '20R', '20B', '25B', '15B', '25R', '35B', '30R', '45B', '5U'],
    PlayerClass.corsair    => ['—', '20R', '15B', '20R', '25R', '30R', '20B', '30B', '30R', '5U'],
    PlayerClass.trickster  => ['—', '20B', '15B', '25R', '20B', '35R', '25B', '20B', '30R', '5U'],
    PlayerClass.wrecker    => ['—', '20R', '25R', '25R', '20R', '30R', '30R', '35R', '40R', '5U'],
  };

  // Spatial extent / targeting range per slot.
  List<String> get abilityRanges => switch (this) {
    //                  1       2       3        4          5       6       7        8        9         10
    PlayerClass.spectre   => ['2.5m',  '2.5m',  'self',   '6m dash',  'self',    '2.5m',   '10m',    '4m AoE',  '2.5m',   'self'   ],
    PlayerClass.geomancer => ['2.5m',  '2.5m',  '2.5m',  'self',     '5m AoE',  'aimed',  '7m',     'aimed',   '5m dash','30m AoE'],
    PlayerClass.archon    => ['2.5m',  '3m',    '5m',    'self',     '5m',      'self',   '7m',     '3m AoE',  '10m AoE','10m AoE'],
    PlayerClass.warden    => ['2.5m',  '3m',    '5m',    '5m',       'self',    '3m',     '5m',     '7m',      'global', 'global' ],
    PlayerClass.corsair   => ['2.5m',  '2.5m',  'self',  '5m dash',  '3m',      '4m',     '20m',    '6m',      '3.5m',   'self'   ],
    PlayerClass.trickster => ['2.5m',  '7m',    'self',  '3m',       '8m',      'global', '5m',     '5m AoE',  '3m',     'global' ],
    PlayerClass.wrecker   => ['2.5m',  '2.5m',  '5m dash','3m',      '4m AoE',  '2.5m',   '8m',    '4m AoE',  '2.5m',   '6m AoE' ],
  };

  // Max cooldowns for slots 1–10 (indices 0–9).
  // All classes share the same cooldown tier pattern:
  //   slots 1–2 → 1.5s  (quick attacks)
  //   slots 3–5 → 5.0s  (main rotation)
  //   slots 6–7 → 10.0s (utility / combo enders)
  //   slots 8–9 → 20.0s (major CC / finishers)
  //   slot  10  → 0.0s  (APEX — gated by ultra mana only)
  List<double> get slotMaxCooldowns => switch (this) {
    PlayerClass.spectre    => [1.5, 1.5, 5.0, 5.0, 5.0, 10.0, 10.0, 20.0, 20.0, 0.0],
    PlayerClass.geomancer  => [1.5, 1.5, 5.0, 5.0, 5.0, 10.0, 10.0, 20.0, 20.0, 0.0],
    PlayerClass.archon     => [1.5, 1.5, 5.0, 5.0, 5.0, 10.0, 10.0, 20.0, 20.0, 0.0],
    PlayerClass.warden     => [1.5, 1.5, 5.0, 5.0, 5.0, 10.0, 10.0, 20.0, 20.0, 0.0],
    PlayerClass.corsair    => [1.5, 1.5, 5.0, 5.0, 5.0, 10.0, 10.0, 20.0, 20.0, 0.0],
    PlayerClass.trickster  => [1.5, 1.5, 5.0, 5.0, 5.0, 10.0, 10.0, 20.0, 20.0, 0.0],
    PlayerClass.wrecker    => [1.5, 1.5, 5.0, 5.0, 5.0, 10.0, 10.0, 20.0, 20.0, 0.0],
  };
}
