extends Node

## 40 pooled floating labels for damage / heal / killa text.

const POOL_SIZE     := 40
const FLOAT_SPEED   := 22.0   # px/s upward
const FADE_DURATION := 1.3    # seconds

const TYPE_COLORS := {
	"dmg":   Color(1.00, 0.30, 0.30),
	"heal":  Color(0.25, 1.00, 0.40),
	"killa": Color(1.00, 0.80, 0.10),
	"miss":  Color(0.60, 0.60, 0.60),
	"crit":  Color(1.00, 1.00, 0.25),
	"ultra": Color(0.90, 0.35, 1.00),
}

# Each entry: {label: Label, active: bool, vel: Vector2, age: float}
var _pool: Array = []

func _ready() -> void:
	for _i in POOL_SIZE:
		var lbl := Label.new()
		lbl.visible = false
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.z_index = 10
		add_child(lbl)
		_pool.append({"label": lbl, "active": false,
					  "vel": Vector2.ZERO, "age": 0.0})
	EventBus.damage_indicator_spawned.connect(_on_spawned)

func _process(delta: float) -> void:
	for entry in _pool:
		if not entry["active"]: continue
		entry["age"] += delta
		var t: float = entry["age"] / FADE_DURATION
		if t >= 1.0:
			entry["label"].visible = false
			entry["active"] = false
			continue
		entry["label"].position += entry["vel"] * delta
		entry["label"].modulate.a = 1.0 - t

func _on_spawned(world_pos: Vector2, text: String, indicator_type: String) -> void:
	var entry := _claim_entry()
	var lbl: Label = entry["label"]
	lbl.text = text
	lbl.add_theme_color_override("font_color",
		TYPE_COLORS.get(indicator_type, Color.WHITE))
	# World → screen conversion via canvas transform
	var screen_pos := get_viewport().get_canvas_transform() * world_pos
	lbl.position = screen_pos + Vector2(randf_range(-12.0, 12.0), -8.0)
	entry["vel"] = Vector2(randf_range(-4.0, 4.0), -FLOAT_SPEED)
	entry["age"] = 0.0
	entry["active"] = true
	lbl.modulate.a = 1.0
	lbl.visible = true

func _claim_entry() -> Dictionary:
	for entry in _pool:
		if not entry["active"]: return entry
	# Pool full: recycle the oldest active entry
	var oldest: Dictionary = _pool[0]
	for entry in _pool:
		if entry["age"] > oldest["age"]:
			oldest = entry
	return oldest
