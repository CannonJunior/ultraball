class_name PlayerBuffs
extends Node

## All buff and debuff timers for a player.
## Ticks timers, provides speed multiplier, and applies/removes status effects.

var health: float = 100.0
var max_health: float = 100.0

# ── Buff timers (remaining, max for progress ring) ────────────────────────────
var speed_mult_remaining: float = 0.0
var speed_mult_max: float = 1.0
var speed_mult_factor: float = 1.0

var damage_boost_remaining: float = 0.0
var damage_boost_max: float = 1.0
var damage_boost_factor: float = 1.0

var damage_reduction_remaining: float = 0.0
var damage_reduction_max: float = 1.0
var damage_reduction_factor: float = 1.0

var stun_immune_remaining: float = 0.0
var stun_immune_max: float = 1.0

var dodge_remaining: float = 0.0
var dodge_max: float = 1.0

var hot_remaining: float = 0.0
var hot_rate: float = 0.0   # HP/s

var duration_double_next: bool = false

# ── Debuff timers ─────────────────────────────────────────────────────────────
var stun_timer: float = 0.0
var stun_max: float = 1.0

var snare_remaining: float = 0.0
var snare_max: float = 1.0
var snare_factor: float = 1.0

var confused_timer: float = 0.0
var hex_timer: float = 0.0
var hex_damage_factor: float = 1.0
var marked_timer: float = 0.0
var marked_damage_mult: float = 1.25

func _ready() -> void:
	var player := get_parent()
	if player and player.class_definition:
		max_health = player.class_definition.max_health
		health = max_health
	EventBus.buff_applied.connect(_on_buff_applied)
	EventBus.debuff_applied.connect(_on_debuff_applied)
	EventBus.damage_applied.connect(_on_damage_applied)
	EventBus.healing_applied.connect(_on_healing_applied)
	EventBus.periodic_hot_applied.connect(_on_periodic_hot_applied)

func _process(delta: float) -> void:
	stun_timer = maxf(0.0, stun_timer - delta)
	snare_remaining = maxf(0.0, snare_remaining - delta)
	confused_timer = maxf(0.0, confused_timer - delta)
	hex_timer = maxf(0.0, hex_timer - delta)
	marked_timer = maxf(0.0, marked_timer - delta)
	stun_immune_remaining = maxf(0.0, stun_immune_remaining - delta)
	dodge_remaining = maxf(0.0, dodge_remaining - delta)
	speed_mult_remaining = maxf(0.0, speed_mult_remaining - delta)
	damage_boost_remaining = maxf(0.0, damage_boost_remaining - delta)
	damage_reduction_remaining = maxf(0.0, damage_reduction_remaining - delta)

	if hot_remaining > 0.0:
		hot_remaining -= delta
		health = minf(max_health, health + hot_rate * delta)

func get_speed_multiplier() -> float:
	var m := 1.0
	if speed_mult_remaining > 0.0: m *= speed_mult_factor
	if snare_remaining > 0.0: m *= snare_factor
	return m

func get_damage_output_multiplier() -> float:
	var m := 1.0
	if damage_boost_remaining > 0.0: m *= damage_boost_factor
	if hex_timer > 0.0: m *= hex_damage_factor
	return m

func get_incoming_damage_multiplier() -> float:
	var m := 1.0
	if damage_reduction_remaining > 0.0: m *= damage_reduction_factor
	if marked_timer > 0.0: m *= marked_damage_mult
	return m

func is_invulnerable() -> bool:
	return dodge_remaining > 0.0

# ── Buff / debuff application ─────────────────────────────────────────────────

func _on_buff_applied(player_id: String, buff_name: String, duration: float) -> void:
	var p := get_parent()
	if not p or p.player_id != player_id: return
	match buff_name:
		"dodge", "invulnerable":
			dodge_remaining = maxf(dodge_remaining, duration)
			dodge_max = maxf(dodge_max, duration)
		"stun_immune":
			stun_immune_remaining = maxf(stun_immune_remaining, duration)
			stun_immune_max = maxf(stun_immune_max, duration)
		"ultra_mana_gain":
			p.mana.add_ultra(duration)   # duration field repurposed as amount
		"duration_double_next":
			duration_double_next = true
		"phase_line_bonus":
			pass  # AbilitySystem handles cooldown refresh on phase line crossing
		# speed_boost, damage_boost, damage_reduction, hot, cleanse:
		# the corresponding _set debuff carries the actual values — no-op here

func _on_debuff_applied(player_id: String, debuff_name: String, duration: float, params: Dictionary) -> void:
	var p := get_parent()
	if not p or p.player_id != player_id: return
	match debuff_name:
		"stun":
			if stun_immune_remaining > 0.0 or dodge_remaining > 0.0: return
			stun_timer = maxf(stun_timer, duration)
			stun_max = maxf(stun_max, duration)
		"snare":
			if dodge_remaining > 0.0: return
			snare_remaining = maxf(snare_remaining, duration)
			snare_max = maxf(snare_max, duration)
			snare_factor = minf(snare_factor, params.get("slow_factor", 0.5))
		"confused":
			confused_timer = maxf(confused_timer, duration)
		"hex":
			hex_timer = maxf(hex_timer, duration)
			hex_damage_factor = params.get("damage_factor", 0.8)
		"marked":
			marked_timer = maxf(marked_timer, duration)
			marked_damage_mult = params.get("damage_taken_multiplier", 1.25)
		"speed_mult_set":
			speed_mult_remaining = duration
			speed_mult_max = maxf(speed_mult_max, duration)
			speed_mult_factor = params.get("multiplier", 1.5)
		"damage_boost_set":
			damage_boost_remaining = duration
			damage_boost_max = maxf(damage_boost_max, duration)
			damage_boost_factor = params.get("multiplier", 1.3)
		"damage_reduction_set":
			damage_reduction_remaining = duration
			damage_reduction_max = maxf(damage_reduction_max, duration)
			damage_reduction_factor = params.get("factor", 0.7)
		"teleport":
			p.global_position = params.get("destination", p.global_position)
		"knockback":
			if dodge_remaining > 0.0: return
			var dir: Vector2 = params.get("direction", Vector2.RIGHT)
			var dist: float = params.get("distance", 3.0)
			p.velocity += dir * (dist / 0.2)   # impulse over ~0.2s
		"mana_drain":
			p.mana.drain(params.get("mana_type", 3), params.get("amount", 15.0))
		"fumble":
			EventBus.ball_dropped.emit(p.global_position, "fumble")
		"swap":
			var partner_id: String = params.get("swap_partner_id", "")
			var my_pos: Vector2 = p.global_position
			p.global_position = params.get("target_pos", p.global_position)
			EventBus.debuff_applied.emit(partner_id, "teleport", 0.0, {"destination": my_pos})
		"dash_impulse":
			if dodge_remaining > 0.0: return
			var dir: Vector2 = params.get("direction", Vector2.RIGHT)
			var dist: float = params.get("distance", 6.0)
			p.velocity = dir * (dist / 0.15)
		"cleanse_cc":
			stun_timer = 0.0
			snare_remaining = 0.0
			snare_factor = 1.0
			confused_timer = 0.0
			hex_timer = 0.0
			if params.get("clear_dots", false):
				hot_remaining = 0.0
		"mana_restore_set":
			var mtype: int = params.get("mana_type", 0)
			var amt: float = params.get("amount", 0.0)
			p.mana.restore(mtype, amt)

func _on_damage_applied(attacker_id: String, target_id: String, amount: float, is_kill: bool) -> void:
	var p := get_parent()
	if not p or p.player_id != target_id: return
	if dodge_remaining > 0.0: return
	var final_dmg := amount * get_incoming_damage_multiplier()
	health = maxf(0.0, health - final_dmg)
	if is_kill or health <= 0.0:
		EventBus.player_died.emit(target_id, "combat", attacker_id)

func _on_healing_applied(_healer_id: String, target_id: String, amount: float) -> void:
	var p := get_parent()
	if not p or p.player_id != target_id: return
	health = minf(max_health, health + amount)

func _on_periodic_hot_applied(payload: Dictionary) -> void:
	var p := get_parent()
	if not p: return
	var tid: String = payload.get("target_id", "")
	if p.player_id != tid: return
	if payload.has("heal_per_second"):
		hot_remaining = maxf(hot_remaining, payload.get("duration", 0.0))
		hot_rate = payload.get("heal_per_second", 0.0)
	elif payload.has("heal_per_tick"):
		var ticks: int = payload.get("ticks", 1)
		var interval: float = payload.get("interval", 2.0)
		hot_remaining = maxf(hot_remaining, ticks * interval)
		hot_rate = payload.get("heal_per_tick", 0.0) / interval
