class_name StatTracker
extends Node

var _ball_holder: String = ""
var _hold_start: float = 0.0
var _current_act: int = 1

func _ready() -> void:
	EventBus.damage_applied.connect(_on_damage_applied)
	EventBus.healing_applied.connect(_on_healing_applied)
	EventBus.killa_scored.connect(_on_killa_scored)
	EventBus.player_died.connect(_on_player_died)
	EventBus.ultra_scored.connect(_on_ultra_scored)
	EventBus.meta_scored.connect(_on_meta_scored)
	EventBus.ball_possession_changed.connect(_on_ball_possession_changed)
	EventBus.ball_thrown.connect(_on_ball_thrown)
	EventBus.ball_dropped.connect(_on_ball_dropped)
	EventBus.ability_resolved.connect(_on_ability_resolved)
	EventBus.act_started.connect(_on_act_started)

func _commit_hold_time() -> void:
	if _ball_holder.is_empty(): return
	var elapsed := Time.get_ticks_msec() / 1000.0 - _hold_start
	MatchState.stat(_ball_holder).ball_time += elapsed
	_ball_holder = ""

# ── Ball tracking ──────────────────────────────────────────────────────────────

func _on_ball_possession_changed(new_holder_id: String, _team_id: int) -> void:
	_commit_hold_time()
	if new_holder_id.is_empty(): return
	_ball_holder = new_holder_id
	_hold_start = Time.get_ticks_msec() / 1000.0
	MatchState.stat(new_holder_id).ball_carries += 1

func _on_ball_thrown(thrower_id: String, _target_position: Vector2, is_charged: bool) -> void:
	_commit_hold_time()
	if thrower_id.is_empty(): return
	var s := MatchState.stat(thrower_id)
	s.passes_thrown += 1
	if is_charged:
		s.charged_throws += 1
	var c := MatchState.ball.charge_at_throw
	if c > s.max_charge_reached:
		s.max_charge_reached = c

func _on_ball_dropped(_position: Vector2, _cause: String) -> void:
	_commit_hold_time()

# ── Combat ─────────────────────────────────────────────────────────────────────

func _on_damage_applied(attacker_id: String, target_id: String, amount: float, _is_kill: bool) -> void:
	if not attacker_id.is_empty():
		MatchState.stat(attacker_id).dmg += amount
	if not target_id.is_empty():
		MatchState.stat(target_id).taken += amount

func _on_healing_applied(healer_id: String, _target_id: String, amount: float) -> void:
	if not healer_id.is_empty():
		MatchState.stat(healer_id).heal += amount

func _on_killa_scored(_team_id: int, killer_id: String, _victim_id: String) -> void:
	if killer_id.is_empty(): return
	var s := MatchState.stat(killer_id)
	s.kills += 1
	s.kills_per_act[_current_act] = s.kills_per_act.get(_current_act, 0) + 1

func _on_player_died(player_id: String, cause: String, _killer_id: String) -> void:
	if player_id.is_empty(): return
	var s := MatchState.stat(player_id)
	s.deaths += 1
	s.death_causes[cause] = s.death_causes.get(cause, 0) + 1

func _on_ultra_scored(_team_id: int, scorer_id: String) -> void:
	if not scorer_id.is_empty():
		MatchState.stat(scorer_id).ub += 1

func _on_meta_scored(_team_id: int, scorer_id: String) -> void:
	if not scorer_id.is_empty():
		MatchState.stat(scorer_id).ca += 1

# ── Abilities ──────────────────────────────────────────────────────────────────

func _on_ability_resolved(caster_id: String, slot: int, _hit_ids: Array) -> void:
	if caster_id.is_empty(): return
	var s := MatchState.stat(caster_id)
	s.ability_uses[slot] = s.ability_uses.get(slot, 0) + 1

# ── Act tracking ───────────────────────────────────────────────────────────────

func _on_act_started(act_number: int) -> void:
	_current_act = act_number
