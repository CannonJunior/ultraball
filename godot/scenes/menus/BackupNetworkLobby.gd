class_name NetworkLobby
extends Control

signal match_ready(config: MatchConfig)

# ── AI script preloads ────────────────────────────────────────────────────────

const _SBalanced        := preload("res://systems/ai/strategies/BalancedStrategy.gd")
const _SAggressive      := preload("res://systems/ai/strategies/AggressiveStrategy.gd")
const _SNumericalEdge   := preload("res://systems/ai/strategies/NumericalEdgeStrategy.gd")
const _SFloodEndzone    := preload("res://systems/ai/strategies/FloodEndzoneStrategy.gd")
const _SPossessionBleed := preload("res://systems/ai/strategies/PossessionBleedStrategy.gd")

const _TBalanced        := preload("res://systems/ai/tactics/BalancedTactics.gd")
const _TFocusFire       := preload("res://systems/ai/tactics/FocusFireTactics.gd")
const _TPickScreen      := preload("res://systems/ai/tactics/PickAndScreenTactics.gd")
const _TQuickRelease    := preload("res://systems/ai/tactics/QuickReleaseTactics.gd")
const _TCreatureFlank   := preload("res://systems/ai/tactics/CreatureFlankTactics.gd")
const _TWedgeRun        := preload("res://systems/ai/tactics/WedgeRunTactics.gd")
const _THeroBall        := preload("res://systems/ai/tactics/HeroBallTactics.gd")

# ── Static data ───────────────────────────────────────────────────────────────

# [emoji, label, description]
const STRATEGY_DATA: Array = [
	["⚖", "BALANCED",       "Adapt to the situation; solid all-around play"],
	["💣", "TEMPO TRAP",     "Deny phase lines; force opponent to hold the ball until it explodes"],
	["🔢", "NUMBERS GAME",   "Eliminate 2–3 opponents early; exploit the numbers edge to score freely"],
	["🌊", "FLOOD THE ZONE", "Flood 3–4 players into/near the endzone; defense can't cover everyone"],
	["🩸", "BLEED OUT",      "Never surrender the ball; drain the clock; only score when completely safe"],
]

const TACTICS_DATA: Array = [
	["⚖", "BALANCED",       "Solid all-around tactics; advance, pass, and defend situationally"],
	["🎯", "FOCUS FIRE",     "All attackers lock onto one target at once; eliminate before moving on"],
	["🏀", "PICK & SCREEN",  "Two players set hard screens; others sprint decoy routes to the endzone"],
	["⚡", "QUICK RELEASE",  "Pass at the first open window; chain passes; never hold the ball long"],
	["👹", "CREATURE FLANK", "Position opposite the creature from the carrier; herd the opponent into it"],
	["🔺", "WEDGE RUN",      "Three players form a tight triangle around the carrier; move as one unit"],
	["⭐", "HERO BALL",      "All units rally around the star player; immediately pass the ball to them"],
]

# [emoji, name, description]
const CREATURE_DATA: Array = [
	["🐙", "KRAKEN",         "Slow & deadly"],
	["🐉", "DRAGON",         "Fast & fierce"],
	["🐍", "HYDRA",          "Large & relentless"],
	["👻", "WRAITH",          "Blindingly fast & ethereal"],
	["⚡", "CHAOS MONSTER",   "Unpredictable & terrifying"],
]

# [name, creature_idx, primary_hex, secondary_hex, player_names[15]]
const TEAM_DEFS: Array = [
	["VIPERS",  0, "00C853", "F9A825",
	 ["Fang","Venom","Cobra","Asp","Adder","Mamba","Python","Anaconda","Boa","Taipan","Scales","Coil","Rattle","Hiss","Pit"]],
	["REAPERS", 1, "AA00FF", "FFD700",
	 ["Scythe","Grim","Shade","Mort","Dusk","Reap","Doom","Skull","Gore","Bone","Crypt","Void","Hex","Ash","Blood"]],
	["TITANS",  2, "FF6D00", "37474F",
	 ["Steel","Forge","Anvil","Iron","Alloy","Boulder","Granite","Basalt","Stone","Flint","Golem","Colossus","Rampart","Bulwark","Aegis"]],
	["GHOSTS",  3, "18FFFF", "4527A0",
	 ["Wraith","Specter","Phantom","Spirit","Wisp","Haunt","Drift","Echo","Mirage","Gloom","Veil","Shroud","Mist","Vapor","Ether"]],
	["INFERNO", 0, "FF1744", "FF6D00",
	 ["Blaze","Cinder","Ember","Flare","Forge","Char","Scorch","Kindle","Brand","Pyre","Smelt","Torch","Flame","Fuse","Burn"]],
	["STORM",   3, "FFD600", "1565C0",
	 ["Gale","Bolt","Thunder","Flash","Surge","Squall","Gust","Cyclone","Torrent","Nimbus","Tempest","Zephyr","Hail","Sleet","Frost"]],
]

const RULES_DATA: Array = [
	["🏟", "THE FIELD", [
		"Total field: 140m × 40m",
		"Left & Right endzones: 20m deep — score here!",
		"Creature channel: 10m each side, patrolled at all times",
		"Main field: 80m with 5 PHASE LINES at 20m intervals",
		"Phase lines reset ball charge when crossed",
	]],
	["🏆", "SCORING", [
		"ULTRA (7 pts) — Ball carrier runs into enemy endzone",
		"META (3 pts) — Pass caught by player already in endzone",
		"KILLA (1 pt) — Opposing player dies (combat/creature/explosion)",
	]],
	["⚡", "THE ULTRABALL", [
		"Holding the ball builds CHARGE — explodes after 7 seconds!",
		"Explosion kills holder, stuns teammates 1 second",
		"Passing resets charge: +1 second per meter thrown",
		"Crossing a PHASE LINE fully resets charge to 0",
		"Phase lines deactivate when crossed (reset on possession change)",
		"Failed pass: entire passing team stunned 1 second",
	]],
	["👹", "THE CREATURE", [
		"Circles the field counter-clockwise at moderate speed",
		"Instantly kills any player it touches — both teams!",
		"Awards 1 KILLA point to the opposite team on each kill",
	]],
	["⚔", "COMBAT", [
		"RED MANA: 0–100, gained by dealing damage, decays after 3s",
		"BLUE MANA: 0–100, auto-regens passively",
		"YELLOW MANA: 0–100, builds while your team holds the ball",
		"ULTRA MANA: charges from all combat actions — your ultimate!",
	]],
	["👥", "TEAMS", [
		"7 players per team on field, 15-player roster total",
		"Deaths are PERMANENT within a match",
		"1 substitution allowed per act when a player dies",
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

# ── Palette ───────────────────────────────────────────────────────────────────

const C_BG     := Color(0.016, 0.020, 0.039)
const C_SURF   := Color(0.031, 0.031, 0.059)
const C_GOLD   := Color(1.000, 0.796, 0.239)
const C_BORDER := Color(0.102, 0.102, 0.180)

# ── State ─────────────────────────────────────────────────────────────────────

var _home_team_idx:     int  = 0
var _away_team_idx:     int  = 1
var _third_team_idx:    int  = 2
var _is_three_team:     bool = false
var _is_neutral_site:   bool = false
var _neutral_creature:  int  = 4   # Chaos default
var _fast_mode:         bool = false
var _home_strat_idx:    int  = 1   # Tempo Trap
var _home_tact_idx:     int  = 6   # Hero Ball
var _opp_strat_idx:     int  = 0   # Balanced
var _opp_tact_idx:      int  = 1   # Focus Fire

# ── Widget refs ───────────────────────────────────────────────────────────────

var _status_lbl:        Label
var _start_online_btn:  Button
var _ip_input:          LineEdit
var _mode_2t:           Button
var _mode_3t:           Button
var _fast_off:          Button
var _fast_on:           Button
var _home_opt:          OptionButton
var _away_opt:          OptionButton
var _third_opt:         OptionButton
var _third_row:         Control
var _neutral_btn:       Button
var _creature_fixed:    Control
var _creature_opt_row:  Control
var _creature_opt:      OptionButton
var _creature_emoji:    Label
var _creature_name:     Label
var _creature_desc:     Label
# Radio panels stored as [PanelContainer, StyleBoxFlat] pairs
var _home_strat_items:  Array = []
var _home_tact_items:   Array = []
var _opp_strat_items:   Array = []
var _opp_tact_items:    Array = []

# ── Layout constants ──────────────────────────────────────────────────────────

const HEADER_H := 300
const BAR_H    := 224

# ── Build ─────────────────────────────────────────────────────────────────────

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	EventBus.peer_connected.connect(_on_peer_connected)
	EventBus.lobby_created.connect(func(_id: int): pass)
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Header — fixed pixel height at top
	var header := _build_header()
	add_child(header)
	header.anchor_left   = 0.0; header.anchor_right  = 1.0
	header.anchor_top    = 0.0; header.anchor_bottom = 0.0
	header.offset_left   = 0;   header.offset_right  = 0
	header.offset_top    = 0;   header.offset_bottom = HEADER_H

	# Network bar — fixed pixel height below header
	var bar := _build_network_bar()
	add_child(bar)
	bar.anchor_left   = 0.0; bar.anchor_right  = 1.0
	bar.anchor_top    = 0.0; bar.anchor_bottom = 0.0
	bar.offset_left   = 0;   bar.offset_right  = 0
	bar.offset_top    = HEADER_H; bar.offset_bottom = HEADER_H + BAR_H

	# Two-column layout anchored below the bar — each column gets its own
	# ScrollContainer so minimum-size propagation is direct: VBoxContainer →
	# ScrollContainer, with no HBoxContainer wrapper breaking the chain.
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 0)
	add_child(columns)
	columns.anchor_left   = 0.0; columns.anchor_right  = 1.0
	columns.anchor_top    = 0.0; columns.anchor_bottom = 1.0
	columns.offset_left   = 0;   columns.offset_right  = 0
	columns.offset_top    = HEADER_H + BAR_H; columns.offset_bottom = 0

	# Left column: settings — VBoxContainer is the DIRECT child of ScrollContainer.
	# No MarginContainer wrapper; padding is handled by the VBoxContainer's own constants.
	var left_scroll := ScrollContainer.new()
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_scroll.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_vertical    = Control.SIZE_EXPAND_FILL
	columns.add_child(left_scroll)

	left_scroll.add_theme_constant_override("margin_left",   24)
	left_scroll.add_theme_constant_override("margin_right",  12)
	left_scroll.add_theme_constant_override("margin_top",    16)
	left_scroll.add_theme_constant_override("margin_bottom", 24)

	var settings_vbox := VBoxContainer.new()
	settings_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_vbox.add_theme_constant_override("separation", 12)
	left_scroll.add_child(settings_vbox)
	_populate_settings(settings_vbox)

	# Divider
	var div := ColorRect.new()
	div.color = C_BORDER
	div.custom_minimum_size.x = 1
	div.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_child(div)

	# Right column: rules — same direct pattern.
	var right_scroll := ScrollContainer.new()
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_scroll.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical    = Control.SIZE_EXPAND_FILL
	columns.add_child(right_scroll)

	right_scroll.add_theme_constant_override("margin_left",   12)
	right_scroll.add_theme_constant_override("margin_right",  24)
	right_scroll.add_theme_constant_override("margin_top",    16)
	right_scroll.add_theme_constant_override("margin_bottom", 24)

	var rules_vbox := VBoxContainer.new()
	rules_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rules_vbox.add_theme_constant_override("separation", 12)
	right_scroll.add_child(rules_vbox)
	_populate_rules(rules_vbox)

func _build_header() -> Control:
	var margin := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 24 if s == "top" else 32)
	margin.add_theme_constant_override("margin_bottom", 16)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "ULTRABALL-X"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", C_GOLD)
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "A COMPETITIVE RAPID CHAOTIC SPORTS COMBAT GAME"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 10)
	sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	vbox.add_child(sub)

	return margin

func _build_network_bar() -> Control:
	var bar := PanelContainer.new()
	var sbox := StyleBoxFlat.new()
	sbox.bg_color = C_SURF
	sbox.border_color = C_BORDER
	sbox.border_width_bottom = 1
	bar.add_theme_stylebox_override("panel", sbox)

	var margin := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 10)
	bar.add_child(margin)

	var vstack := VBoxContainer.new()
	vstack.add_theme_constant_override("separation", 6)
	margin.add_child(vstack)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 8)
	vstack.add_child(hbox)

	var host_btn := _small_btn("Host Game")  # bar h=84 (BAR_H) w=full screen (anchor 0.0→1.0)
	host_btn.pressed.connect(_on_host_pressed)
	hbox.add_child(host_btn)

	_ip_input = LineEdit.new()
	_ip_input.placeholder_text = "Host IP (127.0.0.1)"
	_ip_input.custom_minimum_size.x = 160
	hbox.add_child(_ip_input)

	var join_btn := _small_btn("Join")
	join_btn.pressed.connect(_on_join_pressed)
	hbox.add_child(join_btn)

	var sep := VSeparator.new()
	hbox.add_child(sep)

	_start_online_btn = _small_btn("Start Match (online)")
	_start_online_btn.visible = false
	_start_online_btn.pressed.connect(_on_start_pressed)
	hbox.add_child(_start_online_btn)

	_status_lbl = Label.new()
	_status_lbl.text = "Play offline vs AI — or host/join for multiplayer"
	_status_lbl.add_theme_font_size_override("font_size", 11)
	_status_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	hbox.add_child(_status_lbl)

	var hints_row := HBoxContainer.new()
	hints_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hints_row.add_theme_constant_override("separation", 20)
	vstack.add_child(hints_row)

	for pair in [["WASD", "Move"], ["F", "Pass"], ["SPACE", "Jump"],
				 ["1", "Tackle"], ["2", "Power Slam"], ["3", "Sprint"], ["TAB", "Target"]]:
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 4)
		hints_row.add_child(chip)

		var key_lbl := Label.new()
		key_lbl.text = pair[0]
		key_lbl.add_theme_font_size_override("font_size", 10)
		key_lbl.add_theme_color_override("font_color", Color(0.8, 0.87, 1.0))
		chip.add_child(key_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = pair[1]
		desc_lbl.add_theme_font_size_override("font_size", 10)
		desc_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.40))
		chip.add_child(desc_lbl)

	return bar

func _populate_settings(vbox: VBoxContainer) -> void:
	vbox.add_child(_section_header("MATCH CONFIGURATION"))
	vbox.add_child(_build_mode_card())
	vbox.add_child(_build_teams_card())

	_third_row = _build_third_team_card()
	_third_row.visible = false
	vbox.add_child(_third_row)

	vbox.add_child(_build_creature_card())
	vbox.add_child(_build_strat_tact_row())
	vbox.add_child(_build_duration_card())

	var start_btn := Button.new()
	start_btn.text = "START MATCH"
	start_btn.custom_minimum_size.y = 56
	start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_btn.add_theme_font_size_override("font_size", 24)
	start_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	var start_sbox := StyleBoxFlat.new()
	start_sbox.bg_color = Color(0.80, 0.53, 0.0)
	start_sbox.corner_radius_top_left = 6; start_sbox.corner_radius_top_right = 6
	start_sbox.corner_radius_bottom_left = 6; start_sbox.corner_radius_bottom_right = 6
	start_btn.add_theme_stylebox_override("normal", start_sbox)
	var start_hover := start_sbox.duplicate() as StyleBoxFlat
	start_hover.bg_color = Color(0.87, 0.13, 0.0)
	start_btn.add_theme_stylebox_override("hover", start_hover)
	start_btn.add_theme_stylebox_override("pressed", start_hover)
	start_btn.pressed.connect(_on_offline_pressed)
	vbox.add_child(start_btn)

func _build_mode_card() -> Control:
	var card := _card()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	card.add_child(vb)

	vb.add_child(_field_label("MATCH MODE"))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vb.add_child(row)

	_mode_2t = _mode_btn("2 TEAMS", "Classic — linear field", true)
	_mode_2t.pressed.connect(func(): _set_mode(false))
	row.add_child(_mode_2t)

	_mode_3t = _mode_btn("3 TEAMS", "Triangle field", false)
	_mode_3t.pressed.connect(func(): _set_mode(true))
	row.add_child(_mode_3t)

	return card

func _build_teams_card() -> Control:
	var card := _card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(row)

	row.add_child(_build_team_selector(0, "HOME TEAM (You)"))
	row.add_child(VSeparator.new())
	row.add_child(_build_team_selector(1, "AWAY TEAM (AI)"))

	return card

func _build_team_selector(slot: int, label_text: String) -> Control:
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 6)

	vb.add_child(_field_label(label_text))

	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for td in TEAM_DEFS:
		var ci: int = td[1]
		var emoji: String = CREATURE_DATA[ci][0]
		opt.add_item("%s %s" % [emoji, td[0]])
	if slot == 0:
		opt.selected = _home_team_idx
		_home_opt = opt
		opt.item_selected.connect(_on_home_team_changed)
	else:
		opt.selected = _away_team_idx
		_away_opt = opt
		opt.item_selected.connect(_on_away_team_changed)

	vb.add_child(opt)
	return vb

func _build_third_team_card() -> Control:
	var card := _card()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	card.add_child(vb)

	vb.add_child(_field_label("THIRD TEAM"))

	_third_opt = OptionButton.new()
	_third_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for td in TEAM_DEFS:
		var ci: int = td[1]
		var emoji: String = CREATURE_DATA[ci][0]
		_third_opt.add_item("%s %s" % [emoji, td[0]])
	_third_opt.selected = _third_team_idx
	_third_opt.item_selected.connect(func(i: int): _third_team_idx = i)
	vb.add_child(_third_opt)

	return card

func _build_creature_card() -> Control:
	var card := _card()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	card.add_child(vb)

	var header_row := HBoxContainer.new()
	vb.add_child(header_row)
	header_row.add_child(_field_label("CREATURE"))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(spacer)

	_neutral_btn = _small_btn("NEUTRAL SITE")
	_neutral_btn.toggle_mode = true
	_neutral_btn.button_pressed = false
	_neutral_btn.toggled.connect(_on_neutral_site_toggled)
	header_row.add_child(_neutral_btn)

	# Fixed creature display (based on home team)
	_creature_fixed = HBoxContainer.new()
	_creature_fixed.add_theme_constant_override("separation", 10)
	vb.add_child(_creature_fixed)

	var cbox := StyleBoxFlat.new()
	cbox.bg_color = C_BORDER
	cbox.corner_radius_top_left = 4; cbox.corner_radius_top_right = 4
	cbox.corner_radius_bottom_left = 4; cbox.corner_radius_bottom_right = 4
	var cpanel := PanelContainer.new()
	cpanel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cpanel.add_theme_stylebox_override("panel", cbox)
	_creature_fixed.add_child(cpanel)

	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 10)
	cpanel.add_child(crow)

	_creature_emoji = Label.new()
	_creature_emoji.add_theme_font_size_override("font_size", 22)
	crow.add_child(_creature_emoji)

	var ctexts := VBoxContainer.new()
	ctexts.add_theme_constant_override("separation", 1)
	crow.add_child(ctexts)

	_creature_name = Label.new()
	_creature_name.add_theme_font_size_override("font_size", 14)
	_creature_name.add_theme_color_override("font_color", Color(1, 1, 1, 0.90))
	ctexts.add_child(_creature_name)

	_creature_desc = Label.new()
	_creature_desc.add_theme_font_size_override("font_size", 10)
	_creature_desc.add_theme_color_override("font_color", Color(1, 1, 1, 0.40))
	ctexts.add_child(_creature_desc)

	var home_tag := Label.new()
	home_tag.text = "HOME TEAM"
	home_tag.add_theme_font_size_override("font_size", 9)
	home_tag.add_theme_color_override("font_color", Color(1, 1, 1, 0.25))
	home_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crow.add_child(home_tag)

	# Neutral site override dropdown
	_creature_opt_row = HBoxContainer.new()
	_creature_opt_row.visible = false
	vb.add_child(_creature_opt_row)

	_creature_opt = OptionButton.new()
	_creature_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for cd in CREATURE_DATA:
		_creature_opt.add_item("%s %s — %s" % [cd[0], cd[1], cd[2]])
	_creature_opt.selected = _neutral_creature
	_creature_opt.item_selected.connect(func(i: int): _neutral_creature = i)
	_creature_opt_row.add_child(_creature_opt)

	_update_creature_display()
	return card

func _build_strat_tact_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Home column
	var home_card := _card()
	home_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var home_vb := VBoxContainer.new()
	home_vb.add_theme_constant_override("separation", 12)
	home_card.add_child(home_vb)

	home_vb.add_child(_field_label("HOME STRATEGY"))
	var hs_sub := Label.new()
	hs_sub.text = "How AI teammates approach the game"
	hs_sub.add_theme_font_size_override("font_size", 9)
	hs_sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	home_vb.add_child(hs_sub)
	home_vb.add_child(_build_radio_group(STRATEGY_DATA, _home_strat_idx, _home_strat_items,
		func(i: int): _home_strat_idx = i; _update_radio_group(_home_strat_items, i)))

	home_vb.add_child(_thin_divider())

	home_vb.add_child(_field_label("HOME TACTICS"))
	var ht_sub := Label.new()
	ht_sub.text = "How AI teammates behave moment-to-moment"
	ht_sub.add_theme_font_size_override("font_size", 9)
	ht_sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	home_vb.add_child(ht_sub)
	home_vb.add_child(_build_radio_group(TACTICS_DATA, _home_tact_idx, _home_tact_items,
		func(i: int): _home_tact_idx = i; _update_radio_group(_home_tact_items, i)))

	row.add_child(home_card)

	# Opponent column
	var opp_card := _card()
	opp_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var opp_vb := VBoxContainer.new()
	opp_vb.add_theme_constant_override("separation", 12)
	opp_card.add_child(opp_vb)

	opp_vb.add_child(_field_label("OPPONENT STRATEGY"))
	var os_sub := Label.new()
	os_sub.text = "The computer team's theory of victory"
	os_sub.add_theme_font_size_override("font_size", 9)
	os_sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	opp_vb.add_child(os_sub)
	opp_vb.add_child(_build_radio_group(STRATEGY_DATA, _opp_strat_idx, _opp_strat_items,
		func(i: int): _opp_strat_idx = i; _update_radio_group(_opp_strat_items, i)))

	opp_vb.add_child(_thin_divider())

	opp_vb.add_child(_field_label("OPPONENT TACTICS"))
	var ot_sub := Label.new()
	ot_sub.text = "The computer team's moment-to-moment behavior"
	ot_sub.add_theme_font_size_override("font_size", 9)
	ot_sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	opp_vb.add_child(ot_sub)
	opp_vb.add_child(_build_radio_group(TACTICS_DATA, _opp_tact_idx, _opp_tact_items,
		func(i: int): _opp_tact_idx = i; _update_radio_group(_opp_tact_items, i)))

	row.add_child(opp_card)
	return row

func _build_duration_card() -> Control:
	var card := _card()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	card.add_child(vb)

	vb.add_child(_field_label("MATCH DURATION"))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vb.add_child(row)

	_fast_off = _mode_btn("NORMAL", "3min acts", true)
	_fast_off.pressed.connect(func(): _fast_mode = false; _set_duration_visual())
	row.add_child(_fast_off)

	_fast_on = _mode_btn("FAST", "1min acts", false)
	_fast_on.pressed.connect(func(): _fast_mode = true; _set_duration_visual())
	row.add_child(_fast_on)

	var div := ColorRect.new()
	div.color = Color(0.102, 0.102, 0.180)
	div.custom_minimum_size.y = 1
	div.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(div)

	vb.add_child(_field_label("CONTROLS"))

	for pair in [
		["W / S",     "Move forward / backward"],
		["A / D",     "Turn left / right"],
		["Q / E",     "Strafe left / right"],
		["1",         "Tackle (basic attack)"],
		["2",         "Power Slam  (25 Red Mana)"],
		["3",         "Sprint  (20 Blue Mana)"],
		["F",         "Pass ball to teammate"],
		["SPACE",     "Jump  (evades tackles while airborne)"],
		["SPACE x2",  "Double-jump  (costs 15 Blue Mana)"],
		["TAB",       "Cycle enemy target"],
		["SHIFT+TAB", "Switch controlled player"],
		["M",         "Toggle damage / healing meter"],
		["C",         "Cycle player class  (Test Mode only)"],
		["ESC",       "Clear target / Pause"],
	]:
		var ctrl_row := HBoxContainer.new()
		ctrl_row.add_theme_constant_override("separation", 8)

		var badge := PanelContainer.new()
		var bsbox := StyleBoxFlat.new()
		bsbox.bg_color = Color(0.200, 0.200, 0.333)
		bsbox.border_color = Color(0.333, 0.400, 0.533)
		bsbox.border_width_left = 1; bsbox.border_width_right  = 1
		bsbox.border_width_top  = 1; bsbox.border_width_bottom = 1
		bsbox.corner_radius_top_left    = 3; bsbox.corner_radius_top_right    = 3
		bsbox.corner_radius_bottom_left = 3; bsbox.corner_radius_bottom_right = 3
		bsbox.content_margin_left  = 6; bsbox.content_margin_right  = 6
		bsbox.content_margin_top   = 2; bsbox.content_margin_bottom = 2
		badge.add_theme_stylebox_override("panel", bsbox)
		badge.custom_minimum_size.x = 80

		var key_lbl := Label.new()
		key_lbl.text = pair[0]
		key_lbl.add_theme_font_size_override("font_size", 11)
		key_lbl.add_theme_color_override("font_color", Color(0.800, 0.867, 1.000))
		key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_child(key_lbl)
		ctrl_row.add_child(badge)

		var desc_lbl := Label.new()
		desc_lbl.text = pair[1]
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
		desc_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ctrl_row.add_child(desc_lbl)

		vb.add_child(ctrl_row)

	return card

func _populate_rules(vbox: VBoxContainer) -> void:
	vbox.add_child(_section_header("GAME RULES"))
	for section in RULES_DATA:
		vbox.add_child(_build_rule_section(section[0], section[1], section[2]))

func _build_rule_section(icon: String, title: String, rules: Array) -> Control:
	var card := _card()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	card.add_child(vb)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 6)
	vb.add_child(header_row)

	var icon_lbl := Label.new()
	icon_lbl.text = icon
	icon_lbl.add_theme_font_size_override("font_size", 14)
	header_row.add_child(icon_lbl)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 11)
	title_lbl.add_theme_color_override("font_color", C_GOLD)
	header_row.add_child(title_lbl)

	vb.add_child(_thin_divider())

	for rule in rules:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		vb.add_child(row)

		var dot := Label.new()
		dot.text = "·"
		dot.add_theme_font_size_override("font_size", 11)
		dot.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
		row.add_child(dot)

		var rule_lbl := Label.new()
		rule_lbl.text = rule
		rule_lbl.add_theme_font_size_override("font_size", 11)
		rule_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.70))
		rule_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		rule_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(rule_lbl)

	return card

# ── Radio group builder ───────────────────────────────────────────────────────

func _build_radio_group(data: Array, selected_idx: int, items_out: Array, on_select: Callable) -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)

	for i in data.size():
		var entry: Array = data[i]
		var panel := PanelContainer.new()
		var sbox := StyleBoxFlat.new()
		sbox.corner_radius_top_left = 4; sbox.corner_radius_top_right = 4
		sbox.corner_radius_bottom_left = 4; sbox.corner_radius_bottom_right = 4
		panel.add_theme_stylebox_override("panel", sbox)
		items_out.append([panel, sbox])

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		panel.add_child(row)

		var emoji_lbl := Label.new()
		emoji_lbl.text = entry[0]
		emoji_lbl.add_theme_font_size_override("font_size", 16)
		emoji_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		emoji_lbl.custom_minimum_size.x = 24
		row.add_child(emoji_lbl)

		var text_vb := VBoxContainer.new()
		text_vb.add_theme_constant_override("separation", 1)
		text_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text_vb)

		var label_lbl := Label.new()
		label_lbl.text = entry[1]
		label_lbl.add_theme_font_size_override("font_size", 12)
		text_vb.add_child(label_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = entry[2]
		desc_lbl.add_theme_font_size_override("font_size", 9)
		desc_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.40))
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		text_vb.add_child(desc_lbl)

		# Store label ref in item array so we can tint it on select
		items_out[i].append(label_lbl)

		var captured_i := i
		panel.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				on_select.call(captured_i)
		)
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		vb.add_child(panel)

	_update_radio_group(items_out, selected_idx)
	return vb

func _update_radio_group(items: Array, selected_idx: int) -> void:
	for i in items.size():
		var panel: PanelContainer = items[i][0]
		var sbox: StyleBoxFlat    = items[i][1]
		var label_lbl: Label      = items[i][2]
		var is_sel := (i == selected_idx)
		sbox.bg_color     = Color(0.102, 0.102, 0.180, 0.9) if is_sel else Color(0.0, 0.0, 0.0, 0.0)
		sbox.border_color = C_GOLD if is_sel else Color(0.20, 0.20, 0.33)
		sbox.border_width_left   = 2 if is_sel else 1
		sbox.border_width_right  = 2 if is_sel else 1
		sbox.border_width_top    = 2 if is_sel else 1
		sbox.border_width_bottom = 2 if is_sel else 1
		label_lbl.add_theme_color_override("font_color", C_GOLD if is_sel else Color(1, 1, 1, 0.60))

# ── State change handlers ─────────────────────────────────────────────────────

func _set_mode(three_team: bool) -> void:
	_is_three_team = three_team
	_mode_2t.button_pressed = not three_team
	_mode_3t.button_pressed = three_team
	_third_row.visible = three_team
	_set_mode_btn_visual(_mode_2t, not three_team)
	_set_mode_btn_visual(_mode_3t, three_team)

func _set_duration_visual() -> void:
	_set_mode_btn_visual(_fast_off, not _fast_mode)
	_set_mode_btn_visual(_fast_on, _fast_mode)

func _on_home_team_changed(idx: int) -> void:
	_home_team_idx = idx
	_avoid_team_conflict(0)
	_update_creature_display()

func _on_away_team_changed(idx: int) -> void:
	_away_team_idx = idx
	_avoid_team_conflict(1)

func _avoid_team_conflict(changed_slot: int) -> void:
	if _home_team_idx == _away_team_idx:
		if changed_slot == 0:
			_away_team_idx = (_away_team_idx + 1) % TEAM_DEFS.size()
			if _away_team_idx == _home_team_idx:
				_away_team_idx = (_away_team_idx + 1) % TEAM_DEFS.size()
			_away_opt.selected = _away_team_idx
		else:
			_home_team_idx = (_home_team_idx + 1) % TEAM_DEFS.size()
			if _home_team_idx == _away_team_idx:
				_home_team_idx = (_home_team_idx + 1) % TEAM_DEFS.size()
			_home_opt.selected = _home_team_idx
			_update_creature_display()

func _on_neutral_site_toggled(pressed: bool) -> void:
	_is_neutral_site = pressed
	_creature_fixed.visible = not pressed
	_creature_opt_row.visible = pressed

func _update_creature_display() -> void:
	var ci: int = TEAM_DEFS[_home_team_idx][1]
	var cd: Array = CREATURE_DATA[ci]
	_creature_emoji.text = cd[0]
	_creature_name.text  = cd[1]
	_creature_desc.text  = cd[2]

# ── Config collection ─────────────────────────────────────────────────────────

func _collect_config() -> MatchConfig:
	var cfg := MatchConfig.new()

	cfg.match_mode = MatchConfig.MatchMode.THREE_TEAM if _is_three_team \
	                                                   else MatchConfig.MatchMode.TWO_TEAM
	cfg.fast_mode = _fast_mode

	var team_count := 3 if _is_three_team else 2
	var idxs := [_home_team_idx, _away_team_idx, _third_team_idx]
	var team_name_keys   := ["home_team_name",   "away_team_name",   "third_team_name"]
	var player_name_keys := ["home_player_names", "away_player_names", "third_player_names"]

	cfg.ai_strategy_resources.clear()
	cfg.ai_tactics_resources.clear()
	cfg.is_human_controlled.clear()

	var strat_idxs := [_home_strat_idx, _opp_strat_idx, _opp_strat_idx]
	var tact_idxs  := [_home_tact_idx,  _opp_tact_idx,  _opp_tact_idx]

	for t in team_count:
		var td: Array = TEAM_DEFS[idxs[t]]
		cfg.set(team_name_keys[t], td[0])
		cfg.set(player_name_keys[t], PackedStringArray(td[4]))
		cfg.ai_strategy_resources.append(_make_strategy(strat_idxs[t]))
		cfg.ai_tactics_resources.append(_make_tactics(tact_idxs[t]))
		cfg.is_human_controlled.append(t == 0)

	if _is_neutral_site:
		cfg.creature_type = _neutral_creature
	else:
		cfg.creature_type = TEAM_DEFS[_home_team_idx][1]

	return cfg

func _make_strategy(idx: int) -> Resource:
	match idx:
		1: return _SAggressive.new()
		2: return _SNumericalEdge.new()
		3: return _SFloodEndzone.new()
		4: return _SPossessionBleed.new()
	return _SBalanced.new()

func _make_tactics(idx: int) -> Resource:
	match idx:
		1: return _TFocusFire.new()
		2: return _TPickScreen.new()
		3: return _TQuickRelease.new()
		4: return _TCreatureFlank.new()
		5: return _TWedgeRun.new()
		6: return _THeroBall.new()
	return _TBalanced.new()

# ── Network handlers ──────────────────────────────────────────────────────────

func _on_host_pressed() -> void:
	var err := NetworkManager.host_enet()
	if err != OK:
		_status_lbl.text = "Failed to open port %d" % NetworkManager.ENET_PORT
		return
	_status_lbl.text = "Hosting on port %d — waiting for opponent…" % NetworkManager.ENET_PORT

func _on_join_pressed() -> void:
	var address := _ip_input.text.strip_edges()
	if address.is_empty(): address = "127.0.0.1"
	var err := NetworkManager.join_enet(address)
	if err != OK:
		_status_lbl.text = "Could not connect to %s" % address
		return
	_status_lbl.text = "Connecting to %s…" % address
	await get_tree().create_timer(1.5).timeout
	if not NetworkManager.local_player_id.is_empty():
		match_ready.emit(_collect_config())

func _on_peer_connected(_peer_id: int) -> void:
	if not NetworkManager.is_server(): return
	_status_lbl.text = "Opponent connected!"
	_start_online_btn.visible = true

func _on_start_pressed() -> void:
	match_ready.emit(_collect_config())

func _on_offline_pressed() -> void:
	match_ready.emit(_collect_config())

# ── UI helpers ────────────────────────────────────────────────────────────────

func _card() -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sbox := StyleBoxFlat.new()
	sbox.bg_color = C_SURF
	sbox.border_color = C_BORDER
	sbox.border_width_left = 1; sbox.border_width_right  = 1
	sbox.border_width_top  = 1; sbox.border_width_bottom = 1
	sbox.corner_radius_top_left = 6; sbox.corner_radius_top_right = 6
	sbox.corner_radius_bottom_left = 6; sbox.corner_radius_bottom_right = 6
	sbox.content_margin_left = 16; sbox.content_margin_right  = 16
	sbox.content_margin_top  = 14; sbox.content_margin_bottom = 14
	p.add_theme_stylebox_override("panel", sbox)
	return p

func _section_header(text: String) -> Control:
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

func _field_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 9)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	return l

func _mode_btn(text: String, sub: String, pressed: bool) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = pressed
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size.y = 44

	var sbox_off := StyleBoxFlat.new()
	sbox_off.bg_color = Color(0, 0, 0, 0)
	sbox_off.border_color = Color(0.20, 0.20, 0.33)
	sbox_off.border_width_left = 1; sbox_off.border_width_right  = 1
	sbox_off.border_width_top  = 1; sbox_off.border_width_bottom = 1
	sbox_off.corner_radius_top_left = 4; sbox_off.corner_radius_top_right = 4
	sbox_off.corner_radius_bottom_left = 4; sbox_off.corner_radius_bottom_right = 4

	var sbox_on := sbox_off.duplicate() as StyleBoxFlat
	sbox_on.bg_color = Color(0.102, 0.102, 0.180)
	sbox_on.border_color = C_GOLD
	sbox_on.border_width_left = 2; sbox_on.border_width_right  = 2
	sbox_on.border_width_top  = 2; sbox_on.border_width_bottom = 2

	b.add_theme_stylebox_override("normal",         sbox_off)
	b.add_theme_stylebox_override("hover",          sbox_off)
	b.add_theme_stylebox_override("pressed",        sbox_on)
	b.add_theme_stylebox_override("hover_pressed",  sbox_on)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 2)
	b.add_child(vb)

	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", C_GOLD if pressed else Color(1, 1, 1, 0.60))
	vb.add_child(lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = sub
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 8)
	sub_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	vb.add_child(sub_lbl)

	return b

func _set_mode_btn_visual(btn: Button, selected: bool) -> void:
	for child in btn.get_children():
		if child is VBoxContainer:
			for sub_child in child.get_children():
				if sub_child is Label and sub_child.get_theme_font_size("font_size") >= 12:
					sub_child.add_theme_color_override("font_color",
						C_GOLD if selected else Color(1, 1, 1, 0.60))

func _small_btn(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 11)
	return b

func _thin_divider() -> Control:
	var c := ColorRect.new()
	c.color = C_BORDER
	c.custom_minimum_size.y = 1
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c
