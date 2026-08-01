extends Control

signal match_ready(config: MatchConfig)

const _MatchConfig    := preload("res://data/match/MatchConfig.gd")
const _TeamPortrait   := preload("res://scenes/game/hud/TeamPortrait.gd")
const _LOBBY_SAVE_PATH := "user://lobby_settings.cfg"

# ── AI resource constructors ──────────────────────────────────────────────────
const _StratBalanced      := preload("res://systems/ai/strategies/BalancedStrategy.gd")
const _StratNumericalEdge := preload("res://systems/ai/strategies/NumericalEdgeStrategy.gd")
const _StratAggressive    := preload("res://systems/ai/strategies/AggressiveStrategy.gd")
const _StratFloodEndzone  := preload("res://systems/ai/strategies/FloodEndzoneStrategy.gd")
const _StratPossessionBleed := preload("res://systems/ai/strategies/PossessionBleedStrategy.gd")
const _StratSafePass      := preload("res://systems/ai/strategies/SafePassStrategy.gd")
const _TactFocusFire      := preload("res://systems/ai/tactics/FocusFireTactics.gd")
const _TactPickAndScreen  := preload("res://systems/ai/tactics/PickAndScreenTactics.gd")
const _TactQuickRelease   := preload("res://systems/ai/tactics/QuickReleaseTactics.gd")
const _TactCreatureFlank  := preload("res://systems/ai/tactics/CreatureFlankTactics.gd")
const _TactWedgeRun       := preload("res://systems/ai/tactics/WedgeRunTactics.gd")
const _TactHeroBall       := preload("res://systems/ai/tactics/HeroBallTactics.gd")
const _TactBalanced       := preload("res://systems/ai/tactics/BalancedTactics.gd")
const _TactSafePass       := preload("res://systems/ai/tactics/SafePassTactics.gd")

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
var _match_mode        : int  = 0   # 0=TwoTeam 1=ThreeTeam
var _fast_mode         : bool = false
var _test_mode         : bool = false
var _view_mode         : int  = 0   # 0=FLAT 1=THREE_QUARTER 2=FULL_3D
var _creature          : int  = 4   # neutral creature (defaults to Chaos)
var _home_team         : int  = 0   # index into TEAMS
var _away_team         : int  = 1   # index into TEAMS
var _third_team        : int  = 2   # index into TEAMS (3-team mode only)
var _site              : int  = 0   # 0=Home 1=Away 2=Neutral
var _players_per_side  : int  = 7
var _home_strat  : int  = 0
var _home_tact   : int  = 0
var _opp_strat   : int  = 0
var _opp_tact    : int  = 0

# Button group arrays — filled during build
var _mode_btns   : Array = []   # [btn2team, btn3team]
var _dur_btns    : Array = []   # [btnNormal, btnFast]
var _view_btns   : Array = []   # [btn2d, btn3q, btn3d]
var _crea_btns           : Array   = []   # one per creature (neutral mode only)
var _site_btns           : Array   = []   # [home, away, neutral] buttons
var _creature_auto_lbl   : Label   = null # shown when site=Home/Away
var _neutral_crea_vbox   : VBoxContainer = null # shown when site=Neutral
var _home_team_ob        : OptionButton  = null
var _away_team_ob        : OptionButton  = null
var _third_team_ob       : OptionButton  = null
var _third_row           : HBoxContainer = null
var _hs_radios   : Array = []   # home strategy radio rows
var _ht_radios   : Array = []   # home tactics radio rows
var _os_radios   : Array = []   # opp strategy radio rows
var _ot_radios   : Array = []   # opp tactics radio rows

# Settings overlay
var _settings_overlay  : Control       = null

# Roster
var _home_roster       : Array  = []
var _home_roster_vbox  : VBoxContainer = null
var _away_roster_vbox  : VBoxContainer = null
var _units_count_lbl   : Label         = null
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

# Match history
var _report_overlay  : Control = null

# LAN multiplayer
var _lan_mode        : bool   = false
var _lan_is_host     : bool   = false
var _connected_peers : int    = 0
var _lan_opts        : Control       = null
var _lan_status_lbl  : Label         = null
var _lan_peer_lbl    : Label         = null
var _lan_ip_edit     : LineEdit      = null
var _start_btn       : Button        = null
var _solo_btn        : Button        = null
var _lan_btn         : Button        = null
var _my_team_lbl     : Label         = null

# ── Data ──────────────────────────────────────────────────────────────────────
const STRATEGIES := [
	["⚖️", "BALANCED",       "Ball carrier advances; 2 defenders press the ball; support spreads ahead"],
	["🔢", "NUMBERS GAME",   "On defense converge all pressure on the weakest enemy for quick eliminations"],
	["💥", "AGGRESSIVE",     "3 defenders press the carrier on defense; tighter support spacing on offense"],
	["🌊", "FLOOD THE ZONE", "Flood 3–4 players into the endzone; defense can't cover everyone"],
	["🩸", "BLEED OUT",      "Never surrender the ball; drain the clock; only score when safe"],
	["🎽", "SAFE PASS",      "Stagger receivers at relay distances; one rusher on defense; possession first"],
]

const TACTICS := [
	["🎯", "FOCUS FIRE",     "All attackers lock onto one target at once; eliminate before moving on"],
	["🏀", "PICK & SCREEN",  "Two players set hard screens; others sprint decoy routes to the endzone"],
	["⚡", "QUICK RELEASE",  "Pass at the first open window; chain passes to advance the ball"],
	["👹", "CREATURE FLANK", "Herd the opponent toward the creature from the opposite side"],
	["🔺", "WEDGE RUN",      "Three players form a tight triangle around the carrier; move as one"],
	["⭐", "HERO BALL",      "All units rally around the star player; pass the ball to them"],
	["🤝", "SAFE PASS",      "Throw to the nearest open receiver; sidestep into space when pressured"],
]

const CREATURES := [
	["👻", "WRAITH",       "Fast & lethal — blink and you're dead"],
	["🐍", "SERPENT",      "Medium speed, wide striking coil"],
	["🪨", "GOLEM",        "Slow colossus — its shadow alone kills"],
	["💀", "SPECTER",      "Blindingly fast, near-impossible to avoid"],
	["🔥", "HELLHOUND",    "Hunts the nearest player relentlessly"],
	["⚡", "THUNDERBIRD",  "Erratic speed — impossible to predict"],
	["🐲", "WYVERN",       "Swift aerial predator — fast patrol"],
	["🦎", "BASILISK",     "Slow but its kill radius fills the channel"],
	["😈", "DEMON",        "Teleports unpredictably across the field"],
	["🌫", "BANSHEE",      "Screaming blur — extreme speed, tiny profile"],
	["🌀", "CHAOS MONSTER","Completely unpredictable — avoid at all costs"],
]

# [emoji, name, creature_idx (0–9 unique per team), [15 player names]]
const TEAMS := [
	["💀", "REAPERS",  0, ["Scythe", "Grim", "Shade", "Mort", "Dusk", "Reap", "Doom", "Skull", "Gore", "Bone", "Crypt", "Void", "Hex", "Ash", "Blood"]],
	["🐍", "VIPERS",   1, ["Fang", "Venom", "Cobra", "Asp", "Adder", "Mamba", "Python", "Anaconda", "Boa", "Taipan", "Scales", "Coil", "Rattle", "Hiss", "Pit"]],
	["⚒", "TITANS",   2, ["Steel", "Forge", "Anvil", "Iron", "Alloy", "Boulder", "Granite", "Basalt", "Stone", "Flint", "Golem", "Colossus", "Rampart", "Bulwark", "Aegis"]],
	["👻", "GHOSTS",   3, ["Wraith", "Specter", "Phantom", "Spirit", "Wisp", "Haunt", "Drift", "Echo", "Mirage", "Gloom", "Veil", "Shroud", "Mist", "Vapor", "Ether"]],
	["🔥", "INFERNO",  4, ["Blaze", "Cinder", "Ember", "Flare", "Kindler", "Char", "Scorch", "Brand", "Pyre", "Smelt", "Torch", "Flame", "Fuse", "Burn", "Forge"]],
	["⛈", "STORM",    5, ["Gale", "Bolt", "Thunder", "Flash", "Surge", "Squall", "Gust", "Cyclone", "Torrent", "Nimbus", "Tempest", "Zephyr", "Hail", "Sleet", "Frost"]],
	["✈", "RAPTORS",  6, ["Talon", "Wing", "Vector", "Apex", "Sonic", "Mach", "Afterburn", "Strafe", "Climb", "Descent", "Bogey", "Bandit", "Tally", "Check", "Buster"]],
	["🚁", "COBRAS",   7, ["Gunner", "Striker", "Hunter", "Eagle", "Falcon", "Hawk", "Harrier", "Maverick", "Iceman", "Goose", "Viper", "Rooster", "Hollywood", "Wolfman", "Merlin"]],
	["🧙", "WARLOCKS", 8, ["Hex", "Curse", "Sigil", "Rune", "Rift", "Bane", "Wither", "Shroud", "Omen", "Pact", "Vex", "Bind", "Drain", "Cast", "Glyph"]],
	["🌫", "PHANTOMS", 9, ["Ghost", "Stealth", "Vapor", "Haunt", "Shadow", "Dim", "Fade", "Flicker", "Pale", "Null", "Blank", "Dark", "Drift", "Eerie", "Wisp"]],
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
	["V",          "Cycle camera: Broadcast ↔ Third-person (3D mode only)"],
	["SHIFT+V",    "Toggle ball-cam in Broadcast mode (3D mode only)"],
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
		"All 5 Acts: 3-minute countdown timer (1 min in Fast mode)",
		"An act also ends if all opposing players are eliminated",
		"Highest score at end of Act 5 wins the match!",
	]],
]

const CLASS_NAMES := [
	"SPECTRE", "CORSAIR", "GEOMANCER", "ARCHON", "WARDEN", "TRICKSTER", "WRECKER", "VITALIST",
	"CHRONOKINESIST", "UBERBLITZER"
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
	"Time-manipulating ranged attacker. Speeds allies, slows enemies, extends or collapses terrain effects, and bends the act clock itself.",
	"Storm mage — lightning bolts, chain damage, and three stances: Lightning, Thunder, and Serene.",
]
const CLASS_COLORS := [
	Color(0.267, 1.000, 0.800),   # Spectre         #44FFCC
	Color(1.000, 0.267, 0.667),   # Corsair         #FF44AA
	Color(1.000, 0.333, 0.267),   # Geomancer       #FF5544
	Color(0.267, 0.533, 1.000),   # Archon          #4488FF
	Color(1.000, 0.800, 0.267),   # Warden          #FFCC44
	Color(0.667, 0.267, 1.000),   # Trickster       #AA44FF
	Color(1.000, 0.467, 0.000),   # Wrecker         #FF7700
	Color(0.267, 0.867, 0.533),   # Vitalist        #44DD88
	Color(0.550, 0.120, 0.880),   # Chronokinesist  #8C1FE0
	Color(0.400, 0.800, 1.000),   # Uberblitzer     #66CCFF
]

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_apply_bg()
	_load_lobby_state()
	_build_ui()
	NetworkManager.config_received.connect(_on_config_received)
	EventBus.peer_connected.connect(_on_net_peer_connected)
	EventBus.peer_disconnected.connect(_on_net_peer_disconnected)

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

	# Gear icon — floated to top-right corner of the lobby
	var gear_btn := Button.new()
	gear_btn.text = "⚙"
	gear_btn.flat = true
	gear_btn.focus_mode = Control.FOCUS_NONE
	gear_btn.add_theme_font_size_override("font_size", 22)
	gear_btn.add_theme_color_override("font_color", C_DIM)
	gear_btn.custom_minimum_size = Vector2(48, 48)
	gear_btn.anchor_left  = 1.0; gear_btn.anchor_right  = 1.0
	gear_btn.anchor_top   = 0.0; gear_btn.anchor_bottom = 0.0
	gear_btn.offset_left  = -56; gear_btn.offset_right  = -8
	gear_btn.offset_top   =   8; gear_btn.offset_bottom = 56
	gear_btn.z_index = 10
	gear_btn.pressed.connect(_open_settings)
	add_child(gear_btn)

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

	var title := RichTextLabel.new()
	title.bbcode_enabled = true
	title.fit_content = true
	title.scroll_active = false
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("normal_font_size", 72)
	if FontCache.bangers:
		title.add_theme_font_override("normal_font", FontCache.bangers)
	title.text = _ultra_gradient_bbcode("ULTRABALL", true)
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

	# ── Network section ──────────────────────────────────────────────────────
	inner.add_child(_make_section_header("NETWORK"))
	inner.add_child(_make_spacer(4))
	inner.add_child(_build_lan_card())
	inner.add_child(_make_spacer(8))

	# ── Teams ─────────────────────────────────────────────────────────────────────
	var teams_card := _make_card()
	inner.add_child(teams_card)
	var teams_vbox := VBoxContainer.new()
	teams_vbox.add_theme_constant_override("separation", 10)
	teams_card.add_child(teams_vbox)
	teams_vbox.add_child(_make_field_label("TEAMS"))

	_my_team_lbl = Label.new()
	_my_team_lbl.add_theme_font_size_override("font_size", 12)
	_my_team_lbl.add_theme_color_override("font_color", C_GOLD)
	_my_team_lbl.visible = false
	teams_vbox.add_child(_my_team_lbl)

	var home_row := HBoxContainer.new()
	home_row.add_theme_constant_override("separation", 8)
	teams_vbox.add_child(home_row)
	var home_lbl := Label.new()
	home_lbl.text = "HOME"
	home_lbl.add_theme_font_size_override("font_size", 11)
	home_lbl.add_theme_color_override("font_color", C_DIM)
	home_lbl.custom_minimum_size = Vector2(48, 0)
	home_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	home_row.add_child(home_lbl)
	_home_team_ob = _make_team_option_button(_home_team)
	_home_team_ob.item_selected.connect(_set_home_team)
	home_row.add_child(_home_team_ob)

	var away_row := HBoxContainer.new()
	away_row.add_theme_constant_override("separation", 8)
	teams_vbox.add_child(away_row)
	var away_lbl := Label.new()
	away_lbl.text = "AWAY"
	away_lbl.add_theme_font_size_override("font_size", 11)
	away_lbl.add_theme_color_override("font_color", C_DIM)
	away_lbl.custom_minimum_size = Vector2(48, 0)
	away_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	away_row.add_child(away_lbl)
	_away_team_ob = _make_team_option_button(_away_team)
	_away_team_ob.item_selected.connect(_set_away_team)
	away_row.add_child(_away_team_ob)

	_third_row = HBoxContainer.new()
	_third_row.add_theme_constant_override("separation", 8)
	_third_row.visible = (_match_mode == 1)
	teams_vbox.add_child(_third_row)
	var third_lbl := Label.new()
	third_lbl.text = "THIRD"
	third_lbl.add_theme_font_size_override("font_size", 11)
	third_lbl.add_theme_color_override("font_color", C_DIM)
	third_lbl.custom_minimum_size = Vector2(48, 0)
	third_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_third_row.add_child(third_lbl)
	_third_team_ob = _make_team_option_button(_third_team)
	_third_team_ob.item_selected.connect(_set_third_team)
	_third_row.add_child(_third_team_ob)

	inner.add_child(_make_spacer(8))

	# ── Game Site + Creature ──────────────────────────────────────────────────────
	var site_card := _make_card()
	inner.add_child(site_card)
	var site_vbox := VBoxContainer.new()
	site_vbox.add_theme_constant_override("separation", 10)
	site_card.add_child(site_vbox)
	site_vbox.add_child(_make_field_label("GAME SITE"))
	site_vbox.add_child(_make_hint("Home/Away uses that team's creature. Neutral enables a custom pick."))
	var site_row := HBoxContainer.new()
	site_row.add_theme_constant_override("separation", 8)
	site_vbox.add_child(site_row)
	var sbtn_home := _make_speed_btn("HOME",    "Home team's field", _site == 0)
	var sbtn_away := _make_speed_btn("AWAY",    "Away team's field", _site == 1)
	var sbtn_neut := _make_speed_btn("NEUTRAL", "Neutral site",      _site == 2)
	for b: Button in [sbtn_home, sbtn_away, sbtn_neut]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	site_row.add_child(sbtn_home)
	site_row.add_child(sbtn_away)
	site_row.add_child(sbtn_neut)
	_site_btns = [sbtn_home, sbtn_away, sbtn_neut]
	sbtn_home.pressed.connect(_set_site.bind(0))
	sbtn_away.pressed.connect(_set_site.bind(1))
	sbtn_neut.pressed.connect(_set_site.bind(2))

	site_vbox.add_child(_make_divider())
	site_vbox.add_child(_make_spacer(4))
	site_vbox.add_child(_make_field_label("CREATURE"))

	_creature_auto_lbl = Label.new()
	_creature_auto_lbl.add_theme_font_size_override("font_size", 14)
	_creature_auto_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	_creature_auto_lbl.visible = true
	site_vbox.add_child(_creature_auto_lbl)

	_neutral_crea_vbox = VBoxContainer.new()
	_neutral_crea_vbox.add_theme_constant_override("separation", 4)
	_neutral_crea_vbox.visible = false
	site_vbox.add_child(_neutral_crea_vbox)
	_crea_btns.clear()
	for i in range(CREATURES.size()):
		var c: Array = CREATURES[i]
		var rb := _make_choice_radio(c[0], c[1], c[2], _creature == i)
		rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_neutral_crea_vbox.add_child(rb)
		_crea_btns.append(rb)
		rb.pressed.connect(_set_creature.bind(i))

	_refresh_creature_display()

	inner.add_child(_make_spacer(8))

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

	# ── Test Mode ─────────────────────────────────────────────────────────────
	var test_card := _make_card()
	inner.add_child(test_card)
	var test_vbox := VBoxContainer.new()
	test_vbox.add_theme_constant_override("separation", 10)
	test_card.add_child(test_vbox)
	test_vbox.add_child(_make_field_label("TEST MODE"))
	test_vbox.add_child(_make_hint("1 unit vs. a stationary Target Dummy — no AI, no creatures"))
	var test_row := HBoxContainer.new()
	test_row.add_theme_constant_override("separation", 8)
	test_vbox.add_child(test_row)
	var btn_test_off := _make_speed_btn("OFF", "Normal match", not _test_mode)
	var btn_test_on  := _make_speed_btn("ON",  "Training",     _test_mode)
	btn_test_off.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_test_on.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
	test_row.add_child(btn_test_off)
	test_row.add_child(btn_test_on)
	btn_test_off.pressed.connect(func() -> void:
		_test_mode = false
		_update_speed_btn(btn_test_off, true)
		_update_speed_btn(btn_test_on,  false)
		_save_lobby_state())
	btn_test_on.pressed.connect(func() -> void:
		_test_mode = true
		_update_speed_btn(btn_test_off, false)
		_update_speed_btn(btn_test_on,  true)
		_save_lobby_state())

	# ── Units Per Side ────────────────────────────────────────────────────────
	var units_card := _make_card()
	inner.add_child(units_card)
	var units_vbox := VBoxContainer.new()
	units_vbox.add_theme_constant_override("separation", 10)
	units_card.add_child(units_vbox)
	units_vbox.add_child(_make_field_label("UNITS PER SIDE"))
	units_vbox.add_child(_make_hint("How many players start on the field per team (1–15)"))
	var units_row := HBoxContainer.new()
	units_row.add_theme_constant_override("separation", 0)
	units_vbox.add_child(units_row)
	var btn_minus := _make_speed_btn("−", "", false)
	btn_minus.custom_minimum_size = Vector2(48, 40)
	btn_minus.add_theme_font_size_override("font_size", 22)
	btn_minus.focus_mode = Control.FOCUS_NONE
	units_row.add_child(btn_minus)
	_units_count_lbl = Label.new()
	_units_count_lbl.text = str(_players_per_side)
	_units_count_lbl.add_theme_font_size_override("font_size", 26)
	_units_count_lbl.add_theme_color_override("font_color", Color.WHITE)
	_units_count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_units_count_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_units_count_lbl.custom_minimum_size  = Vector2(72, 40)
	units_row.add_child(_units_count_lbl)
	var btn_plus := _make_speed_btn("+", "", false)
	btn_plus.custom_minimum_size = Vector2(48, 40)
	btn_plus.add_theme_font_size_override("font_size", 22)
	btn_plus.focus_mode = Control.FOCUS_NONE
	units_row.add_child(btn_plus)
	btn_minus.pressed.connect(func() -> void: _set_players_per_side(_players_per_side - 1))
	btn_plus.pressed.connect(func() -> void:  _set_players_per_side(_players_per_side + 1))

	# ── View Mode ────────────────────────────────────────────────────────────
	var view_card := _make_card()
	inner.add_child(view_card)
	var view_vbox := VBoxContainer.new()
	view_vbox.add_theme_constant_override("separation", 10)
	view_card.add_child(view_vbox)
	view_vbox.add_child(_make_field_label("VIEW MODE"))
	var view_row := HBoxContainer.new()
	view_row.add_theme_constant_override("separation", 8)
	view_vbox.add_child(view_row)
	var btn2d := _make_speed_btn("2D",  "Top-down",    _view_mode == 0)
	var btn3q := _make_speed_btn("3/4", "Perspective", _view_mode == 1)
	var btn3d := _make_speed_btn("3D",  "Broadcast",   _view_mode == 2)
	for b: Button in [btn2d, btn3q, btn3d]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_row.add_child(btn2d)
	view_row.add_child(btn3q)
	view_row.add_child(btn3d)
	_view_btns = [btn2d, btn3q, btn3d]
	btn2d.pressed.connect(_set_view_mode.bind(0))
	btn3q.pressed.connect(_set_view_mode.bind(1))
	btn3d.pressed.connect(_set_view_mode.bind(2))
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
	_start_btn = Button.new()
	var start_btn := _start_btn
	start_btn.text = "START MATCH"
	start_btn.custom_minimum_size = Vector2(0, 64)
	start_btn.add_theme_font_size_override("font_size", 28)
	if FontCache.bangers:
		start_btn.add_theme_font_override("font", FontCache.bangers)
	start_btn.add_theme_color_override("font_color", Color.WHITE)
	var start_sb := StyleBoxFlat.new()
	start_sb.bg_color = Color.TRANSPARENT
	start_sb.corner_radius_top_left     = 8
	start_sb.corner_radius_top_right    = 8
	start_sb.corner_radius_bottom_left  = 8
	start_sb.corner_radius_bottom_right = 8
	start_btn.add_theme_stylebox_override("normal", start_sb)
	start_btn.add_theme_stylebox_override("hover",  start_sb)
	start_btn.add_theme_stylebox_override("pressed", start_sb)

	var btn_grad := Gradient.new()
	btn_grad.colors  = PackedColorArray([Color.html("FFCC00"), Color.html("FF6600"), Color.html("FF0044")])
	btn_grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	var btn_grad_tex := GradientTexture2D.new()
	btn_grad_tex.gradient = btn_grad
	btn_grad_tex.width = 256
	btn_grad_tex.height = 1
	btn_grad_tex.fill_from = Vector2(0.0, 0.5)
	btn_grad_tex.fill_to   = Vector2(1.0, 0.5)
	var btn_bg := TextureRect.new()
	btn_bg.texture = btn_grad_tex
	btn_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	btn_bg.stretch_mode = TextureRect.STRETCH_SCALE
	btn_bg.show_behind_parent = true
	btn_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_btn.add_child(btn_bg)
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
	if _home_roster.size() != 15:
		_home_roster.clear()
		for i in range(15):
			_home_roster.append(i)
	inner.add_child(_build_roster_section())
	inner.add_child(_make_spacer(8))

	for rule_data: Array in RULES:
		inner.add_child(_make_rule_section(rule_data[0], rule_data[1], rule_data[2]))

	inner.add_child(_build_classes_section())
	inner.add_child(_make_spacer(24))
	inner.add_child(_make_section_header("MATCH HISTORY"))
	inner.add_child(_make_spacer(4))
	inner.add_child(_build_history_section())
	inner.add_child(_make_spacer(24))

# ─────────────────────────────────────────────────────────────────────────────
# State setters — update button visuals after state change
# ─────────────────────────────────────────────────────────────────────────────
func _set_match_mode(mode: int) -> void:
	_match_mode = mode
	for i in _mode_btns.size():
		_update_speed_btn(_mode_btns[i], _match_mode == i)
	var is_three := (_match_mode == 1)
	if is_instance_valid(_third_row):
		_third_row.visible = is_three
	_save_lobby_state()

func _set_view_mode(idx: int) -> void:
	_view_mode = idx
	for i in _view_btns.size():
		_update_speed_btn(_view_btns[i], _view_mode == i)
	_save_lobby_state()

func _set_fast_mode(fast: bool) -> void:
	_fast_mode = fast
	_update_speed_btn(_dur_btns[0], !_fast_mode)
	_update_speed_btn(_dur_btns[1],  _fast_mode)
	_save_lobby_state()

func _set_creature(idx: int) -> void:
	_creature = idx
	for i in _crea_btns.size():
		_update_choice_radio(_crea_btns[i], _creature == i)
	_refresh_creature_display()
	_save_lobby_state()

func _strategy_for(idx: int) -> Resource:
	match idx:
		1: return _StratNumericalEdge.new()
		2: return _StratAggressive.new()
		3: return _StratFloodEndzone.new()
		4: return _StratPossessionBleed.new()
		5: return _StratSafePass.new()
	return _StratBalanced.new()

func _tactics_for(idx: int) -> Resource:
	match idx:
		0: return _TactFocusFire.new()
		1: return _TactPickAndScreen.new()
		2: return _TactQuickRelease.new()
		3: return _TactCreatureFlank.new()
		4: return _TactWedgeRun.new()
		5: return _TactHeroBall.new()
		6: return _TactSafePass.new()
	return _TactBalanced.new()

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

func _set_players_per_side(n: int) -> void:
	_players_per_side = clampi(n, 1, 15)
	if is_instance_valid(_units_count_lbl):
		_units_count_lbl.text = str(_players_per_side)
	_rebuild_home_roster()
	_rebuild_away_roster()
	_save_lobby_state()

func _set_home_team(idx: int) -> void:
	_home_team = idx
	_home_roster.clear()
	for i in range(15):
		_home_roster.append(i)
	_rebuild_home_roster()
	_refresh_creature_display()
	_save_lobby_state()

func _set_away_team(idx: int) -> void:
	_away_team = idx
	_refresh_creature_display()
	_save_lobby_state()

func _set_third_team(idx: int) -> void:
	_third_team = idx
	_save_lobby_state()

func _set_site(idx: int) -> void:
	_site = idx
	for i in _site_btns.size():
		_update_speed_btn(_site_btns[i], _site == i)
	_refresh_creature_display()
	_save_lobby_state()

func _effective_creature_type() -> int:
	if _site == 0: return TEAMS[_home_team][2]
	if _site == 1: return TEAMS[_away_team][2]
	return _creature

func _refresh_creature_display() -> void:
	if not is_instance_valid(_creature_auto_lbl): return
	var is_neutral := (_site == 2)
	_creature_auto_lbl.visible = not is_neutral
	_neutral_crea_vbox.visible = is_neutral
	if not is_neutral:
		var ctype: int = _effective_creature_type()
		var team_name: String = TEAMS[_home_team if _site == 0 else _away_team][1]
		_creature_auto_lbl.text = "%s %s  (%s)" % [CREATURES[ctype][0], CREATURES[ctype][1], team_name]

func _make_team_option_button(current: int) -> OptionButton:
	var ob := OptionButton.new()
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ob.focus_mode = Control.FOCUS_NONE
	ob.add_theme_font_size_override("font_size", 14)
	for i in TEAMS.size():
		var t: Array = TEAMS[i]
		ob.add_item("%s  %s  ·  %s" % [t[0], t[1], CREATURES[t[2]][1]])
	ob.select(current)
	return ob

# ─────────────────────────────────────────────────────────────────────────────
# Lobby state persistence
# ─────────────────────────────────────────────────────────────────────────────
func _save_lobby_state() -> void:
	var f := ConfigFile.new()
	f.set_value("lobby", "home_team",       _home_team)
	f.set_value("lobby", "away_team",       _away_team)
	f.set_value("lobby", "third_team",      _third_team)
	f.set_value("lobby", "site",            _site)
	f.set_value("lobby", "creature",        _creature)
	f.set_value("lobby", "match_mode",      _match_mode)
	f.set_value("lobby", "fast_mode",       _fast_mode)
	f.set_value("lobby", "test_mode",       _test_mode)
	f.set_value("lobby", "view_mode",       _view_mode)
	f.set_value("lobby", "players_per_side",_players_per_side)
	f.set_value("lobby", "home_roster",     _home_roster)
	f.set_value("lobby", "inactive_classes",_inactive_classes)
	f.save(_LOBBY_SAVE_PATH)

func _load_lobby_state() -> void:
	var f := ConfigFile.new()
	if f.load(_LOBBY_SAVE_PATH) != OK:
		return
	_home_team       = f.get_value("lobby", "home_team",        _home_team)
	_away_team       = f.get_value("lobby", "away_team",        _away_team)
	_site            = f.get_value("lobby", "site",             _site)
	_creature        = f.get_value("lobby", "creature",         _creature)
	_match_mode      = f.get_value("lobby", "match_mode",       _match_mode)
	_fast_mode       = f.get_value("lobby", "fast_mode",        _fast_mode)
	_test_mode       = f.get_value("lobby", "test_mode",        _test_mode)
	_view_mode       = f.get_value("lobby", "view_mode",        _view_mode)
	_players_per_side= f.get_value("lobby", "players_per_side", _players_per_side)
	var roster: Array = f.get_value("lobby", "home_roster", [])
	if roster.size() == 15:
		_home_roster = roster
	_inactive_classes= f.get_value("lobby", "inactive_classes", _inactive_classes)
	_third_team      = f.get_value("lobby", "third_team",       _third_team)
	if is_instance_valid(_third_team_ob):
		_third_team_ob.select(_third_team)

# ─────────────────────────────────────────────────────────────────────────────
# Start match
# ─────────────────────────────────────────────────────────────────────────────
func _build_config() -> MatchConfig:
	var cfg := _MatchConfig.new()
	cfg.match_mode        = _match_mode
	cfg.fast_mode         = _fast_mode
	cfg.view_mode         = _view_mode
	cfg.creature_type     = _effective_creature_type()
	cfg.home_team_name    = TEAMS[_home_team][1]
	cfg.away_team_name    = TEAMS[_away_team][1]
	cfg.third_team_name   = TEAMS[_third_team][1]
	cfg.home_team_idx     = _home_team
	cfg.away_team_idx     = _away_team
	cfg.third_team_idx    = _third_team
	var home_names: Array[String] = []
	for idx in _home_roster:
		home_names.append(TEAMS[_home_team][3][idx])
	cfg.home_player_names  = PackedStringArray(home_names)
	cfg.away_player_names  = PackedStringArray(TEAMS[_away_team][3])
	cfg.third_player_names = PackedStringArray(TEAMS[_third_team][3])
	cfg.home_class_indices = PackedInt32Array(_home_roster)
	var away_default: Array[int] = []
	for i in 15: away_default.append(i)
	cfg.away_class_indices     = PackedInt32Array(away_default)
	cfg.is_human_controlled    = [true, false, false]
	cfg.inactive_class_indices  = PackedInt32Array(_inactive_classes)
	cfg.players_per_side        = _players_per_side
	cfg.test_mode               = _test_mode
	cfg.ai_strategy_resources   = [_strategy_for(_home_strat), _strategy_for(_opp_strat)]
	cfg.ai_tactics_resources    = [_tactics_for(_home_tact),   _tactics_for(_opp_tact)]
	if _test_mode:
		cfg.players_per_side   = 1
		cfg.away_team_name     = "TRAINING"
		cfg.away_player_names  = PackedStringArray(["Target Dummy"])
		cfg.away_class_indices = PackedInt32Array([0])
	return cfg

func _on_start_pressed() -> void:
	var cfg := _build_config()
	if _lan_mode and _lan_is_host:
		NetworkManager.sync_match_config.rpc(cfg.to_dict())
	emit_signal("match_ready", cfg)

# ── LAN multiplayer ──────────────────────────────────────────────────────────

func _build_lan_card() -> Control:
	var card := _make_card()
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	# SOLO / LAN toggle row
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 8)
	vbox.add_child(mode_row)
	_solo_btn = _make_speed_btn("SOLO", "Offline play", not _lan_mode)
	_lan_btn  = _make_speed_btn("LAN",  "Local network", _lan_mode)
	_solo_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lan_btn.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
	mode_row.add_child(_solo_btn)
	mode_row.add_child(_lan_btn)

	# LAN options sub-section
	_lan_opts = VBoxContainer.new()
	_lan_opts.add_theme_constant_override("separation", 8)
	_lan_opts.visible = _lan_mode
	vbox.add_child(_lan_opts)

	# Host / Join row
	var hj_row := HBoxContainer.new()
	hj_row.add_theme_constant_override("separation", 8)
	_lan_opts.add_child(hj_row)

	var host_btn := Button.new()
	host_btn.text = "HOST GAME"
	host_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host_btn.pressed.connect(_on_lan_host_pressed)
	hj_row.add_child(host_btn)

	var or_lbl := Label.new()
	or_lbl.text = "— or —"
	or_lbl.add_theme_color_override("font_color", C_DIM)
	or_lbl.add_theme_font_size_override("font_size", 9)
	or_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hj_row.add_child(or_lbl)

	var join_col := VBoxContainer.new()
	join_col.add_theme_constant_override("separation", 4)
	join_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hj_row.add_child(join_col)

	_lan_ip_edit = LineEdit.new()
	_lan_ip_edit.placeholder_text = "Host IP (e.g. 192.168.1.x)"
	_lan_ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_col.add_child(_lan_ip_edit)

	var join_btn := Button.new()
	join_btn.text = "JOIN GAME"
	join_btn.pressed.connect(_on_lan_join_pressed)
	join_col.add_child(join_btn)

	# Status labels
	_lan_status_lbl = Label.new()
	_lan_status_lbl.text = ""
	_lan_status_lbl.add_theme_color_override("font_color", C_DIM)
	_lan_status_lbl.add_theme_font_size_override("font_size", 10)
	_lan_opts.add_child(_lan_status_lbl)

	_lan_peer_lbl = Label.new()
	_lan_peer_lbl.text = ""
	_lan_peer_lbl.add_theme_color_override("font_color", C_FAINT)
	_lan_peer_lbl.add_theme_font_size_override("font_size", 9)
	_lan_opts.add_child(_lan_peer_lbl)

	_solo_btn.pressed.connect(_set_lan_mode.bind(false))
	_lan_btn.pressed.connect(_set_lan_mode.bind(true))

	return card

func _set_lan_mode(enable: bool) -> void:
	_lan_mode = enable
	if _lan_opts:
		_lan_opts.visible = enable
	if _solo_btn: _update_speed_btn(_solo_btn, not enable)
	if _lan_btn:  _update_speed_btn(_lan_btn, enable)
	if not enable:
		NetworkManager.go_offline()
		_lan_is_host = false
		_connected_peers = 0
		if _my_team_lbl: _my_team_lbl.visible = false
		if _start_btn:
			_start_btn.disabled = false
			_start_btn.text = "START MATCH"

func _on_lan_host_pressed() -> void:
	var err := NetworkManager.host_enet()
	if err == OK:
		_lan_is_host = true
		_connected_peers = 0
		_update_lan_status()
		if _my_team_lbl:
			_my_team_lbl.visible = true
			_my_team_lbl.text = "YOUR TEAM: HOME"
		if _start_btn:
			_start_btn.disabled = false
			_start_btn.text = "START MATCH"
	elif _lan_status_lbl:
		_lan_status_lbl.text = "Failed to host (error %d)" % err

func _on_lan_join_pressed() -> void:
	var addr: String = _lan_ip_edit.text.strip_edges() if _lan_ip_edit else ""
	if addr.is_empty():
		addr = "127.0.0.1"
	var err := NetworkManager.join_enet(addr)
	if err == OK:
		_lan_is_host = false
		if _my_team_lbl:
			_my_team_lbl.visible = true
			_my_team_lbl.text = "YOUR TEAM: AWAY"
		if _lan_status_lbl:
			_lan_status_lbl.text = "Connecting to %s:%d…" % [addr, NetworkManager.ENET_PORT]
		if _start_btn:
			_start_btn.disabled = true
			_start_btn.text = "Waiting for host…"
	elif _lan_status_lbl:
		_lan_status_lbl.text = "Join failed (error %d)" % err

func _on_net_peer_connected(id: int) -> void:
	_connected_peers += 1
	_update_lan_status()
	if NetworkManager.is_server():
		var player_id := "%d_00" % _connected_peers
		NetworkManager.register_peer_player(id, player_id)
		NetworkManager.assign_local_player.rpc_id(id, player_id)

func _on_net_peer_disconnected(_id: int) -> void:
	_connected_peers = maxi(0, _connected_peers - 1)
	_update_lan_status()

func _on_config_received(cfg: MatchConfig) -> void:
	emit_signal("match_ready", cfg)

func _update_lan_status() -> void:
	if not _lan_status_lbl:
		return
	if _lan_is_host:
		_lan_status_lbl.text = "Hosting on %s : %d" % [_get_local_ip(), NetworkManager.ENET_PORT]
		if _lan_peer_lbl:
			_lan_peer_lbl.text = "%d peer%s connected" % [
				_connected_peers,
				"s" if _connected_peers != 1 else "",
			]
	elif NetworkManager.mode == NetworkManager.NetMode.ENET_LAN:
		_lan_status_lbl.text = "Connected to host"
		if _lan_peer_lbl:
			_lan_peer_lbl.text = ""

func _get_local_ip() -> String:
	for addr in IP.get_local_addresses():
		var parts := addr.split(".")
		if parts.size() == 4 and addr != "127.0.0.1":
			return addr
	return "localhost"

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

func _make_stat_chip(label: String, value: String, color: Color, inactive: bool) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var val_lbl := Label.new()
	val_lbl.text = value
	val_lbl.add_theme_font_size_override("font_size", 11)
	val_lbl.add_theme_color_override("font_color", color.darkened(0.4) if inactive else color)
	val_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(val_lbl)
	var key_lbl := Label.new()
	key_lbl.text = label
	key_lbl.add_theme_font_size_override("font_size", 7)
	key_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.20 if inactive else 0.38))
	key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(key_lbl)
	return col

func _stat_vdivider() -> Control:
	var r := ColorRect.new()
	r.color = Color(1, 1, 1, 0.10)
	r.custom_minimum_size = Vector2(1, 18)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _ultra_gradient_bbcode(txt: String, centered: bool = false) -> String:
	var g_colors := [Color.html("FFCC00"), Color.html("FF6600"), Color.html("FF0044")]
	var g_stops  := [0.0, 0.5, 1.0]
	var n := txt.length()
	var result := "[center]" if centered else ""
	for i in n:
		var t := float(i) / float(max(1, n - 1))
		var c: Color
		if t <= g_stops[1]:
			c = (g_colors[0] as Color).lerp(g_colors[1], t / g_stops[1])
		else:
			c = (g_colors[1] as Color).lerp(g_colors[2], (t - g_stops[1]) / (g_stops[2] - g_stops[1]))
		result += "[color=#%s]%s[/color]" % [c.to_html(false), txt[i]]
	if centered:
		result += "[/center]"
	return result

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

	_away_roster_vbox = VBoxContainer.new()
	_away_roster_vbox.add_theme_constant_override("separation", 2)
	away_col.add_child(_away_roster_vbox)
	_rebuild_away_roster()

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
	if not is_instance_valid(_home_roster_vbox): return
	for child in _home_roster_vbox.get_children():
		_home_roster_vbox.remove_child(child)
		child.queue_free()
	_drag_slot_panels.clear()
	for slot in range(15):
		if slot == _players_per_side:
			_home_roster_vbox.add_child(_make_roster_divider())
		var panel := _make_roster_row(slot, _home_roster[slot], true)
		_home_roster_vbox.add_child(panel)
		_drag_slot_panels.append(panel)

func _rebuild_away_roster() -> void:
	if not is_instance_valid(_away_roster_vbox): return
	for child in _away_roster_vbox.get_children():
		_away_roster_vbox.remove_child(child)
		child.queue_free()
	for slot in range(15):
		if slot == _players_per_side:
			_away_roster_vbox.add_child(_make_roster_divider())
		_away_roster_vbox.add_child(_make_roster_row(slot, slot, false))


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
	var class_idx  : int    = player_idx % CLASS_NAMES.size()
	var cls_color  : Color  = CLASS_COLORS[class_idx]
	var cls_name   : String = CLASS_NAMES[class_idx]
	var is_field   : bool   = slot_idx < _players_per_side
	var slot_label : String = ("FIELD " + str(slot_idx + 1)) if is_field else ("RES " + str(slot_idx - _players_per_side + 1))
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
	var class_idx  : int    = player_idx % CLASS_NAMES.size()
	var cls_color  : Color  = CLASS_COLORS[class_idx]
	var cls_name   : String = CLASS_NAMES[class_idx]
	var is_field   : bool   = slot_idx < _players_per_side
	var slot_label : String = ("FIELD " + str(slot_idx + 1)) if is_field else ("RES " + str(slot_idx - _players_per_side + 1))

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


# ── Settings overlay ─────────────────────────────────────────────────────────

func _open_settings() -> void:
	if is_instance_valid(_settings_overlay):
		return
	_settings_overlay = _build_settings_overlay()
	add_child(_settings_overlay)

func _close_settings() -> void:
	if is_instance_valid(_settings_overlay):
		_settings_overlay.queue_free()
	_settings_overlay = null

func _build_settings_overlay() -> Control:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 20

	# Dim backdrop — click outside card to close
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
			_close_settings()
	)
	overlay.add_child(dim)

	# Centered card
	var card := _make_card()
	card.custom_minimum_size = Vector2(500, 0)
	card.anchor_left  = 0.5; card.anchor_right  = 0.5
	card.anchor_top   = 0.5; card.anchor_bottom = 0.5
	card.offset_left  = -250; card.offset_right  = 250
	card.offset_top   = -220; card.offset_bottom = 220
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	card.add_child(vbox)

	# Header row with close button
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	vbox.add_child(title_row)

	var title_lbl := Label.new()
	title_lbl.text = "⚙  SETTINGS"
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", C_GOLD)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.add_theme_color_override("font_color", C_DIM)
	close_btn.pressed.connect(_close_settings)
	title_row.add_child(close_btn)

	vbox.add_child(_make_divider())

	# ── Ability hotkey display ─────────────────────────────────────────────────
	vbox.add_child(_make_field_label("ABILITY HOTKEY DISPLAY"))
	vbox.add_child(_make_hint("Controls how ability slots appear in the HUD during gameplay"))
	vbox.add_child(_make_spacer(4))

	var style_row := HBoxContainer.new()
	style_row.add_theme_constant_override("separation", 8)
	vbox.add_child(style_row)

	var style_names := ["DETAILED", "COMPACT", "MINIMAL"]
	var style_descs := ["Key + name + timer", "Key + timer", "Key only"]
	var style_btns: Array = []
	for i in style_names.size():
		var btn := _make_speed_btn(style_names[i], style_descs[i], GameSettings.hotkey_style == i)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		style_row.add_child(btn)
		style_btns.append(btn)
		var idx := i
		btn.pressed.connect(func() -> void:
			GameSettings.hotkey_style = idx
			GameSettings.save_settings()
			for j in style_btns.size():
				_update_speed_btn(style_btns[j], GameSettings.hotkey_style == j)
		)

	vbox.add_child(_make_divider())

	# ── Ball possession cooldown ───────────────────────────────────────────────
	vbox.add_child(_make_field_label("BALL POSSESSION COOLDOWN"))
	vbox.add_child(_make_hint("Seconds a player must wait before picking up the ball after losing possession"))
	vbox.add_child(_make_spacer(4))

	var cd_row := HBoxContainer.new()
	cd_row.add_theme_constant_override("separation", 10)
	vbox.add_child(cd_row)

	var cd_minus := Button.new()
	cd_minus.text = "−"
	cd_minus.custom_minimum_size = Vector2(36, 36)
	cd_minus.focus_mode = Control.FOCUS_NONE
	cd_row.add_child(cd_minus)

	var cd_val_lbl := Label.new()
	cd_val_lbl.text = "%.0fs" % GameSettings.ball_possession_cooldown
	cd_val_lbl.custom_minimum_size = Vector2(48, 0)
	cd_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd_val_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cd_val_lbl.add_theme_font_size_override("font_size", 18)
	cd_val_lbl.add_theme_color_override("font_color", Color.WHITE)
	cd_row.add_child(cd_val_lbl)

	var cd_plus := Button.new()
	cd_plus.text = "+"
	cd_plus.custom_minimum_size = Vector2(36, 36)
	cd_plus.focus_mode = Control.FOCUS_NONE
	cd_row.add_child(cd_plus)

	var cd_hint := Label.new()
	cd_hint.text = "(0 = disabled)"
	cd_hint.add_theme_color_override("font_color", C_DIM)
	cd_hint.add_theme_font_size_override("font_size", 10)
	cd_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cd_row.add_child(cd_hint)

	cd_minus.pressed.connect(func() -> void:
		GameSettings.ball_possession_cooldown = maxf(0.0, GameSettings.ball_possession_cooldown - 1.0)
		cd_val_lbl.text = "%.0fs" % GameSettings.ball_possession_cooldown
		GameSettings.save_settings()
	)
	cd_plus.pressed.connect(func() -> void:
		GameSettings.ball_possession_cooldown = minf(30.0, GameSettings.ball_possession_cooldown + 1.0)
		cd_val_lbl.text = "%.0fs" % GameSettings.ball_possession_cooldown
		GameSettings.save_settings()
	)

	vbox.add_child(_make_divider())

	# ── Instant self-heal ──────────────────────────────────────────────────────
	vbox.add_child(_make_field_label("INSTANT SELF-HEAL"))
	vbox.add_child(_make_hint("Self-healing abilities fire immediately on cast, bypassing the ability queue and global cooldown"))
	vbox.add_child(_make_spacer(4))

	var ish_row := HBoxContainer.new()
	ish_row.add_theme_constant_override("separation", 8)
	vbox.add_child(ish_row)

	var ish_on_btn  := _make_speed_btn("ON",  "Heals fire instantly", GameSettings.instant_self_heal)
	var ish_off_btn := _make_speed_btn("OFF", "Heals join the queue", not GameSettings.instant_self_heal)
	ish_on_btn.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
	ish_off_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ish_row.add_child(ish_on_btn)
	ish_row.add_child(ish_off_btn)

	ish_on_btn.pressed.connect(func() -> void:
		GameSettings.instant_self_heal = true
		GameSettings.save_settings()
		_update_speed_btn(ish_on_btn, true)
		_update_speed_btn(ish_off_btn, false)
	)
	ish_off_btn.pressed.connect(func() -> void:
		GameSettings.instant_self_heal = false
		GameSettings.save_settings()
		_update_speed_btn(ish_on_btn, false)
		_update_speed_btn(ish_off_btn, true)
	)

	return overlay

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
		_save_lobby_state()
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
	var cls_id    : String = GameRegistry.CLASS_IDS[class_idx]
	var cls_def   : ClassDefinition = GameRegistry.get_class_definition(cls_id)

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

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	panel.add_child(outer)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	outer.add_child(row)

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

	# Stats row
	outer.add_child(_make_spacer(6))
	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 12)
	stats_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(stats_row)
	if cls_def != null:
		const PM_NAMES  := ["RED", "BLUE", "YELLOW"]
		const PM_COLORS := [Color(0.92, 0.22, 0.22), Color(0.35, 0.55, 1.00), Color(0.90, 0.80, 0.10)]
		var pm := clampi(cls_def.primary_mana, 0, 2)
		stats_row.add_child(_make_stat_chip("HP",      "%d" % int(cls_def.max_health),   Color(0.20, 0.85, 0.20), inactive))
		stats_row.add_child(_stat_vdivider())
		stats_row.add_child(_make_stat_chip("SPD",     "%.1f" % cls_def.base_speed,      Color(0.90, 0.80, 0.10), inactive))
		stats_row.add_child(_stat_vdivider())
		stats_row.add_child(_make_stat_chip("PRIMARY", PM_NAMES[pm],                     PM_COLORS[pm],           inactive))
		stats_row.add_child(_stat_vdivider())
		stats_row.add_child(_make_stat_chip("R",       "%.1f/s" % cls_def.red_regen,     Color(0.92, 0.22, 0.22), inactive))
		stats_row.add_child(_make_stat_chip("B",       "%.1f/s" % cls_def.blue_regen,    Color(0.35, 0.55, 1.00), inactive))
		stats_row.add_child(_make_stat_chip("Y",       "%.1f/s" % cls_def.yellow_regen,  Color(0.90, 0.80, 0.10), inactive))
	outer.add_child(_make_spacer(4))

	# Collapsible abilities list
	outer.add_child(_build_class_ability_section(class_idx, cls_color, inactive))

	return panel


func _toggle_class(class_idx: int) -> void:
	if _inactive_classes.has(class_idx):
		_inactive_classes.erase(class_idx)
	else:
		_inactive_classes.append(class_idx)
	_save_lobby_state()
	# Replace only the affected card in-place
	# Path: toggle → row (HBox) → outer (VBox) → panel (PanelContainer)
	var btn   : Button  = _class_btns[class_idx]
	var card  : Control = btn.get_parent().get_parent().get_parent()
	var vbox  : Control = card.get_parent()
	var idx   : int     = card.get_index()
	vbox.remove_child(card)
	card.queue_free()
	_class_btns[class_idx] = null   # will be re-set in _make_class_card
	var new_card := _make_class_card(class_idx)
	vbox.add_child(new_card)
	vbox.move_child(new_card, idx)


func _build_class_ability_section(class_idx: int, cls_color: Color, inactive: bool) -> Control:
	const MANA_COLORS := [
		Color(0.55, 0.55, 0.55),   # 0 = None / FREE
		Color(0.95, 0.30, 0.30),   # 1 = Red
		Color(0.35, 0.55, 1.00),   # 2 = Blue
		Color(0.90, 0.80, 0.10),   # 3 = Yellow
		Color(0.75, 0.25, 0.90),   # 4 = Ultra
	]
	const MANA_LABELS := ["FREE", "RED", "BLU", "YEL", "ULT"]

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)

	# Clickable "ABILITIES ▶" toggle header
	var hdr := HBoxContainer.new()
	hdr.mouse_filter = Control.MOUSE_FILTER_STOP
	hdr.add_theme_constant_override("separation", 6)
	outer.add_child(hdr)

	var spacer := ColorRect.new()
	spacer.color = Color.TRANSPARENT
	spacer.custom_minimum_size = Vector2(4, 0)
	hdr.add_child(spacer)

	var hdr_arrow := Label.new()
	hdr_arrow.text = "▶"
	hdr_arrow.add_theme_font_size_override("font_size", 8)
	hdr_arrow.add_theme_color_override("font_color", Color(1, 1, 1, 0.28))
	hdr_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr.add_child(hdr_arrow)

	var hdr_lbl := Label.new()
	hdr_lbl.text = "ABILITIES"
	hdr_lbl.add_theme_font_size_override("font_size", 8)
	hdr_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.28))
	hdr_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr.add_child(hdr_lbl)

	# The ability list (hidden by default)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 1)
	list.visible = false
	outer.add_child(list)

	# Separator line above list
	var sep_margin := MarginContainer.new()
	for side in ["left", "top", "bottom"]:
		sep_margin.add_theme_constant_override("margin_" + side, 4)
	sep_margin.visible = false
	outer.add_child(sep_margin)

	var sep_line := ColorRect.new()
	sep_line.color = Color(1, 1, 1, 0.08)
	sep_line.custom_minimum_size.y = 1
	sep_margin.add_child(sep_line)

	# Populate ability rows
	var class_id: String = GameRegistry.CLASS_IDS[class_idx]
	for slot in range(1, 11):
		var ability: AbilityDefinition = GameRegistry.get_ability(class_id, slot)
		if ability == null:
			continue

		var key_text := "U" if slot == 10 else str(slot)
		var mtype := clampi(ability.mana_type, 0, 4)
		var mana_str: String
		if ability.mana_cost <= 0.0 or mtype == 0:
			mana_str = "FREE"
		else:
			mana_str = "%d %s" % [int(ability.mana_cost), MANA_LABELS[mtype]]
		var cd_str    := "%.0fs" % ability.cooldown if ability.cooldown > 0.0 else "—"
		var range_str := "%.0fm" % ability.range   if ability.range    > 0.0 else "—"

		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		list.add_child(row)

		var top_row := HBoxContainer.new()
		top_row.add_theme_constant_override("separation", 5)
		row.add_child(top_row)

		var key_lbl := Label.new()
		key_lbl.text = "[%s]" % key_text
		key_lbl.custom_minimum_size.x = 24
		key_lbl.add_theme_font_size_override("font_size", 9)
		key_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.28))
		top_row.add_child(key_lbl)

		var name_lbl := Label.new()
		name_lbl.text = ability.display_name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 9)
		name_lbl.add_theme_color_override("font_color",
			Color(cls_color.r, cls_color.g, cls_color.b, 0.35) if inactive else Color(0.92, 0.92, 0.92))
		top_row.add_child(name_lbl)

		var mana_lbl := Label.new()
		mana_lbl.text = mana_str
		mana_lbl.custom_minimum_size.x = 52
		mana_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		mana_lbl.add_theme_font_size_override("font_size", 9)
		mana_lbl.add_theme_color_override("font_color",
			MANA_COLORS[mtype].darkened(0.35) if inactive else MANA_COLORS[mtype])
		top_row.add_child(mana_lbl)

		var range_lbl := Label.new()
		range_lbl.text = range_str
		range_lbl.custom_minimum_size.x = 28
		range_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		range_lbl.add_theme_font_size_override("font_size", 9)
		range_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.28))
		top_row.add_child(range_lbl)

		var cd_lbl := Label.new()
		cd_lbl.text = cd_str
		cd_lbl.custom_minimum_size.x = 28
		cd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cd_lbl.add_theme_font_size_override("font_size", 9)
		cd_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.28))
		top_row.add_child(cd_lbl)

		if not ability.description.is_empty():
			var desc_lbl := Label.new()
			desc_lbl.text = ability.description
			desc_lbl.add_theme_font_size_override("font_size", 8)
			desc_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.38))
			desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			# Indent to align with name column
			var dm := MarginContainer.new()
			dm.add_theme_constant_override("margin_left", 29)
			dm.add_child(desc_lbl)
			row.add_child(dm)

	hdr.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var open := not list.visible
			list.visible = open
			sep_margin.visible = open
			hdr_arrow.text = "▼" if open else "▶"
	)

	return outer

# ── Match history ─────────────────────────────────────────────────────────────

func _build_history_section() -> Control:
	var reports: Array = MatchReportSaver.load_all()

	if reports.is_empty():
		var lbl := Label.new()
		lbl.text = "No saved matches yet."
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", C_FAINT)
		return lbl

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	for report in reports:
		var row := _make_history_row(report)
		vbox.add_child(row)

	return vbox

func _make_history_row(report: Dictionary) -> Control:
	var card := _make_card()
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	card.add_child(hbox)

	# Score
	var score_lbl := Label.new()
	var hs: int = report.get("final_home_score", 0)
	var as_: int = report.get("final_away_score", 0)
	score_lbl.text = "%d – %d" % [hs, as_]
	score_lbl.add_theme_font_size_override("font_size", 13)
	score_lbl.add_theme_color_override("font_color", C_GOLD)
	score_lbl.custom_minimum_size.x = 60
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(score_lbl)

	# Teams
	var teams_col := VBoxContainer.new()
	teams_col.add_theme_constant_override("separation", 1)
	teams_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(teams_col)

	var home_lbl := Label.new()
	home_lbl.text = report.get("home_team_name", "HOME")
	home_lbl.add_theme_font_size_override("font_size", 10)
	home_lbl.add_theme_color_override("font_color", Color(1.0, 0.231, 0.325))
	teams_col.add_child(home_lbl)

	var vs_lbl := Label.new()
	vs_lbl.text = "vs  " + report.get("away_team_name", "AWAY")
	vs_lbl.add_theme_font_size_override("font_size", 10)
	vs_lbl.add_theme_color_override("font_color", Color(0.184, 0.514, 1.0))
	teams_col.add_child(vs_lbl)

	# Date
	var ts: int = int(report.get("timestamp", 0))
	var date_lbl := Label.new()
	var dt := Time.get_datetime_dict_from_unix_time(ts)
	date_lbl.text = "%04d-%02d-%02d" % [dt["year"], dt["month"], dt["day"]]
	date_lbl.add_theme_font_size_override("font_size", 9)
	date_lbl.add_theme_color_override("font_color", C_FAINT)
	date_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(date_lbl)

	# VIEW button
	var view_btn := Button.new()
	view_btn.text = "VIEW"
	view_btn.custom_minimum_size.x = 56
	view_btn.pressed.connect(_show_match_report.bind(report))
	hbox.add_child(view_btn)

	return card

func _show_match_report(report: Dictionary) -> void:
	if is_instance_valid(_report_overlay):
		_report_overlay.queue_free()

	_report_overlay = Control.new()
	_report_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_report_overlay)

	# Dim background
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_report_overlay.add_child(bg)

	# Content panel
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(900, 560)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical   = Control.GROW_DIRECTION_BOTH
	_report_overlay.add_child(panel)

	var outer_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		outer_margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(outer_margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	outer_margin.add_child(vbox)

	# Title bar
	var title_row := HBoxContainer.new()
	vbox.add_child(title_row)

	var title_lbl := Label.new()
	var hs: int  = report.get("final_home_score", 0)
	var as_: int = report.get("final_away_score", 0)
	title_lbl.text = "%s  %d – %d  %s" % [
		report.get("home_team_name", "HOME"), hs, as_,
		report.get("away_team_name", "AWAY"),
	]
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", C_GOLD)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕  CLOSE"
	close_btn.pressed.connect(func() -> void:
		if is_instance_valid(_report_overlay):
			_report_overlay.queue_free()
			_report_overlay = null
	)
	title_row.add_child(close_btn)

	# Animated replay player
	var replay := preload("res://systems/MatchReplayPlayer.gd").new()
	replay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	replay.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	replay.custom_minimum_size   = Vector2(860, 460)
	vbox.add_child(replay)
	replay.setup(report)

func _report_hex_vals(report: Dictionary, tid: int) -> PackedFloat32Array:
	var kills := 0; var dmg := 0.0; var heal := 0.0
	var ball_time := 0.0; var carries := 0; var points := 0
	var kills_max := 1; var dmg_max := 1.0; var heal_max := 1.0
	var bt_max := 1.0; var carries_max := 1; var pts_max := 1

	for p in report.get("players", []):
		var st: Dictionary = p.get("stats", {})
		var k: int   = st.get("kills", 0)
		var d: float = st.get("dmg", 0.0)
		var h: float = st.get("heal", 0.0)
		var bt: float = st.get("ball_time", 0.0)
		var ca: int  = st.get("ball_carries", 0)
		var pt: int  = st.get("points", 0)
		kills_max   = maxi(kills_max, k)
		dmg_max     = maxf(dmg_max, d)
		heal_max    = maxf(heal_max, h)
		bt_max      = maxf(bt_max, bt)
		carries_max = maxi(carries_max, ca)
		pts_max     = maxi(pts_max, pt)

	for p in report.get("players", []):
		if p["team_id"] != tid:
			continue
		var st: Dictionary = p.get("stats", {})
		kills     += st.get("kills", 0)
		dmg       += st.get("dmg", 0.0)
		heal      += st.get("heal", 0.0)
		ball_time += st.get("ball_time", 0.0)
		carries   += st.get("ball_carries", 0)
		points    += st.get("points", 0)

	return PackedFloat32Array([
		clampf(float(kills)     / float(kills_max   * 2), 0.0, 1.0),
		clampf(dmg              / (dmg_max   * 2.0),       0.0, 1.0),
		clampf(heal             / (heal_max  * 2.0),       0.0, 1.0),
		clampf(ball_time        / (bt_max    * 2.0),       0.0, 1.0),
		clampf(float(carries)   / float(carries_max * 2), 0.0, 1.0),
		clampf(float(points)    / float(pts_max    * 2), 0.0, 1.0),
	])
