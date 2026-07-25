extends Node
## Autoload — records a screenshot + metadata on every Ultra score.
## Consumers connect to HighlightRecorder.clip_added.

signal clip_added(clip: Dictionary)

const MAX_CLIPS := 20

var clips : Array[Dictionary] = []

func _ready() -> void:
	EventBus.ultra_scored.connect(_on_ultra_scored)

func _on_ultra_scored(team_id: int, scorer_id: String) -> void:
	# Cache scores at the instant of the score event, before await.
	var h   : int = MatchState.scores[0]
	var a   : int = MatchState.scores[1]
	var act : int = MatchState.current_act
	# Wait one frame so the score labels have been rendered into the viewport.
	await get_tree().process_frame
	_record(team_id, scorer_id, h, a, act)

func _record(team_id: int, scorer_id: String, h: int, a: int, act: int) -> void:
	var prec = MatchState.players.get(scorer_id)
	var scorer_name: String = prec.display_name if prec else scorer_id

	var cfg := MatchState.config
	var team_name := ""
	if cfg:
		match team_id:
			0: team_name = cfg.home_team_name
			1: team_name = cfg.away_team_name
			2: team_name = cfg.third_team_name

	var img   := get_viewport().get_texture().get_image()
	var tex   : ImageTexture = ImageTexture.create_from_image(img) \
		if img and not img.is_empty() else null

	var clip := {
		"team_id"     : team_id,
		"scorer_name" : scorer_name,
		"team_name"   : team_name,
		"score_type"  : "ULTRA",
		"home_score"  : h,
		"away_score"  : a,
		"act"         : act,
		"texture"     : tex,
	}
	clips.append(clip)
	if clips.size() > MAX_CLIPS:
		clips.pop_front()
	clip_added.emit(clip)
