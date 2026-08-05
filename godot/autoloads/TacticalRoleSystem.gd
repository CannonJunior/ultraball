extends Node

const ROLE_NONE        := 0
const ROLE_CARRIER     := 1
const ROLE_SHOT_CALLER := 2
const ROLE_FOCUS_FIRE  := 3
const ROLE_SHADOW      := 4

const ROLE_LABEL := {
	0: "AUTO",
	1: "CARRIER",
	2: "SHOT-CALL",
	3: "FOCUS FIRE",
	4: "SHADOW",
}

const ROLE_SHORT := {
	0: "AUTO",
	1: "CARRY",
	2: "SHOT",
	3: "FOCUS",
	4: "SHADOW",
}

const ROLE_HOTKEY := {
	1: "C",
	2: "V",
	3: "F",
	4: "R",
}

## True while the TRM is visible — InputManager checks this to block normal input.
var trm_is_open: bool = false
## True while the SRM is visible.
var srm_is_open: bool = false

## player_id → role int
var _roles: Dictionary = {}

## The player_id that ROLE_SHADOW units shadow (set to local player when shadow is assigned).
var shadow_source_id: String = ""

func _ready() -> void:
	EventBus.positions_reset.connect(_on_positions_reset)

func set_role(player_id: String, role: int) -> void:
	if role == ROLE_NONE:
		_roles.erase(player_id)
	else:
		_roles[player_id] = role
	EventBus.tactical_role_assigned.emit(player_id, role)

func get_role(player_id: String) -> int:
	return _roles.get(player_id, ROLE_NONE)

func clear_all() -> void:
	_roles.clear()

func _on_positions_reset() -> void:
	pass  # Role assignments persist across acts — they represent match-long intent.
