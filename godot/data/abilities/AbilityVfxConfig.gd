class_name AbilityVfxConfig
extends Resource

## Per-ability VFX configuration for casting, traversal, and impact effects.
## Set on AbilityDefinition.vfx_config. Null = AbilityVfxLayer uses generic inference.

## Cast effect at the caster's position when the ability fires.
## 0=none 1=ring 2=double_ring 3=petals 4=compressed_rings 5=spiral 6=cross_burst 7=strike_flash
## 8=heal_spiral 9=blue_cloud 10=lightning_discharge 11=chain_burst
@export_enum("none","ring","double_ring","petals","compressed_rings","spiral","cross_burst",
	"strike_flash","heal_spiral","blue_cloud","lightning_discharge","chain_burst")
var cast_type: int = 0
@export var cast_color: Color = Color(0, 0, 0, 0)
@export var cast_radius: float = 0.8
@export var cast_duration: float = 0.3

## Traversal effect traveling from caster to each hit target.
## 0=none 1=mote_ribbon 2=strike_line 3=disc_projectile 4=ring_projectile
## 5=heal_spiral_travel 6=blue_cloud_stream
@export_enum("none","mote_ribbon","strike_line","disc_projectile","ring_projectile",
	"heal_spiral_travel","blue_cloud_stream")
var traversal_type: int = 0
@export var traversal_color: Color = Color(0, 0, 0, 0)
@export var traversal_duration: float = 0.5
@export var traversal_count: int = 5    # mote count for mote_ribbon
@export var traversal_lines: int = 1   # parallel lines for strike_line

## Impact effect at each hit target's position.
## 0=none 1=burst_ring 2=rising_orbs 3=shield_collapse 4=sparks 5=two_phase
## 6=heal_shower 7=blue_cloud_impact
@export_enum("none","burst_ring","rising_orbs","shield_collapse","sparks","two_phase",
	"heal_shower","blue_cloud_impact")
var impact_type: int = 0
@export var impact_color: Color = Color(0, 0, 0, 0)
@export var impact_radius: float = 0.8
@export var impact_phase2_delay: float = 0.0
@export var impact_phase2_color: Color = Color(0, 0, 0, 0)

## Sustained field that persists for sustained_duration seconds after cast.
## 0=none 1=sustained_pulse (follows target) 2=rotating_arcs (stays at cast position)
@export_enum("none","sustained_pulse","rotating_arcs")
var sustained_type: int = 0
@export var sustained_color: Color = Color(0, 0, 0, 0)
@export var sustained_radius: float = 1.0
@export var sustained_duration: float = 10.0

## HUD: CharacterPanel slot flash color on success. Color(0,0,0,0) = use default lime.
@export var cast_flash_color: Color = Color(0, 0, 0, 0)

## HUD: Scoreboard avatar tint while this ability's lasting effect is active on a unit.
@export var active_tint_color: Color = Color(0, 0, 0, 0)
## 0=none 1=pulse 2=throb
@export_enum("none","pulse","throb") var active_tint_mode: int = 0
