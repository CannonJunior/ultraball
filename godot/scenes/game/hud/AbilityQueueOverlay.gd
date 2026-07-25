extends Control

## World-tracking overlay that renders the local player's ability queue above their
## sprite.  Waiting abilities appear in white; each ability transitions to yellow
## and fades over QUEUE_EXIT_DURATION seconds as it executes.
##
## Layout (above player, Flutter parity):
##   [ExitingA] > [ExitingB] > [WaitingC] > [WaitingD] ...
##   Exiting entries: yellow (#ffdc3c), alpha proportional to remaining timer.
##   Separator " > ": inherits alpha of the exiting entry to its left.
##   Waiting entries: white at 70% alpha (#ffffffb3); dimmed to 38% if on cooldown.
##
## Font: Bangers (matches Flutter combatFontFamily default), 18px, letter-spacing 2.

const QUEUE_EXIT_DURATION := 1.0   # seconds the yellow fade lasts
const QUEUE_FONT_SIZE     := 18    # matches Flutter queueFontSz baseline (18.0 * scale=1)
const Y_OFFSET            := -52.0 # screen-px above projected player centre

var _exiting: Array = []          # Array of {name:String, timer:float}
var _waiting: Array = []          # current queue (Array of int slot numbers)
var _slot_names: Dictionary = {}  # slot (int) -> display name String (upper-cased)
var _cached_class_id: String = ""
var _last_pid: String = ""
var _prev_queue_front: int = -1   # slot that was at front before last queue shrink

var _label: RichTextLabel

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 15

	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content    = true
	_label.scroll_active  = false
	_label.autowrap_mode  = TextServer.AUTOWRAP_OFF
	_label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_label.add_theme_stylebox_override("focus",  StyleBoxEmpty.new())
	_label.add_theme_font_size_override("normal_font_size", QUEUE_FONT_SIZE)
	_label.add_theme_font_size_override("bold_font_size",   QUEUE_FONT_SIZE)
	var fnt := FontCache.combat()
	if fnt != null:
		_label.add_theme_font_override("normal_font", fnt)
		_label.add_theme_font_override("bold_font",   fnt)
	_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.88))
	_label.add_theme_constant_override("shadow_offset_x",    1)
	_label.add_theme_constant_override("shadow_offset_y",    1)
	_label.add_theme_constant_override("shadow_outline_size", 3)
	_label.modulate.a = 0.0
	add_child(_label)

	EventBus.ability_queue_changed.connect(_on_queue_changed)
	EventBus.ability_resolved.connect(_on_ability_resolved)

func _process(delta: float) -> void:
	# Tick and prune exiting entries
	for i in range(_exiting.size() - 1, -1, -1):
		_exiting[i]["timer"] -= delta
		if _exiting[i]["timer"] <= 0.0:
			_exiting.remove_at(i)

	var player := _local_player()
	if player == null:
		_label.modulate.a = 0.0
		return

	_sync_class(player)

	if _waiting.is_empty() and _exiting.is_empty():
		_label.modulate.a = 0.0
		return

	_refresh_label(player)
	_label.modulate.a = 1.0

	# Project world position → screen coords, then shift upward.
	# Use 3D camera projection in perspective modes; canvas transform in flat-2D.
	var screen_pos: Vector2
	var vl3d := get_tree().get_first_node_in_group("view_layer_3d")
	if vl3d != null:
		screen_pos = vl3d.world_to_screen(player.global_position, 2.6)
	else:
		screen_pos = get_viewport().get_canvas_transform() * player.global_position
	_label.position = Vector2(
		screen_pos.x - _label.size.x * 0.5,
		screen_pos.y + Y_OFFSET - _label.size.y)

# ── Label content ─────────────────────────────────────────────────────────────

func _refresh_label(player: Node) -> void:
	var bb := ""

	for i in _exiting.size():
		var e: Dictionary = _exiting[i]
		var a := clampf(e["timer"] / QUEUE_EXIT_DURATION, 0.0, 1.0)
		# Yellow #ffdc3c matches Flutter Color.fromRGBO(255, 220, 60, a)
		bb += "[color=#%s]%s[/color]" % [Color(1.00, 0.863, 0.235, a).to_html(true), e["name"]]
		if i < _exiting.size() - 1 or not _waiting.is_empty():
			bb += "[color=#%s] > [/color]" % Color(1.0, 1.0, 1.0, a * 0.7).to_html(true)

	var abilities_node = player.get_node_or_null("PlayerAbilities")
	for i in _waiting.size():
		if i > 0 or not _exiting.is_empty():
			bb += "[color=#ffffffb3] > [/color]"
		var slot: int = _waiting[i]
		# Dim to 38% alpha if the slot is on cooldown (matches Flutter 0x61FFFFFF)
		var on_cd: bool = abilities_node != null and (abilities_node.get_cooldown(slot) as float) > 0.05
		var col := "[color=#ffffff61]" if on_cd else "[color=#ffffffb3]"
		bb += "%s%s[/color]" % [col, _slot_name(slot)]

	_label.text = bb

# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_queue_changed(player_id: String, queue: Array) -> void:
	var local_p := _local_player()
	if local_p == null or local_p.player_id != player_id:
		return
	# Record which slot left the front so we can match it in ability_resolved
	if not _waiting.is_empty():
		var old_front: int = _waiting[0]
		if queue.is_empty() or queue[0] != old_front:
			_prev_queue_front = old_front
	_waiting = queue.duplicate()

func _on_ability_resolved(caster_id: String, slot: int, _hit_ids: Array) -> void:
	var local_p := _local_player()
	if local_p == null or local_p.player_id != caster_id:
		return
	# Only yellow-fade abilities that came from the queue
	if slot != _prev_queue_front:
		return
	_exiting.append({"name": _slot_name(slot), "timer": QUEUE_EXIT_DURATION})
	_prev_queue_front = -1

# ── Helpers ───────────────────────────────────────────────────────────────────

func _slot_name(slot: int) -> String:
	return _slot_names.get(slot, "SLOT %d" % slot)

func _sync_class(player: Node) -> void:
	if player.player_id != _last_pid:
		_last_pid = player.player_id
		_cached_class_id = ""
		_slot_names.clear()
		_waiting.clear()
		_exiting.clear()
		_prev_queue_front = -1

	var rec: MatchState.PlayerRecord = MatchState.players.get(player.player_id)
	if rec == null or rec.class_id == _cached_class_id:
		return

	_cached_class_id = rec.class_id
	_slot_names.clear()
	for slot in range(1, 11):
		var ab: AbilityDefinition = GameRegistry.get_ability(rec.class_id, slot)
		if ab != null:
			_slot_names[slot] = ab.display_name.to_upper()

func _local_player() -> Node:
	var pid := NetworkManager.local_player_id
	if not pid.is_empty():
		for n in get_tree().get_nodes_in_group("players"):
			if n.player_id == pid and n.is_alive and n.is_on_field:
				return n
		return null
	for n in get_tree().get_nodes_in_group("players"):
		if n.get("team_id") == 0 and n.is_alive and n.is_on_field:
			return n
	return null
