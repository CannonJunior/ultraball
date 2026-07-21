class_name AiDirector
extends Node

## Per-team AI coordinator.
## Updates at 10 Hz (not every physics frame) to reduce CPU cost.
## AI submits actions through player.apply_input() — it never calls AbilitySystem directly.

@export var team_id: int = 1
@export var strategy_resource: Resource    # AiStrategy subclass .tres
@export var tactics_resource: Resource     # AiTactics subclass .tres

var _strategy: AiStrategy = null
var _tactics: AiTactics = null
var _tick_timer: float = 0.0
const TICK_RATE: float = 0.1   # 10 Hz

## Policy parameters learned over matches (loaded from user://ai_policies.json)
var _policy: Dictionary = {}

func _ready() -> void:
	_strategy = strategy_resource as AiStrategy
	_tactics = tactics_resource as AiTactics
	_load_policy()

func _physics_process(delta: float) -> void:
	if not MatchState.match_active or MatchState.act_ended: return
	_tick_timer -= delta
	if _tick_timer > 0.0: return
	_tick_timer = TICK_RATE
	_update_ai()

func _update_ai() -> void:
	var view := AiView.build(team_id)
	for agent_pv in view.allies():
		var player_node := _find_player(agent_pv.player_id)
		if player_node == null: continue
		# In network play: skip players this client directly controls.
		# In offline mode (no peer): AI runs for all allies on this team.
		if multiplayer.has_multiplayer_peer() and player_node.is_multiplayer_authority():
			continue
		var input := _decide(agent_pv, view)
		player_node.apply_input(input)
		if input.queued_ability_slot > 0:
			EventBus.ability_queued.emit(agent_pv.player_id, input.queued_ability_slot)

func _decide(agent_pv: AiView.PlayerView, view: AiView) -> InputState:
	var goal := Vector2.ZERO
	if _strategy:
		goal = _strategy.evaluate_goal(agent_pv, view, _policy)
	if _tactics:
		return _tactics.produce_input(agent_pv, goal, view, _policy)
	# Fallback: move toward ball
	return _simple_move_toward(agent_pv, view.ball.position)

func _simple_move_toward(agent_pv: AiView.PlayerView, target: Vector2) -> InputState:
	var input := InputState.new()
	var dir := (target - agent_pv.position)
	if dir.length() > 0.5:
		input.move_direction = dir.normalized()
	return input

# ── Policy persistence ────────────────────────────────────────────────────────

func _load_policy() -> void:
	var path := "user://ai_policies.json"
	if not FileAccess.file_exists(path): return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null: return
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		_policy = data.get(str(team_id), {})

func save_policy() -> void:
	var path := "user://ai_policies.json"
	var existing := {}
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		var data = JSON.parse_string(f.get_as_text())
		if data is Dictionary:
			existing = data
	existing[str(team_id)] = _policy
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(existing))

# ── Helper ─────────────────────────────────────────────────────────────────────

func _find_player(pid: String) -> Node:
	for n in get_tree().get_nodes_in_group("players"):
		if n.player_id == pid: return n
	return null
