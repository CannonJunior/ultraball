import 'creature.dart';
import '../ai/ai_strategy.dart';

enum ViewMode { flat, threeQuarter, full3D }

enum MatchMode { twoTeams, threeTeams }

class TeamDefinition {
  final String name;
  final CreatureType creatureType;
  // primaryColor / secondaryColor are ARGB hex ints (e.g. 0xFF00C853)
  final int primaryColor;
  final int secondaryColor;
  final List<String> playerNames; // 15 names: slot (i % 7) → SPECTRE, CORSAIR, GEOMANCER, ARCHON, WARDEN, TRICKSTER, WRECKER

  const TeamDefinition(
    this.name,
    this.creatureType,
    this.primaryColor,
    this.secondaryColor,
    this.playerNames,
  );

  static const List<TeamDefinition> teams = [
    TeamDefinition('VIPERS', CreatureType.kraken,
      0xFF00C853, // vivid green
      0xFFF9A825, // amber
      [
        'Fang',    'Venom',   'Cobra',    'Asp',     'Adder',
        'Mamba',   'Python',  'Anaconda', 'Boa',     'Taipan',
        'Scales',  'Coil',    'Rattle',   'Hiss',    'Pit',
      ],
    ),
    TeamDefinition('REAPERS', CreatureType.dragon,
      0xFFAA00FF, // electric purple
      0xFFFFD700, // gold
      [
        'Scythe',  'Grim',    'Shade',    'Mort',    'Dusk',
        'Reap',    'Doom',    'Skull',    'Gore',    'Bone',
        'Crypt',   'Void',    'Hex',      'Ash',     'Blood',
      ],
    ),
    TeamDefinition('TITANS', CreatureType.hydra,
      0xFFFF6D00, // burnt orange
      0xFF37474F, // steel gray
      [
        'Steel',   'Forge',   'Anvil',    'Iron',    'Alloy',
        'Boulder', 'Granite', 'Basalt',   'Stone',   'Flint',
        'Golem',   'Colossus','Rampart',  'Bulwark', 'Aegis',
      ],
    ),
    TeamDefinition('GHOSTS', CreatureType.wraith,
      0xFF18FFFF, // electric cyan
      0xFF4527A0, // deep purple
      [
        'Wraith',  'Specter', 'Phantom',  'Spirit',  'Wisp',
        'Haunt',   'Drift',   'Echo',     'Mirage',  'Gloom',
        'Veil',    'Shroud',  'Mist',     'Vapor',   'Ether',
      ],
    ),
    TeamDefinition('INFERNO', CreatureType.kraken,
      0xFFFF1744, // vivid crimson
      0xFFFF6D00, // fire orange
      [
        'Blaze',   'Cinder',  'Ember',    'Flare',   'Forge',
        'Char',    'Scorch',  'Kindle',   'Brand',   'Pyre',
        'Smelt',   'Torch',   'Flame',    'Fuse',    'Burn',
      ],
    ),
    TeamDefinition('STORM', CreatureType.wraith,
      0xFFFFD600, // electric yellow
      0xFF1565C0, // navy blue
      [
        'Gale',    'Bolt',    'Thunder',  'Flash',   'Surge',
        'Squall',  'Gust',    'Cyclone',  'Torrent', 'Nimbus',
        'Tempest', 'Zephyr',  'Hail',     'Sleet',   'Frost',
      ],
    ),
  ];
}

class GameSettings {
  final MatchMode matchMode;

  final String homeTeamName;
  final String awayTeamName;
  final List<String> homePlayerNames;
  final List<String> awayPlayerNames;
  final CreatureType creatureType;
  final bool fastMode;
  final ViewMode viewMode;
  final bool useCubeModels; // full3D only: use single-cube placeholders instead of character rigs
  final AiStrategy homeStrategy;
  final AiTactics  homeTactics;
  final AiStrategy aiStrategy;
  final AiTactics aiTactics;
  // Roster order: indices 0-14 into playerNames. First 7 go on field, rest are reserves in sub order.
  final List<int> homeRosterOrder;
  final List<int> awayRosterOrder;
  // Class indices (0=Spectre … 6=Wrecker) excluded from the match entirely.
  final Set<int> inactiveClasses;
  final bool testMode;

  // Team colors — ARGB hex ints, resolved from TeamDefinition at construction.
  final int homeTeamPrimary;
  final int homeTeamSecondary;
  final int awayTeamPrimary;
  final int awayTeamSecondary;

  // Third team (3-team mode only)
  final String thirdTeamName;
  final List<String> thirdPlayerNames;
  final int thirdTeamPrimary;
  final int thirdTeamSecondary;
  final CreatureType thirdCreatureType;

  static List<String> _namesFor(String teamName) {
    final match = TeamDefinition.teams.where((t) => t.name == teamName).firstOrNull;
    return match?.playerNames ?? List.generate(15, (i) => 'P${i + 1}');
  }

  static int _primaryFor(String teamName) {
    final match = TeamDefinition.teams.where((t) => t.name == teamName).firstOrNull;
    return match?.primaryColor ?? 0xFF1E88E5;
  }

  static int _secondaryFor(String teamName) {
    final match = TeamDefinition.teams.where((t) => t.name == teamName).firstOrNull;
    return match?.secondaryColor ?? 0xFF0D47A1;
  }

  GameSettings({
    this.matchMode = MatchMode.twoTeams,
    required this.homeTeamName,
    required this.awayTeamName,
    List<String>? homePlayerNames,
    List<String>? awayPlayerNames,
    required this.creatureType,
    required this.fastMode,
    this.viewMode = ViewMode.full3D,
    this.useCubeModels = true,
    this.homeStrategy = AiStrategy.numericalEdge,
    this.homeTactics  = AiTactics.heroBall,
    this.aiStrategy   = AiStrategy.tempoTrap,
    this.aiTactics    = AiTactics.focusFire,
    List<int>? homeRosterOrder,
    List<int>? awayRosterOrder,
    Set<int>? inactiveClasses,
    this.testMode = false,
    int? homeTeamPrimary,
    int? homeTeamSecondary,
    int? awayTeamPrimary,
    int? awayTeamSecondary,
    String? thirdTeamName,
    List<String>? thirdPlayerNames,
    int? thirdTeamPrimary,
    int? thirdTeamSecondary,
    CreatureType? thirdCreatureType,
  })  : homePlayerNames   = homePlayerNames   ?? _namesFor(homeTeamName),
        awayPlayerNames   = awayPlayerNames   ?? _namesFor(awayTeamName),
        homeRosterOrder   = homeRosterOrder   ?? List.generate(15, (i) => i),
        awayRosterOrder   = awayRosterOrder   ?? List.generate(15, (i) => i),
        inactiveClasses   = inactiveClasses   ?? {},
        homeTeamPrimary   = homeTeamPrimary   ?? _primaryFor(homeTeamName),
        homeTeamSecondary = homeTeamSecondary ?? _secondaryFor(homeTeamName),
        awayTeamPrimary   = awayTeamPrimary   ?? _primaryFor(awayTeamName),
        awayTeamSecondary = awayTeamSecondary ?? _secondaryFor(awayTeamName),
        thirdTeamName     = thirdTeamName     ?? '',
        thirdPlayerNames  = thirdPlayerNames  ?? const [],
        thirdTeamPrimary  = thirdTeamPrimary  ?? 0xFF888888,
        thirdTeamSecondary= thirdTeamSecondary?? 0xFF444444,
        thirdCreatureType = thirdCreatureType ?? CreatureType.chaos;
}
