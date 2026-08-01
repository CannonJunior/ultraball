class_name MatchConfig
extends Resource

enum MatchMode { TWO_TEAM, THREE_TEAM }
enum ViewMode  { FLAT_2D = 0, THREE_QUARTER = 1, FULL_3D = 2 }


@export_enum("TwoTeam", "ThreeTeam") var match_mode: int = 0
@export var fast_mode: bool = false
@export var test_mode: bool = false
@export var players_per_side: int = 7

@export var home_team_name: String = "HOME"
@export var away_team_name: String = "AWAY"
@export var third_team_name: String = "THIRD"

@export var home_team_idx: int = 0
@export var away_team_idx: int = 1
@export var third_team_idx: int = 2

## 15 player names per team
@export var home_player_names: PackedStringArray
@export var away_player_names: PackedStringArray
@export var third_player_names: PackedStringArray

## Roster-ordered player indices per team (determines class per slot).
## home_class_indices[slot] = player_idx whose class fills that slot.
@export var home_class_indices: PackedInt32Array
@export var away_class_indices: PackedInt32Array

## Class indices excluded from roster generation (empty = all classes available)
@export var inactive_class_indices: PackedInt32Array

## AI configuration per team (0=HOME 1=AWAY 2=THIRD)
@export var ai_strategy_resources: Array[Resource]   # Array[AiStrategy]
@export var ai_tactics_resources: Array[Resource]    # Array[AiTactics]

## Which teams are human-controlled (true) vs AI (false)
@export var is_human_controlled: Array[bool] = [true, false, false]

## Creature type: 0=Kraken 1=Dragon 2=Hydra 3=Wraith 4=Chaos
@export_enum("Kraken","Dragon","Hydra","Wraith","Chaos") var creature_type: int = 0

## Visualization: 0=2D top-down  1=3/4 perspective  2=3D broadcast
@export_enum("2D", "3/4", "3D") var view_mode: int = 0

func to_dict() -> Dictionary:
	return {
		"match_mode": match_mode, "fast_mode": fast_mode, "test_mode": test_mode,
		"players_per_side": players_per_side,
		"home_team_name": home_team_name, "away_team_name": away_team_name,
		"third_team_name": third_team_name,
		"home_team_idx": home_team_idx, "away_team_idx": away_team_idx,
		"third_team_idx": third_team_idx,
		"home_player_names": Array(home_player_names),
		"away_player_names": Array(away_player_names),
		"third_player_names": Array(third_player_names),
		"home_class_indices": Array(home_class_indices),
		"away_class_indices": Array(away_class_indices),
		"inactive_class_indices": Array(inactive_class_indices),
		"creature_type": creature_type, "view_mode": view_mode,
		"is_human_controlled": is_human_controlled.duplicate(),
	}

static func from_dict(d: Dictionary) -> MatchConfig:
	var cfg := MatchConfig.new()
	cfg.match_mode             = d.get("match_mode", 0)
	cfg.fast_mode              = d.get("fast_mode", false)
	cfg.test_mode              = d.get("test_mode", false)
	cfg.players_per_side       = d.get("players_per_side", 7)
	cfg.home_team_name         = d.get("home_team_name", "HOME")
	cfg.away_team_name         = d.get("away_team_name", "AWAY")
	cfg.third_team_name        = d.get("third_team_name", "THIRD")
	cfg.home_team_idx          = d.get("home_team_idx", 0)
	cfg.away_team_idx          = d.get("away_team_idx", 1)
	cfg.third_team_idx         = d.get("third_team_idx", 2)
	cfg.home_player_names      = PackedStringArray(d.get("home_player_names", []))
	cfg.away_player_names      = PackedStringArray(d.get("away_player_names", []))
	cfg.third_player_names     = PackedStringArray(d.get("third_player_names", []))
	cfg.home_class_indices     = PackedInt32Array(d.get("home_class_indices", []))
	cfg.away_class_indices     = PackedInt32Array(d.get("away_class_indices", []))
	cfg.inactive_class_indices = PackedInt32Array(d.get("inactive_class_indices", []))
	cfg.creature_type          = d.get("creature_type", 0)
	cfg.view_mode              = d.get("view_mode", 0)
	cfg.is_human_controlled    = d.get("is_human_controlled", [true, false, false])
	return cfg
