import 'creature.dart';

class GameSettings {
  final String homeTeamName;
  final String awayTeamName;
  final CreatureType creatureType;
  final bool fastMode;

  const GameSettings({
    required this.homeTeamName,
    required this.awayTeamName,
    required this.creatureType,
    required this.fastMode,
  });
}
