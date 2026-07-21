class_name TerrainShapeEffect
extends AbilityEffect

## 0=Hill 1=Valley 2=MudZone 3=LavaPool 4=IcePatch 5=OpenPit 6=Shockwave
@export_enum("Hill", "Valley", "MudZone", "LavaPool", "IcePatch", "OpenPit", "Shockwave") \
	var shape_type: int = 0
@export var radius: float = 3.0
@export var intensity: float = 1.0
## Duration in seconds. 0 = permanent until overridden.
@export var duration: float = 8.0

func apply(ctx: AbilityContext) -> bool:
	var pos := ctx.aim_position if ctx.aim_position != Vector2.ZERO else ctx.caster_position
	var type_name := _type_name()
	if shape_type == 5:  # OpenPit
		EventBus.pit_opened.emit(pos, radius, duration)
	else:
		EventBus.terrain_modified.emit(type_name, pos, radius, duration, intensity)
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
