extends Node
## Autoload — records a rolling frame buffer and metadata on every Ultra score.
## Consumers connect to HighlightRecorder.clip_added.
## clip dict keys: team_id, scorer_name, team_name, score_type, home_score,
##                 away_score, act, texture (last frame), frames (Array[ImageTexture])

signal clip_added(clip: Dictionary)

const MAX_CLIPS     := 20
const CAPTURE_EVERY := 6     # capture 1 frame per N process frames (~10 fps at 60 Hz)
const RING_SIZE     := 25    # frames kept in ring buffer (~2.5 s of footage)
const THUMB_SCALE   := 0.20  # scale captures to 20 % of viewport resolution

var clips : Array[Dictionary] = []

var _ring       : Array = []  # Array[ImageTexture], circular
var _ring_head  : int   = 0
var _frame_tick : int   = 0

func _ready() -> void:
	EventBus.ultra_scored.connect(_on_ultra_scored)

func _process(_delta: float) -> void:
	if not MatchState.match_active: return
	_frame_tick += 1
	if _frame_tick % CAPTURE_EVERY != 0: return
	_capture_frame()

func _capture_frame() -> void:
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty(): return
	var w := maxi(1, int(img.get_width()  * THUMB_SCALE))
	var h := maxi(1, int(img.get_height() * THUMB_SCALE))
	img.resize(w, h, Image.INTERPOLATE_BILINEAR)
	var tex := ImageTexture.create_from_image(img)
	if _ring.size() < RING_SIZE:
		_ring.append(tex)
	else:
		_ring[_ring_head] = tex
	_ring_head = (_ring_head + 1) % RING_SIZE

func _on_ultra_scored(team_id: int, scorer_id: String) -> void:
	var h   : int = MatchState.scores[0]
	var a   : int = MatchState.scores[1]
	var act : int = MatchState.current_act
	# Wait one frame so the score labels are rendered before capturing the final frame.
	await get_tree().process_frame
	_capture_frame()
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

	# Extract ring buffer in chronological order (oldest → newest).
	var frames: Array = []
	if _ring.size() < RING_SIZE:
		frames = _ring.duplicate()
	else:
		frames.resize(RING_SIZE)
		for i in RING_SIZE:
			frames[i] = _ring[(_ring_head + i) % RING_SIZE]

	var tex: ImageTexture = frames.back() if not frames.is_empty() else null

	var clip := {
		"team_id"     : team_id,
		"scorer_name" : scorer_name,
		"team_name"   : team_name,
		"score_type"  : "ULTRA",
		"home_score"  : h,
		"away_score"  : a,
		"act"         : act,
		"texture"     : tex,
		"frames"      : frames,
	}
	clips.append(clip)
	if clips.size() > MAX_CLIPS:
		clips.pop_front()
	clip_added.emit(clip)
