class_name AbilityVfxLayer
extends Node2D

const PlayerLookup = preload("res://systems/PlayerLookup.gd")

# Effect type preloads for VFX classification
const _AoEDmg   := preload("res://data/abilities/effects/AoEDamageEffect.gd")
const _AoEHeal  := preload("res://data/abilities/effects/AoEHealEffect.gd")
const _AoESpeed := preload("res://data/abilities/effects/AoESpeedEffect.gd")
const _ScalPull := preload("res://data/abilities/effects/ScaledAoEPullEffect.gd")
const _StunFx   := preload("res://data/abilities/effects/StunEffect.gd")
const _KnockFx  := preload("res://data/abilities/effects/KnockbackEffect.gd")
const _ConfFx   := preload("res://data/abilities/effects/ConfusionEffect.gd")
const _PullFx   := preload("res://data/abilities/effects/PullEffect.gd")
const _SnapPull := preload("res://data/abilities/effects/SnapPullEffect.gd")
const _SnareFx  := preload("res://data/abilities/effects/SnareEffect.gd")
const _HexFx    := preload("res://data/abilities/effects/HexEffect.gd")
const _MarkFx   := preload("res://data/abilities/effects/MarkEffect.gd")
const _DashFx   := preload("res://data/abilities/effects/DashEffect.gd")
const _TeleFx   := preload("res://data/abilities/effects/TeleportEffect.gd")
const _SpeedFx  := preload("res://data/abilities/effects/SpeedBoostEffect.gd")
const _DmgBstFx := preload("res://data/abilities/effects/DamageBoostEffect.gd")
const _DmgRedFx := preload("res://data/abilities/effects/DamageReductionEffect.gd")
const _InvulnFx := preload("res://data/abilities/effects/InvulnerabilityEffect.gd")
const _StunImFx := preload("res://data/abilities/effects/StunImmuneEffect.gd")
const _HoTFx    := preload("res://data/abilities/effects/HoTEffect.gd")
const _PerHoTFx := preload("res://data/abilities/effects/PeriodicHoTEffect.gd")

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
const C_PURPLE := Color(0.65,  0.15,  0.85)
const C_DMG       := Color(1.0,   0.40,  0.10)
const C_LIGHTNING := Color(0.55,  0.85,  1.00)

const TERRAIN_PREVIEW_DUR := 1.5
const TERRAIN_EXPIRY_DUR  := 1.5
const BOLT_TRAVEL_DUR     := 0.22
const BOLT_IMPACT_DUR     := 0.40
const CHAIN_INTERVAL      := 0.12

var _active: Array = []

# Ability charge bar state
var _charging_player_id: String = ""
var _charge_elapsed: float      = 0.0
var _charge_max: float          = 0.0

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
	EventBus.force_field_shattered.connect(_on_force_field_shattered)
	EventBus.terrain_preview_started.connect(_on_terrain_preview_started)
	EventBus.terrain_expiry_warning.connect(_on_terrain_expiry_warning)
	EventBus.ability_charge_started.connect(_on_ability_charge_started)
	EventBus.ability_charge_released.connect(_on_ability_charge_released)

func _process(delta: float) -> void:
	var needs_redraw := false
	if not _active.is_empty():
		for v in _active:
			v.t = minf(v.t + delta, v.dur)
		_active = _active.filter(func(v): return v.t < v.dur)
		needs_redraw = true
	if not _charging_player_id.is_empty():
		_charge_elapsed = minf(_charge_elapsed + delta, _charge_max)
		needs_redraw = true
	if needs_redraw:
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

	# Classify effects to determine which specialized VFX to add
	var has_aoe     := definition.is_aoe
	var has_hard_cc := false
	var has_soft_cc := false
	var has_dash    := false
	var has_buff    := false
	var aoe_radius  := maxf(definition.aoe_radius, 2.5)
	for e in definition.effects:
		if e is _AoEDmg or e is _AoEHeal or e is _AoESpeed or e is _ScalPull:
			has_aoe = true
		if e is _StunFx or e is _KnockFx or e is _ConfFx or e is _PullFx or e is _SnapPull:
			has_hard_cc = true
		if e is _SnareFx or e is _HexFx or e is _MarkFx:
			has_soft_cc = true
		if e is _DashFx or e is _TeleFx:
			has_dash = true
		if e is _SpeedFx or e is _DmgBstFx or e is _DmgRedFx or e is _InvulnFx \
				or e is _StunImFx or e is _HoTFx or e is _PerHoTFx:
			has_buff = true

	# Bolt VFX for ranged projectile abilities — suppress impact_flash on covered targets.
	var bolt_targets: Array = _try_spawn_bolt_vfx(rec.class_id, slot, cpos, hit_ids)

	# Impact flash on non-bolt targets
	for hit_id in hit_ids:
		if not bolt_targets.has(hit_id):
			_spawn("impact_flash", _player_pos(hit_id), col, 0.20, {})

	# AoE burst ring
	if has_aoe and aoe_radius > 0.0:
		var center := _centroid(hit_ids) if not hit_ids.is_empty() else cpos
		_spawn("aoe_burst", center, col, 0.45, {"radius": aoe_radius})

	# Hard CC burst on targets (stun, knockback, confuse, pull)
	if has_hard_cc:
		for hit_id in hit_ids:
			_spawn("cc_burst", _player_pos(hit_id), C_YELLOW, 0.55, {})

	# Soft CC / debuff splash (snare, hex, mark)
	if has_soft_cc:
		for hit_id in hit_ids:
			_spawn("debuff_splash", _player_pos(hit_id), C_PURPLE, 0.40, {})

	# Dash/teleport afterglow at arrival point
	if has_dash:
		_spawn("dash_trail", cpos, col, 0.40, {})

	# Buff pulse on targets (or caster if no targets)
	if has_buff and not hit_ids.is_empty():
		for hit_id in hit_ids:
			_spawn("buff_pulse", _player_pos(hit_id), C_GREEN, 0.50, {})
	elif has_buff:
		_spawn("buff_pulse", cpos, C_GREEN, 0.50, {})

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
	else:
		col = MatchState.team_color(rec.team_id)
	_spawn("death_burst", _player_pos(player_id), col, 0.50, {})

func _on_ultra_scored(_team_id: int, scorer_id: String) -> void:
	_spawn("ultra_burst", _player_pos(scorer_id), C_GOLD, 0.80, {})

func _on_ball_picked_up(pid: String) -> void:
	_spawn("pickup_pulse", _player_pos(pid), C_GOLD, 0.25, {})

func _on_force_field_shattered(pos: Vector2) -> void:
	_spawn("ff_shatter", pos, Color(0.75, 0.92, 1.0), 0.60, {"radius": 5.0})

func _on_terrain_preview_started(event_type: String, world_pos: Vector2, radius: float, _intensity: float) -> void:
	_spawn("terrain_preview", world_pos, _terrain_color(event_type), TERRAIN_PREVIEW_DUR, {"radius": radius})

func _on_terrain_expiry_warning(event_type: String, world_pos: Vector2, radius: float) -> void:
	_spawn("terrain_expiry", world_pos, _terrain_color(event_type), TERRAIN_EXPIRY_DUR, {"radius": radius})

func _on_ability_charge_started(player_id: String, _slot: int, charge_max: float) -> void:
	_charging_player_id = player_id
	_charge_elapsed     = 0.0
	_charge_max         = charge_max

func _on_ability_charge_released(_pid: String, _slot: int, _charge_t: float) -> void:
	_charging_player_id = ""
	_charge_elapsed     = 0.0
	_charge_max         = 0.0

# ── Bolt VFX helpers ───────────────────────────────────────────────────────────

func _try_spawn_bolt_vfx(class_id: String, slot: int, cpos: Vector2, hit_ids: Array) -> Array:
	if class_id != "uberblitzer" or hit_ids.is_empty():
		return []
	match slot:
		1:  # Static Shock — short single arc
			_spawn_bolt(cpos, _player_pos(hit_ids[0]), C_LIGHTNING, 0.0)
			return [hit_ids[0]]
		2:  # Lightning Bolt — single arc caster → target
			_spawn_bolt(cpos, _player_pos(hit_ids[0]), C_LIGHTNING, 0.0)
			return [hit_ids[0]]
		3:  # Chain Lightning — sequential arcs
			var from := cpos
			for i in hit_ids.size():
				var delay := i * (BOLT_TRAVEL_DUR + CHAIN_INTERVAL)
				_spawn_bolt(from, _player_pos(hit_ids[i]), C_LIGHTNING, delay)
				from = _player_pos(hit_ids[i])
			return hit_ids.duplicate()
	return []

func _spawn_bolt(from: Vector2, to: Vector2, col: Color, delay: float) -> void:
	var travel_end := delay + BOLT_TRAVEL_DUR
	_active.append({
		"type": "bolt_travel", "t": 0.0, "dur": travel_end,
		"pos": from, "color": col,
		"data": {"from": from, "to": to, "delay": delay}
	})
	_active.append({
		"type": "bolt_impact", "t": 0.0, "dur": travel_end + BOLT_IMPACT_DUR,
		"pos": to, "color": col,
		"data": {"delay": travel_end}
	})

# ── Spawn ──────────────────────────────────────────────────────────────────────

func _spawn(type: String, pos: Vector2, color: Color, dur: float, data: Dictionary) -> void:
	_active.append({"type": type, "t": 0.0, "dur": dur, "pos": pos, "color": color, "data": data})

# ── Drawing ────────────────────────────────────────────────────────────────────

func _draw() -> void:
	for v in _active:
		var p: float = float(v.t) / float(v.dur)
		match v.type:
			"cast_ring":      _draw_cast_ring(v, p)
			"impact_flash":   _draw_impact_flash(v, p)
			"aoe_burst":      _draw_aoe_burst(v, p)
			"hit_spark":      _draw_hit_spark(v, p)
			"heal_rise":      _draw_heal_rise(v, p)
			"death_burst":    _draw_death_burst(v, p)
			"ultra_burst":    _draw_ultra_burst(v, p)
			"pickup_pulse":   _draw_pickup_pulse(v, p)
			"ff_shatter":     _draw_ff_shatter(v, p)
			"terrain_preview": _draw_terrain_preview(v, p)
			"terrain_expiry":  _draw_terrain_expiry(v, p)
			"bolt_travel":     _draw_bolt_travel(v, p)
			"bolt_impact":     _draw_bolt_impact(v, p)
			"cc_burst":        _draw_cc_burst(v, p)
			"debuff_splash":   _draw_debuff_splash(v, p)
			"buff_pulse":      _draw_buff_pulse(v, p)
			"dash_trail":      _draw_dash_trail(v, p)
	if not _charging_player_id.is_empty() and _charge_max > 0.0:
		_draw_ability_charge_bar(_player_pos(_charging_player_id), _charge_elapsed / _charge_max)

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

func _draw_ff_shatter(v: Dictionary, p: float) -> void:
	var radius: float = v.data.get("radius", 5.0)
	var ep  := _ease_out(p)
	var a   := lerpf(1.0, 0.0, p * p)
	var col := Color(v.color.r, v.color.g, v.color.b, a)
	# Expanding burst ring
	draw_arc(v.pos, lerpf(radius * 0.8, radius * 1.7, ep), 0.0, TAU, 48,
		col, lerpf(0.18, 0.04, p))
	# Inner flash circle
	draw_circle(v.pos, lerpf(radius * 0.5, 0.0, ep),
		Color(v.color.r, v.color.g, v.color.b, a * 0.35))
	# Radiating shard lines
	for i in 16:
		var angle := i * TAU / 16.0 + p * 0.3
		var dir   := Vector2(cos(angle), sin(angle))
		var r0    := lerpf(radius * 0.4, radius * 0.9, ep)
		var r1    := lerpf(radius * 0.7, radius * 1.9, ep)
		draw_line(v.pos + dir * r0, v.pos + dir * r1, col, 0.06)

func _draw_terrain_preview(v: Dictionary, p: float) -> void:
	var radius: float = v.data.get("radius", 3.0)
	# 3 pulses over the full preview window
	var pulse := sin(p * TAU * 3.0) * 0.5 + 0.5
	var col: Color = v.color
	draw_circle(v.pos, radius, Color(col.r, col.g, col.b, pulse * 0.18))
	draw_arc(v.pos, radius, 0.0, TAU, 64, Color(col.r, col.g, col.b, pulse * 0.85), 0.14)
	draw_arc(v.pos, radius * 0.55, 0.0, TAU, 32, Color(col.r, col.g, col.b, pulse * 0.35), 0.06)

func _draw_terrain_expiry(v: Dictionary, p: float) -> void:
	var radius: float = v.data.get("radius", 3.0)
	# 4 faster pulses, fading toward end
	var pulse := sin(p * TAU * 4.0) * 0.5 + 0.5
	var fade  := lerpf(1.0, 0.0, p)
	var col: Color = v.color
	draw_circle(v.pos, radius, Color(col.r, col.g, col.b, pulse * fade * 0.15))
	draw_arc(v.pos, radius, 0.0, TAU, 64, Color(col.r, col.g, col.b, pulse * fade * 0.75), 0.12)
	for i in 8:
		var angle := float(i) / 8.0 * TAU
		var d     := Vector2(cos(angle), sin(angle))
		draw_line(v.pos + d * radius,
				  v.pos + d * (radius + 0.4 * fade),
				  Color(col.r, col.g, col.b, pulse * fade * 0.55), 0.07)

func _draw_ability_charge_bar(pos: Vector2, pct: float) -> void:
	var bar_w   := 2.0
	var bar_h   := 0.18
	var bar_pos := pos + Vector2(0.0, 0.95)
	var left    := bar_pos - Vector2(bar_w * 0.5, 0.0)
	draw_rect(Rect2(left, Vector2(bar_w, bar_h)), Color(0.04, 0.04, 0.12, 0.88))
	if pct > 0.0:
		var t        := clampf((pct - 0.8) / 0.2, 0.0, 1.0)
		var fill_col := C_GOLD.lerp(C_RED, t)
		draw_rect(Rect2(left, Vector2(bar_w * pct, bar_h)),
				  Color(fill_col.r, fill_col.g, fill_col.b, 0.95))
	draw_rect(Rect2(left, Vector2(bar_w, bar_h)), Color(1.0, 1.0, 1.0, 0.28), false, 0.03)

func _draw_bolt_travel(v: Dictionary, _p: float) -> void:
	var delay: float = v.data.get("delay", 0.0)
	if v.t < delay:
		return
	var lp   := clampf((v.t - delay) / BOLT_TRAVEL_DUR, 0.0, 1.0)
	var from : Vector2 = v.data.get("from", v.pos)
	var to   : Vector2 = v.data.get("to",   v.pos)
	var tip  := from.lerp(to, lp)
	var col: Color = v.color

	# Jagged bolt trail from origin to current tip
	if lp > 0.02:
		_draw_lightning_segment(from, tip, col, lerpf(0.85, 0.45, lp), v.t)
		_draw_lightning_segment(from, tip, Color(1.0, 1.0, 1.0, 0.25), lerpf(0.45, 0.10, lp), v.t + 0.07)

	# Bright glowing head at the tip
	var head_a := lerpf(1.0, 0.0, lp * lp)
	draw_circle(tip, 0.30, Color(1.0, 1.0, 1.0, head_a * 0.88))
	draw_circle(tip, 0.17, Color(col.r, col.g, col.b, head_a))

func _draw_bolt_impact(v: Dictionary, _p: float) -> void:
	var delay: float = v.data.get("delay", 0.0)
	if v.t < delay:
		return
	var lp  := clampf((v.t - delay) / BOLT_IMPACT_DUR, 0.0, 1.0)
	var ep  := _ease_out(lp)
	var col: Color = v.color

	# White flash that fades quickly
	var flash_a := clampf(lerpf(1.0, 0.0, lp * 3.0), 0.0, 1.0)
	draw_circle(v.pos, lerpf(0.0, 0.80, ep), Color(1.0, 1.0, 1.0, flash_a))
	draw_circle(v.pos, lerpf(0.0, 0.48, ep), Color(col.r, col.g, col.b, flash_a * 0.70))

	# Expanding electric ring
	var ring_a := lerpf(0.85, 0.0, lp)
	draw_arc(v.pos, lerpf(0.0, 1.9, ep), 0.0, TAU, 48,
		Color(col.r, col.g, col.b, ring_a), 0.055)

	# Radiating jagged spark lines
	var spark_a := lerpf(0.90, 0.0, lp)
	for i in 8:
		var angle := i * TAU / 8.0 + lp * 0.5
		var dir   := Vector2(cos(angle), sin(angle))
		var perp  := Vector2(-dir.y, dir.x)
		var r0    := lerpf(0.0, 0.28, ep)
		var r1    := lerpf(0.0, 1.15, ep)
		var jitter := sin(float(i) * 1.7 + v.t * 38.0) * 0.18 * ep
		var mid: Vector2 = v.pos + dir * lerpf(r0, r1, 0.5) + perp * jitter
		draw_line(v.pos + dir * r0, mid,
			Color(1.0, 1.0, 1.0, spark_a * 0.65), 0.055)
		draw_line(mid, v.pos + dir * r1,
			Color(col.r, col.g, col.b, spark_a), 0.040)

func _draw_lightning_segment(from: Vector2, to: Vector2, col: Color, alpha: float, t: float) -> void:
	var d := to - from
	if d.length_squared() < 0.05:
		return
	var perp := Vector2(-d.y, d.x).normalized()
	const N := 7
	var pts: PackedVector2Array = []
	pts.append(from)
	for i in range(1, N):
		var frac   := float(i) / float(N)
		var base   := from + d * frac
		var jitter := sin(frac * PI * 5.0 + t * 55.0) * d.length() * 0.09
		pts.append(base + perp * jitter)
	pts.append(to)
	for i in range(pts.size() - 1):
		draw_line(pts[i], pts[i + 1], Color(col.r, col.g, col.b, alpha * 0.55), 0.07)
		draw_line(pts[i], pts[i + 1], Color(1.0, 1.0, 1.0, alpha * 0.85), 0.03)

func _draw_cc_burst(v: Dictionary, p: float) -> void:
	var ep  := _ease_out(p)
	var a   := lerpf(0.95, 0.0, p * p)
	var col := Color(v.color.r, v.color.g, v.color.b, a)
	draw_arc(v.pos, lerpf(0.0, 1.6, ep), 0.0, TAU, 48, col, lerpf(0.12, 0.03, p))
	for i in 6:
		var angle := i * TAU / 6.0 + p * PI * 1.5
		var dir   := Vector2(cos(angle), sin(angle))
		draw_circle(v.pos + dir * lerpf(0.08, 1.2, ep), lerpf(0.10, 0.03, p), col)

func _draw_debuff_splash(v: Dictionary, p: float) -> void:
	var ep  := _ease_out(p)
	var a   := lerpf(0.80, 0.0, p * p)
	var col := Color(v.color.r, v.color.g, v.color.b, a)
	for i in 5:
		var angle := i * TAU / 5.0 + p * 0.8
		var dir   := Vector2(cos(angle), sin(angle))
		draw_line(v.pos + dir * lerpf(0.08, 0.22, ep),
				  v.pos + dir * lerpf(0.22, 0.85, ep), col, 0.05)
	draw_circle(v.pos, lerpf(0.22, 0.0, p), Color(col.r, col.g, col.b, a * 0.45))

func _draw_buff_pulse(v: Dictionary, p: float) -> void:
	var ep  := _ease_out(p)
	var a   := lerpf(0.75, 0.0, p * p)
	var col := Color(v.color.r, v.color.g, v.color.b, a)
	draw_arc(v.pos, lerpf(0.0, 1.1, ep), 0.0, TAU, 48, col, lerpf(0.09, 0.02, p))
	for i in 4:
		var angle := i * TAU / 4.0 + p * 0.4
		var dir   := Vector2(cos(angle), sin(angle))
		var r     := lerpf(0.15, 0.85, ep)
		draw_circle(v.pos + dir * r + Vector2(0.0, -lerpf(0.0, 0.35, ep)), lerpf(0.07, 0.02, p), col)

func _draw_dash_trail(v: Dictionary, p: float) -> void:
	var ep  := _ease_out(p)
	var a   := lerpf(0.65, 0.0, p)
	var col := Color(v.color.r, v.color.g, v.color.b, a)
	draw_arc(v.pos, lerpf(0.45, 0.80, p), 0.0, TAU, 32, col, lerpf(0.10, 0.02, p))
	draw_line(v.pos - Vector2(lerpf(0.9, 0.0, ep), 0.0),
			  v.pos + Vector2(lerpf(0.9, 0.0, ep), 0.0),
			  Color(1.0, 1.0, 1.0, a * 0.45), lerpf(0.18, 0.04, p))

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
	return PlayerLookup.get_position(pid)

func _terrain_color(event_type: String) -> Color:
	match event_type:
		"hill":   return Color(0.35, 0.80, 0.15)
		"valley": return Color(0.30, 0.55, 0.95)
		"pit":    return Color(0.90, 0.15, 0.05)
		"mud":    return Color(0.60, 0.40, 0.10)
		"lava":   return Color(1.00, 0.35, 0.00)
		"ice":    return Color(0.50, 0.90, 1.00)
	return Color(0.80, 0.80, 0.80)

func _centroid(pids: Array) -> Vector2:
	var sum := Vector2.ZERO
	for pid in pids:
		sum += _player_pos(pid)
	return sum / float(pids.size())
