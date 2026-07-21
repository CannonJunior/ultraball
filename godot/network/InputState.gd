class_name InputState

## Per-frame input for a single player.
## Produced by InputManager (local) or reconstructed from InputPacket (network).

var move_direction: Vector2 = Vector2.ZERO
var turn_delta: float = 0.0
var queued_ability_slot: int = 0
var jump_pressed: bool = false
var hold_throw: bool = false
var release_throw: bool = false
var is_aiming: bool = false
var aim_world_position: Vector2 = Vector2.ZERO

static func from_packet(packet: InputPacket) -> InputState:
	var s := InputState.new()
	s.move_direction = Vector2(packet.move_x, packet.move_y)
	s.turn_delta = packet.turn_delta
	s.queued_ability_slot = packet.queued_ability_slot
	s.jump_pressed = packet.has_flag(InputPacket.FLAG_JUMP)
	s.hold_throw = packet.has_flag(InputPacket.FLAG_HOLD_THROW)
	s.release_throw = packet.has_flag(InputPacket.FLAG_RELEASE_THROW)
	s.is_aiming = packet.has_flag(InputPacket.FLAG_IS_AIMING)
	s.aim_world_position = Vector2(packet.aim_x, packet.aim_y)
	return s

func to_packet(tick: int, player_id: String, peer_id: int) -> InputPacket:
	var p := InputPacket.new()
	p.tick = tick
	p.player_id = player_id
	p.peer_id = peer_id
	p.move_x = move_direction.x
	p.move_y = move_direction.y
	p.turn_delta = turn_delta
	p.queued_ability_slot = queued_ability_slot
	if jump_pressed:    p.flags |= InputPacket.FLAG_JUMP
	if hold_throw:      p.flags |= InputPacket.FLAG_HOLD_THROW
	if release_throw:   p.flags |= InputPacket.FLAG_RELEASE_THROW
	if is_aiming:       p.flags |= InputPacket.FLAG_IS_AIMING
	p.aim_x = aim_world_position.x
	p.aim_y = aim_world_position.y
	return p
