class_name StatTracker
extends Node

func _ready() -> void:
	EventBus.damage_applied.connect(_on_damage_applied)
	EventBus.healing_applied.connect(_on_healing_applied)
	EventBus.killa_scored.connect(_on_killa_scored)
	EventBus.player_died.connect(_on_player_died)
	EventBus.ultra_scored.connect(_on_ultra_scored)
	EventBus.meta_scored.connect(_on_meta_scored)

func _on_damage_applied(attacker_id: String, target_id: String, amount: float, _is_kill: bool) -> void:
	if not attacker_id.is_empty():
		MatchState.stat(attacker_id).dmg += amount
	if not target_id.is_empty():
		MatchState.stat(target_id).taken += amount

func _on_healing_applied(healer_id: String, _target_id: String, amount: float) -> void:
	if not healer_id.is_empty():
		MatchState.stat(healer_id).heal += amount

func _on_killa_scored(_team_id: int, killer_id: String, _victim_id: String) -> void:
	if not killer_id.is_empty():
		MatchState.stat(killer_id).kills += 1

func _on_player_died(player_id: String, _cause: String, _killer_id: String) -> void:
	if not player_id.is_empty():
		MatchState.stat(player_id).deaths += 1

func _on_ultra_scored(_team_id: int, scorer_id: String) -> void:
	if not scorer_id.is_empty():
		MatchState.stat(scorer_id).ub += 1

func _on_meta_scored(_team_id: int, scorer_id: String) -> void:
	if not scorer_id.is_empty():
		MatchState.stat(scorer_id).ca += 1
