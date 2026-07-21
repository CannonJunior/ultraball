class_name CreatureSystem
extends Node

## Creature kill detection and goading.
## Creature movement logic lives in Creature.gd / ChaosCreature.gd (entity layer).

const KILL_RADIUS := 2.5   # metres — creature contact radius

## Goading: temporarily override patrol target toward a player.
var _goad_target_id: String = ""
var _goad_timer: float = 0.0

func _ready() -> void:
	EventBus.creature_goaded.connect(_on_creature_goaded)
	EventBus.creature_direction_reversed.connect(_on_creature_direction_reversed)

func _physics_process(delta: float) -> void:
	if not MatchState.match_active: return
	_tick_goad(delta)
	_check_kills()

func _tick_goad(delta: float) -> void:
	if _goad_timer > 0.0:
		_goad_timer -= delta
		if _goad_timer <= 0.0:
			_goad_target_id = ""
			for creature in get_tree().get_nodes_in_group("creatures"):
				creature.clear_goad_target()

func _check_kills() -> void:
	var creatures := get_tree().get_nodes_in_group("creatures")
	for creature in creatures:
		for player in get_tree().get_nodes_in_group("players"):
			if not player.is_alive or not player.is_on_field: continue
			if creature.global_position.distance_to(player.global_position) <= KILL_RADIUS:
				EventBus.creature_killed_player.emit(player.player_id, player.team_id)
				EventBus.player_died.emit(player.player_id, "creature", "")

func _on_creature_goaded(target_player_id: String, duration: float) -> void:
	_goad_target_id = target_player_id
	_goad_timer = duration
	var target_node := _get_player_node(target_player_id)
	if target_node == null: return
	for creature in get_tree().get_nodes_in_group("creatures"):
		creature.set_goad_target(target_node.global_position)

func _on_creature_direction_reversed(_duration: float) -> void:
	for creature in get_tree().get_nodes_in_group("creatures"):
		creature.reverse_patrol()

func get_goad_target_position() -> Vector2:
	if _goad_target_id.is_empty(): return Vector2.ZERO
	var node := _get_player_node(_goad_target_id)
	return node.global_position if node else Vector2.ZERO

func _get_player_node(pid: String) -> Node:
	for n in get_tree().get_nodes_in_group("players"):
		if n.player_id == pid: return n
	return null
