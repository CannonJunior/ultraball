class_name DashEffect
extends AbilityEffect

@export var distance: float = 6.0
## When true, dashes toward the target. When false, dashes in facing direction.
@export var toward_target: bool = false
## When true, dashes backward (opposite facing direction).
@export var reverse_direction: bool = false
## When true, becomes briefly invulnerable during the dash (dodge frames).
@export var invulnerable: bool = false
@export var invulnerable_duration: float = 0.15

func apply(ctx: AbilityContext) -> bool:
	var direction: Vector2
	if toward_target and not ctx.target_id.is_empty():
		direction = (ctx.target_position - ctx.caster_position).normalized()
	else:
		direction = Vector2.from_angle(ctx.caster_facing)
	if reverse_direction:
		direction = -direction

	EventBus.buff_applied.emit(ctx.caster_id, "dash", 0.0)
	# DashEffect emits a movement impulse; PlayerBuffs applies velocity override.
	EventBus.debuff_applied.emit(ctx.caster_id, "dash_impulse", 0.1, {
		"direction": direction,
		"distance": distance,
	})
	if invulnerable:
		EventBus.buff_applied.emit(ctx.caster_id, "dodge", invulnerable_duration)
	return true
