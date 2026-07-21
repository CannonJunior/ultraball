class_name SteamPeer
extends RefCounted

## Wraps SteamMultiplayerPeer from the GodotSteam addon.
## Requires addons/godotsteam/ to be installed and Steam.initialize() called at startup.
##
## Usage:
##   var steam_peer := SteamPeer.new()
##   steam_peer.host_lobby(4)          # creates a public lobby for up to 4 members
##   steam_peer.join_lobby(lobby_id)   # join a known lobby by ID

## Emits lobby_id when a lobby is successfully created.
signal lobby_created(lobby_id: int)
## Emits lobby_id when successfully joined.
signal lobby_joined(lobby_id: int)

var _pending_lobby_id: int = 0

func host_lobby(max_members: int = 4) -> void:
	if not _steam_available():
		push_error("SteamPeer: Steam is not initialized")
		return
	Steam.lobby_created.connect(_on_steam_lobby_created, CONNECT_ONE_SHOT)
	Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, max_members)

func join_lobby(lobby_id: int) -> void:
	if not _steam_available():
		push_error("SteamPeer: Steam is not initialized")
		return
	_pending_lobby_id = lobby_id
	Steam.lobby_joined.connect(_on_steam_lobby_joined, CONNECT_ONE_SHOT)
	Steam.joinLobby(lobby_id)

func close() -> void:
	if multiplayer.multiplayer_peer and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

# ── Steam callbacks ────────────────────────────────────────────────────────────

func _on_steam_lobby_created(connect: int, lobby_id: int) -> void:
	if connect != 1:   # k_EResultOK = 1
		push_error("SteamPeer: lobby creation failed: " + str(connect))
		return
	var steam_mp := SteamMultiplayerPeer.new()
	steam_mp.create_host(0)
	multiplayer.multiplayer_peer = steam_mp
	EventBus.lobby_created.emit(lobby_id)
	emit_signal("lobby_created", lobby_id)

func _on_steam_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	const SUCCESS := 1   # k_EChatRoomEnterResponseSuccess
	if response != SUCCESS:
		push_error("SteamPeer: failed to join lobby %d — response %d" % [lobby_id, response])
		return
	var owner_id := Steam.getLobbyOwner(lobby_id)
	var steam_mp := SteamMultiplayerPeer.new()
	steam_mp.create_client(owner_id, 0)
	multiplayer.multiplayer_peer = steam_mp
	EventBus.lobby_joined.emit(lobby_id)
	emit_signal("lobby_joined", lobby_id)

func _steam_available() -> bool:
	return ClassDB.class_exists("Steam")
