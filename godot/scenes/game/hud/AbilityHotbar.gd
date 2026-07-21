extends Control

## 10 ability slots (1-9 + Ultra) with cooldown overlay and GCD flash.

const SLOT_W    := 52
const SLOT_H    := 58
const SLOT_GAP  := 4
const SLOT_COUNT := 10

# Mana-type tint for slot background (matches AbilityDefinition mana_type enum)
const MANA_TINTS := [
	Color(0.22, 0.22, 0.22),  # 0 = None
	Color(0.35, 0.08, 0.08),  # 1 = Red
	Color(0.08, 0.12, 0.38),  # 2 = Blue
	Color(0.32, 0.28, 0.04),  # 3 = Yellow
	Color(0.28, 0.08, 0.38),  # 4 = Ultra
]
const READY_TINT := Color(0.14, 0.14, 0.18)

var _slots: Array[Dictionary] = []  # [{panel, name_lbl, cd_lbl}]
var _names_loaded := false

func _ready() -> void:
	# Full-width bar at bottom, 8px margin, 66px tall, starts after mana panel
	anchor_left = 0.0;  anchor_top = 1.0
	anchor_right = 1.0; anchor_bottom = 1.0
	offset_left = 206.0; offset_top = -74.0
	offset_right = -8.0; offset_bottom = -8.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()

func _build() -> void:
	var bg := PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sbox := StyleBoxFlat.new()
	sbox.bg_color = Color(0.04, 0.04, 0.10, 0.84)
	sbox.corner_radius_top_left = 4; sbox.corner_radius_top_right = 4
	bg.add_theme_stylebox_override("panel", sbox)
	add_child(bg)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", SLOT_GAP)
	bg.add_child(hbox)

	for i in SLOT_COUNT:
		var slot_label := "U" if i == 9 else str(i + 1)
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(SLOT_W, SLOT_H)
		var slot_sbox := StyleBoxFlat.new()
		slot_sbox.bg_color = READY_TINT
		slot_sbox.corner_radius_top_left = 3; slot_sbox.corner_radius_top_right = 3
		slot_sbox.corner_radius_bottom_left = 3; slot_sbox.corner_radius_bottom_right = 3
		panel.add_theme_stylebox_override("panel", slot_sbox)

		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 2)
		panel.add_child(vbox)

		var key_lbl := Label.new()
		key_lbl.text = slot_label
		key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		key_lbl.add_theme_font_size_override("font_size", 10)
		vbox.add_child(key_lbl)

		var name_lbl := Label.new()
		name_lbl.text = "----"
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		name_lbl.add_theme_font_size_override("font_size", 9)
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		vbox.add_child(name_lbl)

		var cd_lbl := Label.new()
		cd_lbl.text = ""
		cd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cd_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
		cd_lbl.add_theme_font_size_override("font_size", 13)
		vbox.add_child(cd_lbl)

		hbox.add_child(panel)
		_slots.append({"panel": panel, "sbox": slot_sbox, "name_lbl": name_lbl, "cd_lbl": cd_lbl})

func _process(_delta: float) -> void:
	var player := _local_player()
	if player == null: return

	if not _names_loaded:
		_try_load_names(player)

	var abilities: Node = player.get_node_or_null("PlayerAbilities")
	if abilities == null: return

	var gcd_active: bool = abilities.gcd_remaining > 0.05

	for i in SLOT_COUNT:
		var entry: Dictionary = _slots[i]
		var cd: float = abilities.get_cooldown(i + 1)
		var ready := cd < 0.05

		var sbox: StyleBoxFlat = entry["sbox"]
		if not ready:
			sbox.bg_color = Color(0.08, 0.08, 0.08)
			entry["cd_lbl"].text = "%.1f" % cd
		elif gcd_active:
			sbox.bg_color = Color(0.10, 0.10, 0.20)
			entry["cd_lbl"].text = ""
		else:
			# Show mana-type tint when ready
			var tint_idx := 0
			var def = _get_ability_def(player, i)
			if def:
				tint_idx = def.mana_type
			sbox.bg_color = MANA_TINTS[clampi(tint_idx, 0, MANA_TINTS.size() - 1)]
			entry["cd_lbl"].text = ""

func _try_load_names(player: Node) -> void:
	if player.class_definition == null: return
	var defs: Array = player.class_definition.abilities
	for i in mini(defs.size(), SLOT_COUNT):
		var short: String = (defs[i] as AbilityDefinition).display_name.left(6)
		_slots[i]["name_lbl"].text = short
	_names_loaded = true

func _get_ability_def(player: Node, idx: int) -> Resource:
	if player.class_definition == null: return null
	var defs: Array = player.class_definition.abilities
	if idx >= defs.size(): return null
	return defs[idx]

func _local_player() -> Node:
	var pid := NetworkManager.local_player_id
	if pid.is_empty(): return null
	for n in get_tree().get_nodes_in_group("players"):
		if n.player_id == pid: return n
	return null
