class_name ENetPeer
extends RefCounted

## Wraps ENetMultiplayerPeer for LAN / localhost development sessions.

var _peer: ENetMultiplayerPeer = null

func host(port: int) -> Error:
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(port, NetworkManager.MAX_PEERS)
	if err != OK:
		push_error("ENetPeer.host() failed: %s on port %d" % [str(err), port])
		return err
	multiplayer.multiplayer_peer = _peer
	return OK

func join(address: String, port: int) -> Error:
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(address, port)
	if err != OK:
		push_error("ENetPeer.join() failed: %s → %s:%d" % [str(err), address, port])
		return err
	multiplayer.multiplayer_peer = _peer
	return OK

func close() -> void:
	if _peer:
		_peer.close()
		_peer = null
