class_name CombatSystem
extends Node

## Bridges damage_requested → damage_applied.
## Applies the attacker's damage output multiplier; PlayerBuffs handles the
## target's incoming multiplier, dodge check, health reduction, and kill detection.

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

	EventBus.damage_indicator_spawned.emit(
		target_node.global_position,
		str(int(round(amount))),
		"damage"
	)

func _get_player(pid: String) -> Node:
	if pid.is_empty(): return null
	for n in get_tree().get_nodes_in_group("players"):
		if n.player_id == pid: return n
	return null
