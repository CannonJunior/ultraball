extends Control

signal match_ready(config: MatchConfig)

const _MatchConfig := preload("res://data/match/MatchConfig.gd")

# ── Palette ──────────────────────────────────────────────────────────────────
const C_BG     := Color(0.016, 0.020, 0.039)   # #04050A
const C_SURF   := Color(0.031, 0.031, 0.059)   # #08080F
const C_GOLD   := Color(1.000, 0.796, 0.239)   # #FFCB3D
const C_BORDER := Color(0.102, 0.102, 0.180)   # #1A1A2E
const C_DIM    := Color(1, 1, 1, 0.45)
const C_FAINT  := Color(1, 1, 1, 0.25)
const C_KEY_BG := Color(0.200, 0.200, 0.333)
const C_KEY_BD := Color(0.333, 0.400, 0.533)
const C_KEY_TX := Color(0.800, 0.867, 1.000)
const C_DESC   := Color(1, 1, 1, 0.60)

# ── State ─────────────────────────────────────────────────────────────────────
var _match_mode  : int  = 0   # 0=TwoTeam 1=ThreeTeam
var _fast_mode   : bool = false
var _creature    : int  = 0   # 0=Kraken 1=Dragon 2=Hydra 3=Wraith 4=Chaos
var _home_strat  : int  = 0
var _home_tact   : int  = 0
var _opp_strat   : int  = 0
var _opp_tact    : int  = 0

# Button group arrays — filled during build
var _mode_btns   : Array = []   # [btn2team, btn3team]
var _dur_btns    : Array = []   # [btnNormal, btnFast]
var _crea_btns   : Array = []   # one per creature
var _hs_radios   : Array = []   # home strategy radio rows
var _ht_radios   : Array = []   # home tactics radio rows
var _os_radios   : Array = []   # opp strategy radio rows
var _ot_radios   : Array = []   # opp tactics radio rows

# Roster
var _home_roster       : Array  = []
var _home_roster_vbox  : VBoxContainer = null
var _roster_content    : Control       = null
var _roster_expanded   : bool   = false
var _roster_toggle_btn : Button = null
var _dragging          : bool   = false
var _drag_from_slot    : int    = -1
var _drag_ghost        : Control       = null
var _drag_slot_panels  : Array  = []

# Classes
var _inactive_classes  : Array  = []   # set of inactive class indices
var _class_btns        : Array  = []   # toggle Button refs per class

# ── Data ──────────────────────────────────────────────────────────────────────
const STRATEGIES := [
	["💣", "TEMPO TRAP",      "Deny phase lines; force opponent to hold the ball until it explodes"],
	["🔢", "NUMBERS GAME",    "Eliminate 2–3 opponents early; exploit the numbers edge to score freely"],
	["🦅", "CHANNEL CONTROL", "Control creature channels for protected scoring corridors"],
	["🌊", "FLOOD THE ZONE",  "Flood 3–4 players into the endzone; defense can't cover everyone"],
	["🩸", "BLEED OUT",       "Never surrender the ball; drain the clock; only score when safe"],
]

const TACTICS := [
	["🎯", "FOCUS FIRE",     "All attackers lock onto one target at once; eliminate before moving on"],
	["🏀", "PICK & SCREEN",  "Two players set hard screens; others sprint decoy routes to the endzone"],
	["⚡", "QUICK RELEASE",  "Pass at the first open window; chain passes to advance the ball"],
	["👹", "CREATURE FLANK", "Herd the opponent toward the creature from the opposite side"],
	["🔺", "WEDGE RUN",      "Three players form a tight triangle around the carrier; move as one"],
	["⭐", "HERO BALL",      "All units rally around the star player; pass the ball to them"],
]

const CREATURES := [
	["🐙", "KRAKEN",        "Slow & deadly"],
	["🐉", "DRAGON",        "Fast & fierce"],
	["🐍", "HYDRA",         "Large & relentless"],
	["👻", "WRAITH",        "Blindingly fast & ethereal"],
	["⚡", "CHAOS MONSTER", "Unpredictable & terrifying"],
]

const CONTROLS := [
	["W / S",      "Move forward / backward"],
	["A / D",      "Turn left / right"],
	["Q / E",      "Strafe left / right"],
	["1",          "Tackle (basic attack)"],
	["2",          "Power Slam (25 Red Mana)"],
	["3",          "Sprint (20 Blue Mana)"],
	["F",          "Pass ball to teammate"],
	["SPACE",      "Jump (evades tackles while airborne)"],
	["SPACE x2",   "Double-jump (costs 15 Blue Mana)"],
	["TAB",        "Cycle enemy target"],
	["SHIFT+TAB",  "Switch controlled player"],
	["M",          "Toggle damage / healing meter"],
	["C",          "Cycle player class (Test Mode only)"],
	["ESC",        "Clear target / Pause"],
]

const RULES := [
	["🏟", "THE FIELD", [
		"Total field: 140m × 40m",
		"Left & Right endzones: 20m deep — score here!",
		"Left & Right channels: 10m — patrolled by the creature",
		"Main field: 80m with 5 PHASE LINES at 20m intervals",
		"Phase lines reset ball charge when crossed",
	]],
	["🏆", "SCORING", [
		"ULTRA (7 pts) — Ball carrier walks/runs into enemy endzone",
		"META (3 pts) — Pass caught by player already in enemy endzone",
		"KILLA (1 pt) — Opposing player dies (combat, creature, explosion)",
	]],
	["⚡", "THE ULTRABALL", [
		"Holding the ball builds CHARGE — explodes after 7 seconds!",
		"Explosion kills holder, stuns teammates 1 second",
		"Passing resets charge: +1 second per meter thrown",
		"Crossing a PHASE LINE fully resets charge to 0",
		"Phase lines deactivate when crossed (reactivate on possession change)",
		"Failed pass: entire passing team stunned 1 second",
	]],
	["👹", "THE CREATURE", [
		"Circles the entire field counter-clockwise at moderate speed",
		"Instantly kills any player it touches — both teams!",
		"Awards 1 KILLA point to the opposite team on each kill",
		"Creature type is determined by the home team",
	]],
	["⚔", "COMBAT", [
		"RED MANA: 0–100, gained by dealing damage (+5/hit), decays after 3s",
		"BLUE MANA: 0–100, auto-regens at 8/sec passively",
		"TACKLE (1): 15 dmg, 0.8s cooldown — no mana cost",
		"POWER SLAM (2): 35 dmg + knockback, costs 25 Red Mana, 3s CD",
		"SPRINT (3): +50% speed for 3s, costs 20 Blue Mana, 6s CD",
		"3-HIT COMBO: 3 attacks in 4s = COMBO! +30 red mana + knockback",
	]],
	["👥", "TEAMS", [
		"7 players per team on field, 15-player roster total",
		"Deaths are PERMANENT within a match",
		"1 substitution allowed per act when a player dies",
		"After 1st death: sub used; subsequent deaths = disadvantage",
		"Teams restock to 7 at the start of each new act",
		"All 15 players dead = FORFEIT",
	]],
	["📋", "THE ACTS", [
		"Acts 1–4: 3-minute countdown timer (1 min in Fast mode)",
		"Act 5: Ends when the leading team scores an ULTRA...",
		"...OR the trailing team comes back and scores an ULTRA",
		"Highest score at end of Act 5 wins the match!",
	]],
]

const CLASS_NAMES := [
	"SPECTRE", "CORSAIR", "GEOMANCER", "ARCHON", "WARDEN", "TRICKSTER", "WRECKER", "VITALIST"
]
const CLASS_DESCS := [
	"Ghost phase — evasion and burst speed",
	"Dual blades — sustained bleed damage",
	"Stone pillars — terrain and field control",
	"Battle mage — heavy strikes and shield",
	"Guardian — protect and sustain teammates",
	"Deceiver — illusions and flanking",
	"Berserker — brutal knockback and brute force",
	"Healer — team sustain and revival support",
]
const CLASS_COLORS := [
	Color(0.267, 1.000, 0.800),   # Spectre   #44FFCC
	Color(1.000, 0.267, 0.667),   # Corsair   #FF44AA
	Color(1.000, 0.333, 0.267),   # Geomancer #FF5544
	Color(0.267, 0.533, 1.000),   # Archon    #4488FF
	Color(1.000, 0.800, 0.267),   # Warden    #FFCC44
	Color(0.667, 0.267, 1.000),   # Trickster #AA44FF
	Color(1.000, 0.467, 0.000),   # Wrecker   #FF7700
	Color(0.267, 0.867, 0.533),   # Vitalist  #44DD88
]

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_apply_bg()
	_build_ui()

func _apply_bg() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_BG
	add_theme_stylebox_override("panel", sb)

# ── Root layout ───────────────────────────────────────────────────────────────
func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Root VBoxContainer fills the whole viewport
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# Dark background panel
	var bg_panel := ColorRect.new()
	bg_panel.color = C_BG
	bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_panel.z_index = -1
	add_child(bg_panel)

	# ── Header ────────────────────────────────────────────────────────────────
	var header := _build_header()
	root.add_child(header)

	# ── Separator line ────────────────────────────────────────────────────────
	var sep := ColorRect.new()
	sep.color = C_BORDER
	sep.custom_minimum_size = Vector2(0, 1)
	root.add_child(sep)

	# ── Two-column body ───────────────────────────────────────────────────────
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 0)
	root.add_child(columns)

	# Left column: settings
	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(left_scroll)

	var left_vbox := VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_vertical   = Control.SIZE_SHRINK_BEGIN
	left_vbox.add_theme_constant_override("separation", 0)
	left_scroll.add_child(left_vbox)

	_build_settings_panel(left_vbox)

	# Vertical divider
	var vdiv := ColorRect.new()
	vdiv.color = C_BORDER
	vdiv.custom_minimum_size = Vector2(1, 0)
	columns.add_child(vdiv)

	# Right column: rules
	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(right_scroll)

	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical   = Control.SIZE_SHRINK_BEGIN
	right_vbox.add_theme_constant_override("separation", 0)
	right_scroll.add_child(right_vbox)

	_build_rules_panel(right_vbox)

# ── Header ────────────────────────────────────────────────────────────────────
func _build_header() -> Control:
	var container := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_BG
	sb.content_margin_top    = 24
	sb.content_margin_bottom = 24
	sb.content_margin_left   = 32
	sb.content_margin_right  = 32
	container.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_child(vbox)

	var title := Label.new()
	title.text = "ULTRABALL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", C_GOLD)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "A COMPETITIVE RAPID CHAOTIC SPORTS COMBAT GAME"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 10)
	subtitle.add_theme_color_override("font_color", C_DIM)
	vbox.add_child(subtitle)

	return container

# ── Settings Panel ────────────────────────────────────────────────────────────
func _build_settings_panel(vbox: VBoxContainer) -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   24)
	margin.add_theme_constant_override("margin_right",  24)
	margin.add_theme_constant_override("margin_top",    24)
	margin.add_theme_constant_override("margin_bottom", 24)
	vbox.add_child(margin)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	margin.add_child(inner)

	# ── Section Header ────────────────────────────────────────────────────────
	inner.add_child(_make_section_header("MATCH CONFIGURATION"))
	inner.add_child(_make_spacer(4))

	# ── Match Mode ────────────────────────────────────────────────────────────
	var mode_card := _make_card()
	inner.add_child(mode_card)
	var mode_vbox := VBoxContainer.new()
	mode_vbox.add_theme_constant_override("separation", 10)
	mode_card.add_child(mode_vbox)
	mode_vbox.add_child(_make_field_label("MATCH MODE"))
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 8)
	mode_vbox.add_child(mode_row)
	var btn2 := _make_speed_btn("2 TEAMS", "Classic — linear field", _match_mode == 0)
	var btn3 := _make_speed_btn("3 TEAMS", "Triangle field",         _match_mode == 1)
	btn2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_row.add_child(btn2)
	mode_row.add_child(btn3)
	_mode_btns = [btn2, btn3]
	btn2.pressed.connect(_set_match_mode.bind(0))
	btn3.pressed.connect(_set_match_mode.bind(1))

	# ── Match Duration ────────────────────────────────────────────────────────
	var dur_card := _make_card()
	inner.add_child(dur_card)
	var dur_vbox := VBoxContainer.new()
	dur_vbox.add_theme_constant_override("separation", 10)
	dur_card.add_child(dur_vbox)
	dur_vbox.add_child(_make_field_label("MATCH DURATION"))
	var dur_row := HBoxContainer.new()
	dur_row.add_theme_constant_override("separation", 8)
	dur_vbox.add_child(dur_row)
	var btn_norm := _make_speed_btn("NORMAL", "3min acts", !_fast_mode)
	var btn_fast := _make_speed_btn("FAST",   "1min acts", _fast_mode)
	btn_norm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_fast.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dur_row.add_child(btn_norm)
	dur_row.add_child(btn_fast)
	_dur_btns = [btn_norm, btn_fast]
	btn_norm.pressed.connect(_set_fast_mode.bind(false))
	btn_fast.pressed.connect(_set_fast_mode.bind(true))

	# ── Creature ──────────────────────────────────────────────────────────────
	var crea_card := _make_card()
	inner.add_child(crea_card)
	var crea_vbox := VBoxContainer.new()
	crea_vbox.add_theme_constant_override("separation", 10)
	crea_card.add_child(crea_vbox)
	crea_vbox.add_child(_make_field_label("CREATURE"))
	_crea_btns.clear()
	for i in range(CREATURES.size()):
		var c: Array = CREATURES[i]
		var rb := _make_choice_radio(c[0], c[1], c[2], _creature == i)
		rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		crea_vbox.add_child(rb)
		_crea_btns.append(rb)
		rb.pressed.connect(_set_creature.bind(i))

	# ── Home Strategy + Tactics ───────────────────────────────────────────────
	var strat_row := HBoxContainer.new()
	strat_row.add_theme_constant_override("separation", 12)
	inner.add_child(strat_row)

	# Home side
	var home_card := _make_card()
	home_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strat_row.add_child(home_card)
	var home_strat_vbox := VBoxContainer.new()
	home_strat_vbox.add_theme_constant_override("separation", 6)
	home_card.add_child(home_strat_vbox)

	home_strat_vbox.add_child(_make_field_label("HOME STRATEGY"))
	home_strat_vbox.add_child(_make_hint("How AI teammates approach the game"))
	home_strat_vbox.add_child(_make_spacer(4))
	_hs_radios.clear()
	for i in range(STRATEGIES.size()):
		var s: Array = STRATEGIES[i]
		var rb := _make_choice_radio(s[0], s[1], s[2], _home_strat == i)
		home_strat_vbox.add_child(rb)
		_hs_radios.append(rb)
		rb.pressed.connect(_set_home_strat.bind(i))

	home_strat_vbox.add_child(_make_divider())
	home_strat_vbox.add_child(_make_spacer(4))
	home_strat_vbox.add_child(_make_field_label("HOME TACTICS"))
	home_strat_vbox.add_child(_make_hint("How AI teammates behave moment-to-moment"))
	home_strat_vbox.add_child(_make_spacer(4))
	_ht_radios.clear()
	for i in range(TACTICS.size()):
		var t: Array = TACTICS[i]
		var rb := _make_choice_radio(t[0], t[1], t[2], _home_tact == i)
		home_strat_vbox.add_child(rb)
		_ht_radios.append(rb)
		rb.pressed.connect(_set_home_tact.bind(i))

	# Opponent side
	var opp_card := _make_card()
	opp_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strat_row.add_child(opp_card)
	var opp_strat_vbox := VBoxContainer.new()
	opp_strat_vbox.add_theme_constant_override("separation", 6)
	opp_card.add_child(opp_strat_vbox)

	opp_strat_vbox.add_child(_make_field_label("OPPONENT STRATEGY"))
	opp_strat_vbox.add_child(_make_hint("The computer team's theory of victory"))
	opp_strat_vbox.add_child(_make_spacer(4))
	_os_radios.clear()
	for i in range(STRATEGIES.size()):
		var s: Array = STRATEGIES[i]
		var rb := _make_choice_radio(s[0], s[1], s[2], _opp_strat == i)
		opp_strat_vbox.add_child(rb)
		_os_radios.append(rb)
		rb.pressed.connect(_set_opp_strat.bind(i))

	opp_strat_vbox.add_child(_make_divider())
	opp_strat_vbox.add_child(_make_spacer(4))
	opp_strat_vbox.add_child(_make_field_label("OPPONENT TACTICS"))
	opp_strat_vbox.add_child(_make_hint("The computer team's moment-to-moment behavior"))
	opp_strat_vbox.add_child(_make_spacer(4))
	_ot_radios.clear()
	for i in range(TACTICS.size()):
		var t: Array = TACTICS[i]
		var rb := _make_choice_radio(t[0], t[1], t[2], _opp_tact == i)
		opp_strat_vbox.add_child(rb)
		_ot_radios.append(rb)
		rb.pressed.connect(_set_opp_tact.bind(i))

	# ── Controls ──────────────────────────────────────────────────────────────
	var ctrl_card := _make_card()
	inner.add_child(ctrl_card)
	var ctrl_vbox := VBoxContainer.new()
	ctrl_vbox.add_theme_constant_override("separation", 6)
	ctrl_card.add_child(ctrl_vbox)
	ctrl_vbox.add_child(_make_field_label("CONTROLS"))
	ctrl_vbox.add_child(_make_spacer(2))
	for pair: Array in CONTROLS:
		ctrl_vbox.add_child(_make_control_row(pair[0], pair[1]))

	# ── Start Match ───────────────────────────────────────────────────────────
	inner.add_child(_make_spacer(12))
	var start_btn := Button.new()
	start_btn.text = "START MATCH"
	start_btn.custom_minimum_size = Vector2(0, 64)
	start_btn.add_theme_font_size_override("font_size", 28)
	start_btn.add_theme_color_override("font_color", Color.WHITE)
	var start_sb := StyleBoxFlat.new()
	start_sb.bg_color = Color(0.8, 0.27, 0.0)
	start_sb.corner_radius_top_left     = 8
	start_sb.corner_radius_top_right    = 8
	start_sb.corner_radius_bottom_left  = 8
	start_sb.corner_radius_bottom_right = 8
	start_btn.add_theme_stylebox_override("normal", start_sb)
	start_btn.add_theme_stylebox_override("hover",  start_sb)
	start_btn.add_theme_stylebox_override("pressed", start_sb)
	start_btn.pressed.connect(_on_start_pressed)
	inner.add_child(start_btn)
	inner.add_child(_make_spacer(24))

# ── Rules Panel ───────────────────────────────────────────────────────────────
func _build_rules_panel(vbox: VBoxContainer) -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   24)
	margin.add_theme_constant_override("margin_right",  24)
	margin.add_theme_constant_override("margin_top",    24)
	margin.add_theme_constant_override("margin_bottom", 24)
	vbox.add_child(margin)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	margin.add_child(inner)

	inner.add_child(_make_section_header("GAME RULES"))
	inner.add_child(_make_spacer(4))
	_home_roster.clear()
	for i in range(15):
		_home_roster.append(i)
	inner.add_child(_build_roster_section())
	inner.add_child(_make_spacer(8))

	for rule_data: Array in RULES:
		inner.add_child(_make_rule_section(rule_data[0], rule_data[1], rule_data[2]))

	inner.add_child(_build_classes_section())
	inner.add_child(_make_spacer(24))

# ─────────────────────────────────────────────────────────────────────────────
# State setters — update button visuals after state change
# ─────────────────────────────────────────────────────────────────────────────
func _set_match_mode(mode: int) -> void:
	_match_mode = mode
	for i in _mode_btns.size():
		_update_speed_btn(_mode_btns[i], _match_mode == i)

func _set_fast_mode(fast: bool) -> void:
	_fast_mode = fast
	_update_speed_btn(_dur_btns[0], !_fast_mode)
	_update_speed_btn(_dur_btns[1],  _fast_mode)

func _set_creature(idx: int) -> void:
	_creature = idx
	for i in _crea_btns.size():
		_update_choice_radio(_crea_btns[i], _creature == i)

func _set_home_strat(idx: int) -> void:
	_home_strat = idx
	for i in _hs_radios.size():
		_update_choice_radio(_hs_radios[i], _home_strat == i)

func _set_home_tact(idx: int) -> void:
	_home_tact = idx
	for i in _ht_radios.size():
		_update_choice_radio(_ht_radios[i], _home_tact == i)

func _set_opp_strat(idx: int) -> void:
	_opp_strat = idx
	for i in _os_radios.size():
		_update_choice_radio(_os_radios[i], _opp_strat == i)

func _set_opp_tact(idx: int) -> void:
	_opp_tact = idx
	for i in _ot_radios.size():
		_update_choice_radio(_ot_radios[i], _opp_tact == i)

# ─────────────────────────────────────────────────────────────────────────────
# Start match
# ─────────────────────────────────────────────────────────────────────────────
func _on_start_pressed() -> void:
	var cfg := _MatchConfig.new()
	cfg.match_mode   = _match_mode
	cfg.fast_mode    = _fast_mode
	cfg.creature_type = _creature
	cfg.home_team_name = "HOME"
	cfg.away_team_name = "AWAY"
	cfg.third_team_name = "THIRD"
	cfg.is_human_controlled = [true, false, false]
	cfg.inactive_class_indices = PackedInt32Array(_inactive_classes)
	emit_signal("match_ready", cfg)

# ─────────────────────────────────────────────────────────────────────────────
# Widget factories
# ─────────────────────────────────────────────────────────────────────────────
func _make_section_header(text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var bar := ColorRect.new()
	bar.color = C_GOLD
	bar.custom_minimum_size = Vector2(3, 18)
	row.add_child(bar)

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", C_GOLD)
	row.add_child(lbl)

	return row

func _make_field_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", C_DIM)
	return lbl

func _make_hint(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl

func _make_card() -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_SURF
	sb.border_color = C_BORDER
	sb.border_width_left   = 1
	sb.border_width_right  = 1
	sb.border_width_top    = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left     = 6
	sb.corner_radius_top_right    = 6
	sb.corner_radius_bottom_left  = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left   = 16
	sb.content_margin_right  = 16
	sb.content_margin_top    = 16
	sb.content_margin_bottom = 16
	p.add_theme_stylebox_override("panel", sb)
	return p

func _make_speed_btn(label: String, sublabel: String, selected: bool) -> Button:
	var btn := Button.new()
	btn.set_meta("label",    label)
	btn.set_meta("sublabel", sublabel)
	btn.toggle_mode = false
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, 52)

	var inner := VBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 2)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var lbl := Label.new()
	lbl.text = label
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(lbl)

	var sub := Label.new()
	sub.text = sublabel
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 8)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(sub)

	btn.add_child(inner)

	_apply_speed_btn_style(btn, selected)
	return btn

func _apply_speed_btn_style(btn: Button, selected: bool) -> void:
	var lbl : Label = btn.get_child(0).get_child(0)
	var sub : Label = btn.get_child(0).get_child(1)

	lbl.add_theme_color_override("font_color", C_GOLD if selected else Color(1,1,1,0.6))
	sub.add_theme_color_override("font_color", Color(1,1,1,0.35))

	var sb := StyleBoxFlat.new()
	sb.bg_color     = Color(0.102, 0.102, 0.180) if selected else Color.TRANSPARENT
	sb.border_color = C_GOLD if selected else Color(0.2, 0.2, 0.333)
	sb.border_width_left   = 2 if selected else 1
	sb.border_width_right  = 2 if selected else 1
	sb.border_width_top    = 2 if selected else 1
	sb.border_width_bottom = 2 if selected else 1
	sb.corner_radius_top_left     = 4
	sb.corner_radius_top_right    = 4
	sb.corner_radius_bottom_left  = 4
	sb.corner_radius_bottom_right = 4
	sb.content_margin_left   = 8
	sb.content_margin_right  = 8
	sb.content_margin_top    = 4
	sb.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal",  sb)
	btn.add_theme_stylebox_override("hover",   sb)
	btn.add_theme_stylebox_override("pressed", sb)

func _update_speed_btn(btn: Button, selected: bool) -> void:
	_apply_speed_btn_style(btn, selected)

func _make_choice_radio(emoji: String, label: String, desc: String, selected: bool) -> Button:
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.toggle_mode = false
	btn.focus_mode = Control.FOCUS_NONE

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var em := Label.new()
	em.text = emoji
	em.add_theme_font_size_override("font_size", 16)
	em.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	em.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(em)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 2)
	text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_col)

	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_col.add_child(lbl)

	var dlbl := Label.new()
	dlbl.text = desc
	dlbl.add_theme_font_size_override("font_size", 9)
	dlbl.add_theme_color_override("font_color", Color(1,1,1,0.38))
	dlbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dlbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_col.add_child(dlbl)

	btn.add_child(row)
	_apply_choice_radio_style(btn, lbl, selected)
	return btn

func _apply_choice_radio_style(btn: Button, lbl: Label, selected: bool) -> void:
	lbl.add_theme_color_override("font_color", C_GOLD if selected else Color(1,1,1,0.75))

	var sb := StyleBoxFlat.new()
	sb.bg_color     = Color(0.102, 0.102, 0.180) if selected else Color.TRANSPARENT
	sb.border_color = C_GOLD if selected else Color(0.2, 0.2, 0.333)
	sb.border_width_left   = 2 if selected else 1
	sb.border_width_right  = 2 if selected else 1
	sb.border_width_top    = 2 if selected else 1
	sb.border_width_bottom = 2 if selected else 1
	sb.corner_radius_top_left     = 4
	sb.corner_radius_top_right    = 4
	sb.corner_radius_bottom_left  = 4
	sb.corner_radius_bottom_right = 4
	sb.content_margin_left   = 12
	sb.content_margin_right  = 12
	sb.content_margin_top    = 8
	sb.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal",  sb)
	btn.add_theme_stylebox_override("hover",   sb)
	btn.add_theme_stylebox_override("pressed", sb)

func _update_choice_radio(btn: Button, selected: bool) -> void:
	var lbl : Label = btn.get_child(0).get_child(1).get_child(0)
	_apply_choice_radio_style(btn, lbl, selected)

func _make_control_row(key: String, desc: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(80, 0)
	var badge_sb := StyleBoxFlat.new()
	badge_sb.bg_color = C_KEY_BG
	badge_sb.border_color = C_KEY_BD
	badge_sb.border_width_left   = 1
	badge_sb.border_width_right  = 1
	badge_sb.border_width_top    = 1
	badge_sb.border_width_bottom = 1
	badge_sb.corner_radius_top_left     = 3
	badge_sb.corner_radius_top_right    = 3
	badge_sb.corner_radius_bottom_left  = 3
	badge_sb.corner_radius_bottom_right = 3
	badge_sb.content_margin_left   = 6
	badge_sb.content_margin_right  = 6
	badge_sb.content_margin_top    = 3
	badge_sb.content_margin_bottom = 3
	badge.add_theme_stylebox_override("panel", badge_sb)

	var key_lbl := Label.new()
	key_lbl.text = key
	key_lbl.add_theme_font_size_override("font_size", 11)
	key_lbl.add_theme_color_override("font_color", C_KEY_TX)
	key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(key_lbl)
	row.add_child(badge)

	var desc_lbl := Label.new()
	desc_lbl.text = desc
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", C_DESC)
	desc_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(desc_lbl)

	return row

func _make_rule_section(icon: String, title: String, rules) -> Control:
	var card := _make_card()
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	card.add_child(vbox)

	# Clickable header row
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 10)
	header_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.mouse_filter = Control.MOUSE_FILTER_STOP
	vbox.add_child(header_row)

	var icon_lbl := Label.new()
	icon_lbl.text = icon
	icon_lbl.add_theme_font_size_override("font_size", 18)
	icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_row.add_child(icon_lbl)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_row.add_child(title_lbl)

	var arrow := Label.new()
	arrow.text = "▶"
	arrow.add_theme_font_size_override("font_size", 10)
	arrow.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_row.add_child(arrow)

	# Collapsible rules list — hidden by default
	var rules_container := MarginContainer.new()
	rules_container.add_theme_constant_override("margin_top", 10)
	rules_container.visible = false
	vbox.add_child(rules_container)

	var rules_vbox := VBoxContainer.new()
	rules_vbox.add_theme_constant_override("separation", 5)
	rules_container.add_child(rules_vbox)

	for rule_text in rules:
		var rule_row := HBoxContainer.new()
		rule_row.add_theme_constant_override("separation", 8)

		var dot := ColorRect.new()
		dot.color = C_GOLD
		dot.custom_minimum_size = Vector2(4, 4)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rule_row.add_child(dot)

		var rule_lbl := Label.new()
		rule_lbl.text = rule_text
		rule_lbl.add_theme_font_size_override("font_size", 12)
		rule_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
		rule_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rule_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rule_row.add_child(rule_lbl)

		rules_vbox.add_child(rule_row)

	header_row.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			rules_container.visible = !rules_container.visible
			arrow.text = "▼" if rules_container.visible else "▶"
	)

	return card

func _make_divider() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.102, 0.102, 0.2)
	r.custom_minimum_size = Vector2(0, 1)
	return r

func _make_spacer(h: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	return s

# ─────────────────────────────────────────────────────────────────────────────
# Roster section
# ─────────────────────────────────────────────────────────────────────────────
func _build_roster_section() -> Control:
	var card := _make_card()
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	card.add_child(outer)

	# ── Clickable header row ──────────────────────────────────────────────────
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 10)
	hrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hrow.mouse_filter = Control.MOUSE_FILTER_STOP
	outer.add_child(hrow)

	var icon_lbl := Label.new()
	icon_lbl.text = "👥"
	icon_lbl.add_theme_font_size_override("font_size", 18)
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hrow.add_child(icon_lbl)

	var title_col := VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_col.add_theme_constant_override("separation", 2)
	title_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hrow.add_child(title_col)

	var title_lbl := Label.new()
	title_lbl.text = "TEAM ROSTERS"
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_col.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "Drag home rows to set lineup order"
	sub_lbl.add_theme_font_size_override("font_size", 8)
	sub_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.3))
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_col.add_child(sub_lbl)

	_roster_toggle_btn = Button.new()
	_roster_toggle_btn.text = "▶"
	_roster_toggle_btn.flat = true
	_roster_toggle_btn.focus_mode = Control.FOCUS_NONE
	_roster_toggle_btn.add_theme_color_override("font_color", C_GOLD)
	_roster_toggle_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hrow.add_child(_roster_toggle_btn)

	# ── Expandable content ────────────────────────────────────────────────────
	_roster_content = VBoxContainer.new()
	_roster_content.add_theme_constant_override("separation", 6)
	_roster_content.visible = false
	outer.add_child(_roster_content)

	_roster_content.add_child(_make_spacer(10))

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	_roster_content.add_child(cols)

	# Home column
	var home_col := VBoxContainer.new()
	home_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	home_col.add_theme_constant_override("separation", 4)
	cols.add_child(home_col)

	var home_hdr := Label.new()
	home_hdr.text = "HOME — DRAG TO REORDER"
	home_hdr.add_theme_font_size_override("font_size", 8)
	home_hdr.add_theme_color_override("font_color", Color(0.267, 1.0, 0.533, 0.7))
	home_col.add_child(home_hdr)

	_home_roster_vbox = VBoxContainer.new()
	_home_roster_vbox.add_theme_constant_override("separation", 2)
	home_col.add_child(_home_roster_vbox)
	_rebuild_home_roster()

	# Away column
	var away_col := VBoxContainer.new()
	away_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	away_col.add_theme_constant_override("separation", 4)
	cols.add_child(away_col)

	var away_hdr := Label.new()
	away_hdr.text = "AWAY — AI CONTROLLED"
	away_hdr.add_theme_font_size_override("font_size", 8)
	away_hdr.add_theme_color_override("font_color", Color(1, 1, 1, 0.3))
	away_col.add_child(away_hdr)

	var away_rows := VBoxContainer.new()
	away_rows.add_theme_constant_override("separation", 2)
	away_col.add_child(away_rows)
	for slot in range(15):
		if slot == 7:
			away_rows.add_child(_make_roster_divider())
		away_rows.add_child(_make_roster_row(slot, slot, false))

	hrow.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_toggle_roster()
	)
	return card


func _toggle_roster() -> void:
	_roster_expanded = !_roster_expanded
	_roster_content.visible = _roster_expanded
	_roster_toggle_btn.text = "▼" if _roster_expanded else "▶"


func _rebuild_home_roster() -> void:
	for child in _home_roster_vbox.get_children():
		_home_roster_vbox.remove_child(child)
		child.queue_free()
	_drag_slot_panels.clear()
	for slot in range(15):
		if slot == 7:
			_home_roster_vbox.add_child(_make_roster_divider())
		var panel := _make_roster_row(slot, _home_roster[slot], true)
		_home_roster_vbox.add_child(panel)
		_drag_slot_panels.append(panel)


func _make_roster_divider() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var left := ColorRect.new()
	left.color = Color(0.2, 0.267, 0.4)
	left.custom_minimum_size = Vector2(0, 1)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	row.add_child(left)

	var lbl := Label.new()
	lbl.text = "RESERVE"
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.3))
	row.add_child(lbl)

	var right := ColorRect.new()
	right.color = Color(0.2, 0.267, 0.4)
	right.custom_minimum_size = Vector2(0, 1)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	row.add_child(right)

	return row


func _make_roster_row(slot_idx: int, player_idx: int, clickable: bool) -> Control:
	var class_idx  : int    = player_idx % 8
	var cls_color  : Color  = CLASS_COLORS[class_idx]
	var cls_name   : String = CLASS_NAMES[class_idx]
	var is_field   : bool   = slot_idx < 7
	var slot_label : String = ("FIELD " + str(slot_idx + 1)) if is_field else ("RES " + str(slot_idx - 6))
	var slot_color : Color  = Color(0.267, 1.0, 0.533) if is_field else Color(1, 1, 1, 0.3)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	if is_field:
		sb.bg_color     = Color(0.039, 0.078, 0.039)
		sb.border_color = Color(0.267, 1.0, 0.533, 0.2)
	else:
		sb.bg_color     = Color(0.039, 0.039, 0.071)
		sb.border_color = Color(0.102, 0.102, 0.180)
	sb.border_width_left   = 1
	sb.border_width_right  = 1
	sb.border_width_top    = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left     = 4
	sb.corner_radius_top_right    = 4
	sb.corner_radius_bottom_left  = 4
	sb.corner_radius_bottom_right = 4
	sb.content_margin_left   = 4
	sb.content_margin_right  = 6
	sb.content_margin_top    = 4
	sb.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", sb)
	if clickable:
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.mouse_default_cursor_shape = Control.CURSOR_DRAG

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)

	var slot_lbl := Label.new()
	slot_lbl.text = slot_label
	slot_lbl.custom_minimum_size = Vector2(52, 0)
	slot_lbl.add_theme_font_size_override("font_size", 9)
	slot_lbl.add_theme_color_override("font_color", slot_color)
	slot_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(slot_lbl)

	var swatch := PanelContainer.new()
	swatch.custom_minimum_size = Vector2(22, 22)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sw_sb := StyleBoxFlat.new()
	sw_sb.bg_color     = Color(cls_color.r, cls_color.g, cls_color.b, 0.15)
	sw_sb.border_color = Color(cls_color.r, cls_color.g, cls_color.b, 0.35)
	sw_sb.border_width_left   = 1
	sw_sb.border_width_right  = 1
	sw_sb.border_width_top    = 1
	sw_sb.border_width_bottom = 1
	sw_sb.corner_radius_top_left     = 4
	sw_sb.corner_radius_top_right    = 4
	sw_sb.corner_radius_bottom_left  = 4
	sw_sb.corner_radius_bottom_right = 4
	swatch.add_theme_stylebox_override("panel", sw_sb)
	var sw_lbl := Label.new()
	sw_lbl.text = cls_name[0]
	sw_lbl.add_theme_font_size_override("font_size", 10)
	sw_lbl.add_theme_color_override("font_color", cls_color)
	sw_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sw_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swatch.add_child(sw_lbl)
	row.add_child(swatch)

	var name_lbl := Label.new()
	name_lbl.text = cls_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Color(1,1,1,0.9) if is_field else Color(1,1,1,0.45))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_lbl)

	if clickable:
		var drag_dots := Label.new()
		drag_dots.text = "⠿"
		drag_dots.add_theme_font_size_override("font_size", 14)
		drag_dots.add_theme_color_override("font_color", Color(1, 1, 1, 0.18))
		drag_dots.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		drag_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(drag_dots)

		panel.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_begin_drag(slot_idx)
		)

	return panel


func _begin_drag(slot_idx: int) -> void:
	if _dragging:
		return
	_dragging = true
	_drag_from_slot = slot_idx

	var player_idx : int    = _home_roster[slot_idx]
	var class_idx  : int    = player_idx % 8
	var cls_color  : Color  = CLASS_COLORS[class_idx]
	var cls_name   : String = CLASS_NAMES[class_idx]
	var is_field   : bool   = slot_idx < 7
	var slot_label : String = ("FIELD " + str(slot_idx + 1)) if is_field else ("RES " + str(slot_idx - 6))

	_drag_ghost = PanelContainer.new()
	_drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_ghost.z_index = 100
	var ghost_sb := StyleBoxFlat.new()
	ghost_sb.bg_color     = Color(cls_color.r, cls_color.g, cls_color.b, 0.25)
	ghost_sb.border_color = C_GOLD
	ghost_sb.border_width_left   = 2
	ghost_sb.border_width_right  = 2
	ghost_sb.border_width_top    = 2
	ghost_sb.border_width_bottom = 2
	ghost_sb.corner_radius_top_left     = 4
	ghost_sb.corner_radius_top_right    = 4
	ghost_sb.corner_radius_bottom_left  = 4
	ghost_sb.corner_radius_bottom_right = 4
	ghost_sb.content_margin_left   = 10
	ghost_sb.content_margin_right  = 10
	ghost_sb.content_margin_top    = 6
	ghost_sb.content_margin_bottom = 6
	_drag_ghost.add_theme_stylebox_override("panel", ghost_sb)

	var ghost_row := HBoxContainer.new()
	ghost_row.add_theme_constant_override("separation", 8)
	ghost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_ghost.add_child(ghost_row)

	var ghost_slot := Label.new()
	ghost_slot.text = slot_label
	ghost_slot.add_theme_font_size_override("font_size", 9)
	ghost_slot.add_theme_color_override("font_color", C_GOLD)
	ghost_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost_row.add_child(ghost_slot)

	var ghost_name := Label.new()
	ghost_name.text = cls_name
	ghost_name.add_theme_font_size_override("font_size", 13)
	ghost_name.add_theme_color_override("font_color", cls_color)
	ghost_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost_row.add_child(ghost_name)

	add_child(_drag_ghost)
	# Position will be corrected in _process; set an initial pos near cursor
	var mouse_pos := get_viewport().get_mouse_position()
	_drag_ghost.position = mouse_pos - Vector2(60, 15)


func _process(_delta: float) -> void:
	if not _dragging or not is_instance_valid(_drag_ghost):
		return
	var mouse_pos := get_viewport().get_mouse_position()
	_drag_ghost.position = mouse_pos - _drag_ghost.size * 0.5


func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_end_drag()
		get_viewport().set_input_as_handled()


func _end_drag() -> void:
	_dragging = false
	var mouse_pos := get_viewport().get_mouse_position()
	var target_slot := -1
	for i in range(_drag_slot_panels.size()):
		if is_instance_valid(_drag_slot_panels[i]):
			if _drag_slot_panels[i].get_global_rect().has_point(mouse_pos):
				target_slot = i
				break
	if target_slot != -1 and target_slot != _drag_from_slot:
		var temp: int = _home_roster[_drag_from_slot]
		_home_roster[_drag_from_slot] = _home_roster[target_slot]
		_home_roster[target_slot] = temp
	if is_instance_valid(_drag_ghost):
		_drag_ghost.queue_free()
		_drag_ghost = null
	_drag_from_slot = -1
	_rebuild_home_roster()

# ─────────────────────────────────────────────────────────────────────────────
# Classes section
# ─────────────────────────────────────────────────────────────────────────────
func _build_classes_section() -> Control:
	var card := _make_card()
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	card.add_child(outer)

	# Clickable header
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 10)
	hrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hrow.mouse_filter = Control.MOUSE_FILTER_STOP
	outer.add_child(hrow)

	var icon_lbl := Label.new()
	icon_lbl.text = "🧬"
	icon_lbl.add_theme_font_size_override("font_size", 18)
	icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hrow.add_child(icon_lbl)

	var title_lbl := Label.new()
	title_lbl.text = "CLASSES"
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hrow.add_child(title_lbl)

	var arrow := Label.new()
	arrow.text = "▶"
	arrow.add_theme_font_size_override("font_size", 10)
	arrow.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hrow.add_child(arrow)

	# Collapsible content
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	content.visible = false
	outer.add_child(content)

	content.add_child(_make_spacer(8))

	_class_btns.clear()
	_class_btns.resize(CLASS_NAMES.size())
	for i in range(CLASS_NAMES.size()):
		content.add_child(_make_class_card(i))

	hrow.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			content.visible = !content.visible
			arrow.text = "▼" if content.visible else "▶"
	)

	return card


func _make_class_card(class_idx: int) -> Control:
	var inactive  : bool   = _inactive_classes.has(class_idx)
	var cls_color : Color  = CLASS_COLORS[class_idx]
	var cls_name  : String = CLASS_NAMES[class_idx]
	var cls_desc  : String = CLASS_DESCS[class_idx]

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color     = Color(0.12, 0.0, 0.0, 0.6) if inactive else Color(0, 0, 0, 0.4)
	sb.border_color = Color(0.6, 0.267, 0.267, 0.5) if inactive else Color(cls_color.r, cls_color.g, cls_color.b, 0.4)
	sb.border_width_left   = 1
	sb.border_width_right  = 1
	sb.border_width_top    = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left     = 6
	sb.corner_radius_top_right    = 6
	sb.corner_radius_bottom_left  = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left   = 10
	sb.content_margin_right  = 10
	sb.content_margin_top    = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	# Left accent bar in class color
	var bar := ColorRect.new()
	bar.color = Color(cls_color.r, cls_color.g, cls_color.b, 0.8 if not inactive else 0.2)
	bar.custom_minimum_size = Vector2(4, 20)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 2)
	row.add_child(text_col)

	var name_lbl := Label.new()
	name_lbl.text = cls_name
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color",
		Color(cls_color.r, cls_color.g, cls_color.b, 0.35) if inactive else cls_color)
	text_col.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = cls_desc
	desc_lbl.add_theme_font_size_override("font_size", 9)
	desc_lbl.add_theme_color_override("font_color",
		Color(1, 1, 1, 0.2) if inactive else Color(1, 1, 1, 0.45))
	text_col.add_child(desc_lbl)

	# Active/Inactive toggle button
	var toggle := Button.new()
	toggle.text = "INACTIVE" if inactive else "ACTIVE"
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.add_theme_font_size_override("font_size", 8)
	toggle.add_theme_color_override("font_color",
		Color(1.0, 0.4, 0.4) if inactive else Color(1, 1, 1, 0.4))
	var t_sb := StyleBoxFlat.new()
	t_sb.bg_color     = Color(0.6, 0.267, 0.267, 0.25) if inactive else Color.TRANSPARENT
	t_sb.border_color = Color(0.6, 0.267, 0.267, 0.7)  if inactive else Color(1, 1, 1, 0.2)
	t_sb.border_width_left   = 1
	t_sb.border_width_right  = 1
	t_sb.border_width_top    = 1
	t_sb.border_width_bottom = 1
	t_sb.corner_radius_top_left     = 4
	t_sb.corner_radius_top_right    = 4
	t_sb.corner_radius_bottom_left  = 4
	t_sb.corner_radius_bottom_right = 4
	t_sb.content_margin_left   = 8
	t_sb.content_margin_right  = 8
	t_sb.content_margin_top    = 4
	t_sb.content_margin_bottom = 4
	toggle.add_theme_stylebox_override("normal",  t_sb)
	toggle.add_theme_stylebox_override("hover",   t_sb)
	toggle.add_theme_stylebox_override("pressed", t_sb)
	toggle.pressed.connect(_toggle_class.bind(class_idx))
	_class_btns[class_idx] = toggle
	row.add_child(toggle)

	return panel


func _toggle_class(class_idx: int) -> void:
	if _inactive_classes.has(class_idx):
		_inactive_classes.erase(class_idx)
	else:
		_inactive_classes.append(class_idx)
	# Replace only the affected card in-place
	var btn   : Button  = _class_btns[class_idx]
	var card  : Control = btn.get_parent().get_parent()
	var vbox  : Control = card.get_parent()
	var idx   : int     = card.get_index()
	vbox.remove_child(card)
	card.queue_free()
	_class_btns[class_idx] = null   # will be re-set in _make_class_card
	var new_card := _make_class_card(class_idx)
	vbox.add_child(new_card)
	vbox.move_child(new_card, idx)
