enum PlayerClass { spectre, geomancer, archon, warden, corsair, trickster, wrecker }

/// Semantic purpose of an ability — drives icon color.
enum AbilityType {
  damage,   // deals direct damage as primary effect
  heal,     // restores HP (self or ally)
  selfBuff, // enhances speed, defense, or invulnerability on self
  support,  // buffs or restores an ally (mana, shield, pull-ally)
  cc,       // crowd control: stun, confuse, dedicated snare, pull-enemy
  movement, // repositioning with no significant damage primary
  terrain,  // creates or manipulates field terrain
  utility,  // mark, drain, creature manipulation, disruption
  ultra,    // APEX ability gated by ultra mana
}

/// Secondary properties shown as corner pips on the ability icon.
enum AbilityTag {
  aoe,    // hits multiple targets — top-left orange pip
  cc,     // CC rider on a non-CC-type ability — top-right purple pip
  snare,  // slow/root rider (shown only if no cc tag) — top-right blue pip
  fumble, // forces ball fumble — bottom-right gold pip
}

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
      'Fault Line',     // 2  snare strike
      'March',          // 3  speed burst
      'Fortress',       // 4  self damage reduction
      'Field Stitch',   // 5  heal ally
      'Charge',         // 6  gap-close + snare
      'Tenacity',       // 7  self heal + mana
      'Aegis Stomp',    // 8  ally damage reduction
      'Salvation',      // 9  mass heal + cleanse
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
      '20 dmg · 2m push',
      '28 dmg · 1.5s snare (50% slow)',
      '1.5× speed for 3s',
      '50% dmg reduction for 3s',
      '+35 HP to nearest ally',
      'Dash to target (up to 8m) · 25 dmg · 1s stun on hit',
      'Self +35 HP · +20 Blue Mana',
      '30% dmg reduction to nearest ally for 4s',
      '+25 HP · CC cleanse to all allies in 7m',
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
  // Tier costs: slot 2 (1.5s CD): 5R/15B · slots 3–5 (5s): 7–10R/20–30B ·
  //             slots 6–7 (10s): 13–17R/40–50B · slots 8–9 (20s): 20–25R/60–70B
  // Red ≈ 1/3 of blue at the same tier. Corsair only uses both mana types.
  List<String> get abilityManaCosts => switch (this) {
    //                  1     2      3      4      5      6      7      8      9     10
    PlayerClass.spectre    => ['—',  '5R',  '7R',  '8R', '10R', '13R', '17R', '20R', '25R', '5U'],
    PlayerClass.geomancer  => ['—', '15B', '20B', '25B', '30B', '40B', '50B', '60B', '70B', '5U'],
    PlayerClass.archon     => ['—', '15B', '20B', '25B', '30B', '40B', '50B', '60B', '70B', '5U'],
    PlayerClass.warden     => ['—', '15B', '20B', '25B', '30B', '40B', '50B', '60B', '70B', '5U'],
    PlayerClass.corsair    => ['—',  '5R', '20B', '10R', '12R', '15R', '40B', '60B', '20R', '5U'],
    PlayerClass.trickster  => ['—', '15B', '20B', '25B', '30B', '40B', '50B', '60B', '70B', '5U'],
    PlayerClass.wrecker    => ['—',  '5R',  '7R',  '8R', '10R', '13R', '17R', '20R', '25R', '5U'],
  };

  // Spatial extent / targeting range per slot.
  List<String> get abilityRanges => switch (this) {
    //                  1       2       3        4          5       6       7        8        9         10
    PlayerClass.spectre   => ['2.5m',  '2.5m',  'self',   '6m dash',  'self',    '2.5m',   '10m',    '4m AoE',  '2.5m',   'self'   ],
    PlayerClass.geomancer => ['2.5m',  '2.5m',  '2.5m',  'self',     '5m AoE',  'aimed',  '7m',     'aimed',   '5m dash','30m AoE'],
    PlayerClass.archon    => ['2.5m',  '3m',    'self',  'self',     '5m',      '8m',     'self',   '5m',      '7m AoE', '10m AoE'],
    PlayerClass.warden    => ['2.5m',  '3m',    '5m',    '5m',       'self',    '3m',     '5m',     '7m',      'global', 'global' ],
    PlayerClass.corsair   => ['2.5m',  '2.5m',  'self',  '5m dash',  '3m',      '4m',     '20m',    '6m',      '3.5m',   'self'   ],
    PlayerClass.trickster => ['2.5m',  '7m',    'self',  '3m',       '8m',      'global', '5m',     '5m AoE',  '3m',     'global' ],
    PlayerClass.wrecker   => ['2.5m',  '2.5m',  '5m dash','3m',      '4m AoE',  '2.5m',   '8m',    '4m AoE',  '2.5m',   '6m AoE' ],
  };

  /// Numeric range in world units for slot [slot] (1-indexed).
  /// Returns 0.0 for self-cast, global, aimed, or unparseable ranges.
  double slotRange(int slot) {
    if (slot < 1 || slot > 10) return 0.0;
    final str = abilityRanges[slot - 1];
    if (str == 'self' || str == 'global' || str == 'aimed') return 0.0;
    final m = RegExp(r'^(\d+(?:\.\d+)?)m').firstMatch(str);
    return m != null ? double.parse(m.group(1)!) : 0.0;
  }

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

  // ─── Semantic ability metadata ────────────────────────────────────────────
  // Based on what each slot actually does in combat_system.dart (slots 1–10).
  // Drives icon color and corner-pip indicators in the ability hotbar.

  List<AbilityType> get abilityTypes {
    const d = AbilityType.damage,   h = AbilityType.heal,
              b = AbilityType.selfBuff, p = AbilityType.support,
              c = AbilityType.cc,   m = AbilityType.movement,
              t = AbilityType.terrain,  u = AbilityType.utility,
              x = AbilityType.ultra;
    return switch (this) {
      // Spectre:   jab  snare  sprint  dash   invuln  stun-hit  self-heal  AoE-snare  stun-immune  ultra
      PlayerClass.spectre   => [d, d, b, m, b, d, h, c, b, x],
      // Geomancer: fist  hill  shove  pit  AoE-snare  armor  selfheal  upheaval  fissure  ultra
      PlayerClass.geomancer => [d, t, d, t, d, b, h, b, t, x],
      // Archon:    fist  snare  sprint  shield  heal-ally  charge  self-heal  ally-shield  AoE-heal  ultra
      PlayerClass.archon    => [d, d, b, b, h, d, h, p, h, x],
      // Warden:    jab  snare  sprint  heal-ally  mana-ally  stun+snare  big-heal  AoE-mana  dash-stun  ultra
      PlayerClass.warden    => [d, d, b, h, p, c, h, p, c, x],
      // Corsair:   fang  stun+fumble  sprint  dash-snare  dmgbuff  hit+snare  mark  AoE-push  bait  ultra
      PlayerClass.corsair   => [d, d, b, m, b, d, u, c, u, x],
      // Trickster: hex-hit  teleport  sprint  confuse  goad  swap  drain  AoE-hex  chaos  ultra
      PlayerClass.trickster => [d, m, b, c, u, u, u, c, c, x],
      // Wrecker:   all damage, all the time
      PlayerClass.wrecker   => [d, d, d, d, d, d, d, d, d, x],
    };
  }

  List<Set<AbilityTag>> get abilityTags {
    const a = AbilityTag.aoe,   c = AbilityTag.cc,
              s = AbilityTag.snare, f = AbilityTag.fumble;
    const e = <AbilityTag>{};
    return switch (this) {
      //                                      1   2      3  4  5     6     7  8      9  10
      PlayerClass.spectre   => [e, {s}, e, e, e, {c}, e, {a}, e, e],
      PlayerClass.geomancer => [e, e,   e, e, {a, s}, e, e, e, e, {a}],
      PlayerClass.archon    => [e, {s}, e, e, e, {s}, e, e, {a}, {a}],
      PlayerClass.warden    => [e, {s}, e, e, e, {s}, e, {a}, e, {a}],
      PlayerClass.corsair   => [e, {c, f}, e, {s}, e, {s}, e, {a}, e, e],
      PlayerClass.trickster => [e, {s}, e, {f}, {a}, e, {c}, {a}, {f}, {a}],
      PlayerClass.wrecker   => [e, {c}, e, {s}, {a}, {c}, {a}, {a, c}, {c}, {a, c}],
    };
  }
}
