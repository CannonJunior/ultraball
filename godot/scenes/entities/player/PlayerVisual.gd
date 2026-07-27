class_name PlayerVisual
extends Node2D

## Player visual: body disc + direction dot + persistent buff/debuff indicators.
## All rendering via _draw(); no child nodes.
## Phase 8 replaces the body with AnimatedSprite2D / 3D mesh.

const BODY_RADIUS := 0.4
const DOT_RADIUS  := 0.1

# Effect ring radii (metres, local space)
const R_INNER := 0.60   # stun stars / confused ring
const R_OUTER := 0.72   # shield / hex / power / speed aura
const R_MARK  := 0.90   # mark diamond

# Effect palette
const C_SPEED   := Color(0.50, 1.00, 0.50)
const C_POWER   := Color(1.00, 0.20, 0.20)
const C_SHIELD  := Color(0.90, 0.95, 1.00)
const C_IMMUNE  := Color(0.70, 0.80, 1.00)
const C_STUN    := Color(1.00, 0.88, 0.15)
const C_SNARE   := Color(0.60, 0.35, 0.10)
const C_HEX     := Color(0.65, 0.20, 0.90)
const C_MARK    := Color(1.00, 0.18, 0.18)
const C_CONFUSE := Color(0.90, 0.60, 0.10)

var _body_color: Color = Color.WHITE

# Persistent effect timers. Values are seconds remaining.
var _buffs:   Dictionary = {}
var _debuffs: Dictionary = {}

# Running clock used for orbits, pulses, rotations.
var _phase: float = 0.0

func _ready() -> void:
	var player := get_parent()
	if player and player.class_definition:
		_body_color = player.class_definition.body_color
	EventBus.buff_applied.connect(_on_buff_applied)
	EventBus.debuff_applied.connect(_on_debuff_applied)
	queue_redraw()

func _process(delta: float) -> void:
	var any := false
	for key in _buffs.keys():
		_buffs[key] -= delta
		if _buffs[key] <= 0.0:
			_buffs.erase(key)
		else:
			any = true
	for key in _debuffs.keys():
		_debuffs[key] -= delta
		if _debuffs[key] <= 0.0:
			_debuffs.erase(key)
		else:
			any = true
	if any:
		_phase += delta
		queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, BODY_RADIUS, _body_color)
	draw_circle(Vector2(0.0, -(BODY_RADIUS + DOT_RADIUS * 0.5)), DOT_RADIUS, Color.WHITE)

	# Inner orbit — stun takes priority over confused
	if _debuffs.has("stun_stars"):
		_draw_stun_stars()
	elif _debuffs.has("confused_ring"):
		_draw_confused_ring()

	# Outer ring — priority: shield > hex > power > speed
	if _buffs.has("shield_ring"):
		_draw_shield_ring()
	elif _debuffs.has("hex_ring"):
		_draw_hex_ring()
	elif _buffs.has("power_ring"):
		_draw_power_ring()
	elif _buffs.has("speed_aura"):
		_draw_speed_aura()

	# Snare root lines — radial, no conflict with the ring layer
	if _debuffs.has("root_lines"):
		_draw_root_lines()

	# Mark diamond — always additive, separate visual layer
	if _debuffs.has("mark_diamond"):
		_draw_mark_diamond()

	# Immune shimmer — subtle dashed outer ring
	if _buffs.has("immune_shimmer"):
		_draw_immune_shimmer()

# ── Effect renderers ──────────────────────────────────────────────────────────

func _draw_stun_stars() -> void:
	for i in 3:
		var angle := fmod(_phase * TAU * 2.0, TAU) + i * TAU / 3.0
		draw_circle(Vector2(cos(angle), sin(angle)) * R_INNER, 0.07, C_STUN)

func _draw_confused_ring() -> void:
	var base := fmod(_phase * TAU * 0.6, TAU)
	for i in 3:
		var a0 := base + i * TAU / 3.0
		draw_arc(Vector2.ZERO, R_INNER, a0, a0 + TAU / 3.0 - 0.30,
			10, Color(C_CONFUSE.r, C_CONFUSE.g, C_CONFUSE.b, 0.70), 0.04)

func _draw_shield_ring() -> void:
	var gap := fmod(_phase * TAU * 0.8, TAU)
	draw_arc(Vector2.ZERO, R_OUTER, gap + 0.70, gap + TAU,
		48, Color(C_SHIELD.r, C_SHIELD.g, C_SHIELD.b, 0.90), 0.045)

func _draw_hex_ring() -> void:
	var base := fmod(_phase * 0.40, TAU)
	for i in 6:
		var a0 := base + i * TAU / 6.0
		draw_arc(Vector2.ZERO, R_OUTER, a0 + 0.12, a0 + TAU / 6.0 - 0.12,
			8, Color(C_HEX.r, C_HEX.g, C_HEX.b, 0.80), 0.05)

func _draw_power_ring() -> void:
	var pulse := 0.5 + 0.5 * sin(_phase * TAU * 0.7)
	var r     := lerpf(0.68, 0.75, pulse)
	var a     := lerpf(0.45, 0.75, pulse)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48,
		Color(C_POWER.r, C_POWER.g, C_POWER.b, a), 0.04)

func _draw_speed_aura() -> void:
	var base := fmod(_phase * TAU * 0.5, TAU)
	for i in 3:
		var a0 := base + i * TAU / 3.0
		draw_arc(Vector2.ZERO, R_OUTER, a0, a0 + TAU / 6.0,
			12, Color(C_SPEED.r, C_SPEED.g, C_SPEED.b, 0.65), 0.04)

func _draw_root_lines() -> void:
	for i in 4:
		var angle := i * TAU / 4.0 + PI * 0.25
		var base  := Vector2(cos(angle), sin(angle)) * (BODY_RADIUS + 0.04)
		draw_line(base, base + Vector2(0.0, 0.28),
			Color(C_SNARE.r, C_SNARE.g, C_SNARE.b, 0.80), 0.04)

func _draw_mark_diamond() -> void:
	var pulse := 0.5 + 0.5 * sin(_phase * TAU * 1.5)
	var a     := lerpf(0.40, 0.90, pulse)
	var r     := R_MARK
	draw_polyline(PackedVector2Array([
		Vector2(0.0, -r), Vector2(r, 0.0),
		Vector2(0.0,  r), Vector2(-r, 0.0),
		Vector2(0.0, -r),
	]), Color(C_MARK.r, C_MARK.g, C_MARK.b, a), 0.04)

func _draw_immune_shimmer() -> void:
	for i in 8:
		if i % 2 == 0:
			continue
		var a0 := float(i) * TAU / 8.0
		draw_arc(Vector2.ZERO, 0.82, a0, a0 + TAU / 8.0 * 0.6,
			6, Color(C_IMMUNE.r, C_IMMUNE.g, C_IMMUNE.b, 0.50), 0.03)

# ── Signal handlers ────────────────────────────────────────────────────────────

func _on_buff_applied(player_id: String, buff_name: String, duration: float) -> void:
	var player := get_parent()
	if not player or player.player_id != player_id:
		return
	match buff_name:
		"speed_boost":
			_buffs["speed_aura"] = maxf(_buffs.get("speed_aura", 0.0), duration)
		"damage_boost":
			_buffs["power_ring"] = maxf(_buffs.get("power_ring", 0.0), duration)
		"invulnerable", "dodge":
			_buffs["shield_ring"] = maxf(_buffs.get("shield_ring", 0.0), duration)
		"stun_immune":
			_buffs["immune_shimmer"] = maxf(_buffs.get("immune_shimmer", 0.0), duration)

func _on_debuff_applied(player_id: String, debuff_name: String, duration: float, params: Dictionary) -> void:
	var player := get_parent()
	if not player or player.player_id != player_id:
		return
	match debuff_name:
		"stun":
			_debuffs["stun_stars"] = maxf(_debuffs.get("stun_stars", 0.0), duration)
		"snare":
			_debuffs["root_lines"] = maxf(_debuffs.get("root_lines", 0.0), duration)
		"hex":
			_debuffs["hex_ring"] = maxf(_debuffs.get("hex_ring", 0.0), duration)
		"marked":
			_debuffs["mark_diamond"] = maxf(_debuffs.get("mark_diamond", 0.0), duration)
		"confused":
			_debuffs["confused_ring"] = maxf(_debuffs.get("confused_ring", 0.0), duration)
		"speed_mult_set":
			# Show speed aura for any positive multiplier (boost, not slow)
			if params.get("multiplier", 1.5) > 1.0:
				_buffs["speed_aura"] = maxf(_buffs.get("speed_aura", 0.0), duration)
		"damage_boost_set":
			_buffs["power_ring"] = maxf(_buffs.get("power_ring", 0.0), duration)
