class_name TerrainShapeEffect
extends AbilityEffect

## 0=Hill 1=Valley 2=MudZone 3=LavaPool 4=IcePatch 5=OpenPit 6=Shockwave
@export_enum("Hill", "Valley", "MudZone", "LavaPool", "IcePatch", "OpenPit", "Shockwave") \
	var shape_type: int = 0
@export var radius: float = 3.0
@export var intensity: float = 1.0
## Duration in seconds. 0 = permanent until overridden.
@export var duration: float = 8.0
## When true, position the effect immediately in front of the caster rather than at aim_position.
@export var use_caster_front: bool = false
@export var front_distance: float = 8.0
## Seconds to flash the area before applying terrain. 0 = immediate (original behaviour).
@export var preview_delay: float = 0.0

## Charge scaling (only active when the parent AbilityDefinition has charge_max > 0).
@export var chargeable: bool = false
@export var charge_max: float = 3.0
@export var charge_min_intensity: float = 0.25
@export var charge_max_intensity: float = 1.5
@export var charge_min_radius: float = 9.0
@export var charge_max_radius: float = 2.0

func apply(ctx: AbilityContext) -> bool:
	var pos: Vector2
	if use_caster_front:
		var fwd := Vector2(sin(ctx.caster_facing), -cos(ctx.caster_facing))
		pos = ctx.caster_position + fwd * front_distance
	else:
		pos = ctx.aim_position if ctx.aim_position != Vector2.ZERO else ctx.caster_position

	var eff_intensity := intensity
	var eff_radius    := radius
	if chargeable and charge_max > 0.0:
		var t := clampf(ctx.charge_t / charge_max, 0.0, 1.0)
		eff_intensity = lerpf(charge_min_intensity, charge_max_intensity, t)
		eff_radius    = lerpf(charge_min_radius, charge_max_radius, t)

	var type_name := _type_name()
	EventBus.damage_indicator_spawned.emit(pos, _terrain_label(), "terrain")
	if preview_delay > 0.0:
		EventBus.terrain_incoming.emit(type_name, pos, eff_radius, duration, eff_intensity)
	elif shape_type == 5:  # OpenPit
		EventBus.pit_opened.emit(pos, eff_radius, duration)
	else:
		EventBus.terrain_modified.emit(type_name, pos, eff_radius, duration, eff_intensity)
	return true

func _type_name() -> String:
	match shape_type:
		0: return "hill"
		1: return "valley"
		2: return "mud"
		3: return "lava"
		4: return "ice"
		5: return "pit"
		6: return "shockwave"
	return "unknown"

func _terrain_label() -> String:
	match shape_type:
		0: return "RAISE HILL"
		1: return "CREVASSE"
		2: return "QUAGMIRE"
		3: return "LAVA POOL"
		4: return "ICE PATCH"
		5: return "FISSURE"
		6: return "SHOCKWAVE"
	return "TERRAIN"
