class_name AbilityDefinition
extends Resource

@export var ability_id: String = ""
@export var display_name: String = ""
@export var description: String = ""

## 1-indexed slot (1–10; slot 10 = ultra).
@export var slot: int = 1
@export var cooldown: float = 5.0
@export var mana_cost: float = 0.0
## 0=None 1=Red 2=Blue 3=Yellow 4=Ultra
@export_enum("None", "Red", "Blue", "Yellow", "Ultra") var mana_type: int = 0

## Range in world units (metres). 0 = self or global.
@export var range: float = 2.5
## When true, the player must hold the key and aim with the cursor.
@export var requires_aim: bool = false
## When true, hits all valid targets in aoe_radius around the impact point.
@export var is_aoe: bool = false
@export var aoe_radius: float = 0.0

## 0=NearestEnemy 1=NearestAlly 2=Self 3=Global 4=TargetedEnemy
## 5=AoEAroundSelf 6=AoEAroundTarget 7=AimedPoint 8=Cone
@export_enum(
	"NearestEnemy", "NearestAlly", "Self", "Global", "TargetedEnemy",
	"AoEAroundSelf", "AoEAroundTarget", "AimedPoint", "Cone"
) var target_mode: int = 0

## Ordered list of effects applied when the ability fires.
@export var effects: Array[AbilityEffect]

## UI metadata ──────────────────────────────────────────────────────────────────
## 0=Damage 1=Heal 2=SelfBuff 3=Support 4=CC 5=Movement 6=Terrain 7=Utility 8=Ultra
@export_enum(
	"Damage", "Heal", "SelfBuff", "Support", "CC",
	"Movement", "Terrain", "Utility", "Ultra"
) var ability_type: int = 0

## Secondary tags for pip indicators: "aoe", "cc", "snare", "fumble"
@export var tags: PackedStringArray
