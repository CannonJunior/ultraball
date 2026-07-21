class_name PlayerMana
extends Node

## Four mana pools with regen. Mana types match AbilityDefinition.mana_type enum.
## 0=None 1=Red 2=Blue 3=Yellow 4=Ultra

const MAX_RED := 100.0
const MAX_BLUE := 100.0
const MAX_YELLOW := 100.0
const MAX_ULTRA := 10.0

var red: float = 100.0
var blue: float = 100.0
var yellow: float = 100.0
var ultra: float = 0.0

var _red_regen: float = 3.0
var _blue_regen: float = 4.0
var _yellow_regen: float = 3.0

## Yellow regens faster when holding the ball.
var is_holding_ball: bool = false

func _ready() -> void:
	var player := get_parent()
	if player and player.class_definition:
		_red_regen = player.class_definition.red_regen
		_blue_regen = player.class_definition.blue_regen
		_yellow_regen = player.class_definition.yellow_regen
	EventBus.ball_picked_up.connect(_on_ball_picked_up)
	EventBus.ball_dropped.connect(_on_ball_dropped)

func _process(delta: float) -> void:
	red = minf(MAX_RED, red + _red_regen * delta)
	blue = minf(MAX_BLUE, blue + _blue_regen * delta)
	var yellow_rate := _yellow_regen * (2.0 if is_holding_ball else 1.0)
	yellow = minf(MAX_YELLOW, yellow + yellow_rate * delta)
	# Ultra does not regen passively

func can_afford(mana_type: int, cost: float) -> bool:
	match mana_type:
		0: return true         # None
		1: return red >= cost
		2: return blue >= cost
		3: return yellow >= cost
		4: return ultra >= cost
	return true

func deduct(mana_type: int, cost: float) -> void:
	match mana_type:
		1: red -= cost
		2: blue -= cost
		3: yellow -= cost
		4: ultra -= cost

## mana_type uses ManaDrainEffect enum: 0=Red, 1=Blue, 2=Yellow, 3=All
func drain(mana_type: int, amount: float) -> void:
	match mana_type:
		0: red = maxf(0.0, red - amount)
		1: blue = maxf(0.0, blue - amount)
		2: yellow = maxf(0.0, yellow - amount)
		3:
			red = maxf(0.0, red - amount)
			blue = maxf(0.0, blue - amount)
			yellow = maxf(0.0, yellow - amount)

func add_ultra(amount: float) -> void:
	ultra = minf(MAX_ULTRA, ultra + amount)

func restore(mana_type: int, amount: float) -> void:
	match mana_type:
		0: red = minf(MAX_RED, red + amount)
		1: blue = minf(MAX_BLUE, blue + amount)
		2: yellow = minf(MAX_YELLOW, yellow + amount)
		3:
			red = minf(MAX_RED, red + amount)
			blue = minf(MAX_BLUE, blue + amount)
			yellow = minf(MAX_YELLOW, yellow + amount)

func _on_ball_picked_up(pid: String) -> void:
	var player := get_parent()
	if player and player.player_id == pid:
		is_holding_ball = true

func _on_ball_dropped(_pos: Vector2, _cause: String) -> void:
	var player := get_parent()
	if player and MatchState.ball.holder_id != player.player_id:
		is_holding_ball = false
