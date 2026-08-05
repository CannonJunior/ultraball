class_name ThunderAudio
extends Node

## Polyphonic thunder playback for lightning bolt abilities.
## Pool of 4 AudioStreamPlayers to handle overlapping chain bounces.
## Drop .ogg files into assets/audio/sfx/ and uncomment _SOUNDS to activate.

const _SPEED_OF_SOUND := 12.0   # game units / sec (exaggerated for drama)
const _MAX_VOL_DB     := -6.0
const _MIN_VOL_DB     := -26.0
const _MAX_RANGE      := 55.0

# Uncomment when audio files are available:
# const _SOUNDS: Array[AudioStream] = [
#     preload("res://assets/audio/sfx/thunder_01.ogg"),
#     preload("res://assets/audio/sfx/thunder_02.ogg"),
#     preload("res://assets/audio/sfx/thunder_03.ogg"),
# ]

var _pool: Array[AudioStreamPlayer] = []

func _ready() -> void:
	for i in 4:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	add_to_group("thunder_audio")

## Play thunder for a bolt of bolt_length game-units.
## delay < 0 → compute from distance; delay >= 0 → use directly.
func play_thunder(bolt_length: float, delay: float = -1.0) -> void:
	var player := _get_free()
	if player == null:
		return
	# if _SOUNDS.is_empty(): return   # uncomment with _SOUNDS

	var sound_delay := (bolt_length / _SPEED_OF_SOUND) if delay < 0.0 else delay
	var vol := lerpf(_MAX_VOL_DB, _MIN_VOL_DB,
		clampf(bolt_length / _MAX_RANGE, 0.0, 1.0))

	# player.stream      = _SOUNDS.pick_random()
	player.volume_db   = vol
	player.pitch_scale = randf_range(0.88, 1.14)

	if sound_delay > 0.02:
		await get_tree().create_timer(sound_delay).timeout
	# player.play()   # uncomment with _SOUNDS

func _get_free() -> AudioStreamPlayer:
	for p in _pool:
		if not p.playing:
			return p
	return null  # all slots busy (rare — chain lightning fires in quick succession)
