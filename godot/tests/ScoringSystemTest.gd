## Unit tests for ScoringSystem — killa scoring, explosion, act timer, game over.
##
## Run headlessly:
##   godot4 --headless --path godot/ tests/ScoringSystemTest.tscn
extends Node

var _sys: Node = null

func _ready() -> void:
	_sys = load("res://systems/ScoringSystem.gd").new()
	add_child(_sys)
	await get_tree().process_frame
	_run_tests()

func _run_tests() -> void:
	var passed := 0
	var failed := 0

	for result in [
		_test_killa_score_on_player_death(),
		_test_killa_increments_kills_count(),
		_test_killa_unique_victim_tracked(),
		_test_killa_buff_emitted_for_killer(),
		_test_no_killa_without_killer(),
		_test_explosion_killa_2team(),
		_test_explosion_killa_3team_cycles(),
		_test_determine_winner_picks_highest(),
		_test_act_timer_expiry_sets_act_ended(),
		_test_act_5_expiry_triggers_game_over(),
	]:
		if result.ok:
			passed += 1
			print("PASS  ", result.name)
		else:
			failed += 1
			print("FAIL  ", result.name, " — ", result.msg)

	print("")
	print("Results: %d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)

func _r(name: String, ok: bool, msg: String = "") -> Dictionary:
	return {"name": name, "ok": ok, "msg": msg}

func _make_player(pid: String, team: int) -> MatchState.PlayerRecord:
	var rec := MatchState.PlayerRecord.new()
	rec.player_id    = pid
	rec.team_id      = team
	rec.is_alive     = true
	rec.is_on_field  = true
	rec.class_id     = "wrecker"
	rec.display_name = pid
	return rec

func _reset() -> void:
	MatchState.reset_for_new_match()
	MatchState.is_three_team = false

# ── Tests ──────────────────────────────────────────────────────────────────────

func _test_killa_score_on_player_death() -> Dictionary:
	const NAME := "player_died with killer → killer team scores 1 killa point"
	_reset()
	MatchState.players["killer"] = _make_player("killer", 0)
	MatchState.players["victim"] = _make_player("victim", 1)
	EventBus.player_died.emit("victim", "combat", "killer")
	var ok := MatchState.scores[0] == ScoringSystem.KILLA_POINTS
	_reset()
	return _r(NAME, ok, "" if ok else "scores[0]=%d" % MatchState.scores[0])

func _test_killa_increments_kills_count() -> Dictionary:
	const NAME := "player_died → kills[killer_team] incremented"
	_reset()
	MatchState.players["k"] = _make_player("k", 1)
	MatchState.players["v"] = _make_player("v", 0)
	EventBus.player_died.emit("v", "combat", "k")
	var ok := MatchState.kills[1] == 1
	_reset()
	return _r(NAME, ok, "" if ok else "kills[1]=%d" % MatchState.kills[1])

func _test_killa_unique_victim_tracked() -> Dictionary:
	const NAME := "player_died → victim added once to kills_unique[killer_team]"
	_reset()
	MatchState.players["k"] = _make_player("k", 0)
	MatchState.players["v"] = _make_player("v", 1)
	EventBus.player_died.emit("v", "combat", "k")
	EventBus.player_died.emit("v", "combat", "k")   # second kill of same victim
	var unique: Array = MatchState.kills_unique[0]
	var ok: bool = unique.count("v") == 1   # tracked only once
	_reset()
	return _r(NAME, ok, "" if ok else "victim count=%d" % MatchState.kills_unique[0].count("v"))

func _test_killa_buff_emitted_for_killer() -> Dictionary:
	const NAME := "player_died with killer → buff_applied ultra_mana_gain emitted for killer"
	_reset()
	MatchState.players["k"] = _make_player("k", 0)
	MatchState.players["v"] = _make_player("v", 1)
	var s := {"ok": false}
	var conn := func(pid: String, bname: String, _dur: float):
		if pid == "k" and bname == "ultra_mana_gain": s["ok"] = true
	EventBus.buff_applied.connect(conn)
	EventBus.player_died.emit("v", "combat", "k")
	EventBus.buff_applied.disconnect(conn)
	var got_buff: bool = s["ok"]
	_reset()
	return _r(NAME, got_buff, "" if got_buff else "buff_applied not received")

func _test_no_killa_without_killer() -> Dictionary:
	const NAME := "player_died with empty killer → no killa point awarded"
	_reset()
	MatchState.players["v"] = _make_player("v", 1)
	EventBus.player_died.emit("v", "pit", "")
	var ok := MatchState.scores[0] == 0 and MatchState.scores[1] == 0
	_reset()
	return _r(NAME, ok, "" if ok else "unexpected score after no-killer death")

func _test_explosion_killa_2team() -> Dictionary:
	const NAME := "ball_exploded (2-team) → opposing team gains killa point"
	_reset()
	MatchState.is_three_team = false
	MatchState.players["holder"] = _make_player("holder", 0)
	EventBus.ball_exploded.emit("holder")
	var ok := MatchState.scores[1] == ScoringSystem.KILLA_POINTS and MatchState.scores[0] == 0
	_reset()
	return _r(NAME, ok, "" if ok else "scores=%s" % str(MatchState.scores))

func _test_explosion_killa_3team_cycles() -> Dictionary:
	const NAME := "ball_exploded (3-team) → (victim_team+1)%%3 gains killa"
	_reset()
	MatchState.is_three_team = true
	# Team 0 holds and explodes → team 1 should gain
	MatchState.players["holder"] = _make_player("holder", 0)
	EventBus.ball_exploded.emit("holder")
	var ok := MatchState.scores[1] == ScoringSystem.KILLA_POINTS \
		   and MatchState.scores[0] == 0 and MatchState.scores[2] == 0
	_reset()
	return _r(NAME, ok, "" if ok else "scores=%s" % str(MatchState.scores))

func _test_determine_winner_picks_highest() -> Dictionary:
	const NAME := "_determine_winner picks team with highest score"
	_reset()
	MatchState.scores = [3, 14, 7]
	var winner: int = int(_sys.call("_determine_winner"))
	_reset()
	return _r(NAME, winner == 1, "" if winner == 1 else "winner=%d" % winner)

func _test_act_timer_expiry_sets_act_ended() -> Dictionary:
	const NAME := "act timer at zero → _end_current_act sets act_ended = true"
	_reset()
	MatchState.match_active = true
	MatchState.act_ended    = false
	MatchState.game_over    = false
	MatchState.current_act  = 1
	MatchState.act_timer    = 0.0
	_sys.call("_physics_process", 0.1)   # forced tick: timer goes negative → _end_current_act
	var ok: bool = MatchState.act_ended
	_reset()
	return _r(NAME, ok, "" if ok else "act_ended still false after simulated tick")

func _test_act_5_expiry_triggers_game_over() -> Dictionary:
	const NAME := "act 5 timer at zero → _end_current_act triggers game_over"
	_reset()
	MatchState.match_active = true
	MatchState.act_ended    = false
	MatchState.game_over    = false
	MatchState.current_act  = 5
	MatchState.act_timer    = 0.0
	_sys.call("_physics_process", 0.1)
	var ok: bool = MatchState.game_over
	_reset()
	return _r(NAME, ok, "" if ok else "game_over false after simulated act-5 tick")
