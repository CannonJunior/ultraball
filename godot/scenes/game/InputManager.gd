class_name InputManager
extends Node

## Local input handler for the human-controlled player.

var _lost_control_logged: bool = false
## Offline: applies input directly to the player node.
## Network client: applies locally (for prediction) and submits InputPacket to server.

## Chargeable ability tracking
var _charging_slot: int = 0
var _charge_timer: float = 0.0

## Tracks the previously-controlled player id to detect unit switches after death.
var _prev_pid: String = ""

func _ready() -> void:
	# Must always process so ESC can unpause the tree.
	process_mode = Node.PROCESS_MODE_ALWAYS

func _physics_process(delta: float) -> void:
	if MatchState.is_paused:
		return
	var player := _local_player()
	_detect_player_switch()
	if player == null:
		return

	# Charge tick — runs before other input so release is handled immediately.
	if _charging_slot > 0:
		_charge_timer += delta
		var action := "ability_ultra" if _charging_slot == 10 else "ability_" + str(_charging_slot)
		if Input.is_action_just_released(action):
			var charge_max := _ability_charge_max(player, _charging_slot)
			var charge_t := minf(_charge_timer, charge_max)
			EventBus.ability_charge_released.emit(player.player_id, _charging_slot, charge_t)
			_charging_slot = 0
			_charge_timer  = 0.0
		var turn_delta := Input.get_axis("move_left", "move_right")
		if MatchState.config != null and MatchState.config.view_mode != MatchConfig.ViewMode.FLAT_2D:
			turn_delta = -turn_delta
		if absf(turn_delta) > 0.01:
			var turn_state := InputState.new()
			turn_state.turn_delta = turn_delta
			player.apply_input(turn_state)
		return  # don't process normal input while charging

	# "Pass to me" — C just pressed while a teammate holds the ball.
	# Skipped when TRM is open (C is the Carrier role hotkey there).
	if not TacticalRoleSystem.trm_is_open and Input.is_action_just_pressed("throw_ball"):
		var ball := MatchState.ball
		if not ball.holder_id.is_empty() and ball.holder_id != player.player_id:
			if MatchState.team_for_player(ball.holder_id) == player.team_id:
				EventBus.pass_to_player_requested.emit(ball.holder_id, player.player_id)
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
	if not TacticalRoleSystem.trm_is_open:
		state.hold_throw    = Input.is_action_pressed("throw_ball")
		state.release_throw = Input.is_action_just_released("throw_ball")

	# Ability slots 1–9, then ultra (slot 10)
	for i in range(1, 10):
		if Input.is_action_just_pressed("ability_" + str(i)):
			if _ability_charge_max(player, i) > 0.0:
				_charging_slot = i
				_charge_timer  = 0.0
				EventBus.ability_charge_started.emit(player.player_id, i, _ability_charge_max(player, i))
			else:
				state.queued_ability_slot = i
			break
	if state.queued_ability_slot == 0 and _charging_slot == 0 \
			and Input.is_action_just_pressed("ability_ultra"):
		state.queued_ability_slot = 10

	state.hold_ultra    = Input.is_action_pressed("ability_ultra")
	state.release_ultra = Input.is_action_just_released("ability_ultra")

	# `: pop the last queued ability. Backspace: defense-fill the queue.
	if Input.is_action_just_pressed("ability_cancel"):
		EventBus.ability_queue_pop.emit(player.player_id)
	if Input.is_action_just_pressed("ability_defense_fill"):
		EventBus.ability_queue_defense_fill.emit(player.player_id)

	# Only override AI input when the user is actively pressing something.
	var has_input := state.move_direction.length_squared() > 0.01 \
		or absf(state.turn_delta) > 0.01 \
		or state.jump_pressed or state.hold_throw or state.release_throw \
		or state.queued_ability_slot > 0 \
		or state.hold_ultra or state.release_ultra
	if not has_input:
		return

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
	var cur := NetworkManager.local_player_id
	var my_team := 0
	if not cur.is_empty():
		my_team = int(cur.split("_")[0])
	var alive: Array = []
	for n in get_tree().get_nodes_in_group("players"):
		if n.team_id == my_team and n.is_alive and n.is_on_field:
			alive.append(n)
	if alive.is_empty():
		return
	var idx := -1
	for i in alive.size():
		if alive[i].player_id == cur:
			idx = i
			break
	NetworkManager.local_player_id = alive[(idx + 1) % alive.size()].player_id

func _detect_player_switch() -> void:
	var cur_pid := NetworkManager.local_player_id
	if cur_pid == _prev_pid:
		_prev_pid = cur_pid
		return
	if not _prev_pid.is_empty() and not cur_pid.is_empty():
		var old_rec: MatchState.PlayerRecord = MatchState.players.get(_prev_pid)
		if old_rec != null and not old_rec.is_alive:
			EventBus.local_player_switched.emit(cur_pid)
	_prev_pid = cur_pid

func _ability_charge_max(player: Node, slot: int) -> float:
	var rec: MatchState.PlayerRecord = MatchState.players.get(player.player_id)
	if rec == null: return 0.0
	var def: AbilityDefinition = GameRegistry.get_ability(rec.class_id, slot)
	if def == null: return 0.0
	return def.charge_max

func _local_player() -> Node:
	var pid := NetworkManager.local_player_id
	if not pid.is_empty():
		for n in get_tree().get_nodes_in_group("players"):
			if n.player_id == pid and n.is_alive and n.is_on_field:
				_lost_control_logged = false
				return n
		# In offline mode, auto-follow the substitute so the human stays in control.
		if NetworkManager.mode == NetworkManager.NetMode.OFFLINE:
			var my_team := int(pid.split("_")[0])
			for n in get_tree().get_nodes_in_group("players"):
				if n.team_id == my_team and n.is_alive and n.is_on_field:
					NetworkManager.local_player_id = n.player_id
					_lost_control_logged = false
					return n
		# Online: the player is dead/off-field — log once per state change.
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
