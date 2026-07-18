import 'package:vector_math/vector_math.dart';

enum PlayerClass { spectre, geomancer, archon, warden, corsair, trickster, wrecker, vitalist }

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
  static final _rangeRe = RegExp(r'^(\d+(?:\.\d+)?)m');
  static const List<double> _defaultSlotCooldowns = [1.5, 1.5, 5.0, 5.0, 5.0, 10.0, 10.0, 20.0, 20.0, 0.0];
  String get displayName => switch (this) {
    PlayerClass.spectre    => 'SPECTRE',
    PlayerClass.geomancer  => 'GEOMANCER',
    PlayerClass.archon     => 'ARCHON',
    PlayerClass.warden     => 'WARDEN',
    PlayerClass.corsair    => 'CORSAIR',
    PlayerClass.trickster  => 'TRICKSTER',
    PlayerClass.wrecker    => 'WRECKER',
    PlayerClass.vitalist   => 'VITALIST',
  };

  String get description => switch (this) {
    PlayerClass.spectre    => 'Speed · Evasion · Ball Carrier',
    PlayerClass.geomancer  => 'Terrain · Disruption · Geological Control',
    PlayerClass.archon     => 'Defense · Healing · Team Fortress',
    PlayerClass.warden     => 'Support · Field Control · Restoration',
    PlayerClass.corsair    => 'Disruption · Predation · Strip & Mark',
    PlayerClass.trickster  => 'Confusion · Traps · Creature Manipulation',
    PlayerClass.wrecker    => 'Brutality · Close Combat · Maximum Damage',
    PlayerClass.vitalist   => 'Renewal · Restoration · Duration Mastery',
  };

  double get baseSpeed => switch (this) {
    PlayerClass.spectre    => 10.0,
    PlayerClass.geomancer  =>  7.0,
    PlayerClass.archon     =>  7.5,
    PlayerClass.warden     =>  8.0,
    PlayerClass.corsair    =>  8.5,
    PlayerClass.trickster  =>  9.0,
    PlayerClass.wrecker    =>  8.0,
    PlayerClass.vitalist   =>  8.0,
  };

  double get maxHealth => switch (this) {
    PlayerClass.spectre    =>  75.0,
    PlayerClass.geomancer  => 115.0,
    PlayerClass.archon     => 120.0,
    PlayerClass.warden     =>  95.0,
    PlayerClass.corsair    => 105.0,
    PlayerClass.trickster  =>  85.0,
    PlayerClass.wrecker    => 110.0,
    PlayerClass.vitalist   =>  90.0,
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
      'Raise Hill',     // 2  terrain: hill (hold-to-aim)
      'Seismic Shove',  // 3  knockback
      'Quagmire',       // 4  terrain: mud zone (hold-to-aim)
      'Tremor',         // 5  AoE snare
      'Stone Armor',    // 6  damage reduction
      'Earthmend',      // 7  self-heal
      'Crevasse',       // 8  terrain: valley cone (hold-to-aim)
      'Fissure',        // 9  hold-to-aim rock projectile → pit
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
    // ── VITALIST ────────────────────────────────────────────────────────────
    // Play pattern: mend ally → infuse burst → empower attacker → shield → refresh + cleanse → cascade AoE → prolong key buff → verdure ultra
    PlayerClass.vitalist => [
      'Tap',            // 1  light strike + self-heal
      'Mend',           // 2  HoT to ally (spam)
      'Infuse',         // 3  burst heal + HoT to ally
      'Empower',        // 4  damage boost to ally
      'Bulwark',        // 5  damage shield to ally
      'Refresh',        // 6  big heal + cleanse to ally
      'Cascade',        // 7  AoE heal to all nearby allies
      'Rebuke',         // 8  stun + fumble (defensive CC)
      'Prolong',        // 9  next ally ability buff durations doubled
      'VERDURE',        // 10 ultra: periodic AoE HoT (5 ticks × 2s)
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
      'Raise 4m hill at aimed spot (hold [2])',
      '12 dmg · push 4m',
      'Mud zone at aimed spot · 45% slow · 8s (hold [4])',
      '15 dmg/target · 1.5s snare (40% slow) in 5m AoE',
      '40% dmg reduction for 4s',
      'Self +35 HP',
      'Sink valley at aimed spot · slows traversal (hold [8])',
      'Hold [9] to aim · rock flies to target · 1.5s warning · 5s pit',
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
    PlayerClass.vitalist => [
      '10 dmg · self +5 HP',
      '4s HoT (6 HP/sec) to nearest ally in 5m',
      '+30 HP · 4s HoT (8 HP/sec) to nearest ally in 5m',
      '+20% dmg for 4s to nearest ally in 5m',
      '30% dmg reduction for 4s to nearest ally in 5m',
      '+45 HP · CC cleanse to nearest ally in 7m',
      '+25 HP to all allies in 6m',
      '20 dmg · 2s stun · force fumble if holding ball',
      'Nearest ally in 10m: next ability buff durations doubled',
      'All allies in 8m: +20 HP every 2s for 10s (5 ticks)',
    ],
  };

  // Mana cost per slot. Format: 'NR' = N Red, 'NB' = N Blue, 'NY' = N Yellow, 'NU' = N Ultra, '—' = free.
  // Tier costs: slot 2 (1.5s CD): 5R/15B · slots 3–5 (5s): 7–10R/20–30B ·
  //             slots 6–7 (10s): 13–17R/40–50B · slots 8–9 (20s): 20–25R/60–70B
  // Red ≈ 1/3 of blue at the same tier. Corsair exclusively uses yellow mana.
  List<String> get abilityManaCosts => switch (this) {
    //                  1     2      3      4      5      6      7      8      9     10
    PlayerClass.spectre    => ['—',  '5R',  '7R',  '8R', '10R', '13R', '17R', '20R', '25R', '5U'],
    PlayerClass.geomancer  => ['—', '15B', '20B', '25B', '30B', '40B', '50B', '60B', '70B', '5U'],
    PlayerClass.archon     => ['—', '15B', '20B', '25B', '30B', '40B', '50B', '60B', '70B', '5U'],
    PlayerClass.warden     => ['—', '15B', '20B', '25B', '30B', '40B', '50B', '60B', '70B', '5U'],
    PlayerClass.corsair    => ['—',  '5Y', '20Y', '10Y', '12Y', '15Y', '40Y', '60Y', '20Y', '5U'],
    PlayerClass.trickster  => ['—', '15B', '20B', '25B', '30B', '40B', '50B', '60B', '70B', '5U'],
    PlayerClass.wrecker    => ['—',  '5R',  '7R',  '8R', '10R', '13R', '17R', '20R', '25R', '5U'],
    PlayerClass.vitalist   => ['—',  '5Y', '20Y', '15Y', '10Y', '35Y', '45Y', '60Y', '25Y', '5U'],
  };

  // Spatial extent / targeting range per slot.
  List<String> get abilityRanges => switch (this) {
    //                  1       2       3        4          5       6       7        8        9         10
    PlayerClass.spectre   => ['2.5m',  '2.5m',  'self',   '6m dash',  'self',    '2.5m',   '10m',    '4m AoE',  '2.5m',   'self'   ],
    PlayerClass.geomancer => ['2.5m',  'aimed', '2.5m',  'aimed',    '5m AoE',  'self',   'self',   'aimed',   'aimed',  '30m AoE'],
    PlayerClass.archon    => ['2.5m',  '3m',    'self',  'self',     '5m',      '8m',     'self',   '5m',      '7m AoE', '10m AoE'],
    PlayerClass.warden    => ['2.5m',  '3m',    '5m',    '5m',       'self',    '3m',     '5m',     '7m',      'global', 'global' ],
    PlayerClass.corsair   => ['2.5m',  '2.5m',  'self',  '5m dash',  '3m',      '4m',     '20m',    '6m',      '3.5m',   'self'   ],
    PlayerClass.trickster => ['2.5m',  '7m',    'self',  '3m',       '8m',      'global', '5m',     '5m AoE',  '3m',     'global' ],
    PlayerClass.wrecker   => ['2.5m',  '2.5m',  '5m dash','3m',      '4m AoE',  '2.5m',   '8m',    '4m AoE',  '2.5m',   '6m AoE' ],
    PlayerClass.vitalist  => ['2.5m',  '5m',    '5m',    '5m',       '5m',      '7m',     '6m AoE', '3m',     '10m',    '8m AoE' ],
  };

  /// Numeric range in world units for slot [slot] (1-indexed).
  /// Returns 0.0 for self-cast, global, aimed, or unparseable ranges.
  double slotRange(int slot) {
    if (slot < 1 || slot > 10) return 0.0;
    final str = abilityRanges[slot - 1];
    if (str == 'self' || str == 'global' || str == 'aimed') return 0.0;
    final m = _rangeRe.firstMatch(str);
    return m != null ? double.parse(m.group(1)!) : 0.0;
  }

  // Max cooldowns for slots 1–10 (indices 0–9).
  // All classes share the same cooldown tier pattern:
  //   slots 1–2 → 1.5s  (quick attacks)
  //   slots 3–5 → 5.0s  (main rotation)
  //   slots 6–7 → 10.0s (utility / combo enders)
  //   slots 8–9 → 20.0s (major CC / finishers)
  //   slot  10  → 0.0s  (APEX — gated by ultra mana only)
  List<double> get slotMaxCooldowns => _defaultSlotCooldowns;

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
      // Geomancer: fist  hill  shove  mud  AoE-snare  armor  selfheal  crevasse  fissure  ultra
      PlayerClass.geomancer => [d, t, d, t, d, b, h, t, t, x],
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
      // Vitalist:  jab+selfheal  HoT  burst-heal  ally-dmgbuff  ally-shield  big-heal+cleanse  AoE-heal  stun+fumble  duration-double  ultra
      PlayerClass.vitalist  => [d, h, h, p, p, h, h, c, p, x],
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
      PlayerClass.vitalist  => [e, e, e, e, e, e, {a}, {c, f}, e, {a}],
    };
  }

  // ── 3D mesh colors ────────────────────────────────────────────────────────

  /// Accent color used for the selected-player cube highlight and class tinting.
  Vector3 get meshColor => switch (this) {
    PlayerClass.spectre   => Vector3(0x44 / 255, 1.0,          0xCC / 255),
    PlayerClass.corsair   => Vector3(1.0,         0x44 / 255,  0xAA / 255),
    PlayerClass.geomancer => Vector3(1.0,         0x55 / 255,  0x44 / 255),
    PlayerClass.archon    => Vector3(0x44 / 255,  0x88 / 255,  1.0       ),
    PlayerClass.warden    => Vector3(1.0,         0xCC / 255,  0x44 / 255),
    PlayerClass.trickster => Vector3(0xAA / 255,  0x44 / 255,  1.0       ),
    PlayerClass.wrecker   => Vector3(1.0,         0x77 / 255,  0.0       ),
    PlayerClass.vitalist  => Vector3(0x44 / 255,  0xDD / 255,  0x88 / 255),
  };

  /// Subtle per-class jersey tint offset applied on top of the team base color.
  Vector3 get jerseyShift => switch (this) {
    PlayerClass.spectre   => Vector3( 0.00,  0.08, -0.05),
    PlayerClass.geomancer => Vector3(-0.05, -0.05,  0.00),
    PlayerClass.archon    => Vector3( 0.05,  0.05,  0.05),
    PlayerClass.warden    => Vector3(-0.02,  0.08,  0.04),
    PlayerClass.corsair   => Vector3( 0.08, -0.02, -0.08),
    PlayerClass.trickster => Vector3(-0.10,  0.05,  0.15),
    PlayerClass.wrecker   => Vector3( 0.15, -0.08, -0.10),
    PlayerClass.vitalist  => Vector3(-0.05,  0.10,  0.00),
  };

  /// Helmet color in the 3D character rig.
  Vector3 get helmetColor => switch (this) {
    PlayerClass.spectre   => Vector3(0.90, 0.75, 0.10),
    PlayerClass.corsair   => Vector3(0.90, 0.45, 0.08),
    PlayerClass.geomancer => Vector3(0.12, 0.45, 0.12),
    PlayerClass.archon    => Vector3(0.78, 0.78, 0.80),
    PlayerClass.warden    => Vector3(0.10, 0.80, 0.85),
    PlayerClass.trickster => Vector3(0.60, 0.10, 0.90),
    PlayerClass.wrecker   => Vector3(0.85, 0.20, 0.02),
    PlayerClass.vitalist  => Vector3(0.10, 0.80, 0.40),
  };
}
