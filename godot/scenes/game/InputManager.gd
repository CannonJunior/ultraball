class_name InputManager
extends Node

## Local input handler for the human-controlled player.
## Offline: applies input directly to the player node.
## Network client: applies locally (for prediction) and submits InputPacket to server.

const ABILITY_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5,
								   KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]

func _physics_process(_delta: float) -> void:
	var player := _local_player()
	if player == null:
		return

	var state := InputState.new()
	state.move_direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	state.hold_throw    = Input.is_action_pressed("ui_accept")
	state.release_throw = Input.is_action_just_released("ui_accept")

	# Always apply locally (offline authority or client prediction)
	player.apply_input(state)

	if NetworkManager.mode != NetworkManager.NetMode.OFFLINE and not multiplayer.is_server():
		# Record predicted state before server corrects it
		var predictor := get_tree().get_first_node_in_group("client_predictors") as ClientPredictor
		if predictor:
			predictor.record_prediction(get_tree().get_frame(), player, state)
		# Submit to server
		var packet := state.to_packet(
			get_tree().get_frame(),
			NetworkManager.local_player_id,
			multiplayer.get_unique_id()
		)
		NetworkManager.submit_input.rpc_id(1, packet.serialize())

func _unhandled_key_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	var player := _local_player()
	if player == null:
		return
	for i in ABILITY_KEYS.size():
		if key_event.physical_keycode == ABILITY_KEYS[i]:
			var state := InputState.new()
			state.queued_ability_slot = i + 1
			player.apply_input(state)
			if NetworkManager.mode != NetworkManager.NetMode.OFFLINE and not multiplayer.is_server():
				var packet := state.to_packet(
					get_tree().get_frame(),
					NetworkManager.local_player_id,
					multiplayer.get_unique_id()
				)
				NetworkManager.submit_input.rpc_id(1, packet.serialize())
			return

func _local_player() -> Node:
	var target_id := NetworkManager.local_player_id
	if not target_id.is_empty():
		for n in get_tree().get_nodes_in_group("players"):
			if n.player_id == target_id and n.is_alive and n.is_on_field:
				return n
		return null
	# Offline fallback: first alive home-team player
	for n in get_tree().get_nodes_in_group("players"):
		if n.team_id == 0 and n.is_alive and n.is_on_field:
			return n
	return null
