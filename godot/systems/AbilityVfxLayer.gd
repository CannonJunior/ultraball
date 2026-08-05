class_name AbilityVfxLayer
extends Node2D

const PlayerLookup    = preload("res://systems/PlayerLookup.gd")
const AbilityVfxConfig = preload("res://data/abilities/AbilityVfxConfig.gd")
const _LightningBoltVfx = preload("res://scenes/game/vfx/LightningBoltVfx.gd")

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

## One-shot and sustained world-space VFX for ability casts, traversals, impacts, and deaths.
## Draw-call based — no scene nodes, no particles. Consistent with the rest of the 2D world.
## Added to GameScene as a sibling of $Entities (z_index 10).
##
## Each active effect is a plain Dictionary: { type, t, dur, pos, color, data }
## t advances in _process(); _draw() dispatches to per-type draw functions.

const C_RED    := Color(1.0,   0.25,  0.25)
const C_BLUE   := Color(0.25,  0.50,  1.0)
const C_YELLOW := Color(1.0,   0.85,  0.15)
const C_GOLD   := Color(1.0,   0.82,  0.10)
const C_GREEN  := Color(0.20,  0.90,  0.35)
const C_TEAL   := Color(0.10,  0.75,  0.60)
const C_PURPLE := Color(0.65,  0.15,  0.85)
const C_DMG       := Color(1.0,   0.40,  0.10)
const C_LIGHTNING := Color(0.55,  0.85,  1.00)

const _HEAL_CAST_COLORS: Array = [
	Color(1.00, 0.90, 0.25),  # warm yellow
	Color(0.95, 0.45, 0.75),  # pink
	Color(0.35, 0.85, 1.00),  # sky blue
	Color(1.00, 0.55, 0.20),  # orange
	Color(0.70, 1.00, 0.40),  # bright green
	Color(1.00, 0.40, 0.50),  # coral
	Color(0.45, 0.95, 0.75),  # aqua
	Color(0.85, 0.95, 0.25),  # yellow-green
]

const TERRAIN_PREVIEW_DUR := 1.5
const TERRAIN_EXPIRY_DUR  := 1.5
const BOLT_TRAVEL_DUR     := 0.22
const BOLT_IMPACT_DUR     := 0.40
const CHAIN_INTERVAL      := 0.12

var _active: Array = []
var _is_3d_mode := false

# Lightning support nodes — resolved one frame after _ready via call_deferred.
var _flash_overlay: Node = null
var _thunder_audio: Node = null

# Ability charge bar state
var _charging_player_id: String = ""
var _charge_elapsed: float      = 0.0
var _charge_max: float          = 0.0

func _ready() -> void:
	z_index = 10
	_is_3d_mode = MatchState.config != null and \
		MatchState.config.view_mode != MatchConfig.ViewMode.FLAT_2D
	# Always maintain the effect pool — ViewLayer3D reads _active in 3D mode.
	EventBus.ability_resolved.connect(_on_ability_resolved)
	EventBus.damage_applied.connect(_on_damage_applied)
	EventBus.healing_applied.connect(_on_healing_applied)
	EventBus.periodic_hot_applied.connect(_on_periodic_hot_applied)
	EventBus.player_died.connect(_on_player_died)
	EventBus.ultra_scored.connect(_on_ultra_scored)
	EventBus.ball_picked_up.connect(_on_ball_picked_up)
	EventBus.force_field_shattered.connect(_on_force_field_shattered)
	EventBus.ability_charge_started.connect(_on_ability_charge_started)
	EventBus.ability_charge_released.connect(_on_ability_charge_released)
	if not _is_3d_mode:
		# ViewLayer3D handles terrain indicators in 3D mode already.
		EventBus.terrain_preview_started.connect(_on_terrain_preview_started)
		EventBus.terrain_expiry_warning.connect(_on_terrain_expiry_warning)
	# Flash overlay and thunder audio are added by GameScene after this _ready fires.
	call_deferred("_resolve_lightning_nodes")

func _resolve_lightning_nodes() -> void:
	var flash_nodes := get_tree().get_nodes_in_group("lightning_flash")
	if not flash_nodes.is_empty():
		_flash_overlay = flash_nodes[0]
	var thunder_nodes := get_tree().get_nodes_in_group("thunder_audio")
	if not thunder_nodes.is_empty():
		_thunder_audio = thunder_nodes[0]

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
	var vfx: AbilityVfxConfig = definition.vfx_config

	# Cast effect at caster
	if vfx != null and vfx.cast_type != 0:
		_spawn_custom_cast(vfx, cpos, hit_ids)
	else:
		_spawn("cast_ring", cpos, col, 0.35, {})

	# Classify generic effects
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

	for hit_id in hit_ids:
		if bolt_targets.has(hit_id):
			continue
		var tpos := _player_pos(hit_id)
		# Traversal
		if vfx != null and vfx.traversal_type != 0:
			_spawn_custom_traversal(vfx, cpos, tpos)
		# Impact
		if vfx != null and vfx.impact_type != 0:
			_spawn_custom_impact(vfx, tpos, cpos)
		else:
			_spawn("impact_flash", tpos, col, 0.20, {})

	# AoE burst ring — use custom cast color when vfx_config present
	if has_aoe and aoe_radius > 0.0:
		var center := _centroid(hit_ids) if not hit_ids.is_empty() else cpos
		var burst_col := vfx.cast_color if (vfx != null and vfx.cast_color.a > 0.01) else col
		_spawn("aoe_burst", center, burst_col, 0.45, {"radius": aoe_radius})

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

	# Generic buff pulse only when no custom impact already shows it
	if has_buff and not hit_ids.is_empty():
		if vfx == null or vfx.impact_type == 0:
			for hit_id in hit_ids:
				_spawn("buff_pulse", _player_pos(hit_id), C_GREEN, 0.50, {})
	elif has_buff:
		if vfx == null or vfx.impact_type == 0:
			_spawn("buff_pulse", cpos, C_GREEN, 0.50, {})

	# Sustained field effect (Prolong pulse, Verdure rotating arcs)
	if vfx != null and vfx.sustained_type != 0:
		var spos := cpos
		var follow_id := ""
		if vfx.sustained_type == 1 and not hit_ids.is_empty():
			spos = _player_pos(hit_ids[0])
			follow_id = hit_ids[0]
		_spawn_custom_sustained(vfx, spos, follow_id)

func _on_damage_applied(_attacker_id: String, target_id: String, _amount: float, _is_kill: bool) -> void:
	_spawn("hit_spark", _player_pos(target_id), C_DMG, 0.25, {})

func _on_healing_applied(_healer_id: String, target_id: String, _amount: float) -> void:
	_spawn("heal_rise", _player_pos(target_id), C_GREEN, 0.60,
		{"delays": [0.0, 0.15, 0.10, 0.22], "offsets": [0.0, -0.15, 0.12, -0.07]})

func _on_periodic_hot_applied(payload: Dictionary) -> void:
	var target_id: String = payload.get("target_id", "")
	if target_id.is_empty():
		return
	var tpos := _player_pos(target_id)
	_spawn("heal_rise", tpos, C_TEAL, 0.55,
		{"delays": [0.0, 0.08, 0.14], "offsets": [0.0, -0.10, 0.08]})
	_spawn("hot_sparkle", tpos, C_GREEN, 0.45, {})

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

# ── Custom VFX spawners ────────────────────────────────────────────────────────

func _spawn_custom_cast(vfx: AbilityVfxConfig, cpos: Vector2, hit_ids: Array) -> void:
	var dir := Vector2.ZERO
	if not hit_ids.is_empty():
		var tpos := _player_pos(hit_ids[0])
		if tpos.distance_squared_to(cpos) > 0.01:
			dir = (tpos - cpos).normalized()
	match vfx.cast_type:
		1:  # ring — slow expanding ring (Mend, Bulwark)
			_spawn("cast_ring", cpos, vfx.cast_color, vfx.cast_duration,
				{"radius": vfx.cast_radius})
		2:  # double_ring — inner + outer rings with directed mote fan (Infuse)
			_spawn("double_ring", cpos, vfx.cast_color, vfx.cast_duration,
				{"radius": vfx.cast_radius, "dir": dir})
		3:  # petals — N petals blooming outward (Cascade, Verdure)
			var count := 8 if vfx.cast_radius < 7.0 else 12
			_spawn("petal_bloom", cpos, vfx.cast_color, vfx.cast_duration,
				{"radius": vfx.cast_radius, "count": count})
		4:  # compressed_rings — rings collapse inward then burst (Empower)
			_spawn("compressed_rings", cpos, vfx.cast_color, vfx.cast_duration,
				{"radius": vfx.cast_radius, "dir": dir})
		5:  # spiral — rotating spiral of motes (Prolong)
			_spawn("spiral_cast", cpos, vfx.cast_color, vfx.cast_duration,
				{"radius": vfx.cast_radius})
		6:  # cross_burst — cross shape at caster (Refresh)
			_spawn("cross_burst", cpos, vfx.cast_color, vfx.cast_duration,
				{"arm_len": vfx.cast_radius})
		7:  # strike_flash — sharp ring + directional lines (Tap, Rebuke)
			_spawn("strike_flash", cpos, vfx.cast_color, vfx.cast_duration,
				{"radius": vfx.cast_radius, "dir": dir, "arc_count": 2})
		8:  # heal_spiral — colored lines spiraling upward from caster
			_spawn("heal_spiral_cast", cpos, vfx.cast_color, vfx.cast_duration, {})
		9:  # blue_cloud — blue particle cloud expanding from caster
			_spawn("blue_cloud_cast", cpos, vfx.cast_color, vfx.cast_duration, {})
		10: # lightning_discharge — directional arcs + large flash ring (Lightning Bolt)
			_spawn("lightning_discharge", cpos, vfx.cast_color, vfx.cast_duration,
				{"radius": vfx.cast_radius, "dir": dir})
		11: # chain_burst — radial zigzag arcs in all directions + double ring (Chain Lightning)
			_spawn("chain_burst", cpos, vfx.cast_color, vfx.cast_duration,
				{"radius": vfx.cast_radius})

func _spawn_custom_traversal(vfx: AbilityVfxConfig, from_pos: Vector2, to_pos: Vector2) -> void:
	var d := {"from": from_pos, "to": to_pos}
	match vfx.traversal_type:
		1:  # mote_ribbon — staggered motes along bezier arc
			d["count"]   = vfx.traversal_count
			d["stagger"] = 0.05 / maxf(vfx.traversal_duration, 0.1)  # normalized stagger
			_spawn("mote_ribbon", from_pos, vfx.traversal_color, vfx.traversal_duration, d)
		2:  # strike_line — parallel lines between two points
			d["lines"] = vfx.traversal_lines
			_spawn("strike_line", from_pos, vfx.traversal_color, vfx.traversal_duration, d)
		3:  # disc_projectile — filled disc traveling A→B
			d["radius"] = 0.30
			_spawn("disc_projectile", from_pos, vfx.traversal_color, vfx.traversal_duration, d)
		4:  # ring_projectile — shrinking spinning ring traveling A→B (Prolong)
			d["start_radius"] = 0.80
			d["end_radius"]   = 0.25
			_spawn("ring_projectile", from_pos, vfx.traversal_color, vfx.traversal_duration, d)
		5:  # heal_spiral_travel — colored lines spiraling along path
			_spawn("heal_spiral_travel", from_pos, vfx.traversal_color, vfx.traversal_duration, d)
		6:  # blue_cloud_stream — blue particles streaming along path
			_spawn("blue_cloud_travel", from_pos, vfx.traversal_color, vfx.traversal_duration, d)

func _spawn_custom_impact(vfx: AbilityVfxConfig, tpos: Vector2, _cpos: Vector2) -> void:
	match vfx.impact_type:
		1:  # burst_ring — expanding ring
			_spawn("burst_ring", tpos, vfx.impact_color, 0.35,
				{"radius": vfx.impact_radius})
		2:  # rising_orbs — like heal_rise but in custom color
			_spawn("heal_rise", tpos, vfx.impact_color, 0.60,
				{"delays": [0.0, 0.12, 0.08, 0.18], "offsets": [0.0, -0.12, 0.10, -0.06]})
		3:  # shield_collapse — arcs collapse inward, then buff_pulse (Bulwark, Prolong)
			_spawn("shield_collapse", tpos, vfx.impact_color, 0.30,
				{"start_radius": vfx.impact_radius, "count": 5})
			_spawn("buff_pulse", tpos, vfx.impact_color, 0.50, {})
		4:  # sparks — radiating lines in custom color (Empower)
			_spawn("hit_spark", tpos, vfx.impact_color, 0.30, {})
			_spawn("buff_pulse", tpos, vfx.impact_color, 0.50, {})
		5:  # two_phase — heal burst then HoT ring (Infuse)
			_spawn("burst_ring", tpos, vfx.impact_color, 0.30,
				{"radius": vfx.impact_radius})
			_active.append({
				"type": "burst_ring", "t": 0.0,
				"dur": vfx.impact_phase2_delay + 0.50,
				"pos": tpos, "color": vfx.impact_phase2_color,
				"data": {"radius": vfx.impact_radius * 1.25, "delay": vfx.impact_phase2_delay}
			})
		6:  # heal impact — same rising spark effect as cast, at target position
			_spawn("heal_spiral_cast", tpos, vfx.cast_color, vfx.cast_duration, {})
		7:  # blue_cloud_impact — blue particles orbiting at impact
			_spawn("blue_cloud_impact", tpos, vfx.impact_color, 0.70, {})

func _spawn_custom_sustained(vfx: AbilityVfxConfig, pos: Vector2, follow_id: String) -> void:
	match vfx.sustained_type:
		1:  # sustained_pulse — slow persistent pulse following target (Prolong)
			_active.append({
				"type": "sustained_pulse", "t": 0.0, "dur": vfx.sustained_duration,
				"pos": pos, "color": vfx.sustained_color,
				"data": {"radius": vfx.sustained_radius, "target_id": follow_id,
						 "pulse_freq": 0.5}
			})
		2:  # rotating_arcs — arcs rotating at perimeter for Verdure field
			_active.append({
				"type": "rotating_arcs", "t": 0.0, "dur": vfx.sustained_duration,
				"pos": pos, "color": vfx.sustained_color,
				"data": {"radius": vfx.sustained_radius, "count": 12,
						 "speed": TAU / 3.0, "target_id": follow_id}
			})

# ── Bolt VFX helpers ───────────────────────────────────────────────────────────

func _try_spawn_bolt_vfx(class_id: String, slot: int, cpos: Vector2, hit_ids: Array) -> Array:
	if class_id != "uberblitzer" or hit_ids.is_empty():
		return []
	match slot:
		1:  # Static Shock — short single arc
			_spawn_bolt(cpos, _player_pos(hit_ids[0]), C_LIGHTNING, 0.0, slot)
			return [hit_ids[0]]
		2:  # Lightning Bolt — single arc caster → target
			_spawn_bolt(cpos, _player_pos(hit_ids[0]), C_LIGHTNING, 0.0, slot)
			return [hit_ids[0]]
		3:  # Chain Lightning — sequential arcs
			var chain_from := cpos
			for i in hit_ids.size():
				var chain_delay := float(i) * (BOLT_TRAVEL_DUR + CHAIN_INTERVAL)
				_spawn_bolt(chain_from, _player_pos(hit_ids[i]), C_LIGHTNING, chain_delay, slot)
				chain_from = _player_pos(hit_ids[i])
			return hit_ids.duplicate()
	return []

func _spawn_bolt(from: Vector2, to: Vector2, col: Color, delay: float, slot: int = 0) -> void:
	var travel_end := delay + BOLT_TRAVEL_DUR

	# ── 2D: Line2D procedural bolt node ──────────────────────────────────────
	var bolt := _LightningBoltVfx.new()
	bolt.from      = from
	bolt.to        = to
	bolt.delay     = delay
	bolt.duration  = BOLT_TRAVEL_DUR
	bolt.color     = col
	bolt.is_3d_mode = _is_3d_mode
	add_child(bolt)

	# ── Screen flash at moment of impact ─────────────────────────────────────
	if _flash_overlay != null:
		var anim_name  := "chain_flash" if slot == 3 else "bolt_flash"
		var overlay_ref := _flash_overlay
		var flash_cb   := func():
			if is_instance_valid(overlay_ref):
				overlay_ref.play(anim_name)
		get_tree().create_timer(travel_end).timeout.connect(flash_cb, CONNECT_ONE_SHOT)

	# ── Thunder audio ─────────────────────────────────────────────────────────
	if _thunder_audio != null:
		_thunder_audio.play_thunder(from.distance_to(to), travel_end + 0.05)

	# ── 3D cue — ViewLayer3D reads bolt_travel for its own rendering ──────────
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
	if _is_3d_mode:
		return  # ViewLayer3D renders the pool in 3D
	for v in _active:
		var p: float = float(v.t) / float(v.dur)
		match v.type:
			"cast_ring":        _draw_cast_ring(v, p)
			"impact_flash":     _draw_impact_flash(v, p)
			"aoe_burst":        _draw_aoe_burst(v, p)
			"hit_spark":        _draw_hit_spark(v, p)
			"heal_rise":        _draw_heal_rise(v, p)
			"death_burst":      _draw_death_burst(v, p)
			"ultra_burst":      _draw_ultra_burst(v, p)
			"pickup_pulse":     _draw_pickup_pulse(v, p)
			"ff_shatter":       _draw_ff_shatter(v, p)
			"terrain_preview":  _draw_terrain_preview(v, p)
			"terrain_expiry":   _draw_terrain_expiry(v, p)
			# bolt_travel: thin draw_line core + LightningBoltVfx glow halo (both render together).
			"bolt_travel":      _draw_bolt_travel(v, p)
			"bolt_impact":      _draw_bolt_impact(v, p)
			"cc_burst":         _draw_cc_burst(v, p)
			"debuff_splash":    _draw_debuff_splash(v, p)
			"buff_pulse":       _draw_buff_pulse(v, p)
			"dash_trail":       _draw_dash_trail(v, p)
			# ── Vitalist custom types ──────────────────────────────────────────
			"burst_ring":       _draw_burst_ring(v, p)
			"double_ring":      _draw_double_ring(v, p)
			"petal_bloom":      _draw_petal_bloom(v, p)
			"compressed_rings": _draw_compressed_rings(v, p)
			"spiral_cast":      _draw_spiral_cast(v, p)
			"cross_burst":      _draw_cross_burst(v, p)
			"strike_flash":     _draw_strike_flash(v, p)
			"mote_ribbon":      _draw_mote_ribbon(v, p)
			"strike_line":      _draw_strike_line(v, p)
			"disc_projectile":  _draw_disc_projectile(v, p)
			"ring_projectile":  _draw_ring_projectile(v, p)
			"shield_collapse":  _draw_shield_collapse(v, p)
			"sustained_pulse":  _draw_sustained_pulse(v, p)
			"rotating_arcs":    _draw_rotating_arcs(v, p)
			# ── Heal spiral and blue cloud ─────────────────────────────────────
			"heal_spiral_cast":    _draw_heal_spiral_cast(v, p)
			"heal_spiral_travel":  _draw_heal_spiral_travel(v, p)
			"blue_cloud_cast":     _draw_blue_cloud_cast(v, p)
			"blue_cloud_travel":   _draw_blue_cloud_travel(v, p)
			"blue_cloud_impact":   _draw_blue_cloud_impact(v, p)
			"hot_sparkle":         _draw_hot_sparkle(v, p)
			"lightning_discharge": _draw_lightning_discharge(v, p)
			"chain_burst":         _draw_chain_burst(v, p)
	if not _charging_player_id.is_empty() and _charge_max > 0.0:
		_draw_ability_charge_bar(_player_pos(_charging_player_id), _charge_elapsed / _charge_max)

# ── Existing draw functions ────────────────────────────────────────────────────

func _draw_cast_ring(v: Dictionary, p: float) -> void:
	var ep      := _ease_out(p)
	var max_r   : float = v.data.get("radius", 1.40)
	var r       := lerpf(max_r * 0.35, max_r, ep)
	var a       := lerpf(0.90, 0.00, p)
	var w       := lerpf(0.07, 0.02, p)
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
	for i in mini(delays.size(), offsets.size()):
		var dp := clampf((p - delays[i]) / (1.0 - delays[i]), 0.0, 1.0)
		if dp <= 0.0:
			continue
		var a    := lerpf(0.80, 0.0, dp * dp)
		var rise := lerpf(0.00, 0.65, _ease_out(dp))
		draw_circle(v.pos + Vector2(offsets[i], -rise), 0.07,
			Color(v.color.r, v.color.g, v.color.b, a))

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
	draw_arc(v.pos, lerpf(radius * 0.8, radius * 1.7, ep), 0.0, TAU, 48,
		col, lerpf(0.18, 0.04, p))
	draw_circle(v.pos, lerpf(radius * 0.5, 0.0, ep),
		Color(v.color.r, v.color.g, v.color.b, a * 0.35))
	for i in 16:
		var angle := i * TAU / 16.0 + p * 0.3
		var dir   := Vector2(cos(angle), sin(angle))
		var r0    := lerpf(radius * 0.4, radius * 0.9, ep)
		var r1    := lerpf(radius * 0.7, radius * 1.9, ep)
		draw_line(v.pos + dir * r0, v.pos + dir * r1, col, 0.06)

func _draw_terrain_preview(v: Dictionary, p: float) -> void:
	var radius: float = v.data.get("radius", 3.0)
	var pulse := sin(p * TAU * 3.0) * 0.5 + 0.5
	var col: Color = v.color
	draw_circle(v.pos, radius, Color(col.r, col.g, col.b, pulse * 0.18))
	draw_arc(v.pos, radius, 0.0, TAU, 64, Color(col.r, col.g, col.b, pulse * 0.85), 0.14)
	draw_arc(v.pos, radius * 0.55, 0.0, TAU, 32, Color(col.r, col.g, col.b, pulse * 0.35), 0.06)

func _draw_terrain_expiry(v: Dictionary, p: float) -> void:
	var radius: float = v.data.get("radius", 3.0)
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
	var lp : float = clampf((v.t - delay) / BOLT_TRAVEL_DUR, 0.0, 1.0)
	var from: Vector2 = v.data.get("from", v.pos)
	var to:   Vector2 = v.data.get("to",   v.pos)
	var tip: Vector2  = from.lerp(to, _ease_out(lp))
	var a := lerpf(0.90, 0.15, lp)
	var col := Color(v.color.r, v.color.g, v.color.b, a)
	var pts: PackedVector2Array = _displace_bolt(from, tip, 3)
	for i in range(pts.size() - 1):
		draw_line(pts[i], pts[i + 1], col, 0.05)

func _displace_bolt(a: Vector2, b: Vector2, levels: int) -> PackedVector2Array:
	var pts := PackedVector2Array([a, b])
	var disp := a.distance_to(b) * 0.35
	for _lvl in levels:
		var next := PackedVector2Array()
		next.append(pts[0])
		for i in range(pts.size() - 1):
			var p0: Vector2 = pts[i]
			var p1: Vector2 = pts[i + 1]
			var mid  := (p0 + p1) * 0.5
			var perp := Vector2(-(p1 - p0).y, (p1 - p0).x).normalized()
			var kick := (randf() - 0.5) * 2.0 * disp
			next.append(mid + perp * kick)
			next.append(p1)
		pts  = next
		disp *= 0.5
	return pts

func _draw_bolt_impact(v: Dictionary, _p: float) -> void:
	var delay: float = v.data.get("delay", 0.0)
	if v.t < delay:
		return
	var lp  := clampf((v.t - delay) / BOLT_IMPACT_DUR, 0.0, 1.0)
	var ep  := _ease_out(lp)
	var col: Color = v.color
	var flash_a := clampf(lerpf(1.0, 0.0, lp * 3.0), 0.0, 1.0)
	draw_circle(v.pos, lerpf(0.0, 2.5, ep),  Color(1.0, 1.0, 1.0, flash_a))
	draw_circle(v.pos, lerpf(0.0, 1.5, ep),  Color(col.r, col.g, col.b, flash_a * 0.70))
	var ring_a := lerpf(0.85, 0.0, lp)
	draw_arc(v.pos, lerpf(0.0, 5.5, ep), 0.0, TAU, 64,
		Color(col.r, col.g, col.b, ring_a), lerpf(0.07, 0.02, lp))
	var ring2_a := lerpf(0.55, 0.0, lp)
	draw_arc(v.pos, lerpf(0.0, 3.0, _ease_out(clampf(lp * 0.7, 0.0, 1.0))), 0.0, TAU, 48,
		Color(1.0, 1.0, 1.0, ring2_a), lerpf(0.05, 0.01, lp))
	var spark_a := lerpf(0.90, 0.0, lp)
	for i in 12:
		var angle := float(i) * TAU / 12.0 + lp * 0.5
		var dir   := Vector2(cos(angle), sin(angle))
		var perp  := Vector2(-dir.y, dir.x)
		var r0    := lerpf(0.0, 0.40, ep)
		var r1    := lerpf(0.0, 3.5, ep)
		var jitter := sin(float(i) * 1.7 + v.t * 38.0) * 0.28 * ep
		var mid: Vector2 = v.pos + dir * lerpf(r0, r1, 0.5) + perp * jitter
		draw_line(v.pos + dir * r0, mid,
			Color(1.0, 1.0, 1.0, spark_a * 0.65), 0.06)
		draw_line(mid, v.pos + dir * r1,
			Color(col.r, col.g, col.b, spark_a), 0.045)

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

# ── Vitalist custom draw functions ─────────────────────────────────────────────

func _draw_burst_ring(v: Dictionary, p: float) -> void:
	var delay: float = v.data.get("delay", 0.0)
	if v.t < delay:
		return
	var lp := clampf((v.t - delay) / maxf(v.dur - delay, 0.01), 0.0, 1.0)
	var ep  := _ease_out(lp)
	var r   : float = v.data.get("radius", 1.0)
	var a   := lerpf(0.80, 0.0, lp * lp)
	draw_arc(v.pos, lerpf(r * 0.2, r, ep), 0.0, TAU, 48,
		Color(v.color.r, v.color.g, v.color.b, a), lerpf(0.07, 0.02, lp))

func _draw_double_ring(v: Dictionary, p: float) -> void:
	var max_r: float = v.data.get("radius", 0.85)
	var dir: Vector2 = v.data.get("dir", Vector2.ZERO)
	var col: Color = v.color
	# Inner ring: fast (completes at 60% of total duration)
	var ip := clampf(p / 0.6, 0.0, 1.0)
	var ir := lerpf(0.0, max_r * 0.55, _ease_out(ip))
	var ia := lerpf(0.90, 0.0, ip)
	draw_arc(v.pos, ir, 0.0, TAU, 32, Color(col.r, col.g, col.b, ia), lerpf(0.06, 0.02, ip))
	# Outer ring: starts at 15%, slower
	var op := clampf((p - 0.15) / 0.85, 0.0, 1.0)
	if op > 0.0:
		var or_ := lerpf(0.0, max_r, _ease_out(op))
		var oa  := lerpf(0.70, 0.0, op)
		draw_arc(v.pos, or_, 0.0, TAU, 48,
			Color(col.r, col.g * 0.85, col.b * 0.7, oa), lerpf(0.05, 0.02, op))
	# Directed mote fan toward target
	if dir.length_squared() > 0.01:
		const MOTE_COUNT := 6
		for i in MOTE_COUNT:
			var fan_angle := (float(i) - float(MOTE_COUNT - 1) * 0.5) * 0.28
			var mote_dir  := dir.rotated(fan_angle)
			var mp  := clampf(p - float(i) * 0.025, 0.0, 1.0)
			if mp <= 0.0: continue
			var mep := _ease_out(mp)
			var ma  := lerpf(0.80, 0.0, mp)
			draw_circle(v.pos + mote_dir * lerpf(0.15, max_r * 0.85, mep),
				lerpf(0.07, 0.02, mp), Color(col.r, col.g, col.b, ma))

func _draw_petal_bloom(v: Dictionary, p: float) -> void:
	var max_r : float = v.data.get("radius", 2.0)
	var count : int   = v.data.get("count", 8)
	var ep    := _ease_out(p)
	var r     := lerpf(0.1, max_r, ep)
	var a     := lerpf(0.85, 0.0, p * p)
	var col   : Color = v.color
	var arc_span := TAU / float(count) * 0.52
	for i in count:
		var center_angle := float(i) / float(count) * TAU
		draw_arc(v.pos, r, center_angle - arc_span * 0.5, center_angle + arc_span * 0.5,
			8, Color(col.r, col.g, col.b, a), lerpf(0.18, 0.05, p))

func _draw_compressed_rings(v: Dictionary, p: float) -> void:
	var max_r: float = v.data.get("radius", 0.9)
	var dir: Vector2 = v.data.get("dir", Vector2.ZERO)
	var col: Color = v.color
	if p < 0.5:
		# Phase 1: 3 rings collapse inward
		var cp := p * 2.0
		for i in 3:
			var base_r := max_r * (1.0 - float(i) * 0.28)
			var r      := lerpf(base_r, 0.0, _ease_in(cp))
			var a      := lerpf(0.70, 0.0, cp)
			draw_arc(v.pos, r, 0.0, TAU, 32,
				Color(col.r, col.g, col.b, a), lerpf(0.05, 0.02, cp))
	else:
		# Phase 2: burst lines radiate outward in target direction + perpendicular
		var bp  := (p - 0.5) * 2.0
		var ep  := _ease_out(bp)
		var a   := lerpf(0.90, 0.0, bp * bp)
		var burst_col := Color(col.r, col.g, col.b, a)
		var base_dir  := dir if dir.length_squared() > 0.01 else Vector2.RIGHT
		for i in 4:
			var angle := float(i) * TAU / 4.0
			var d     := base_dir.rotated(angle)
			draw_line(v.pos + d * lerpf(0.0, 0.18, ep),
					  v.pos + d * lerpf(0.18, 0.80, ep), burst_col, lerpf(0.06, 0.02, bp))

func _draw_spiral_cast(v: Dictionary, p: float) -> void:
	var r   : float = v.data.get("radius", 0.4)
	var col: Color = v.color
	# 6 motes rotating 1.2 full turns, then expanding outward
	for i in 6:
		var base_angle := float(i) / 6.0 * TAU
		var cur_angle  := base_angle + p * TAU * 1.2
		var mote_r     := lerpf(r * 0.3, r, _ease_out(p))
		var a          := lerpf(0.90, 0.0, p)
		var mpos: Vector2 = v.pos + Vector2(cos(cur_angle), sin(cur_angle)) * mote_r
		draw_circle(mpos, lerpf(0.07, 0.02, p), Color(col.r, col.g, col.b, a))

func _draw_cross_burst(v: Dictionary, p: float) -> void:
	var arm_len: float = v.data.get("arm_len", 0.5)
	var ep  := _ease_out(p)
	var a   := lerpf(0.90, 0.0, p * p)
	var col := Color(v.color.r, v.color.g, v.color.b, a)
	var l   := lerpf(0.0, arm_len, ep)
	# Four arms of the cross
	draw_line(v.pos - Vector2(l, 0), v.pos + Vector2(l, 0), col, lerpf(0.06, 0.02, p))
	draw_line(v.pos - Vector2(0, l), v.pos + Vector2(0, l), col, lerpf(0.06, 0.02, p))
	# Small ring at each arm tip
	for i in 4:
		var angle := float(i) * PI * 0.5
		var tip: Vector2 = v.pos + Vector2(cos(angle), sin(angle)) * l
		var ra    := lerpf(0.60, 0.0, p)
		draw_arc(tip, lerpf(0.0, 0.16, ep), 0.0, TAU, 16,
			Color(col.r, col.g, col.b, ra * a), 0.03)

func _draw_strike_flash(v: Dictionary, p: float) -> void:
	var r   : float   = v.data.get("radius", 0.5)
	var dir : Vector2 = v.data.get("dir", Vector2.ZERO)
	var count : int   = v.data.get("arc_count", 2)
	var ep := _ease_out(p)
	var a  := lerpf(0.95, 0.0, p * p * 5.0)  # very fast fade
	draw_arc(v.pos, lerpf(0.0, r, ep), 0.0, TAU, 24,
		Color(v.color.r, v.color.g, v.color.b, a), lerpf(0.07, 0.02, p))
	# Directional arc lines toward target
	if dir.length_squared() > 0.01:
		for i in count:
			var oa     := (float(i) - float(count - 1) * 0.5) * 0.4
			var adir   := dir.rotated(oa)
			var line_a := lerpf(0.85, 0.0, p * p * 4.0)
			draw_line(v.pos + adir * lerpf(0.08, 0.18, ep),
					  v.pos + adir * lerpf(0.18, r * 1.1, ep),
					  Color(v.color.r, v.color.g, v.color.b, line_a), lerpf(0.05, 0.02, p))

# ── Traversal draw functions ───────────────────────────────────────────────────

func _draw_mote_ribbon(v: Dictionary, p: float) -> void:
	var from    : Vector2 = v.data.get("from", v.pos)
	var to      : Vector2 = v.data.get("to",   v.pos)
	var count   : int     = v.data.get("count", 5)
	var stagger : float   = v.data.get("stagger", 0.08)  # normalized (fraction of total p)
	var col: Color = v.color
	# Quadratic bezier control point: midpoint + perpendicular offset
	var mid  := (from + to) * 0.5
	var diff := to - from
	var perp := Vector2(-diff.y, diff.x).normalized() * diff.length() * 0.22
	var ctrl := mid + perp
	for i in count:
		var mote_p0 := float(i) * stagger
		if p < mote_p0:
			continue
		var mp  := clampf((p - mote_p0) / maxf(1.0 - mote_p0, 0.01), 0.0, 1.0)
		var bep := _ease_out(mp)
		# Quadratic bezier position
		var b0   := from.lerp(ctrl, bep)
		var b1   := ctrl.lerp(to,   bep)
		var bpos := b0.lerp(b1, bep)
		var a    := lerpf(0.85, 0.0, mp * mp)
		draw_circle(bpos, lerpf(0.08, 0.03, mp), Color(col.r, col.g, col.b, a))

func _draw_strike_line(v: Dictionary, p: float) -> void:
	var from  : Vector2 = v.data.get("from", v.pos)
	var to    : Vector2 = v.data.get("to",   v.pos)
	var lines : int     = v.data.get("lines", 1)
	var a   := lerpf(0.90, 0.0, p * p * 6.0)  # very fast fade
	var col := Color(v.color.r, v.color.g, v.color.b, a)
	var d   := to - from
	var perp := d.normalized().rotated(PI * 0.5)
	for i in lines:
		var offset := (float(i) - float(lines - 1) * 0.5) * 0.05
		draw_line(from + perp * offset, to + perp * offset, col, lerpf(0.04, 0.01, p))

func _draw_disc_projectile(v: Dictionary, p: float) -> void:
	var from   : Vector2 = v.data.get("from",   v.pos)
	var to     : Vector2 = v.data.get("to",     v.pos)
	var radius : float   = v.data.get("radius", 0.30)
	var ep  := _ease_out(p)
	var pos := from.lerp(to, ep)
	var col: Color = v.color
	# Main disc
	var a := lerpf(0.55, 0.0, p * p)
	draw_circle(pos, radius, Color(col.r, col.g, col.b, a))
	# Trailing rings at prior positions
	for i in 4:
		var trail_ep  := _ease_out(clampf(p - float(i + 1) * 0.06, 0.0, 1.0))
		var trail_pos := from.lerp(to, trail_ep)
		var trail_a   := lerpf(0.30, 0.0, p * p) * (1.0 - float(i) / 4.0)
		draw_arc(trail_pos, radius * (1.0 - float(i) * 0.12), 0.0, TAU, 16,
			Color(col.r, col.g, col.b, trail_a), 0.03)

func _draw_ring_projectile(v: Dictionary, p: float) -> void:
	var from       : Vector2 = v.data.get("from",         v.pos)
	var to         : Vector2 = v.data.get("to",           v.pos)
	var start_r    : float   = v.data.get("start_radius", 0.80)
	var end_r      : float   = v.data.get("end_radius",   0.25)
	var ep  := _ease_out(p)
	var pos := from.lerp(to, ep)
	var r   := lerpf(start_r, end_r, p)
	var rot := p * TAU  # one full rotation during travel
	var a   := lerpf(0.75, 0.0, p * p)
	draw_arc(pos, r, rot, rot + TAU, 48,
		Color(v.color.r, v.color.g, v.color.b, a), lerpf(0.06, 0.02, p))

# ── Impact draw functions ──────────────────────────────────────────────────────

func _draw_shield_collapse(v: Dictionary, p: float) -> void:
	var start_r : float = v.data.get("start_radius", 1.0)
	var count   : int   = v.data.get("count", 5)
	var eip := _ease_in(p)
	var r   := lerpf(start_r, 0.0, eip)
	var a   := lerpf(0.85, 0.0, p)
	var col := Color(v.color.r, v.color.g, v.color.b, a)
	var arc_span := TAU / float(count) * 0.60
	for i in count:
		var angle := float(i) / float(count) * TAU + p * 0.5
		draw_arc(v.pos, r, angle, angle + arc_span, 10, col, lerpf(0.08, 0.02, p))

# ── Sustained draw functions ───────────────────────────────────────────────────

func _draw_sustained_pulse(v: Dictionary, p: float) -> void:
	var target_id  : String = v.data.get("target_id", "")
	var pos        : Vector2 = _player_pos(target_id) if not target_id.is_empty() else v.pos
	var r          : float   = v.data.get("radius", 0.8)
	var pulse_freq : float   = v.data.get("pulse_freq", 0.5)
	var pulse := sin(v.t * pulse_freq * TAU) * 0.5 + 0.5
	var fade  := lerpf(1.0, 0.0, p * p * 0.3)  # slow fade, mainly at end
	var a     := pulse * 0.22 * fade
	draw_arc(pos, r, 0.0, TAU, 32, Color(v.color.r, v.color.g, v.color.b, a), 0.04)

func _draw_rotating_arcs(v: Dictionary, p: float) -> void:
	var target_id : String  = v.data.get("target_id", "")
	var pos       : Vector2 = _player_pos(target_id) if not target_id.is_empty() else v.pos
	var r         : float   = v.data.get("radius", 8.0)
	var count     : int     = v.data.get("count",  12)
	var speed     : float   = v.data.get("speed",  TAU / 3.0)
	# Fade in first 5%, fade out last 15%
	var fade := minf(lerpf(0.0, 1.0, p / 0.05), lerpf(1.0, 0.0, clampf((p - 0.85) / 0.15, 0.0, 1.0)))
	var a    := 0.55 * fade
	var col  := Color(v.color.r, v.color.g, v.color.b, a)
	var arc_span := TAU / float(count) * 0.42
	for i in count:
		var angle: float = float(i) / float(count) * TAU + float(v.t) * speed
		draw_arc(pos, r, angle, angle + arc_span, 8, col, lerpf(0.07, 0.04, p))

# ── Helpers ────────────────────────────────────────────────────────────────────

func _ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)

func _ease_in(t: float) -> float:
	return t * t * t

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

# ── Heal spiral and blue cloud draw functions ──────────────────────────────────

func _draw_heal_spiral_cast(v: Dictionary, p: float) -> void:
	# Sparks scatter outward and rise vertically upward from caster
	const N := 16
	for i in N:
		var phase := float(i) / float(N) * 0.45
		var dp := clampf((p - phase) / maxf(1.0 - phase, 0.01), 0.0, 1.0)
		if dp <= 0.0: continue
		var ep := _ease_out(dp)
		# Golden-angle scatter around caster base
		var ga := float(i) * 2.399963
		var sr := sqrt(float(i + 1) / float(N)) * 1.75
		var ox := cos(ga) * sr
		# Rise straight up (negative Y = up in screen space)
		var rise := lerpf(0.0, 12.0, ep)
		var drift := sin(float(i) * 1.7 + ep * 2.0) * rise * 0.06
		var pos: Vector2 = v.pos + Vector2(ox + drift, -rise)
		# Warm palette blending to green as sparks rise
		var c: Color = _HEAL_CAST_COLORS[i % _HEAL_CAST_COLORS.size()]
		c = c.lerp(Color(0.30, 1.0, 0.25), dp * 0.65)
		# Spark shrinks as it rises and fades
		var spark_len := lerpf(2.8, 0.5, dp)
		var a: float = lerpf(0.92, 0.0, dp * dp)
		draw_line(pos, pos + Vector2(drift * 0.05, -spark_len), Color(c.r, c.g, c.b, a), 0.20)

func _draw_heal_spiral_travel(v: Dictionary, p: float) -> void:
	# Sparks arc parabolically from caster, peaking high then descending toward target
	const N := 14
	var from: Vector2 = v.data.get("from", v.pos)
	var to: Vector2   = v.data.get("to",   v.pos)
	var dist := from.distance_to(to)
	var arc_h := minf(dist * 0.55, 12.0)
	var dx := to.x - from.x
	var dy := to.y - from.y
	for i in N:
		var phase := float(i) / float(N) * 0.60
		var dp := clampf((p - phase) / maxf(1.0 - phase, 0.01), 0.0, 1.0)
		if dp <= 0.0: continue
		# t: position along the arc (0=caster, 1=target)
		var t := clampf(phase * 0.35 + dp * 0.75, 0.0, 1.0)
		# Parabolic arc: base linear path + upward arc offset
		var base := from.lerp(to, t)
		var arc_y := -arc_h * 4.0 * t * (1.0 - t)  # negative Y = up in screen space
		var pos: Vector2 = base + Vector2(0.0, arc_y)
		# Velocity direction is the arc tangent
		var vx := dx
		var vy := dy - arc_h * 4.0 * (1.0 - 2.0 * t)
		var vel := Vector2(vx, vy).normalized()
		# Color warm→green as sparks travel
		var c: Color = _HEAL_CAST_COLORS[i % _HEAL_CAST_COLORS.size()]
		c = c.lerp(Color(0.25, 1.0, 0.20), t)
		var a: float = lerpf(0.88, 0.0, dp * dp)
		draw_line(pos, pos + vel * 1.8, Color(c.r, c.g, c.b, a), 0.20)

func _draw_blue_cloud_cast(v: Dictionary, p: float) -> void:
	const N := 14
	var blue := Color(0.30, 0.65, 1.0)
	for i in N:
		var phase := float(i) / float(N) * 0.08
		var dp := clampf((p - phase) / maxf(1.0 - phase, 0.01), 0.0, 1.0)
		if dp <= 0.0: continue
		var ep := _ease_out(dp)
		var angle: float = float(i) / float(N) * TAU + dp * 0.5
		var r: float = lerpf(0.5, 7.5, ep)
		var drift_y: float = lerpf(0.0, -2.8, ep)
		var pos: Vector2 = v.pos + Vector2(cos(angle) * r, sin(angle) * r + drift_y)
		var a: float = lerpf(0.85, 0.0, dp)
		draw_circle(pos, lerpf(1.0, 0.4, dp), Color(blue.r, blue.g, blue.b, a))

func _draw_blue_cloud_travel(v: Dictionary, p: float) -> void:
	const N := 14
	var from: Vector2 = v.data.get("from", v.pos)
	var to: Vector2   = v.data.get("to",   v.pos)
	var fwd := (to - from).normalized() if from.distance_squared_to(to) > 0.01 else Vector2.RIGHT
	var perp := Vector2(-fwd.y, fwd.x)
	var blue := Color(0.30, 0.65, 1.0)
	for i in N:
		var phase := float(i) / float(N) * 0.6
		var dp := clampf((p - phase) / maxf(1.0 - phase, 0.01), 0.0, 1.0)
		if dp <= 0.0: continue
		var travel_t: float = clampf(float(i) / float(N) * 0.4 + dp * 0.65, 0.0, 1.0)
		var path_pos := from.lerp(to, travel_t)
		var wave: float = sin(float(i) * 2.1 + p * TAU * 2.0) * 2.2
		var pos := path_pos + perp * wave
		var a: float = lerpf(0.80, 0.0, dp * dp)
		draw_circle(pos, lerpf(1.1, 0.5, dp), Color(blue.r, blue.g, blue.b, a))

func _draw_blue_cloud_impact(v: Dictionary, p: float) -> void:
	const N := 14
	var blue := Color(0.30, 0.65, 1.0)
	for i in N:
		var phase := float(i) / float(N) * 0.15
		var dp := clampf((p - phase) / maxf(1.0 - phase, 0.01), 0.0, 1.0)
		if dp <= 0.0: continue
		var angle: float = float(i) / float(N) * TAU + p * TAU * 1.5
		var r: float = lerpf(7.2, 3.0, dp)
		var drift_y: float = lerpf(-1.5, 5.5, dp * dp)
		var pos: Vector2 = v.pos + Vector2(cos(angle) * r, sin(angle) * r + drift_y)
		var a: float = lerpf(0.85, 0.0, dp * dp)
		draw_circle(pos, lerpf(0.9, 0.3, dp), Color(blue.r, blue.g, blue.b, a))

func _draw_hot_sparkle(v: Dictionary, p: float) -> void:
	const N := 6
	for i in N:
		var phase := float(i) / float(N) * 0.35
		var dp := clampf((p - phase) / maxf(1.0 - phase, 0.01), 0.0, 1.0)
		if dp <= 0.0: continue
		var ep := _ease_out(dp)
		var ga := float(i) * 2.399963
		var sr := sqrt(float(i + 1) / float(N)) * 1.75
		var ox := cos(ga) * sr
		var fall := lerpf(12.0, 0.0, ep)
		var drift := sin(float(i) * 1.7 + ep * 2.0) * fall * 0.06
		var pos: Vector2 = v.pos + Vector2(ox + drift, -fall)
		var a: float = lerpf(0.90, 0.0, dp * dp)
		var spark_len := lerpf(2.8, 0.5, dp)
		draw_line(pos, pos + Vector2(drift * 0.05, spark_len), Color(0.30, 1.0, 0.25, a), 0.20)

func _draw_lightning_discharge(v: Dictionary, p: float) -> void:
	var r   : float   = v.data.get("radius", 5.0)
	var dir : Vector2 = v.data.get("dir", Vector2.ZERO)
	var col : Color   = v.color
	var ep  := _ease_out(p)
	var flash_a := clampf(lerpf(1.0, 0.0, p * 4.0), 0.0, 1.0)
	draw_circle(v.pos, lerpf(0.0, r * 0.5, ep), Color(1.0, 1.0, 1.0, flash_a * 0.70))
	draw_arc(v.pos, lerpf(0.0, r, ep), 0.0, TAU, 48,
		Color(col.r, col.g, col.b, lerpf(0.90, 0.0, p * p)), lerpf(0.08, 0.02, p))
	draw_arc(v.pos, lerpf(0.0, r * 0.6, _ease_out(clampf(p * 1.5, 0.0, 1.0))), 0.0, TAU, 32,
		Color(1.0, 1.0, 1.0, lerpf(0.60, 0.0, p)), lerpf(0.05, 0.01, p))
	if dir.length_squared() > 0.01:
		var line_a := lerpf(0.95, 0.0, p * p * 3.0)
		for i in 4:
			var adir := dir.rotated((float(i) - 1.5) * 0.25)
			var perp := Vector2(-adir.y, adir.x)
			var seg_s: Vector2 = v.pos + adir * lerpf(0.1, 0.3, ep)
			var seg_e: Vector2 = v.pos + adir * lerpf(0.3, r * 1.05, ep)
			var jitter := sin(float(i) * 2.3 + p * 40.0) * seg_s.distance_to(seg_e) * 0.12
			var mid: Vector2 = seg_s.lerp(seg_e, 0.5) + perp * jitter
			draw_line(seg_s, mid, Color(1.0, 1.0, 1.0, line_a * 0.8), 0.06)
			draw_line(mid, seg_e, Color(col.r, col.g, col.b, line_a), 0.04)

func _draw_chain_burst(v: Dictionary, p: float) -> void:
	var r   : float = v.data.get("radius", 6.5)
	var col : Color = v.color
	var ep  := _ease_out(p)
	var flash_a := clampf(lerpf(1.0, 0.0, p * 3.5), 0.0, 1.0)
	draw_circle(v.pos, lerpf(0.0, r * 0.45, ep), Color(1.0, 1.0, 1.0, flash_a * 0.75))
	draw_arc(v.pos, lerpf(0.0, r, ep), 0.0, TAU, 64,
		Color(col.r, col.g, col.b, lerpf(0.90, 0.0, p * p)), lerpf(0.08, 0.02, p))
	draw_arc(v.pos, lerpf(0.0, r * 0.5, _ease_out(clampf(p * 1.4, 0.0, 1.0))),
		0.0, TAU, 48, Color(1.0, 1.0, 1.0, lerpf(0.70, 0.0, p)), lerpf(0.07, 0.02, p))
	var spark_a := lerpf(0.95, 0.0, p * p * 2.5)
	for i in 8:
		var angle := float(i) * TAU / 8.0 + p * 0.3
		var dir   := Vector2(cos(angle), sin(angle))
		var perp  := Vector2(-dir.y, dir.x)
		var seg_s: Vector2 = v.pos + dir * lerpf(0.1, 0.35, ep)
		var seg_e: Vector2 = v.pos + dir * lerpf(0.35, r * 1.1, ep)
		var jitter := sin(float(i) * 1.9 + p * 35.0) * seg_s.distance_to(seg_e) * 0.14
		var mid: Vector2 = seg_s.lerp(seg_e, 0.5) + perp * jitter
		draw_line(seg_s, mid, Color(1.0, 1.0, 1.0, spark_a * 0.7), 0.06)
		draw_line(mid, seg_e, Color(col.r, col.g, col.b, spark_a), 0.045)
