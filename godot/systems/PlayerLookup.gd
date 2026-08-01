class_name PlayerLookup

## Single implementation of the player-node-by-id lookup shared across all systems.
## Caches results for the duration of each physics frame so each group scan
## happens at most once per tick regardless of how many systems call in.

static var _cache: Dictionary = {}    # player_id → Node
static var _cache_frame: int = -1

static func _ensure_fresh() -> void:
	var f := Engine.get_physics_frames()
	if _cache_frame == f:
		return
	_cache.clear()
	for n in Engine.get_main_loop().current_scene.get_tree().get_nodes_in_group("players"):
		_cache[n.player_id] = n
	_cache_frame = f

static func get_node(pid: String) -> Node:
	_ensure_fresh()
	var n: Node = _cache.get(pid)
	return n if n != null and is_instance_valid(n) else null

static func get_position(pid: String) -> Vector2:
	var n := get_node(pid)
	return n.global_position if n else Vector2.ZERO

## Returns all cached player nodes as an array — callers that need to iterate
## every player should use this instead of their own get_nodes_in_group call.
static func get_all_nodes() -> Array:
	_ensure_fresh()
	return _cache.values()
