class_name InputPacket

## Serializable per-tick input snapshot transmitted from client to server.

var tick: int = 0
var player_id: String = ""
var peer_id: int = 0

var move_x: float = 0.0
var move_y: float = 0.0
var turn_delta: float = 0.0
var queued_ability_slot: int = 0   # 0 = no ability this tick

## Bitfield flags
const FLAG_JUMP          := 1 << 0
const FLAG_HOLD_THROW    := 1 << 1
const FLAG_RELEASE_THROW := 1 << 2
const FLAG_IS_AIMING     := 1 << 3
var flags: int = 0

var aim_x: float = 0.0
var aim_y: float = 0.0

func serialize() -> PackedByteArray:
	var buf := PackedByteArray()
	buf.resize(44)
	var offset := 0
	buf.encode_s32(offset, tick);             offset += 4
	buf.encode_s32(offset, peer_id);          offset += 4
	buf.encode_float(offset, move_x);         offset += 4
	buf.encode_float(offset, move_y);         offset += 4
	buf.encode_float(offset, turn_delta);     offset += 4
	buf.encode_s32(offset, queued_ability_slot); offset += 4
	buf.encode_s32(offset, flags);            offset += 4
	buf.encode_float(offset, aim_x);          offset += 4
	buf.encode_float(offset, aim_y);          offset += 4
	# player_id as fixed 8-byte hash (sufficient for session)
	var id_hash := player_id.hash()
	buf.encode_s64(offset, id_hash);          offset += 8
	return buf

static func deserialize(bytes: PackedByteArray) -> InputPacket:
	var p := InputPacket.new()
	var offset := 0
	p.tick = bytes.decode_s32(offset);              offset += 4
	p.peer_id = bytes.decode_s32(offset);           offset += 4
	p.move_x = bytes.decode_float(offset);          offset += 4
	p.move_y = bytes.decode_float(offset);          offset += 4
	p.turn_delta = bytes.decode_float(offset);      offset += 4
	p.queued_ability_slot = bytes.decode_s32(offset); offset += 4
	p.flags = bytes.decode_s32(offset);             offset += 4
	p.aim_x = bytes.decode_float(offset);           offset += 4
	p.aim_y = bytes.decode_float(offset);           offset += 4
	# player_id resolved server-side by peer_id mapping
	return p

func has_flag(flag: int) -> bool:
	return (flags & flag) != 0
