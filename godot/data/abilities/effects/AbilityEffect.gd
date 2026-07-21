class_name AbilityEffect
extends Resource

## Base class for all composable ability effects.
## Subclasses implement apply() and communicate results exclusively
## through EventBus signals — never by calling other systems directly.

## Called by AbilitySystem when the ability fires.
## Returns true if the effect was successfully applied.
func apply(ctx: AbilityContext) -> bool:
	push_error("AbilityEffect.apply() not implemented in: " + resource_path)
	return false
