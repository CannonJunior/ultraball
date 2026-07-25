class_name InputManager
extends Node

## Local input handler for the human-controlled player.

var _lost_control_logged: bool = false
## Offline: applies input directly to the player node.
## Network client: applies locally (for prediction) and submits InputPacket to server.

func _ready() -> void:
	# Must always process so ESC can unpause the tree.
	process_mode = Node.PROCESS_MODE_ALWAYS

func _physics_process(_delta: float) -> void:
	if MatchState.is_paused:
		return
	var player := _local_player()
	if player == null:
		return

	var state := InputState.new()
	state.move_direction = Vector2(
		Input.get_axis("strafe_left", "strafe_right"),
		Input.get_axis("move_up", "move_down"))
	state.turn_delta    = Input.get_axis("move_left", "move_right")

	# In 3D view modes the 2D-Y → 3D-Z flip visually mirrors turning and
	# strafe direction; negate both so A/D/Q/E feel correct from the 3D camera.
	if MatchState.config != null and MatchState.config.view_mode != MatchConfig.ViewMode.FLAT_2D:
		state.turn_delta       = -state.turn_delta
		state.move_direction.x = -state.move_direction.x
	state.jump_pressed  = Input.is_action_just_pressed("jump")
	state.hold_throw    = Input.is_action_pressed("throw_ball")
	state.release_throw = Input.is_action_just_released("throw_ball")

	# Ability slots 1–9, then ultra (slot 10)
	for i in range(1, 10):
		if Input.is_action_just_pressed("ability_" + str(i)):
			state.queued_ability_slot = i
			break
	if state.queued_ability_slot == 0 and Input.is_action_just_pressed("ability_ultra"):
		state.queued_ability_slot = 10

	player.apply_input(state)

	if NetworkManager.mode != NetworkManager.NetMode.OFFLINE and not multiplayer.is_server():
		var predictor := get_tree().get_first_node_in_group("client_predictors") as ClientPredictor
		if predictor:
			predictor.record_prediction(get_tree().get_frame(), player, state)
		var packet := state.to_packet(
			get_tree().get_frame(),
			NetworkManager.local_player_id,
			multiplayer.get_unique_id())
		NetworkManager.submit_input.rpc_id(1, packet.serialize())

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		MatchState.is_paused = !MatchState.is_paused
		get_tree().paused = MatchState.is_paused
		EventBus.game_paused.emit(MatchState.is_paused)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("player_switch"):
		_cycle_player()
	if event.is_action_pressed("target_next"):
		var p := _local_player()
		if p:
			p.cycle_target()

func _cycle_player() -> void:
	var alive: Array = []
	for n in get_tree().get_nodes_in_group("players"):
		if n.team_id == 0 and n.is_alive and n.is_on_field:
			alive.append(n)
	if alive.size() < 2:
		return
	var cur := NetworkManager.local_player_id
	var idx := -1
	for i in alive.size():
		if alive[i].player_id == cur:
			idx = i
			break
	NetworkManager.local_player_id = alive[(idx + 1) % alive.size()].player_id

func _local_player() -> Node:
	var pid := NetworkManager.local_player_id
	if not pid.is_empty():
		for n in get_tree().get_nodes_in_group("players"):
			if n.player_id == pid and n.is_alive and n.is_on_field:
				return n
		# Found local_player_id but player is dead/off-field — log once per state change.
		if not _lost_control_logged:
			_lost_control_logged = true
			print("[INPUT] local_player_id=%s is dead or off-field — no controlled player" % pid)
		return null
	_lost_control_logged = false
	# Offline fallback: first alive home-team player
	for n in get_tree().get_nodes_in_group("players"):
		if n.team_id == 0 and n.is_alive and n.is_on_field:
			return n
	return null
