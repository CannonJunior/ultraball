class_name ManaDrainEffect
extends AbilityEffect

@export var drain_amount: float = 15.0
## 0=Red 1=Blue 2=Yellow 3=All
@export_enum("Red", "Blue", "Yellow", "All") var mana_type: int = 3

func apply(ctx: AbilityContext) -> bool:
	if ctx.target_id.is_empty():
		return false
	EventBus.debuff_applied.emit(ctx.target_id, "mana_drain", 0.0, {
		"amount": drain_amount,
		"mana_type": mana_type,
	})
	return true
