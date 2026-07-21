class_name PlayerAbilities
extends Node

## Cooldown tracking and ability queue for a player.
## Thin wrapper — AbilitySystem owns the canonical cooldown state,
## but this component caches values for UI rendering without querying the system.

const SLOT_COUNT := 10
const MAX_QUEUE := 5
const GCD_DURATION := 1.0

## UI-facing cooldown values (updated by AbilitySystem via RPC or direct call)
var cooldowns: PackedFloat32Array
var gcd_remaining: float = 0.0

## Aim state for terrain abilities (Geomancer, etc.)
var is_aiming: bool = false
var aim_charge: float = 0.0
var aim_charge_max: float = 1.5   # seconds to full charge

func _ready() -> void:
	cooldowns = PackedFloat32Array()
	cooldowns.resize(SLOT_COUNT)
	EventBus.gcd_started.connect(_on_gcd_started)
	EventBus.ability_resolved.connect(_on_ability_resolved)

func _process(delta: float) -> void:
	gcd_remaining = maxf(0.0, gcd_remaining - delta)
	for i in cooldowns.size():
		cooldowns[i] = maxf(0.0, cooldowns[i] - delta)
	if is_aiming:
		aim_charge = minf(aim_charge_max, aim_charge + delta)

func start_aim() -> void:
	is_aiming = true
	aim_charge = 0.0

func release_aim() -> Vector2:
	is_aiming = false
	var player := get_parent()
	return player.aim_world_position if player else Vector2.ZERO

func get_cooldown(slot: int) -> float:
	return cooldowns[clamp(slot - 1, 0, SLOT_COUNT - 1)]

func get_cooldown_pct(slot: int) -> float:
	var p := get_parent()
	if p == null: return 0.0
	var def: AbilityDefinition = GameRegistry.get_ability(p.class_definition.class_id if p.class_definition else "", slot)
	if def == null or def.cooldown <= 0.0: return 0.0
	return cooldowns[slot - 1] / def.cooldown

func _on_gcd_started(player_id: String, duration: float) -> void:
	var p := get_parent()
	if p and p.player_id == player_id:
		gcd_remaining = duration

func _on_ability_resolved(caster_id: String, slot: int, _hit_ids: Array) -> void:
	var p := get_parent()
	if p == null or p.player_id != caster_id: return
	var def: AbilityDefinition = GameRegistry.get_ability(p.class_definition.class_id if p.class_definition else "", slot)
	if def:
		cooldowns[slot - 1] = def.cooldown
