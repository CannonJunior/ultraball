class_name AbilityVfxLayer
extends Node2D

## One-shot world-space VFX for ability casts, impacts, damage, and deaths.
## Draw-call based — no scene nodes, no particles. Consistent with the rest of
## the 2D world. Added to GameScene as a sibling of $Entities (z_index 10).
##
## Each active effect is a plain Dictionary:
##   { type, t, dur, pos, color, data }
## t advances in _process(); _draw() dispatches to per-type draw functions.

const C_RED    := Color(1.0,   0.25,  0.25)
const C_BLUE   := Color(0.25,  0.50,  1.0)
const C_YELLOW := Color(1.0,   0.85,  0.15)
const C_GOLD   := Color(1.0,   0.82,  0.10)
const C_GREEN  := Color(0.20,  0.90,  0.35)
const C_DMG    := Color(1.0,   0.40,  0.10)
const C_HOME   := Color(1.0,   0.231, 0.325)
const C_AWAY   := Color(0.184, 0.514, 1.0)

var _active: Array = []

func _ready() -> void:
	z_index = 10
	if not MatchState.config or MatchState.config.view_mode != MatchConfig.ViewMode.FLAT_2D:
		set_process(false)
		return
	EventBus.ability_resolved.connect(_on_ability_resolved)
	EventBus.damage_applied.connect(_on_damage_applied)
	EventBus.healing_applied.connect(_on_healing_applied)
	EventBus.player_died.connect(_on_player_died)
	EventBus.ultra_scored.connect(_on_ultra_scored)
	EventBus.ball_picked_up.connect(_on_ball_picked_up)

func _process(delta: float) -> void:
	if _active.is_empty():
		return
	for v in _active:
		v.t = minf(v.t + delta, v.dur)
	_active = _active.filter(func(v): return v.t < v.dur)
	queue_redraw()

# ── Signal handlers ────────────────────────────────────────────────────────────

func _on_ability_resolved(caster_id: String, slot: int, hit_ids: Array) -> void:
	var rec: MatchState.PlayerRecord = MatchState.players.get(caster_id)
	if rec == null:
		return
	var definition: AbilityDefinition = GameRegistry.get_ability(rec.class_id, slot)
	if definition == null:
		return
	var col  := _mana_color(definition.mana_type)
	var cpos := _player_pos(caster_id)
	_spawn("cast_ring", cpos, col, 0.35, {})
	for hit_id in hit_ids:
		_spawn("impact_flash", _player_pos(hit_id), col, 0.20, {})
	if definition.is_aoe and definition.aoe_radius > 0.0:
		var center := _centroid(hit_ids) if not hit_ids.is_empty() else cpos
		_spawn("aoe_burst", center, col, 0.45, {"radius": definition.aoe_radius})

func _on_damage_applied(_attacker_id: String, target_id: String, _amount: float, _is_kill: bool) -> void:
	_spawn("hit_spark", _player_pos(target_id), C_DMG, 0.25, {})

func _on_healing_applied(_healer_id: String, target_id: String, _amount: float) -> void:
	_spawn("heal_rise", _player_pos(target_id), C_GREEN, 0.60,
		{"delays": [0.0, 0.15, 0.10, 0.22], "offsets": [0.0, -0.15, 0.12, -0.07]})

func _on_player_died(player_id: String, _cause: String, _killer_id: String) -> void:
	var rec: MatchState.PlayerRecord = MatchState.players.get(player_id)
	var col: Color
	if rec == null:
		col = Color(0.7, 0.7, 0.7)
	elif rec.team_id == 0:
		col = C_HOME
	elif rec.team_id == 1:
		col = C_AWAY
	else:
		col = Color(0.20, 0.90, 0.30)
	_spawn("death_burst", _player_pos(player_id), col, 0.50, {})

func _on_ultra_scored(_team_id: int, scorer_id: String) -> void:
	_spawn("ultra_burst", _player_pos(scorer_id), C_GOLD, 0.80, {})

func _on_ball_picked_up(pid: String) -> void:
	_spawn("pickup_pulse", _player_pos(pid), C_GOLD, 0.25, {})

# ── Spawn ──────────────────────────────────────────────────────────────────────

func _spawn(type: String, pos: Vector2, color: Color, dur: float, data: Dictionary) -> void:
	_active.append({"type": type, "t": 0.0, "dur": dur, "pos": pos, "color": color, "data": data})

# ── Drawing ────────────────────────────────────────────────────────────────────

func _draw() -> void:
	for v in _active:
		var p: float = float(v.t) / float(v.dur)
		match v.type:
			"cast_ring":    _draw_cast_ring(v, p)
			"impact_flash": _draw_impact_flash(v, p)
			"aoe_burst":    _draw_aoe_burst(v, p)
			"hit_spark":    _draw_hit_spark(v, p)
			"heal_rise":    _draw_heal_rise(v, p)
			"death_burst":  _draw_death_burst(v, p)
			"ultra_burst":  _draw_ultra_burst(v, p)
			"pickup_pulse": _draw_pickup_pulse(v, p)

func _draw_cast_ring(v: Dictionary, p: float) -> void:
	var ep := _ease_out(p)
	var r  := lerpf(0.50, 1.40, ep)
	var a  := lerpf(0.90, 0.00, p)
	var w  := lerpf(0.07, 0.02, p)
	draw_arc(v.pos, r, 0.0, TAU, 48, Color(v.color.r, v.color.g, v.color.b, a), w)

func _draw_impact_flash(v: Dictionary, p: float) -> void:
	var r := lerpf(0.00, 0.35, _ease_out(p))
	var a := lerpf(0.85, 0.00, p * p)
	draw_circle(v.pos, r, Color(v.color.r, v.color.g, v.color.b, a))

func _draw_aoe_burst(v: Dictionary, p: float) -> void:
	var ep     := _ease_out(p)
	var radius : float = v.data.get("radius", 2.0)
	var r      := lerpf(0.0, radius, ep)
	var fill_a := lerpf(0.18, 0.00, p)
	var ring_a := lerpf(0.70, 0.00, p)
	draw_circle(v.pos, r, Color(v.color.r, v.color.g, v.color.b, fill_a))
	draw_arc(v.pos, r, 0.0, TAU, 48,
		Color(v.color.r, v.color.g, v.color.b, ring_a), lerpf(0.06, 0.02, p))

func _draw_hit_spark(v: Dictionary, p: float) -> void:
	var ep  := _ease_out(p)
	var a   := lerpf(0.90, 0.00, p * p)
	var col := Color(v.color.r, v.color.g, v.color.b, a)
	for i in 6:
		var angle := i * TAU / 6.0
		var dir   := Vector2(cos(angle), sin(angle))
		draw_line(v.pos + dir * lerpf(0.10, 0.20, ep),
				  v.pos + dir * lerpf(0.20, 0.65, ep), col, 0.05)

func _draw_heal_rise(v: Dictionary, p: float) -> void:
	var delays  : Array = v.data.get("delays",  [0.0, 0.15, 0.10, 0.22])
	var offsets : Array = v.data.get("offsets", [0.0, -0.15, 0.12, -0.07])
	for i in 4:
		var dp := clampf((p - delays[i]) / (1.0 - delays[i]), 0.0, 1.0)
		if dp <= 0.0:
			continue
		var a    := lerpf(0.80, 0.0, dp * dp)
		var rise := lerpf(0.00, 0.65, _ease_out(dp))
		draw_circle(v.pos + Vector2(offsets[i], -rise), 0.07,
			Color(C_GREEN.r, C_GREEN.g, C_GREEN.b, a))

func _draw_death_burst(v: Dictionary, p: float) -> void:
	var ep  := _ease_out(p)
	var a   := lerpf(1.0, 0.0, p)
	var col := Color(v.color.r, v.color.g, v.color.b, a)
	for i in 10:
		var angle := i * TAU / 10.0
		var dir   := Vector2(cos(angle), sin(angle))
		draw_line(v.pos, v.pos + dir * lerpf(0.0, 1.8, ep), col, 0.05)

func _draw_ultra_burst(v: Dictionary, p: float) -> void:
	var ep     := _ease_out(p)
	var r      := lerpf(0.0, 3.0, ep)
	var fill_a := lerpf(0.20, 0.00, p)
	var ring_a := lerpf(1.00, 0.00, p)
	draw_circle(v.pos, r, Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, fill_a))
	draw_arc(v.pos, r, 0.0, TAU, 64, Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, ring_a), 0.06)
	var spark_a := lerpf(0.90, 0.0, p)
	for i in 12:
		var angle := i * TAU / 12.0
		var dir   := Vector2(cos(angle), sin(angle))
		draw_line(v.pos + dir * lerpf(0.0, 0.5, ep),
				  v.pos + dir * lerpf(0.5, 2.5, ep),
				  Color(1.0, 1.0, 1.0, spark_a), 0.05)

func _draw_pickup_pulse(v: Dictionary, p: float) -> void:
	var r := lerpf(0.30, 0.90, _ease_out(p))
	var a := lerpf(0.80, 0.00, p)
	draw_arc(v.pos, r, 0.0, TAU, 32, Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, a), 0.04)

# ── Helpers ────────────────────────────────────────────────────────────────────

func _ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)

func _mana_color(mana_type: int) -> Color:
	match mana_type:
		1: return C_RED
		2: return C_BLUE
		3: return C_YELLOW
		4: return C_GOLD
	return Color(0.88, 0.88, 0.88)

func _player_pos(pid: String) -> Vector2:
	for node in get_tree().get_nodes_in_group("players"):
		if node.player_id == pid:
			return node.global_position
	return Vector2.ZERO

func _centroid(pids: Array) -> Vector2:
	var sum := Vector2.ZERO
	for pid in pids:
		sum += _player_pos(pid)
	return sum / float(pids.size())
