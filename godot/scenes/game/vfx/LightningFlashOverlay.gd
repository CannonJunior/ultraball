class_name LightningFlashOverlay
extends CanvasLayer

## Full-screen flash overlay for lightning bolt impacts.
## Sits at CanvasLayer 15 (above HUD layer 10).
## Call play("bolt_flash") or play("chain_flash") on impact.

var _flash_rect: ColorRect
var _anim_player: AnimationPlayer

func _ready() -> void:
	layer = 15

	_flash_rect = ColorRect.new()
	_flash_rect.name = "FlashRect"
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.color = Color(0.70, 0.88, 1.0, 0.0)
	add_child(_flash_rect)

	_anim_player = AnimationPlayer.new()
	_anim_player.name = "AnimationPlayer"
	add_child(_anim_player)

	_build_animations()
	add_to_group("lightning_flash")

func play(anim_name: String) -> void:
	_flash_rect.color.a = 0.0
	_anim_player.stop()
	_anim_player.play(anim_name)

func stop_flash() -> void:
	_anim_player.stop()
	_flash_rect.color.a = 0.0

func _build_animations() -> void:
	var lib := AnimationLibrary.new()

	# Single bolt: sharp blue-white spike, fast decay in 0.30s
	var bolt := _make_animation(0.30, [
		[0.000, 0.55],
		[0.045, 0.00],
		[0.300, 0.00],
	])
	lib.add_animation("bolt_flash", bolt)

	# Chain lightning: stronger first hit, echo pulse, 0.45s total
	var chain := _make_animation(0.45, [
		[0.000, 0.70],
		[0.050, 0.08],
		[0.160, 0.25],
		[0.210, 0.00],
		[0.450, 0.00],
	])
	lib.add_animation("chain_flash", chain)

	_anim_player.add_animation_library("", lib)

func _make_animation(length: float, keyframes: Array) -> Animation:
	var anim := Animation.new()
	anim.length = length
	var track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, NodePath("FlashRect:color:a"))
	anim.value_track_set_update_mode(track, Animation.UPDATE_CONTINUOUS)
	anim.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
	for kf in keyframes:
		anim.track_insert_key(track, float(kf[0]), float(kf[1]))
	return anim
