extends Control
## Top-right HUD panel showing the running list of highlight clips.
## Mirrors Flutter's HighlightClipList / _ClipListPanel.

const C_GOLD := Color(1.000, 0.796, 0.239)
const C_HOME := Color(1.000, 0.231, 0.325)
const C_AWAY := Color(0.184, 0.514, 1.000)
const C_BG   := Color(0.016, 0.020, 0.039, 0.93)
const C_DIM  := Color(1, 1, 1, 0.40)

const PANEL_W := 240.0
const MAX_H   := 280.0
const BAR_H   := 83.0

var _list     : VBoxContainer
var _count    : Label

func _ready() -> void:
	mouse_filter  = Control.MOUSE_FILTER_IGNORE
	anchor_left   = 1.0;  anchor_right  = 1.0
	anchor_top    = 0.0;  anchor_bottom = 0.0
	offset_left   = -(PANEL_W + 8.0)
	offset_right  = -8.0
	offset_top    = BAR_H + 4.0
	offset_bottom = BAR_H + 4.0 + MAX_H
	clip_contents = true
	visible       = false
	_build()
	HighlightRecorder.clip_added.connect(_on_clip_added)

func _build() -> void:
	# Background
	var bg := PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_BG
	sb.corner_radius_top_left     = 4
	sb.corner_radius_bottom_left  = 4
	sb.corner_radius_top_right    = 0
	sb.corner_radius_bottom_right = 0
	bg.add_theme_stylebox_override("panel", sb)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(root)

	# Header row
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 4)
	hdr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hdr_m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		hdr_m.add_theme_constant_override("margin_" + side, 6)
	hdr_m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr.add_child(hdr_m)

	var hdr_row := HBoxContainer.new()
	hdr_row.add_theme_constant_override("separation", 4)
	hdr_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr_m.add_child(hdr_row)

	var title := Label.new()
	title.text = "HIGHLIGHTS"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", C_GOLD)
	title.add_theme_font_size_override("font_size", 9)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr_row.add_child(title)

	_count = Label.new()
	_count.text = ""
	_count.add_theme_color_override("font_color", C_DIM)
	_count.add_theme_font_size_override("font_size", 8)
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr_row.add_child(_count)

	root.add_child(hdr)

	# Divider
	var div := ColorRect.new()
	div.color = Color(1, 1, 1, 0.06)
	div.custom_minimum_size = Vector2(0, 1)
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(div)

	# Scrollable list
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 0)
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(_list)

func _on_clip_added(_clip: Dictionary) -> void:
	visible = true
	_rebuild_list()

func _rebuild_list() -> void:
	for c in _list.get_children():
		c.queue_free()

	var all : Array[Dictionary] = HighlightRecorder.clips
	_count.text = "%d clip%s" % [all.size(), "s" if all.size() != 1 else ""]

	# Newest first
	for i in range(all.size() - 1, -1, -1):
		_list.add_child(_make_row(all[i]))

func _make_row(clip: Dictionary) -> Control:
	var team_id : int   = clip["team_id"]
	var tc      : Color = C_HOME if team_id == 0 else C_AWAY

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rm := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		rm.add_theme_constant_override("margin_" + side, 5)
	rm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rm.add_child(row)

	# Left: badge + scorer + team name
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 1)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(left)

	var badge := Label.new()
	badge.text = "● %s" % (clip["score_type"] if clip.has("score_type") else "ULTRA")
	badge.add_theme_color_override("font_color", Color(tc.r, tc.g, tc.b, 0.85))
	badge.add_theme_font_size_override("font_size", 8)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(badge)

	var scorer := Label.new()
	scorer.text = (clip["scorer_name"] as String).to_upper()
	scorer.add_theme_color_override("font_color", Color.WHITE)
	scorer.add_theme_font_size_override("font_size", 10)
	scorer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(scorer)

	var team_lbl := Label.new()
	team_lbl.text = (clip["team_name"] as String).to_upper()
	team_lbl.add_theme_color_override("font_color", Color(tc.r, tc.g, tc.b, 0.65))
	team_lbl.add_theme_font_size_override("font_size", 8)
	team_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(team_lbl)

	# Right: score in gold
	var score_lbl := Label.new()
	score_lbl.text = "%d – %d" % [clip["home_score"], clip["away_score"]]
	score_lbl.add_theme_color_override("font_color", C_GOLD)
	score_lbl.add_theme_font_size_override("font_size", 12)
	score_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	score_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(score_lbl)

	# Row divider
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(rm)
	var rdiv := ColorRect.new()
	rdiv.color = Color(1, 1, 1, 0.04)
	rdiv.custom_minimum_size = Vector2(0, 1)
	rdiv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(rdiv)

	return outer
