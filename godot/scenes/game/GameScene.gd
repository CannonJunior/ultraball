class_name GameScene
extends Node2D

## Thin orchestrator: initialises systems, spawns entities, and handles pause.
## All game logic lives in systems; this node wires them together.

const _BalancedStrategy = preload("res://systems/ai/strategies/BalancedStrategy.gd")
const _BalancedTactics   = preload("res://systems/ai/tactics/BalancedTactics.gd")
const _HUD               = preload("res://scenes/game/hud/HUD.gd")

@export var match_config: MatchConfig

@onready var ability_system: AbilitySystem = $Systems/AbilitySystem
@onready var ball_system: BallSystem = $Systems/BallSystem
@onready var scoring_system: ScoringSystem = $Systems/ScoringSystem
@onready var substitution_system: SubstitutionSystem = $Systems/SubstitutionSystem
@onready var terrain_system: TerrainMutationSystem = $Systems/TerrainMutationSystem
@onready var collision_system: CollisionSystem = $Systems/CollisionSystem
@onready var creature_system: CreatureSystem = $Systems/CreatureSystem

@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner
@onready var hud: CanvasLayer = $HUD

var _tick: int = 0
## Tracks how many non-server client teams have been assigned so far.
var _clients_assigned: int = 0

func _ready() -> void:
	if match_config == null:
		push_error("GameScene: no MatchConfig assigned")
		return
	MatchState.config = match_config
	MatchState.is_three_team = match_config.match_mode == MatchConfig.MatchMode.THREE_TEAM
	_populate_roster()
	_spawn_initial_players()
	_start_match()
	# HUD
	var hud_control: Control = _HUD.new()
	hud.add_child(hud_control)
	# Network: add ClientPredictor for this instance if it is a client
	if NetworkManager.mode != NetworkManager.NetMode.OFFLINE and not NetworkManager.is_server():
		var predictor := ClientPredictor.new()
		predictor.name = "ClientPredictor"
		add_child(predictor)
	# Server: handle future peer connections (assign player authority)
	EventBus.peer_connected.connect(_on_peer_connected)
	# Handle peers that connected before GameScene was instantiated (normal lobby flow)
	if NetworkManager.is_server() and NetworkManager.mode != NetworkManager.NetMode.OFFLINE:
		for peer_id in multiplayer.get_peers():
			_on_peer_connected(peer_id)

func _physics_process(_delta: float) -> void:
	_tick += 1
	if NetworkManager.is_server():
		NetworkManager.apply_buffered_inputs(self)
		var snapshot := GameSnapshot.capture(MatchState, _tick)
		NetworkManager.broadcast_snapshot(snapshot)

func get_player_node(player_id: String) -> Node:
	for n in get_tree().get_nodes_in_group("players"):
		if n.player_id == player_id: return n
	return null

# ── Roster initialization ──────────────────────────────────────────────────────

func _populate_roster() -> void:
	var cfg := match_config
	_add_team_roster(0, cfg.home_player_names, cfg.home_team_name)
	_add_team_roster(1, cfg.away_player_names, cfg.away_team_name)
	if MatchState.is_three_team:
		_add_team_roster(2, cfg.third_player_names, cfg.third_team_name)

func _add_team_roster(team_id: int, names: PackedStringArray, _team_name: String) -> void:
	for i in 8:
		var rec := MatchState.PlayerRecord.new()
		rec.player_id = "%d_%02d" % [team_id, i]
		rec.team_id = team_id
		rec.class_id = GameRegistry.class_id_for_roster_index(i)
		rec.roster_slot = i
		rec.deploy_slot = i
		rec.display_name = names[i] if i < names.size() else ("P%d" % i)
		rec.is_alive = true
		rec.is_on_field = i < 4
		MatchState.players[rec.player_id] = rec

# ── Player spawning ────────────────────────────────────────────────────────────

func _spawn_initial_players() -> void:
	for pid in MatchState.players:
		var rec: MatchState.PlayerRecord = MatchState.players[pid]
		if not rec.is_on_field: continue
		_spawn_player(rec)

func _spawn_player(rec: MatchState.PlayerRecord) -> void:
	var scene: PackedScene = preload("res://scenes/entities/player/Player.tscn")
	var node: Player = scene.instantiate()
	# Named nodes let MultiplayerSpawner track them across peers
	node.name = "Player_%s" % rec.player_id
	node.player_id = rec.player_id
	node.team_id = rec.team_id
	node.class_definition = GameRegistry.get_class_definition(rec.class_id)
	node.global_position = _team_spawn_position(rec.team_id, rec.deploy_slot)
	node.is_on_field = true
	node.is_alive = true
	add_child(node)

func _team_spawn_position(team_id: int, slot: int) -> Vector2:
	if MatchState.is_three_team:
		var norm: Vector2 = MatchState.TEAM3_NORMALS[team_id]
		var perp := Vector2(-norm.y, norm.x)
		var base_dist := MatchState.FIELD3_INRADIUS + 25.0
		var spread := float(slot - 2) * 5.0
		return Vector2(
			MatchState.FIELD3_CX + norm.x * base_dist + perp.x * spread,
			MatchState.FIELD3_CY + norm.y * base_dist + perp.y * spread
		)
	var row := float(slot % 4) * 10.0 + 5.0
	match team_id:
		0: return Vector2(10.0, row)
		1: return Vector2(130.0, row)
		2: return Vector2(70.0, row)
	return Vector2(70.0, 20.0)

# ── Match start ────────────────────────────────────────────────────────────────

func _start_match() -> void:
	MatchState.match_active = true
	MatchState.act_timer = MatchState.act_duration()
	_spawn_ai_directors()
	EventBus.act_started.emit(1)

func _spawn_ai_directors() -> void:
	var cfg := MatchState.config
	var team_count := 3 if MatchState.is_three_team else 2
	for t in range(1, team_count):
		var director := AiDirector.new()
		director.name = "AiDirector_Team%d" % t
		director.team_id = t
		director.strategy_resource = cfg.ai_strategy_resources[t] if cfg.ai_strategy_resources.size() > t else _BalancedStrategy.new()
		director.tactics_resource  = cfg.ai_tactics_resources[t]  if cfg.ai_tactics_resources.size()  > t else _BalancedTactics.new()
		add_child(director)

# ── Network: assign arriving clients to player slots ──────────────────────────

func _on_peer_connected(peer_id: int) -> void:
	if not NetworkManager.is_server(): return
	# Assign next available non-server team. Convention: server=team0, clients=team1,2,...
	_clients_assigned += 1
	var team_id := _clients_assigned   # 1 for first client, 2 for second, etc.
	var player_id := "%d_00" % team_id
	NetworkManager.register_peer_player(peer_id, player_id)
	# Tell the client which player they own
	NetworkManager.assign_local_player.rpc_id(peer_id, player_id)
	# Grant the client authority over their player node so the guard in
	# Player._physics_process passes on the client side
	var node := get_player_node(player_id)
	if node:
		node.set_multiplayer_authority(peer_id)
	# Remove the AI director for this team (human is now in charge)
	var director := get_node_or_null("AiDirector_Team%d" % team_id)
	if director:
		director.queue_free()
