extends Control

## Large centered event message overlay for ULTRA!, META!, KILLA!, QUEUE FULL, etc.
## Listens on EventBus; displays with a fade-in / hold / fade-out tween.

const MSG_COLORS: Dictionary = {
	"ULTRA!":     Color(0.00, 0.90, 1.00),   # cyan
	"META!":      Color(1.00, 0.80, 0.10),   # gold
	"KILLA!":     Color(1.00, 0.25, 0.15),   # red-orange
	"QUEUE FULL": Color(1.00, 0.55, 0.05),   # amber
}
const DEFAULT_COLOR := Color(1.0, 1.0, 1.0)
const FONT_SIZE     := 52

var _label : Label
var _tween : Tween

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index      = 20

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	if FontCache.combat() != null:
		_label.add_theme_font_override("font", FontCache.combat())
	_label.modulate.a = 0.0
	_label.z_index    = 20
	add_child(_label)

	EventBus.event_message_shown.connect(_on_event_message)
	EventBus.ultra_scored.connect(func(_t, _s): _show("ULTRA!", 1.8))
	EventBus.meta_scored.connect(func(_t, _s): _show("META!", 1.8))
	EventBus.killa_scored.connect(func(_t, _k, _v): _show("KILLA!", 1.4))

func _on_event_message(message: String, duration: float) -> void:
	_show(message, duration)

func _show(message: String, duration: float) -> void:
	_label.text = message
	_label.add_theme_color_override("font_color",
		MSG_COLORS.get(message, DEFAULT_COLOR))
	const LW := 800.0
	const LH := 120.0
	const SCOREBOARD_BOTTOM := 80.0 + 3.0 + 55.0   # BAR_H + gap + CARDS_H
	_label.size     = Vector2(LW, LH)
	var vp := get_viewport_rect().size
	_label.position = Vector2((vp.x - LW) * 0.5, SCOREBOARD_BOTTOM + 16.0)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_label, "modulate:a", 1.0, 0.10)
	_tween.tween_interval(duration * 0.6)
	_tween.tween_property(_label, "modulate:a", 0.0, duration * 0.4)
