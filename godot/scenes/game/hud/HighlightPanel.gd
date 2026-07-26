extends Control
## Expandable highlight panel flanking the Scoreboard.
## Instantiate, call setup(), then add_child().

const PANEL_W   := 340.0
const STRIP_W   := 7.0
const BAR_H     := 138.0  # Scoreboard BAR_H(80) + charge bar(3) + CARDS_H(55)
const ANIM_SECS := 0.55

const C_GOLD := Color(1.0, 0.796, 0.239)

# Diagonal-stripe placeholder drawn before first clip arrives.
class _Stripes extends Control:
	var stripe_color : Color = Color(1, 1, 1, 0.06)
	var bg_color     : Color = Color(0.04, 0.05, 0.10)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(0, 0, w, h), bg_color)
		var step := 18.0
		var t := -h
		while t < w + h:
			draw_line(Vector2(t, 0.0), Vector2(t + h, h), stripe_color, 7.0)
			t += step

# ── Public config (set before add_child) ─────────────────────────────────────
var is_left    : bool  = true
var team_color : Color = Color.WHITE
var team_id    : int   = 0

func setup(p_left: bool, p_color: Color, p_id: int) -> void:
	is_left    = p_left
	team_color = p_color
	team_id    = p_id

# ── Internal state ────────────────────────────────────────────────────────────
var _open_pct  : float = 0.0
var _tween     : Tween = null

var _strip     : ColorRect
var _content   : Control
var _stripes   : _Stripes
var _thumb     : TextureRect
var _ph_label  : Label
var _scorer    : Label
var _score     : Label
var _info      : VBoxContainer

func _ready() -> void:
	mouse_filter  = Control.MOUSE_FILTER_IGNORE
	anchor_top    = 0.0
	anchor_bottom = 0.0
	offset_top    = 0.0
	offset_bottom = BAR_H
	if is_left:
		anchor_left  = 0.0; anchor_right = 0.0
		offset_left  = 0.0; offset_right = STRIP_W
	else:
		anchor_left  = 1.0; anchor_right = 1.0
		offset_left  = -STRIP_W; offset_right = 0.0
	_build()
	HighlightRecorder.clip_added.connect(_on_clip_added)

func _build() -> void:
	# ── Colored edge strip (always visible, click to toggle) ──────────────────
	_strip = ColorRect.new()
	_strip.color = team_color
	_strip.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_strip)

	# ── Expandable content container ──────────────────────────────────────────
	_content = Control.new()
	_content.clip_contents = true
	_content.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(_content)

	# Diagonal-stripe placeholder background
	_stripes = _Stripes.new()
	_stripes.stripe_color = Color(team_color.r, team_color.g, team_color.b, 0.07)
	_stripes.bg_color     = Color(0.04, 0.05, 0.10)
	_stripes.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stripes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_stripes)

	# Screenshot thumbnail (hidden until first clip)
	_thumb = TextureRect.new()
	_thumb.expand_mode   = TextureRect.EXPAND_IGNORE_SIZE
	_thumb.stretch_mode  = TextureRect.STRETCH_SCALE
	_thumb.set_anchors_preset(Control.PRESET_FULL_RECT)
	_thumb.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_thumb.visible       = false
	_content.add_child(_thumb)

	# Semi-transparent overlay dims the screenshot
	var ovl := ColorRect.new()
	ovl.color = Color(0.0, 0.0, 0.0, 0.45)
	ovl.set_anchors_preset(Control.PRESET_FULL_RECT)
	ovl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(ovl)

	# "GAMEPLAY HIGHLIGHT" placeholder text
	_ph_label = Label.new()
	_ph_label.text = "GAMEPLAY\nHIGHLIGHT"
	_ph_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ph_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_ph_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ph_label.add_theme_font_size_override("font_size", 9)
	_ph_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.22))
	_ph_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_ph_label)

	# Info overlay pinned to the bottom of content
	_info = VBoxContainer.new()
	_info.add_theme_constant_override("separation", 1)
	_info.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_info.offset_top    = -48.0
	_info.offset_bottom = -5.0
	_info.offset_left   = 7.0
	_info.offset_right  = -7.0
	_info.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_info.visible       = false
	_content.add_child(_info)

	_scorer = _lbl("", Color.WHITE, 10)
	_info.add_child(_scorer)
	_score = _lbl("", C_GOLD, 15)
	_info.add_child(_score)
	var badge := _lbl("● ULTRA", Color(team_color.r, team_color.g, team_color.b, 0.80), 8)
	_info.add_child(badge)

	_update_layout()

	_strip.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed \
				and e.button_index == MOUSE_BUTTON_LEFT:
			_toggle()
	)

# ── Layout ────────────────────────────────────────────────────────────────────
func _update_layout() -> void:
	var cw := PANEL_W * _open_pct
	if is_left:
		_strip.position   = Vector2.ZERO
		_strip.size       = Vector2(STRIP_W, BAR_H)
		_content.position = Vector2(STRIP_W, 0.0)
		_content.size     = Vector2(cw, BAR_H)
		offset_right      = STRIP_W + cw
	else:
		_content.position = Vector2.ZERO
		_content.size     = Vector2(cw, BAR_H)
		_strip.position   = Vector2(cw, 0.0)
		_strip.size       = Vector2(STRIP_W, BAR_H)
		offset_left       = -(STRIP_W + cw)

# ── Animation ─────────────────────────────────────────────────────────────────
func expand()  -> void: _animate_to(1.0)
func collapse()-> void: _animate_to(0.0)

func _toggle() -> void:
	_animate_to(0.0 if _open_pct > 0.5 else 1.0)

func _animate_to(target: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_QUART)
	_tween.tween_method(_set_open, _open_pct, target, ANIM_SECS)

func _set_open(v: float) -> void:
	_open_pct = v
	_update_layout()

# ── Clip handling ─────────────────────────────────────────────────────────────
func _on_clip_added(clip: Dictionary) -> void:
	if clip["team_id"] != team_id:
		return
	if clip["texture"] != null:
		_thumb.texture = clip["texture"]
		_thumb.visible = true
		_stripes.visible = false
		_ph_label.visible = false
	_scorer.text  = (clip["scorer_name"] as String).to_upper()
	_score.text   = "%d – %d" % [clip["home_score"], clip["away_score"]]
	_info.visible = true
	expand()

# ── Helpers ───────────────────────────────────────────────────────────────────
func _lbl(txt: String, col: Color, sz: int) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", sz)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
