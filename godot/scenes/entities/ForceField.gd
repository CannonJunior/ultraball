class_name ForceField
extends Node2D

const PlayerLookup = preload("res://systems/PlayerLookup.gd")

const RADIUS     := 5.0
const MAX_HP     := 200.0
const DRAIN_RATE := 1.0    # Ultra mana/s while following
const LIFETIME   := 6.0

var field_id: String = ""
var caster_id: String = ""
var caster_team_id: int = -1
var hp: float = MAX_HP

var _timer: float = 0.0
var _following: bool = true

func _ready() -> void:
	add_to_group("force_fields")
	EventBus.force_field_anchor_requested.connect(_on_anchor_requested)
	EventBus.player_died.connect(_on_caster_died)

func _physics_process(delta: float) -> void:
	_timer += delta
	if _timer >= LIFETIME:
		queue_free()
		return

	if _following:
		var caster_node := _find_caster()
		if caster_node:
			global_position = caster_node.global_position
			caster_node.mana.deduct(4, DRAIN_RATE * delta)
			if caster_node.mana.ultra <= 0.0:
				_anchor()
		else:
			_anchor()

	_push_enemies()
	queue_redraw()

func absorb_damage(amount: float, attacker_id: String) -> void:
	hp = maxf(0.0, hp - amount)
	EventBus.damage_applied.emit(attacker_id, field_id, amount, false)
	EventBus.damage_indicator_spawned.emit(global_position, str(int(round(amount))), "damage")
	if hp <= 0.0:
		_shatter()

func _anchor() -> void:
	_following = false

func _shatter() -> void:
	EventBus.force_field_shattered.emit(global_position)
	queue_free()

func _on_anchor_requested(pid: String) -> void:
	if pid == caster_id:
		_anchor()

func _on_caster_died(pid: String, _cause: String, _killer: String) -> void:
	if pid == caster_id:
		_anchor()

const _RADIUS_SQ := RADIUS * RADIUS

func _push_enemies() -> void:
	for player in PlayerLookup.get_all_nodes():
		if not player.is_alive or not player.is_on_field: continue
		if player.team_id == caster_team_id: continue
		var diff: Vector2 = player.global_position - global_position
		var dist_sq := diff.length_squared()
		if dist_sq >= _RADIUS_SQ:
			continue
		if dist_sq > 0.000001:
			player.global_position = global_position + diff.normalized() * RADIUS
		else:
			player.global_position = global_position + Vector2(RADIUS, 0.0)

func _find_caster() -> Node:
	return PlayerLookup.get_node(caster_id)

func _draw() -> void:
	var life_frac := 1.0 - (_timer / LIFETIME)
	var hp_frac   := hp / MAX_HP
	# Gold when healthy, shifts toward cyan-white as damaged
	var col := Color(1.0, 0.82, 0.10).lerp(Color(0.7, 0.92, 1.0), 1.0 - hp_frac)
	# Outer fill — very transparent
	draw_circle(Vector2.ZERO, RADIUS, Color(col.r, col.g, col.b, 0.09 * life_frac))
	# Main ring
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 64,
		Color(col.r, col.g, col.b, 0.55 * life_frac), 0.15)
	# Inner decorative ring
	draw_arc(Vector2.ZERO, RADIUS * 0.82, 0.0, TAU, 48,
		Color(col.r, col.g, col.b, 0.20 * life_frac), 0.05)
	# Rotating inner tick marks when following
	if _following:
		var angle_offset := _timer * 0.8
		for i in 6:
			var a := i * TAU / 6.0 + angle_offset
			var r0 := RADIUS * 0.70
			var r1 := RADIUS * 0.78
			draw_line(
				Vector2(cos(a) * r0, sin(a) * r0),
				Vector2(cos(a) * r1, sin(a) * r1),
				Color(col.r, col.g, col.b, 0.45 * life_frac), 0.04)
