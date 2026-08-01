extends Control

## Ability cast bar — visible while the local player holds a chargeable ability key.
## Same panel/label/bar layout as ThrowChargeBar; positioned below the scoreboard avatars.

const C_GOLD := Color(1.0, 0.85, 0.2)

var _bar  : ProgressBar
var _label: Label
var _charge_max: float = 1.0
var _elapsed:    float = 0.0
var _active:     bool  = false

func _ready() -> void:
	anchor_left  = 0.5;  anchor_top    = 0.0
	anchor_right = 0.5;  anchor_bottom = 0.0
	offset_left  = -120.0; offset_top    = 142.0
	offset_right =  120.0; offset_bottom = 164.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()
	EventBus.ability_charge_started.connect(_on_charge_started)
	EventBus.ability_charge_released.connect(_on_charge_released)

func _build() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sbox := StyleBoxFlat.new()
	sbox.bg_color = Color(0.04, 0.04, 0.12, 0.88)
	sbox.corner_radius_top_left     = 4; sbox.corner_radius_top_right    = 4
	sbox.corner_radius_bottom_left  = 4; sbox.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", sbox)
	add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	panel.add_child(hbox)

	_label = Label.new()
	_label.text = "CAST"
	_label.add_theme_color_override("font_color", C_GOLD)
	_label.add_theme_font_size_override("font_size", 12)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(_label)

	_bar = ProgressBar.new()
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.value = 0.0
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.custom_minimum_size.y = 14
	_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = C_GOLD
	_bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.08, 0.02, 0.9)
	_bar.add_theme_stylebox_override("background", bg)
	hbox.add_child(_bar)

func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	var pct := minf(_elapsed / _charge_max, 1.0)
	_bar.value = pct
	var fill := _bar.get_theme_stylebox("fill") as StyleBoxFlat
	fill.bg_color = Color(1.0, 0.25, 0.25) if pct >= 1.0 else C_GOLD

func _on_charge_started(pid: String, slot: int, charge_max: float) -> void:
	if pid != NetworkManager.local_player_id:
		return
	_charge_max = maxf(charge_max, 0.01)
	_elapsed = 0.0
	_active = true
	_bar.value = 0.0
	var rec: MatchState.PlayerRecord = MatchState.players.get(pid)
	if rec != null:
		var ability: AbilityDefinition = GameRegistry.get_ability(rec.class_id, slot)
		_label.text = ability.display_name.to_upper() if ability != null else "CAST"
	else:
		_label.text = "CAST"
	visible = true

func _on_charge_released(pid: String, _slot: int, _charge_t: float) -> void:
	if pid != NetworkManager.local_player_id:
		return
	_active = false
	visible = false
