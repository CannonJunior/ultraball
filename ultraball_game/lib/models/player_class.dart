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
