class_name AbilitySystem
extends Node

## Replaces the 2000-line CombatSystem.
## Dispatches data-driven AbilityEffect arrays; communicates only via EventBus.

const MAX_QUEUE := 5
const GCD_DURATION := 1.0

## Per-player ability queues: player_id -> Array[int] (slot numbers)
var _queues: Dictionary = {}

## Per-player GCD tracking: player_id -> float (seconds remaining)
var _gcd: Dictionary = {}

## Per-player per-slot cooldowns: player_id -> PackedFloat32Array (10 slots)
var _cooldowns: Dictionary = {}

## Tracks "duration_double_next" flag per player
var _duration_double: Dictionary = {}   # player_id -> bool

func _ready() -> void:
	EventBus.ability_used.connect(_on_ability_used)
	EventBus.ability_queued.connect(_on_ability_queued)
	EventBus.buff_applied.connect(_on_buff_applied)
	EventBus.player_subbed_in.connect(_on_player_subbed_in)

func _physics_process(delta: float) -> void:
	_tick_cooldowns(delta)
	_drain_queues()

# ── Cooldown tick ──────────────────────────────────────────────────────────────

func _tick_cooldowns(delta: float) -> void:
	for pid in _gcd:
		_gcd[pid] = maxf(0.0, _gcd[pid] - delta)
	for pid in _cooldowns:
		var cds: PackedFloat32Array = _cooldowns[pid]
		for i in cds.size():
			cds[i] = maxf(0.0, cds[i] - delta)

# ── Queue drain ────────────────────────────────────────────────────────────────

func _drain_queues() -> void:
	for pid in _queues:
		var queue: Array = _queues[pid]
		if queue.is_empty(): continue
		if _gcd.get(pid, 0.0) > 0.0: continue
		var slot: int = queue[0]
		if _can_use_now(pid, slot):
			queue.pop_front()
			_fire_ability(pid, slot)

func _on_ability_queued(player_id: String, slot: int) -> void:
	if not _queues.has(player_id):
		_queues[player_id] = []
	var queue: Array = _queues[player_id]
	if queue.size() >= MAX_QUEUE:
		return
	queue.append(slot)

# ── Direct use (skips queue) ───────────────────────────────────────────────────

func _on_ability_used(caster_id: String, slot: int) -> void:
	if not _can_use_now(caster_id, slot):
		var reason := _failure_reason(caster_id, slot)
		EventBus.ability_failed.emit(caster_id, slot, reason)
		return
	_fire_ability(caster_id, slot)

# ── Fire ──────────────────────────────────────────────────────────────────────

func _fire_ability(caster_id: String, slot: int) -> void:
	var player_rec: MatchState.PlayerRecord = MatchState.players.get(caster_id)
	if player_rec == null: return

	var definition: AbilityDefinition = GameRegistry.get_ability(player_rec.class_id, slot)
	if definition == null: return

	var player_node := _get_player_node(caster_id)
	if player_node == null: return

	# Mana deduction (PlayerMana component handles actual mana values)
	player_node.mana.deduct(definition.mana_type, definition.mana_cost)

	# Set cooldowns
	_set_cooldown(caster_id, slot, definition.cooldown)
	_gcd[caster_id] = GCD_DURATION
	EventBus.gcd_started.emit(caster_id, GCD_DURATION)

	# Resolve target
	var target_id: String = player_node.current_target_id
	var aim_pos: Vector2 = player_node.aim_world_position

	# Build context
	var all_players := get_tree().get_nodes_in_group("players")
	var ctx := AbilityContext.build(caster_id, target_id, aim_pos, all_players)

	# Apply effects in order
	for effect in definition.effects:
		var double_dur: bool = _duration_double.get(caster_id, false)
		if double_dur:
			_apply_with_doubled_duration(effect, ctx)
		else:
			effect.apply(ctx)

	if _duration_double.get(caster_id, false):
		_duration_double[caster_id] = false

	EventBus.ability_resolved.emit(caster_id, slot, ctx.hit_ids)

func _apply_with_doubled_duration(effect: AbilityEffect, ctx: AbilityContext) -> void:
	# Temporarily patch duration properties via duck-typing before applying.
	# This handles SpeedBoostEffect, HealEffect, StunEffect, etc.
	if "duration" in effect:
		var orig: float = effect.get("duration")
		effect.set("duration", orig * 2.0)
		effect.apply(ctx)
		effect.set("duration", orig)
	else:
		effect.apply(ctx)

# ── Guards ────────────────────────────────────────────────────────────────────

func _can_use_now(pid: String, slot: int) -> bool:
	if _failure_reason(pid, slot) != "": return false
	return true

func _failure_reason(pid: String, slot: int) -> String:
	if _gcd.get(pid, 0.0) > 0.0: return "on_gcd"
	var cd := _get_cooldown(pid, slot)
	if cd > 0.0: return "on_cd"
	# Mana check delegated to PlayerMana component
	var player_node := _get_player_node(pid)
	if player_node == null: return "no_player"
	var _rec: MatchState.PlayerRecord = MatchState.players.get(pid)
	if _rec == null: return "no_player"
	var definition: AbilityDefinition = GameRegistry.get_ability(_rec.class_id, slot)
	if definition == null: return "no_definition"
	if not player_node.mana.can_afford(definition.mana_type, definition.mana_cost):
		return "no_mana"
	return ""

# ── Cooldown helpers ──────────────────────────────────────────────────────────

func _set_cooldown(pid: String, slot: int, duration: float) -> void:
	if not _cooldowns.has(pid):
		var arr := PackedFloat32Array()
		arr.resize(10)
		_cooldowns[pid] = arr
	_cooldowns[pid][slot - 1] = duration

func _get_cooldown(pid: String, slot: int) -> float:
	if not _cooldowns.has(pid): return 0.0
	return _cooldowns[pid][slot - 1]

func get_cooldown_for_ui(pid: String, slot: int) -> float:
	return _get_cooldown(pid, slot)

func get_gcd_for_ui(pid: String) -> float:
	return _gcd.get(pid, 0.0)

# ── Event listeners ───────────────────────────────────────────────────────────

func _on_buff_applied(player_id: String, buff_name: String, _duration: float) -> void:
	if buff_name == "duration_double_next":
		_duration_double[player_id] = true

func _on_player_subbed_in(player_id: String, _replaced: String, _team: int) -> void:
	# Reset cooldowns for newly subbed-in player
	if _cooldowns.has(player_id):
		_cooldowns[player_id].fill(0.0)
	_gcd[player_id] = 0.0
	if _queues.has(player_id):
		_queues[player_id].clear()

# ── Helpers ───────────────────────────────────────────────────────────────────

func _get_player_node(pid: String) -> Node:
	for node in get_tree().get_nodes_in_group("players"):
		if node.player_id == pid:
			return node
	return null
