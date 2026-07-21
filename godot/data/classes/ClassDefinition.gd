class_name ClassDefinition
extends Resource

## Unique identifier matching the file name (e.g. "spectre").
@export var class_id: String = ""
@export var display_name: String = ""
@export var description: String = ""

## Base movement speed in m/s (world units per second).
@export var base_speed: float = 8.0
@export var max_health: float = 100.0

## Primary mana type used for most abilities. 0=Red 1=Blue 2=Yellow
@export_enum("Red", "Blue", "Yellow") var primary_mana: int = 0

## Mana regen rate per second for each pool.
@export var red_regen: float = 3.0
@export var blue_regen: float = 4.0
@export var yellow_regen: float = 3.0
## Ultra mana is gained through gameplay events, not regen.

## Visual identity (used by PlayerVisual to tint sprite / mesh).
@export var body_color: Color = Color.WHITE
@export var helmet_color: Color = Color.WHITE
@export var jersey_color: Color = Color.WHITE

## Exactly 10 ability definitions; slot = index + 1.
@export var abilities: Array[AbilityDefinition]
