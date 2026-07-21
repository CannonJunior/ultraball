extends Node

const GAME_SCENE    := preload("res://scenes/game/GameScene.tscn")
const _NetworkLobby := preload("res://scenes/menus/NetworkLobby.gd")

var _lobby: Control = null

func _ready() -> void:
	_show_lobby()

func _show_lobby() -> void:
	_lobby = _NetworkLobby.new()
	_lobby.match_ready.connect(_on_match_ready)
	add_child(_lobby)

func _on_match_ready(config: MatchConfig) -> void:
	if _lobby:
		_lobby.queue_free()
		_lobby = null
	var game: Node = GAME_SCENE.instantiate()
	game.match_config = config
	add_child(game)

