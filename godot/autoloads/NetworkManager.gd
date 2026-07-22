## Peer abstraction: switches between offline, ENet (LAN), and Steam transports.
## All game code interacts with multiplayer through standard Godot RPC — never
## directly with ENetMultiplayerPeer or SteamMultiplayerPeer.
extends Node

enum NetMode { OFFLINE, ENET_LAN, STEAM }

const ENET_PORT: int = 7777
const MAX_PEERS: int = 6

var mode: NetMode = NetMode.OFFLINE
## The player_id this instance controls (set by server via assign_local_player).
var local_player_id: String = ""

var _enet_peer: ENetMultiplayerPeer = null

## Server-side: maps multiplayer peer_id → game player_id
var _peer_to_player_id: Dictionary = {}
## Server-side: next AWAY/THIRD team slot to assign to incoming clients
var _next_client_team: int = 1

# ── Input buffer: server collects one InputPacket per peer per tick ─────────────
var _input_buffer: Dictionary = {}    # peer_id (int) -> InputPacket

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	go_offline()   # establishes OfflineMultiplayerPeer so authority checks work

# ── Host / Join (ENet) ─────────────────────────────────────────────────────────

func host_enet(port: int = ENET_PORT) -> Error:
	_enet_peer = ENetMultiplayerPeer.new()
	var err := _enet_peer.create_server(port, MAX_PEERS)
	if err != OK:
		push_error("NetworkManager: ENet host failed: " + str(err))
		return err
	multiplayer.multiplayer_peer = _enet_peer
	mode = NetMode.ENET_LAN
	local_player_id = "0_00"   # server owns home team player 0
	_peer_to_player_id[1] = local_player_id
	EventBus.lobby_created.emit(0)
	return OK

func join_enet(address: String, port: int = ENET_PORT) -> Error:
	_enet_peer = ENetMultiplayerPeer.new()
	var err := _enet_peer.create_client(address, port)
	if err != OK:
		push_error("NetworkManager: ENet join failed: " + str(err))
		return err
	multiplayer.multiplayer_peer = _enet_peer
	mode = NetMode.ENET_LAN
	return OK

func go_offline() -> void:
	if _enet_peer:
		_enet_peer.close()
		_enet_peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	mode = NetMode.OFFLINE
	local_player_id = "0_00"
	_peer_to_player_id.clear()
	_next_client_team = 1

# ── Peer → player mapping ──────────────────────────────────────────────────────

func register_peer_player(peer_id: int, player_id: String) -> void:
	_peer_to_player_id[peer_id] = player_id

func get_player_id_for_peer(peer_id: int) -> String:
	return _peer_to_player_id.get(peer_id, "")

## Server calls this to tell a client which player_id they own.
@rpc("authority", "reliable")
func assign_local_player(player_id: String) -> void:
	local_player_id = player_id

# ── RPC: client → server (input submission) ────────────────────────────────────

@rpc("any_peer", "unreliable_ordered")
func submit_input(packet_bytes: PackedByteArray) -> void:
	if not multiplayer.is_server():
		return
	var packet := InputPacket.deserialize(packet_bytes)
	var sender := multiplayer.get_remote_sender_id()
	packet.player_id = get_player_id_for_peer(sender)
	_input_buffer[sender] = packet

# ── RPC: server → clients (authoritative snapshot) ─────────────────────────────

@rpc("authority", "unreliable_ordered")
func receive_snapshot(snapshot_bytes: PackedByteArray) -> void:
	if multiplayer.is_server():
		return
	var snapshot := GameSnapshot.deserialize(snapshot_bytes)
	get_tree().call_group("client_predictors", "reconcile", snapshot)

# ── Server tick ────────────────────────────────────────────────────────────────

func apply_buffered_inputs(game_scene: Node) -> void:
	for peer_id in _input_buffer:
		var packet: InputPacket = _input_buffer[peer_id]
		var pid := packet.player_id
		if pid.is_empty():
			pid = get_player_id_for_peer(peer_id)
		var player_node: Node = game_scene.get_player_node(pid)
		if player_node:
			player_node.apply_input(InputState.from_packet(packet))
	_input_buffer.clear()

func broadcast_snapshot(snapshot: GameSnapshot) -> void:
	receive_snapshot.rpc(snapshot.serialize())

# ── Connection callbacks ────────────────────────────────────────────────────────

func _on_peer_connected(id: int) -> void:
	EventBus.peer_connected.emit(id)

func _on_peer_disconnected(id: int) -> void:
	_peer_to_player_id.erase(id)
	EventBus.peer_disconnected.emit(id)

func _on_connected_to_server() -> void:
	local_player_id = ""   # will be set by server via assign_local_player RPC

func _on_connection_failed() -> void:
	push_error("NetworkManager: connection to server failed")
	go_offline()

func is_server() -> bool:
	return multiplayer.is_server()
