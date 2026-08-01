class_name CollisionSystem
extends Node

## Pure physics: player-player overlap separation.
## No EventBus signals needed — purely positional correction.
## Mirrors the 3-pass pushback from the original collision_system.dart.

const PlayerLookup = preload("res://systems/PlayerLookup.gd")

const PLAYER_RADIUS := 1.0   # metres
const PASSES := 3

const _MIN_DIST    := PLAYER_RADIUS * 2.0
const _MIN_DIST_SQ := _MIN_DIST * _MIN_DIST

func _physics_process(_delta: float) -> void:
	if not MatchState.match_active: return
	var players := PlayerLookup.get_all_nodes()
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
	var dist_sq := delta.length_squared()
	if dist_sq >= _MIN_DIST_SQ or dist_sq < 0.000001:
		return
	var dist := sqrt(dist_sq)   # sqrt deferred to here — most pairs pass the early exit
	var push := delta.normalized() * (_MIN_DIST - dist) * 0.5
	a.global_position -= push
	b.global_position += push
