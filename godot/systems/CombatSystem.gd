class_name CombatSystem
extends Node

## Bridges damage_requested → damage_applied.
## Applies the attacker's damage output multiplier; PlayerBuffs handles the
## target's incoming multiplier, dodge check, health reduction, and kill detection.

const PlayerLookup = preload("res://systems/PlayerLookup.gd")

func _ready() -> void:
	EventBus.damage_requested.connect(_on_damage_requested)

func _on_damage_requested(payload: Dictionary) -> void:
	var attacker_id: String = payload.get("attacker_id", "")
	var target_id: String   = payload.get("target_id", "")
	var base_amount: float  = payload.get("amount", 0.0)
	var kb_dist: float      = payload.get("knockback_distance", 0.0)
	var facing: float       = payload.get("facing", 0.0)

	var target_node := _get_player(target_id)
	if target_node == null or not target_node.is_alive or not target_node.is_on_field:
		return

	var output_mult := 1.0
	var attacker_node := _get_player(attacker_id)
	if attacker_node:
		output_mult = attacker_node.buffs.get_damage_output_multiplier()

	var amount := base_amount * output_mult

	# Intercept: if target is inside a friendly force field, the field absorbs the hit.
	var ff := _find_protecting_force_field(attacker_id, target_node)
	if ff != null:
		ff.absorb_damage(amount, attacker_id)
		return

	var hp_before: float = target_node.buffs.health
	var incoming_mult: float = target_node.buffs.get_incoming_damage_multiplier()
	var final_dmg := amount * incoming_mult
	print("[COMBAT] %s → %s | base=%.1f out_mult=%.2f in_mult=%.2f final=%.1f | hp_before=%.1f hp_after≈%.1f" % [
		attacker_id, target_id,
		base_amount, output_mult, incoming_mult, final_dmg,
		hp_before, maxf(0.0, hp_before - final_dmg)
	])

	if kb_dist > 0.0:
		EventBus.debuff_applied.emit(target_id, "knockback", 0.0, {
			"direction": Vector2.from_angle(facing),
			"distance": kb_dist,
		})

	# PlayerBuffs handles incoming multiplier, dodge, health reduction, and kill.
	EventBus.damage_applied.emit(attacker_id, target_id, amount, false)

	if attacker_node != null:
		_try_honor_healing(attacker_node, attacker_id, amount)

	EventBus.damage_indicator_spawned.emit(
		target_node.global_position,
		str(int(round(amount))),
		"damage"
	)

const HONOR_HEAL_RANGE  := 40.0
const HONOR_HEAL_PCT    := 0.25
const HONOR_MAX_ALLIES  := 4

func _try_honor_healing(attacker: Node, attacker_id: String, damage: float) -> void:
	if attacker.get("stance") != "honor": return
	var rec: MatchState.PlayerRecord = MatchState.players.get(attacker_id)
	if rec == null or rec.class_id != "warden": return
	var heal := damage * HONOR_HEAL_PCT
	if heal <= 0.0: return
	var allies: Array = []
	for node in PlayerLookup.get_all_nodes():
		if node.player_id == attacker_id: continue
		if not node.is_alive or not node.is_on_field: continue
		var ally_rec: MatchState.PlayerRecord = MatchState.players.get(node.player_id)
		if ally_rec == null or ally_rec.team_id != rec.team_id: continue
		if attacker.global_position.distance_to(node.global_position) <= HONOR_HEAL_RANGE:
			allies.append(node)
	allies.sort_custom(func(a, b):
		return attacker.global_position.distance_squared_to(a.global_position) \
			 < attacker.global_position.distance_squared_to(b.global_position))
	for i in mini(HONOR_MAX_ALLIES, allies.size()):
		EventBus.healing_applied.emit(attacker_id, allies[i].player_id, heal)

func _get_player(pid: String) -> Node:
	if pid.is_empty(): return null
	return PlayerLookup.get_node(pid)

func _find_protecting_force_field(attacker_id: String, target_node: Node) -> Node:
	var attacker_rec: MatchState.PlayerRecord = MatchState.players.get(attacker_id)
	if attacker_rec == null: return null
	for ff in get_tree().get_nodes_in_group("force_fields"):
		if ff.caster_team_id != target_node.team_id: continue
		if attacker_rec.team_id == ff.caster_team_id: continue
		if target_node.global_position.distance_to(ff.global_position) > ff.RADIUS: continue
		return ff
	return null
