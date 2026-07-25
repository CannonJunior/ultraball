extends Node

const GAME_SCENE    := preload("res://scenes/game/GameScene.tscn")
const _NetworkLobby := preload("res://scenes/menus/NetworkLobby.gd")

var _lobby: Control = null
var _game: Node = null

func _ready() -> void:
	EventBus.exit_to_lobby_requested.connect(_on_exit_to_lobby)
	_show_lobby()

func _show_lobby() -> void:
	_lobby = _NetworkLobby.new()
	_lobby.match_ready.connect(_on_match_ready)
	add_child(_lobby)

func _on_match_ready(config: MatchConfig) -> void:
	if _lobby:
		_lobby.queue_free()
		_lobby = null
	_game = GAME_SCENE.instantiate()
	_game.match_config = config
	add_child(_game)

func _on_exit_to_lobby() -> void:
	if _game:
		_game.queue_free()
		_game = null
	_show_lobby()

