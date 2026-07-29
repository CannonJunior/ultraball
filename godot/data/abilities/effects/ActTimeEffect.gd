class_name ActTimeEffect
extends AbilityEffect

## Adds seconds to the current act timer. Use negative to subtract.
@export var extra_seconds: float = 15.0

func apply(_ctx: AbilityContext) -> bool:
	if not MatchState.match_active or MatchState.act_ended:
		return false
	MatchState.act_timer += extra_seconds
	EventBus.act_timer_changed.emit(MatchState.act_timer)
	var sign_str := "+" if extra_seconds >= 0.0 else ""
	EventBus.event_message_shown.emit(
		"CHRONO SURGE  %s%ds!" % [sign_str, int(extra_seconds)], 2.5)
	return true
