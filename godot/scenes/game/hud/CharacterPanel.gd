extends Control

## Unified bottom HUD panel: player card (left) | ability slots (centre) | target card (right).

# Effect types not yet in Godot's global-class cache must be preloaded explicitly.
const _AoEDamageEffect    := preload("res://data/abilities/effects/AoEDamageEffect.gd")
const _AoEHealEffect      := preload("res://data/abilities/effects/AoEHealEffect.gd")
const _InvulnEffect       := preload("res://data/abilities/effects/InvulnerabilityEffect.gd")
const _PullEffect         := preload("res://data/abilities/effects/PullEffect.gd")
const _TrapSpawnEffect    := preload("res://data/abilities/effects/TrapSpawnEffect.gd")

const C_BG     := Color(0.04, 0.04, 0.10, 0.88)
const C_BORDER := Color(0.12, 0.12, 0.24, 0.80)
const C_SEP    := Color(0.12, 0.12, 0.24, 0.60)
const C_DIM        := Color(1, 1, 1, 0.38)
const C_ENEMY      := Color(1.0, 0.35, 0.35)
const C_NONE       := Color(1, 1, 1, 0.20)
const C_QUEUE_GOLD := Color(1.00, 0.85, 0.15)
const C_QUEUE_FAIL := Color(1.00, 0.22, 0.10)

const HP_COLOR    := Color(0.20, 0.85, 0.20)
const MANA_COLORS := [
	Color(0.92, 0.22, 0.22),   # Red
	Color(0.25, 0.45, 1.00),   # Blue
	Color(0.90, 0.80, 0.10),   # Yellow
	Color(0.75, 0.25, 0.90),   # Ultra
]
const MANA_NAMES  := ["RED", "BLU", "YEL", "ULT"]
const MANA_MAXES  := [100.0, 100.0, 100.0, 10.0]
const MANA_TINTS  := [
	Color(0.22, 0.22, 0.22),   # 0 = None
	Color(0.35, 0.08, 0.08),   # 1 = Red
	Color(0.08, 0.12, 0.38),   # 2 = Blue
	Color(0.32, 0.28, 0.04),   # 3 = Yellow
	Color(0.28, 0.08, 0.38),   # 4 = Ultra
]
const READY_TINT := Color(0.14, 0.14, 0.18)

# ── Ability category background colours (dark / muted) ────────────────────────
# See docs/ability_styling.md for the full design rationale.
const SLOT_BG_DAMAGE    := Color(0.38, 0.06, 0.06)  # Direct single-target damage
const SLOT_BG_AOE_DMG   := Color(0.40, 0.16, 0.02)  # AoE / splash damage
const SLOT_BG_HEAL      := Color(0.06, 0.32, 0.08)  # Direct or AoE healing
const SLOT_BG_HOT       := Color(0.04, 0.26, 0.22)  # Heal over time
const SLOT_BG_SELF_BUFF := Color(0.06, 0.10, 0.38)  # Self buff (speed, invuln…)
const SLOT_BG_SUPPORT   := Color(0.04, 0.22, 0.34)  # Ally buff / support
const SLOT_BG_MOVEMENT  := Color(0.18, 0.04, 0.34)  # Pure mobility (dash/teleport)
const SLOT_BG_DEBUFF    := Color(0.22, 0.04, 0.28)  # Hex / mark / mana drain
const SLOT_BG_CC        := Color(0.32, 0.24, 0.02)  # Crowd control
const SLOT_BG_TERRAIN   := Color(0.20, 0.12, 0.02)  # Terrain / trap placement
const SLOT_BG_UTILITY   := Color(0.10, 0.12, 0.20)  # Cleanse, mana restore, misc
const SLOT_BG_ULTRA     := Color(0.30, 0.22, 0.02)  # Ultra abilities

# ── Secondary-effect border colours (vivid; transparent = no secondary) ───────
const SLOT_BORDER_HARD_CC := Color(0.90, 0.75, 0.00)  # Stun / knockback / confuse
const SLOT_BORDER_SNARE   := Color(0.90, 0.40, 0.00)  # Slow / snare
const SLOT_BORDER_DEBUFF  := Color(0.80, 0.10, 0.80)  # Hex / mark (stat debuff)
const SLOT_BORDER_FUMBLE  := Color(0.90, 0.70, 0.05)  # Ball interaction
const SLOT_BORDER_MANA    := Color(0.15, 0.35, 0.90)  # Mana drain

# ── Cached nodes ──────────────────────────────────────────────────────────────
var _class_dot    : ColorRect
var _name_lbl     : Label
var _class_lbl    : Label
var _hp_bar       : ProgressBar
var _mana_bars     : Array[ProgressBar] = []
var _mana_bar_rows : Array[Control]     = []
var _ultra_bar     : Control            = null

var _slots        : Array[Dictionary] = []
var _names_loaded : bool = false
var _last_pid     : String = ""

var _queue_badges       : Array[Label]     = []
var _queue_preview_dots : Array[ColorRect] = []
var _queue_positions    : Dictionary       = {}   # slot_num -> 1-indexed position in queue
var _cached_queue       : Array            = []   # current queue array for local player

var _target_icon  : Label
var _target_name  : Label
var _target_class : Label
var _target_hp    : ProgressBar

class _UltraGradientBar extends Control:
	var _grad_tex : GradientTexture1D
	var _fill     : float = 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(0, 12)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var grad := Gradient.new()
		grad.colors  = PackedColorArray([Color.html("FFCC00"), Color.html("FF6600"), Color.html("FF0044")])
		grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		_grad_tex = GradientTexture1D.new()
		_grad_tex.gradient = grad
		_grad_tex.width = 256

	func set_value(v: float) -> void:
		_fill = clampf(v, 0.0, 1.0)
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(0, 0, w, h), Color(0.08, 0.08, 0.08, 0.9))
		if _fill > 0.0 and _grad_tex != null:
			draw_texture_rect(_grad_tex, Rect2(0, 0, w, h), false)
			if _fill < 1.0:
				draw_rect(Rect2(w * _fill, 0, w * (1.0 - _fill), h), Color(0.08, 0.08, 0.08, 0.9))

# ── Layout ────────────────────────────────────────────────────────────────────
func _ready() -> void:
	anchor_left   = 0.0;  anchor_top    = 1.0
	anchor_right  = 1.0;  anchor_bottom = 1.0
	offset_left   = 8.0;  offset_top    = -130.0
	offset_right  = -8.0; offset_bottom = -8.0
	mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_build()
	EventBus.ability_queue_changed.connect(_on_queue_changed)
	EventBus.ability_resolved.connect(_on_ability_resolved)
	EventBus.ability_failed.connect(_on_ability_failed)

func _build() -> void:
	var root := PanelContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color           = C_BG
	bg.border_color       = C_BORDER
	bg.border_width_left  = 1; bg.border_width_right  = 1
	bg.border_width_top   = 1; bg.border_width_bottom = 1
	bg.corner_radius_top_left    = 4; bg.corner_radius_top_right    = 4
	bg.corner_radius_bottom_left = 4; bg.corner_radius_bottom_right = 4
	root.add_theme_stylebox_override("panel", bg)
	add_child(root)

	var m := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 8)
	root.add_child(m)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	m.add_child(row)

	row.add_child(_build_player_pane())
	row.add_child(_vsep())
	row.add_child(_build_slot_pane())
	row.add_child(_vsep())
	row.add_child(_build_target_pane())

# ── Player pane ───────────────────────────────────────────────────────────────
func _build_player_pane() -> Control:
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size.x = 220
	vbox.add_theme_constant_override("separation", 3)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 6)
	vbox.add_child(hdr)

	_class_dot = ColorRect.new()
	_class_dot.custom_minimum_size = Vector2(5, 0)
	_class_dot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_class_dot.color = Color(0.5, 0.5, 0.5)
	hdr.add_child(_class_dot)

	_name_lbl = Label.new()
	_name_lbl.text = "—"
	_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_lbl.add_theme_font_size_override("font_size", 11)
	_name_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	hdr.add_child(_name_lbl)

	_class_lbl = Label.new()
	_class_lbl.text = ""
	_class_lbl.add_theme_font_size_override("font_size", 9)
	_class_lbl.add_theme_color_override("font_color", C_DIM)
	hdr.add_child(_class_lbl)

	_hp_bar = _make_bar(HP_COLOR)
	vbox.add_child(_bar_row("HP ", _hp_bar, HP_COLOR))

	_mana_bars.clear()
	_mana_bar_rows.clear()
	for i in 3:
		var bar := _make_bar(MANA_COLORS[i])
		_mana_bars.append(bar)
		var row := _bar_row(MANA_NAMES[i], bar, MANA_COLORS[i])
		_mana_bar_rows.append(row)
		vbox.add_child(row)

	_ultra_bar = _UltraGradientBar.new()
	var ultra_row := HBoxContainer.new()
	ultra_row.add_theme_constant_override("separation", 4)
	var ultra_lbl := Label.new()
	ultra_lbl.text = "ULT"
	ultra_lbl.custom_minimum_size.x = 30
	ultra_lbl.add_theme_font_size_override("font_size", 9)
	ultra_lbl.add_theme_color_override("font_color", MANA_COLORS[3])
	ultra_row.add_child(ultra_lbl)
	ultra_row.add_child(_ultra_bar)
	_mana_bar_rows.append(ultra_row)
	vbox.add_child(ultra_row)

	return vbox

# ── Ability slot pane ─────────────────────────────────────────────────────────
func _build_slot_pane() -> Control:
	var wrapper := VBoxContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_theme_constant_override("separation", 2)
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Queue preview strip — 5 small bars showing what's queued next
	var strip := HBoxContainer.new()
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.add_theme_constant_override("separation", 3)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_queue_preview_dots.clear()
	for _j in 5:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(28, 6)
		dot.color = Color(0.15, 0.15, 0.20, 0.9)
		_queue_preview_dots.append(dot)
		strip.add_child(dot)
	wrapper.add_child(strip)

	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 3)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_slots.clear()
	_queue_badges.clear()
	for i in 10:
		var key_text := "U" if i == 9 else str(i + 1)
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var sbox := StyleBoxFlat.new()
		sbox.bg_color = READY_TINT
		sbox.corner_radius_top_left     = 3; sbox.corner_radius_top_right    = 3
		sbox.corner_radius_bottom_left  = 3; sbox.corner_radius_bottom_right = 3
		sbox.border_width_left  = 2; sbox.border_width_right  = 2
		sbox.border_width_top   = 2; sbox.border_width_bottom = 2
		sbox.border_color = Color.TRANSPARENT
		sbox.content_margin_left  = 2; sbox.content_margin_right  = 2
		sbox.content_margin_top   = 2; sbox.content_margin_bottom = 2
		panel.add_theme_stylebox_override("panel", sbox)

		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 2)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(vbox)

		# Key label row with queue position badge on the right
		var key_row := HBoxContainer.new()
		key_row.add_theme_constant_override("separation", 0)
		key_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(key_row)

		var key_lbl := Label.new()
		key_lbl.text = key_text
		key_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_lbl.add_theme_font_size_override("font_size", 9)
		key_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key_row.add_child(key_lbl)

		var badge_lbl := Label.new()
		badge_lbl.text = ""
		badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge_lbl.add_theme_font_size_override("font_size", 8)
		badge_lbl.add_theme_color_override("font_color", C_QUEUE_GOLD)
		badge_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key_row.add_child(badge_lbl)
		_queue_badges.append(badge_lbl)

		var name_lbl := Label.new()
		name_lbl.text = "----"
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 8)
		name_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(name_lbl)

		var cd_lbl := Label.new()
		cd_lbl.text = ""
		cd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cd_lbl.add_theme_font_size_override("font_size", 13)
		cd_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
		cd_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(cd_lbl)

		var slot_num := i + 1   # capture for closure
		panel.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton \
					and event.button_index == MOUSE_BUTTON_LEFT \
					and event.pressed:
				var p := _local_player()
				if p:
					EventBus.ability_queued.emit(p.player_id, slot_num)
		)

		hbox.add_child(panel)
		_slots.append({"sbox": sbox, "name_lbl": name_lbl, "cd_lbl": cd_lbl, "panel": panel, "style": null})

	wrapper.add_child(hbox)
	return wrapper

# ── Target pane ───────────────────────────────────────────────────────────────
func _build_target_pane() -> Control:
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size.x = 190
	vbox.add_theme_constant_override("separation", 3)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 6)
	vbox.add_child(hdr)

	_target_icon = Label.new()
	_target_icon.text = "⊕"
	_target_icon.add_theme_font_size_override("font_size", 11)
	_target_icon.add_theme_color_override("font_color", C_NONE)
	hdr.add_child(_target_icon)

	_target_name = Label.new()
	_target_name.text = "NO TARGET"
	_target_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_target_name.add_theme_font_size_override("font_size", 11)
	_target_name.add_theme_color_override("font_color", C_NONE)
	hdr.add_child(_target_name)

	_target_class = Label.new()
	_target_class.text = ""
	_target_class.add_theme_font_size_override("font_size", 9)
	_target_class.add_theme_color_override("font_color", C_DIM)
	hdr.add_child(_target_class)

	_target_hp = _make_bar(C_ENEMY)
	vbox.add_child(_bar_row("HP ", _target_hp, C_ENEMY))

	return vbox

# ── Shared widget builders ────────────────────────────────────────────────────
func _bar_row(lbl_text: String, bar: ProgressBar, color: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var lbl := Label.new()
	lbl.text = lbl_text
	lbl.custom_minimum_size.x = 30
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", color)
	row.add_child(lbl)
	row.add_child(bar)
	return row

func _make_bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0; bar.max_value = 1.0; bar.value = 1.0
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size.y = 12
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.corner_radius_top_left    = 2; fill.corner_radius_top_right    = 2
	fill.corner_radius_bottom_left = 2; fill.corner_radius_bottom_right = 2
	bar.add_theme_stylebox_override("fill", fill)
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.08, 0.08, 0.08, 0.9)
	bar.add_theme_stylebox_override("background", bg_sb)
	return bar

func _vsep() -> Control:
	var r := ColorRect.new()
	r.color = C_SEP
	r.custom_minimum_size.x = 1
	r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return r

# ── _process ──────────────────────────────────────────────────────────────────
func _process(_delta: float) -> void:
	var player := _local_player()
	if player == null:
		return
	_update_player(player)
	_update_slots(player)
	_update_target(player)

func _update_player(player: Node) -> void:
	var dot_color: Color = player.class_definition.body_color \
		if player.class_definition else Color(0.5, 0.5, 0.5)
	_class_dot.color = dot_color

	var rec = MatchState.players.get(player.player_id, null)
	_name_lbl.text = rec.display_name if rec else player.player_id
	_name_lbl.add_theme_color_override("font_color", dot_color.lightened(0.15))
	_class_lbl.text = player.class_definition.display_name \
		if player.class_definition else ""

	var buffs = player.get_node_or_null("PlayerBuffs")
	if buffs and buffs.max_health > 0:
		_hp_bar.value = buffs.health / buffs.max_health

	var mana = player.get_node_or_null("PlayerMana")
	if mana:
		_mana_bars[0].value = mana.red    / 100.0
		_mana_bars[1].value = mana.blue   / 100.0
		_mana_bars[2].value = mana.yellow / 100.0
		(_ultra_bar as _UltraGradientBar).set_value(mana.ultra / 10.0)

func _update_slots(player: Node) -> void:
	# Reset when controlled player changes
	if _last_pid != player.player_id:
		_last_pid = player.player_id
		_names_loaded = false
		for entry in _slots:
			entry["name_lbl"].text = "----"
			entry["style"] = null

	if not _names_loaded:
		_try_load_names(player)

	var abilities = player.get_node_or_null("PlayerAbilities")
	if abilities == null:
		return

	var gcd_active: bool = abilities.gcd_remaining > 0.05
	for i in 10:
		var entry: Dictionary = _slots[i]
		var cd: float = abilities.get_cooldown(i + 1)
		var ready := cd < 0.05
		var sbox: StyleBoxFlat = entry["sbox"]

		var style = entry["style"]
		var cls_bg: Color     = style["bg"]     if style != null else SLOT_BG_UTILITY
		var cls_border: Color = style["border"] if style != null else Color.TRANSPARENT

		if not ready:
			sbox.bg_color     = cls_bg.darkened(0.72)
			sbox.border_color = Color.TRANSPARENT
			entry["cd_lbl"].text = "%.1f" % cd
		elif gcd_active:
			sbox.bg_color     = cls_bg.darkened(0.52)
			sbox.border_color = Color.TRANSPARENT
			entry["cd_lbl"].text = ""
		else:
			var ability: AbilityDefinition = null
			var _prec = MatchState.players.get(player.player_id)
			if _prec != null:
				ability = GameRegistry.get_ability(_prec.class_id, i + 1)
			if ability != null and not _ability_in_range(player, ability):
				sbox.bg_color     = cls_bg.darkened(0.45)
				sbox.border_color = cls_border.darkened(0.45)
				entry["cd_lbl"].text = "⊘"
			else:
				sbox.bg_color     = cls_bg
				sbox.border_color = cls_border
				entry["cd_lbl"].text = ""

		# Queue gold border takes priority over all other border states
		if _queue_positions.has(i + 1):
			sbox.border_color = C_QUEUE_GOLD

func _try_load_names(player: Node) -> void:
	var rec = MatchState.players.get(player.player_id)
	if rec == null:
		return
	for i in 10:
		var ability: AbilityDefinition = GameRegistry.get_ability(rec.class_id, i + 1)
		if ability == null:
			continue
		_slots[i]["name_lbl"].text = ability.display_name.left(6)
		_slots[i]["panel"].tooltip_text = _ability_tooltip(ability, i + 1)
		_slots[i]["style"] = _classify_slot_style(ability)
	_names_loaded = true
	_update_mana_visibility(player)

func _update_mana_visibility(player: Node) -> void:
	if _mana_bar_rows.size() < 4:
		return
	var rec = MatchState.players.get(player.player_id)
	if rec == null:
		return
	var uses_red := false
	var uses_blue := false
	var uses_yellow := false
	for slot in range(1, 10):
		var ab: AbilityDefinition = GameRegistry.get_ability(rec.class_id, slot)
		if ab == null:
			continue
		if ab.mana_type == 1:   uses_red    = true
		elif ab.mana_type == 2: uses_blue   = true
		elif ab.mana_type == 3: uses_yellow = true
	_mana_bar_rows[0].visible = uses_red
	_mana_bar_rows[1].visible = uses_blue
	_mana_bar_rows[2].visible = uses_yellow
	_mana_bar_rows[3].visible = true

func _ability_tooltip(ability: AbilityDefinition, slot: int) -> String:
	const MANA_LABELS := ["FREE", "RED", "BLU", "YEL", "ULT"]
	var key := "U" if slot == 10 else str(slot)
	var mtype := clampi(ability.mana_type, 0, 4)
	var mana_str: String
	if ability.mana_cost <= 0.0 or mtype == 0:
		mana_str = "FREE"
	else:
		mana_str = "%d %s" % [int(ability.mana_cost), MANA_LABELS[mtype]]
	var cd_str := "%.1fs CD" % ability.cooldown if ability.cooldown > 0.0 else "No CD"
	var tip := "[%s] %s\n%s  ·  %s" % [key, ability.display_name, mana_str, cd_str]
	if not ability.description.is_empty():
		tip += "\n" + ability.description
	return tip

func _update_target(player: Node) -> void:
	var tid: String = player.current_target_id
	if tid.is_empty():
		_target_icon.add_theme_color_override("font_color", C_NONE)
		_target_name.text = "NO TARGET"
		_target_name.add_theme_color_override("font_color", C_NONE)
		_target_class.text = ""
		_target_hp.value = 0.0
		return

	var target: Node = null
	for n in get_tree().get_nodes_in_group("players"):
		if n.player_id == tid:
			target = n
			break
	if target == null:
		return

	_target_icon.add_theme_color_override("font_color", C_ENEMY)
	var rec = MatchState.players.get(tid, null)
	_target_name.text = rec.display_name if rec else tid
	_target_name.add_theme_color_override("font_color", C_ENEMY)
	_target_class.text = target.class_definition.display_name \
		if target.class_definition else ""
	var t_buffs = target.get_node_or_null("PlayerBuffs")
	if t_buffs and t_buffs.max_health > 0:
		_target_hp.value = t_buffs.health / t_buffs.max_health

func _ability_in_range(player: Node, ability: AbilityDefinition) -> bool:
	if ability.range <= 0.0:
		return true
	if ability.target_mode in [2, 3, 5, 7, 8]:  # Self, Global, AoEAroundSelf, AimedPoint, Cone
		return true
	var target_id: String = player.current_target_id
	if target_id.is_empty():
		return false
	for n in get_tree().get_nodes_in_group("players"):
		if n.get("player_id") == target_id:
			return player.global_position.distance_to(n.global_position) <= ability.range
	return false

func _classify_slot_style(ability: AbilityDefinition) -> Dictionary:
	var has_aoe_dmg    := false
	var has_damage     := false
	var has_hot        := false
	var has_heal       := false
	var has_dash       := false
	var has_buff       := false
	var has_terrain    := false
	var has_hex_mark   := false
	var has_mana_drain := false
	var has_fumble     := false
	var has_hard_cc    := false
	var has_snare      := false

	for e in ability.effects:
		if e is _AoEDamageEffect:       has_aoe_dmg    = true
		if e is DamageEffect:           has_damage     = true
		if e is HoTEffect:              has_hot        = true
		if e is PeriodicHoTEffect:      has_hot        = true
		if e is HealEffect:             has_heal       = true
		if e is _AoEHealEffect:         has_heal       = true
		if e is DashEffect:             has_dash       = true
		if e is TeleportEffect:         has_dash       = true
		if e is SpeedBoostEffect:       has_buff       = true
		if e is DamageBoostEffect:      has_buff       = true
		if e is DamageReductionEffect:  has_buff       = true
		if e is _InvulnEffect:          has_buff       = true
		if e is StunImmuneEffect:       has_buff       = true
		if e is TerrainShapeEffect:     has_terrain    = true
		if e is _TrapSpawnEffect:       has_terrain    = true
		if e is HexEffect:              has_hex_mark   = true
		if e is MarkEffect:             has_hex_mark   = true
		if e is ManaDrainEffect:        has_mana_drain = true
		if e is FumbleEffect:           has_fumble     = true
		if e is StunEffect:             has_hard_cc    = true
		if e is KnockbackEffect:        has_hard_cc    = true
		if e is _PullEffect:            has_hard_cc    = true
		if e is ConfusionEffect:        has_hard_cc    = true
		if e is SnareEffect:            has_snare      = true

	# Primary background — first match wins
	var bg: Color
	if ability.mana_type == 4:
		bg = SLOT_BG_ULTRA
	elif has_aoe_dmg:
		bg = SLOT_BG_AOE_DMG
	elif has_damage:
		bg = SLOT_BG_DAMAGE
	elif has_hot:
		bg = SLOT_BG_HOT
	elif has_heal:
		bg = SLOT_BG_HEAL
	elif has_dash and not has_damage:
		bg = SLOT_BG_MOVEMENT
	elif has_buff and ability.target_mode == 1:  # 1 = NearestAlly
		bg = SLOT_BG_SUPPORT
	elif has_buff:
		bg = SLOT_BG_SELF_BUFF
	elif has_terrain:
		bg = SLOT_BG_TERRAIN
	elif has_hex_mark or has_mana_drain or has_fumble:
		bg = SLOT_BG_DEBUFF
	elif has_hard_cc or has_snare:
		bg = SLOT_BG_CC
	else:
		bg = SLOT_BG_UTILITY

	# Secondary border — first match wins; suppressed if already the primary
	var border := Color.TRANSPARENT
	var bg_is_cc     := bg == SLOT_BG_CC
	var bg_is_debuff := bg == SLOT_BG_DEBUFF
	if has_hard_cc and not bg_is_cc:
		border = SLOT_BORDER_HARD_CC
	elif has_snare and not bg_is_cc:
		border = SLOT_BORDER_SNARE
	elif has_hex_mark and not bg_is_debuff:
		border = SLOT_BORDER_DEBUFF
	elif has_fumble and not bg_is_debuff:
		border = SLOT_BORDER_FUMBLE
	elif has_mana_drain and not bg_is_debuff:
		border = SLOT_BORDER_MANA

	return {"bg": bg, "border": border}

func _local_player() -> Node:
	var pid := NetworkManager.local_player_id
	if pid.is_empty():
		return null
	for n in get_tree().get_nodes_in_group("players"):
		if n.player_id == pid:
			return n
	return null

# ── Queue visualization ───────────────────────────────────────────────────────

func _on_queue_changed(player_id: String, queue: Array) -> void:
	var local_p := _local_player()
	if local_p == null or local_p.player_id != player_id:
		return
	_cached_queue = queue
	_queue_positions.clear()
	for k in queue.size():
		_queue_positions[queue[k]] = k + 1
	_refresh_queue_visuals()

func _refresh_queue_visuals() -> void:
	for i in 10:
		var slot_num := i + 1
		var pos: int = _queue_positions.get(slot_num, 0)
		_queue_badges[i].text = "Q%d" % pos if pos > 0 else ""

	for i in 5:
		var dot: ColorRect = _queue_preview_dots[i]
		if i < _cached_queue.size():
			var slot_num: int = _cached_queue[i]
			var idx := slot_num - 1
			var style = _slots[idx]["style"] if idx >= 0 and idx < _slots.size() else null
			dot.color = (style["bg"] as Color).lightened(0.12) if style != null else C_QUEUE_GOLD
		else:
			dot.color = Color(0.15, 0.15, 0.20, 0.9)

func _on_ability_resolved(caster_id: String, slot: int, _hit_ids: Array) -> void:
	var local_p := _local_player()
	if local_p == null or local_p.player_id != caster_id:
		return
	_flash_slot(slot, Color(1.0, 0.95, 0.4, 0.85))

func _on_ability_failed(caster_id: String, slot: int, _reason: String) -> void:
	var local_p := _local_player()
	if local_p == null or local_p.player_id != caster_id:
		return
	_flash_slot(slot, C_QUEUE_FAIL)

func _flash_slot(slot: int, flash_color: Color) -> void:
	if slot < 1 or slot > _slots.size():
		return
	var sbox: StyleBoxFlat = _slots[slot - 1]["sbox"]
	var orig := sbox.bg_color
	sbox.bg_color = flash_color
	var tween := create_tween()
	tween.tween_property(sbox, "bg_color", orig, 0.35)
