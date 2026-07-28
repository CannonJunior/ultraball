extends Node
## Persistent user preferences. Access via the GameSettings autoload singleton.

## Ability slot display style.
##   HOTKEY_DETAILED — key label + ability name + cooldown timer
##   HOTKEY_COMPACT  — key label + cooldown timer (no name)
##   HOTKEY_MINIMAL  — key label only; cooldown indicated by panel dimming
const HOTKEY_DETAILED := 0
const HOTKEY_COMPACT  := 1
const HOTKEY_MINIMAL  := 2

var hotkey_style: int = HOTKEY_DETAILED

## Seconds a player must wait before picking up the ball after losing possession.
var ball_possession_cooldown: float = 6.0

const _SAVE_PATH := "user://settings.cfg"

func _ready() -> void:
	_load()

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("hud", "hotkey_style", hotkey_style)
	cfg.set_value("gameplay", "ball_possession_cooldown", ball_possession_cooldown)
	cfg.save(_SAVE_PATH)

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_SAVE_PATH) != OK:
		return
	hotkey_style = cfg.get_value("hud", "hotkey_style", HOTKEY_DETAILED)
	ball_possession_cooldown = cfg.get_value("gameplay", "ball_possession_cooldown", 6.0)
