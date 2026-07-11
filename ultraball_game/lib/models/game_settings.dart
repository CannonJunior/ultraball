import 'creature.dart';
import '../ai/ai_strategy.dart';

enum ViewMode { flat, threeQuarter, full3D }

class TeamDefinition {
  final String name;
  final CreatureType creatureType;
  final List<String> playerNames; // 15 names: slot (i % 7) → SPECTRE, CORSAIR, GEOMANCER, ARCHON, WARDEN, TRICKSTER, WRECKER

  const TeamDefinition(this.name, this.creatureType, this.playerNames);

  static const List<TeamDefinition> teams = [
    TeamDefinition('VIPERS', CreatureType.kraken, [
      'Fang',    'Venom',   'Cobra',    'Asp',     'Adder',
      'Mamba',   'Python',  'Anaconda', 'Boa',     'Taipan',
      'Scales',  'Coil',    'Rattle',   'Hiss',    'Pit',
    ]),
    TeamDefinition('REAPERS', CreatureType.dragon, [
      'Scythe',  'Grim',    'Shade',    'Mort',    'Dusk',
      'Reap',    'Doom',    'Skull',    'Gore',    'Bone',
      'Crypt',   'Void',    'Hex',      'Ash',     'Blood',
    ]),
    TeamDefinition('TITANS', CreatureType.hydra, [
      'Steel',   'Forge',   'Anvil',    'Iron',    'Alloy',
      'Boulder', 'Granite', 'Basalt',   'Stone',   'Flint',
      'Golem',   'Colossus','Rampart',  'Bulwark', 'Aegis',
    ]),
    TeamDefinition('GHOSTS', CreatureType.wraith, [
      'Wraith',  'Specter', 'Phantom',  'Spirit',  'Wisp',
      'Haunt',   'Drift',   'Echo',     'Mirage',  'Gloom',
      'Veil',    'Shroud',  'Mist',     'Vapor',   'Ether',
    ]),
  ];
}

class GameSettings {
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

  static List<String> _namesFor(String teamName) {
    final match = TeamDefinition.teams.where((t) => t.name == teamName).firstOrNull;
    return match?.playerNames ?? List.generate(15, (i) => 'P${i + 1}');
  }

  GameSettings({
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
  })  : homePlayerNames = homePlayerNames ?? _namesFor(homeTeamName),
        awayPlayerNames = awayPlayerNames ?? _namesFor(awayTeamName),
        homeRosterOrder = homeRosterOrder ?? List.generate(15, (i) => i),
        awayRosterOrder = awayRosterOrder ?? List.generate(15, (i) => i),
        inactiveClasses = inactiveClasses ?? {};
}
