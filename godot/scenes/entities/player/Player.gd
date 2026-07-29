class_name Player
extends CharacterBody2D

## Core player entity.
## Movement, input application, and field clamping only.
## Buff/debuff timers → PlayerBuffs; mana → PlayerMana; cooldowns → PlayerAbilities.

@export var player_id: String = ""
@export var team_id: int = 0
@export var class_definition: ClassDefinition

@onready var buffs: PlayerBuffs = $PlayerBuffs
@onready var mana: PlayerMana = $PlayerMana
@onready var abilities: PlayerAbilities = $PlayerAbilities
@onready var visual: Node2D = $PlayerVisual

## Current targeting state (read by AbilitySystem)
var current_target_id: String = ""
var aim_world_position: Vector2 = Vector2.ZERO

## Explicit target locked in by the player via target_next; overrides proximity auto-target.
var _explicit_target_id: String = ""

var is_alive: bool = true
var is_on_field: bool = false

## Input state applied this frame (set by InputManager or AI)
var _current_input: InputState = InputState.new()

## While > 0, movement input cannot override an in-flight impulse (knockback/dash).
var _impulse_timer: float = 0.0

## Jump / Z-axis state
var z_height: float = 0.0
var z_velocity: float = 0.0
var _can_double_jump: bool = false
const JUMP_VELOCITY    := 6.0
const Z_GRAVITY        := 12.0
const DOUBLE_JUMP_COST := 15.0

## Field bounds (2-team mode defaults; overridden for 3-team)
## y∈[−10,50] includes the side creature channels outside the main field.
var field_min: Vector2 = Vector2(0.0, -10.0)
var field_max: Vector2 = Vector2(140.0, 50.0)

func _ready() -> void:
	add_to_group("players")
	if MatchState.is_three_team:
		field_min = Vector2(0.0, 0.0)
		field_max = Vector2(MatchState.FIELD3_SIZE, MatchState.FIELD3_SIZE)
	EventBus.player_died.connect(_on_player_died)
	EventBus.player_subbed_in.connect(_on_player_subbed_in)
	add_child(load("res://scenes/entities/player/TargetRing.gd").new())

func _physics_process(delta: float) -> void:
	if not is_alive or not is_on_field: return
	if not multiplayer.is_server():
		# Network client: only process the locally-owned player (client prediction).
		if NetworkManager.mode != NetworkManager.NetMode.OFFLINE:
			if player_id != NetworkManager.local_player_id: return
		elif not is_multiplayer_authority():
			return

	_apply_movement(delta)
	_update_z(delta)
	_block_steep_terrain()
	move_and_slide()
	_clamp_to_field()

	# Throw release
	if _current_input.release_throw and MatchState.ball.holder_id == player_id:
		var is_charged := MatchState.ball.charge_timer > 1.0
		var throw_dir: Vector2
		if _current_input.is_aiming and _current_input.aim_world_position != Vector2.ZERO:
			throw_dir = (_current_input.aim_world_position - global_position).normalized()
		else:
			throw_dir = Vector2(0.0, -1.0).rotated(rotation)
		EventBus.throw_requested.emit(player_id, throw_dir, is_charged)

	# Ability queue input
	if _current_input.queued_ability_slot > 0:
		EventBus.ability_queued.emit(player_id, _current_input.queued_ability_slot)

	# Force field anchor: key released → anchor the active force field
	if _current_input.release_ultra:
		EventBus.force_field_anchor_requested.emit(player_id)

	_update_auto_target()
	aim_world_position = _current_input.aim_world_position if _current_input.is_aiming \
		else global_position + Vector2(0.0, -1.0).rotated(rotation) * 15.0

	_current_input = InputState.new()   # consume input

# ── Input interface ────────────────────────────────────────────────────────────

func apply_input(input: InputState) -> void:
	_current_input = input

# ── Movement ──────────────────────────────────────────────────────────────────

func _apply_movement(delta: float) -> void:
	if buffs.stun_timer > 0.0:
		velocity = Vector2.ZERO
		_impulse_timer = 0.0
		return

	if _impulse_timer > 0.0:
		_impulse_timer -= delta
		return

	var speed := _effective_speed()
	var confused := buffs.confused_timer > 0.0
	var flip := -1.0 if confused else 1.0

	rotation += _current_input.turn_delta * deg_to_rad(150.0) * delta * flip

	var dir := _current_input.move_direction
	if dir.length_squared() > 0.01:
		dir = dir.normalized().rotated(rotation)
		velocity = dir * speed
	else:
		velocity = velocity.move_toward(Vector2.ZERO, speed * 4.0 * delta)

	if _current_input.jump_pressed:
		if z_height <= 0.0:
			z_velocity = JUMP_VELOCITY
			_can_double_jump = true
		elif _can_double_jump and mana.can_afford(2, DOUBLE_JUMP_COST):
			z_velocity = JUMP_VELOCITY
			mana.deduct(2, DOUBLE_JUMP_COST)
			_can_double_jump = false

func _effective_speed() -> float:
	if class_definition == null: return 8.0
	return class_definition.base_speed * buffs.get_speed_multiplier() * _terrain_speed_mult()

func _terrain_speed_mult() -> float:
	var col := int(global_position.x / 5.0)
	var row := int(global_position.y / 5.0)
	col = clampi(col, 0, 27)
	row = clampi(row, 0, 7)
	var t := MatchState.terrain
	if t.cell_speed_mults.size() < 224: return 1.0
	var cell_idx := row * 28 + col
	var grid_mult := t.cell_speed_mults[cell_idx]
	# Geomancers are immune to their own Quagmire (mud surface type == 2)
	if grid_mult < 1.0 and t.cell_surface_types[cell_idx] == 2 \
			and class_definition != null and class_definition.class_id == "geomancer":
		grid_mult = 1.0
	# Fine elevation penalty: hills slow slightly, valleys slow more
	var elev := _elevation_at(global_position)
	var elev_mult := 1.0
	if elev > 0.0:
		elev_mult = maxf(0.5, 1.0 - elev * 0.08)
	elif elev < 0.0:
		elev_mult = maxf(0.4, 1.0 + elev * 0.1)
	return grid_mult * elev_mult

func _elevation_at(pos: Vector2) -> float:
	const ELEV_COLS := 168
	const ELEV_ROWS := 48
	const ELEV_CELL_W := 140.0 / ELEV_COLS
	const ELEV_CELL_H :=  40.0 / ELEV_ROWS
	var elev := MatchState.terrain.elevation_heights
	if elev.size() < ELEV_COLS * ELEV_ROWS: return 0.0
	var col := clampi(int(pos.x / ELEV_CELL_W), 0, ELEV_COLS - 1)
	var row := clampi(int(pos.y / ELEV_CELL_H), 0, ELEV_ROWS - 1)
	return elev[row * ELEV_COLS + col]

func _update_z(delta: float) -> void:
	if z_height > 0.0 or z_velocity > 0.0:
		z_velocity -= Z_GRAVITY * delta
		z_height = maxf(0.0, z_height + z_velocity * delta)

func _block_steep_terrain() -> void:
	if velocity.length_squared() < 0.01: return
	const LOOK_DIST := 140.0 / 168.0  # one fine-elevation cell ≈ 0.833 m
	var ahead := global_position + velocity.normalized() * LOOK_DIST
	var elev_ahead := _elevation_at(ahead)
	var elev_here  := _elevation_at(global_position)
	if elev_ahead - elev_here > z_height + 0.4:
		velocity = Vector2.ZERO

# ── Field clamping ────────────────────────────────────────────────────────────

func _clamp_to_field() -> void:
	global_position.x = clampf(global_position.x, field_min.x, field_max.x)
	if MatchState.is_three_team:
		global_position.y = clampf(global_position.y, field_min.y, field_max.y)
		return
	var has_ball    := MatchState.ball != null and MatchState.ball.holder_id == player_id
	var in_endzone  := global_position.x < 20.0 or global_position.x > 120.0
	if has_ball or in_endzone:
		# Ball carriers and endzone units cannot enter the side creature channels.
		global_position.y = clampf(global_position.y, 0.0, 40.0)
	else:
		# Non-carriers in the inner field/end-channels can access side creature channels.
		global_position.y = clampf(global_position.y, field_min.y, field_max.y)

# ── State capture for network ─────────────────────────────────────────────────

func capture_state() -> Dictionary:
	return {
		"player_id": player_id,
		"position": global_position,
		"rotation": rotation,
		"velocity": velocity,
		"health": buffs.health,
		"is_alive": is_alive,
	}

# ── Event listeners ───────────────────────────────────────────────────────────

func _on_player_died(pid: String, _cause: String, _killer: String) -> void:
	if pid != player_id: return
	is_alive = false
	is_on_field = false
	hide()

func _on_player_subbed_in(pid: String, _replaced: String, _team: int) -> void:
	if pid != player_id: return
	is_alive = true
	is_on_field = true
	global_position = _spawn_position()
	z_height = 0.0
	z_velocity = 0.0
	_can_double_jump = false
	show()

func _spawn_position() -> Vector2:
	if MatchState.is_three_team:
		var norm: Vector2 = MatchState.TEAM3_NORMALS[team_id]
		var dist := MatchState.FIELD3_INRADIUS + 25.0
		return Vector2(MatchState.FIELD3_CX + norm.x * dist, MatchState.FIELD3_CY + norm.y * dist)
	if team_id == 0:
		return Vector2(10.0, 20.0)
	return Vector2(130.0, 20.0)

# ── Targeting ─────────────────────────────────────────────────────────────────

func set_explicit_target(pid: String) -> void:
	_explicit_target_id = pid

## Cycle explicit target through living enemies, sorted by current distance.
func cycle_target() -> void:
	var enemies: Array = []
	for node in get_tree().get_nodes_in_group("players"):
		if not node.is_alive or not node.is_on_field: continue
		if node.team_id == team_id: continue
		enemies.append(node)
	if enemies.is_empty():
		_explicit_target_id = ""
		return
	enemies.sort_custom(func(a, b):
		return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position))
	var cur_idx := -1
	for i in enemies.size():
		if enemies[i].player_id == _explicit_target_id:
			cur_idx = i
			break
	_explicit_target_id = enemies[(cur_idx + 1) % enemies.size()].player_id

func _update_auto_target() -> void:
	# Validate explicit target — clear if they left the field or died.
	if not _explicit_target_id.is_empty():
		var still_valid := false
		if _explicit_target_id == "creature":
			for c in get_tree().get_nodes_in_group("creatures"):
				if c.get("is_alive") == true:
					still_valid = true
					break
		else:
			for node in get_tree().get_nodes_in_group("players"):
				if node.player_id == _explicit_target_id and node.is_alive and node.is_on_field:
					still_valid = true
					break
		if not still_valid:
			_explicit_target_id = ""

	if not _explicit_target_id.is_empty():
		current_target_id = _explicit_target_id
		return

	# Fallback: nearest enemy within 15 units.
	var best_dist := 15.0
	var best_id := ""
	for node in get_tree().get_nodes_in_group("players"):
		if not node.is_alive: continue
		if node.team_id == team_id: continue
		var d := global_position.distance_to(node.global_position)
		if d < best_dist:
			best_dist = d
			best_id = node.player_id
	current_target_id = best_id
