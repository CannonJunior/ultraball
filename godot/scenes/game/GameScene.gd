class_name GameScene
extends Node2D

## Thin orchestrator: initialises systems, spawns entities, and handles pause.
## All game logic lives in systems; this node wires them together.

const _BalancedStrategy = preload("res://systems/ai/strategies/BalancedStrategy.gd")
const _BalancedTactics   = preload("res://systems/ai/tactics/BalancedTactics.gd")
const _HUD               = preload("res://scenes/game/hud/HUD.gd")
const _ForceField        = preload("res://scenes/entities/ForceField.gd")
const _Creature          = preload("res://scenes/entities/creature/Creature.tscn")

@export var match_config: MatchConfig

@onready var ability_system: AbilitySystem = $Systems/AbilitySystem
@onready var ball_system: BallSystem = $Systems/BallSystem
@onready var scoring_system: ScoringSystem = $Systems/ScoringSystem
@onready var substitution_system: SubstitutionSystem = $Systems/SubstitutionSystem
@onready var terrain_system: TerrainMutationSystem = $Systems/TerrainMutationSystem
@onready var collision_system: CollisionSystem = $Systems/CollisionSystem
@onready var creature_system: CreatureSystem = $Systems/CreatureSystem

@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner

var _tick: int = 0
## Tracks how many non-server client teams have been assigned so far.
var _clients_assigned: int = 0

func _ready() -> void:
	if match_config == null:
		push_error("GameScene: no MatchConfig assigned")
		return
	MatchState.reset_for_new_match()
	MatchState.config = match_config
	MatchState.is_three_team = match_config.match_mode == MatchConfig.MatchMode.THREE_TEAM
	MatchState.is_paused = false
	_populate_roster()
	_spawn_initial_players()
	_spawn_creatures()
	_start_match()
	# HUD
	get_node("HUD").add_child(_HUD.new())

	# Ability VFX layer — world-space one-shot effects (self-disables in 3D modes)
	var vfx_layer := preload("res://systems/AbilityVfxLayer.gd").new()
	vfx_layer.name = "AbilityVfxLayer"
	add_child(vfx_layer)

	# Lightning flash overlay — full-screen colour flash on bolt impact (CanvasLayer 15)
	var flash_overlay := preload("res://scenes/game/vfx/LightningFlashOverlay.gd").new()
	flash_overlay.name = "LightningFlashOverlay"
	add_child(flash_overlay)

	# Thunder audio manager — polyphonic playback stub, active when SFX assets are present
	var thunder_audio := preload("res://systems/ThunderAudio.gd").new()
	thunder_audio.name = "ThunderAudio"
	add_child(thunder_audio)

	# 3D/3Q visual layer — hides 2D world and renders a live 3D mirror
	if match_config.view_mode != MatchConfig.ViewMode.FLAT_2D:
		var view_layer := preload("res://systems/ViewLayer3D.gd").new()
		view_layer.name = "ViewLayer3D"
		view_layer.view_mode = match_config.view_mode
		add_child(view_layer)
		$Field.visible    = false
		$Entities.visible = false
		$Camera2D.enabled = false

	if MatchState.is_three_team:
		_setup_3team_camera()
	# Network: add ClientPredictor for this instance if it is a client
	if NetworkManager.mode != NetworkManager.NetMode.OFFLINE and not NetworkManager.is_server():
		var predictor := ClientPredictor.new()
		predictor.name = "ClientPredictor"
		add_child(predictor)
	EventBus.force_field_spawned.connect(_on_force_field_spawned)
	EventBus.positions_reset.connect(_on_positions_reset)
	EventBus.player_subbed_in.connect(_on_player_subbed_in)
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
	var on_field: int = match_config.players_per_side
	var class_indices: PackedInt32Array = match_config.home_class_indices if team_id == 0 else match_config.away_class_indices
	for i in 15:
		var rec := MatchState.PlayerRecord.new()
		rec.player_id = "%d_%02d" % [team_id, i]
		rec.team_id = team_id
		var player_idx := class_indices[i] if i < class_indices.size() else i
		rec.class_id = GameRegistry.class_id_for_roster_index(player_idx)
		rec.roster_slot = i
		rec.deploy_slot = i
		rec.display_name = names[i] if i < names.size() else ("P%d" % i)
		rec.is_alive = true
		rec.is_on_field = i < on_field
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
	if rec.player_id == NetworkManager.local_player_id:
		node.global_rotation = _team_spawn_rotation(rec.team_id)
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
	var n := match_config.players_per_side if match_config else 7
	var row := 5.0 + (float(slot) / float(max(1, n - 1))) * 30.0
	match team_id:
		0: return Vector2(20.0, row)
		1: return Vector2(120.0, row)
		2: return Vector2(70.0, row)
	return Vector2(70.0, 20.0)

func _team_spawn_rotation(team_id: int) -> float:
	if MatchState.is_three_team:
		# Face inward: forward = -norm, so rotation = atan2(-norm.x, norm.y)
		var norm: Vector2 = MatchState.TEAM3_NORMALS[team_id]
		return atan2(-norm.x, norm.y)
	match team_id:
		0: return PI * 0.5   # face right toward field centre
		1: return -PI * 0.5  # face left toward field centre
	return 0.0

# ── Creature spawning ──────────────────────────────────────────────────────────

func _spawn_creatures() -> void:
	var num_teams := 3 if MatchState.is_three_team else 1
	for t in num_teams:
		var creature := _Creature.instantiate()
		creature.team_id = t
		creature.name = "Creature%d" % t
		$Entities.add_child(creature)

# ── Match start ────────────────────────────────────────────────────────────────

func _start_match() -> void:
	MatchState.match_active = true
	MatchState.act_timer = MatchState.act_duration()
	_spawn_ai_directors()
	EventBus.act_started.emit(1)

func _spawn_ai_directors() -> void:
	var cfg := MatchState.config
	var team_count := 3 if MatchState.is_three_team else 2
	for t in range(0, team_count):
		# In test mode the away unit is a stationary dummy — no AI director.
		if cfg.test_mode and t == 1:
			continue
		var director := AiDirector.new()
		director.name = "AiDirector_Team%d" % t
		director.team_id = t
		director.strategy_resource = cfg.ai_strategy_resources[t] if cfg.ai_strategy_resources.size() > t else _BalancedStrategy.new()
		director.tactics_resource  = cfg.ai_tactics_resources[t]  if cfg.ai_tactics_resources.size()  > t else _BalancedTactics.new()
		add_child(director)

# ── Network: assign arriving clients to player slots ──────────────────────────

func _setup_3team_camera() -> void:
	var cam: Camera2D = $Camera2D
	if not cam.enabled:
		return
	cam.zoom = Vector2(8.0, 8.0)
	var local_id := NetworkManager.local_player_id
	var player := get_player_node(local_id) if not local_id.is_empty() else null
	if player:
		cam.reparent(player)
		cam.position = Vector2.ZERO
	else:
		cam.global_position = Vector2(MatchState.FIELD3_CX, MatchState.FIELD3_CY)

func _on_positions_reset() -> void:
	for n in get_tree().get_nodes_in_group("players"):
		if not n.is_alive or not n.is_on_field: continue
		var rec: MatchState.PlayerRecord = MatchState.players.get(n.player_id)
		if rec == null: continue
		n.global_position = _team_spawn_position(rec.team_id, rec.deploy_slot)
		n.global_rotation = _team_spawn_rotation(rec.team_id)
		n.velocity = Vector2.ZERO
		n.z_height = 0.0
		n.z_velocity = 0.0

func _on_player_subbed_in(player_id: String, _replaced: String, _team: int) -> void:
	# Existing nodes (players who died and are respawning) handle themselves via
	# Player._on_player_subbed_in. Only act if this player has no node yet (bench reserve).
	if get_player_node(player_id) != null:
		return
	var rec: MatchState.PlayerRecord = MatchState.players.get(player_id)
	if rec == null: return
	_spawn_player(rec)
	# _spawn_player places the node at the field start position; move to endzone instead.
	var node := get_player_node(player_id)
	if node:
		node.global_position = _endzone_spawn_position(rec.team_id)

func _endzone_spawn_position(team_id: int) -> Vector2:
	if MatchState.is_three_team:
		var norm: Vector2 = MatchState.TEAM3_NORMALS[team_id]
		var dist := MatchState.FIELD3_INRADIUS + 25.0
		return Vector2(MatchState.FIELD3_CX + norm.x * dist, MatchState.FIELD3_CY + norm.y * dist)
	match team_id:
		0: return Vector2(10.0, 20.0)
		1: return Vector2(130.0, 20.0)
	return Vector2(70.0, 20.0)

func _on_force_field_spawned(caster_id: String, caster_team_id: int, caster_position: Vector2) -> void:
	var ff := _ForceField.new()
	ff.field_id = "ff_" + caster_id
	ff.caster_id = caster_id
	ff.caster_team_id = caster_team_id
	ff.global_position = caster_position
	add_child(ff)

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
