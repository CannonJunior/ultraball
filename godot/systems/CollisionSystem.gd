class_name CollisionSystem
extends Node

## Pure physics: player-player overlap separation.
## No EventBus signals needed — purely positional correction.
## Mirrors the 3-pass pushback from the original collision_system.dart.

const PLAYER_RADIUS := 1.0   # metres
const PASSES := 3

func _physics_process(_delta: float) -> void:
	if not MatchState.match_active: return
	var players := get_tree().get_nodes_in_group("players")
	for _pass in PASSES:
		_resolve_pass(players)

func _resolve_pass(players: Array) -> void:
	for i in players.size():
		var a: Node = players[i]
		if not a.is_alive or not a.is_on_field: continue
		for j in range(i + 1, players.size()):
			var b: Node = players[j]
			if not b.is_alive or not b.is_on_field: continue
			_separate(a, b)

func _separate(a: Node, b: Node) -> void:
	var delta: Vector2 = b.global_position - a.global_position
	var dist := delta.length()
	var min_dist := PLAYER_RADIUS * 2.0
	if dist >= min_dist or dist < 0.001:
		return
	var push := delta.normalized() * (min_dist - dist) * 0.5
	a.global_position -= push
	b.global_position += push
