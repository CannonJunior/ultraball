class_name MatchConfig
extends Resource

enum MatchMode { TWO_TEAM, THREE_TEAM }

@export_enum("TwoTeam", "ThreeTeam") var match_mode: int = 0
@export var fast_mode: bool = false

@export var home_team_name: String = "HOME"
@export var away_team_name: String = "AWAY"
@export var third_team_name: String = "THIRD"

## 15 player names per team
@export var home_player_names: PackedStringArray
@export var away_player_names: PackedStringArray
@export var third_player_names: PackedStringArray

## Class indices excluded from roster generation (empty = all classes available)
@export var inactive_class_indices: PackedInt32Array

## AI configuration per team (0=HOME 1=AWAY 2=THIRD)
@export var ai_strategy_resources: Array[Resource]   # Array[AiStrategy]
@export var ai_tactics_resources: Array[Resource]    # Array[AiTactics]

## Which teams are human-controlled (true) vs AI (false)
@export var is_human_controlled: Array[bool] = [true, false, false]

## Creature type: 0=Kraken 1=Dragon 2=Hydra 3=Wraith 4=Chaos
@export_enum("Kraken","Dragon","Hydra","Wraith","Chaos") var creature_type: int = 0
